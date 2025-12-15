#!/bin/bash

# Usage

usage (){

	cat <<USAGE
	
	Usage:
	
	`basename $0` -d <path> -p <subid> <other options>
	
	Description:
	
	Project MD metrics from qsimeasure.py to fsaverage and subject-specific template surfaces. Subject-specific surfaces are defined by the 'base' surfaces from FreeSurfer's longitudinal pipeline.
	
	Compulsory arguments:
	
	-d: BIDS directory
	
	-p: Subject ID
	
	Examples:
	
	1. ~/scripts/Personalized-Parkinson-Project-Motor/qsimeasure/project_to_surface.sh -d /project/3022026.01/pep/bids -p sub-POMUAAF1257055021C21
	
	2. ~/scripts/Personalized-Parkinson-Project-Motor/qsimeasure/project_to_surface_sub.sh
	
USAGE

	exit 1

}

# >>> Provide help
[ "$1" == "" ] && usage >&2
[ "$1" == "-h" ] && usage >&2
[ "$1" == "--help" ] && usage >&2

# >>> Get command-line options
while getopts ":d:p:" OPT; do
	case "${OPT}" in
		d)
			echo ">>> -d ${OPTARG}"
			optD=${OPTARG}
		;;
		p)
			echo ">>> -p ${OPTARG}"
			optP=${OPTARG}
		;;
		\?)
			echo ">>> Error: Invalid option -${OPTARG}."
			usage >&2
		;;
		:)
			echo ">>>> Error: Option -${OPTARG} requires an argument."
			usage >&2
		;;
		esac
done
shift $((OPTIND-1))

# >>> Set up environment, directories, and template (adjust as necessary)
#ANTSDIR="/network/iss/apps/software/scit/ANTs/2.5.4"
# FreeSurfer
module unload FreeSurfer; module load FreeSurfer/8.1.0
export fs_dir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.1.0
export SUBJECTS_DIR=${fs_dir}/outputs
export FS_ALLOW_DEEP=1
source $FREESURFER_HOME/SetUpFreeSurfer.sh
# FSL
export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

bidsdir=${optD}
subject=${optP}
qsiprepdir=${bidsdir}/derivatives/qsirecon_1.1.1/derivatives/qsirecon-PYAFQ
qsiprep_sub=${qsiprepdir}/${subject}
fsdir_sub=${SUBJECTS_DIR}/${subject}
mkdir -p ${qsiprep_sub}/wd

# Check mandatory arguments
if [ ! "$bidsdir" ] || [ ! "$subject" ]; then
  echo ">>> Error: arguments -d, -p must be provided"
  usage >&2
fi

# Check QSIprep output
if [ ! -d "${qsiprepdir}/${subject}" ]; then
	echo ">>> Error: PyAFQ output missing"
	exit 1
fi
# Check if already processed (need a better check condition than this...)
# norms=( $(ls ${qsiprep_sub}/ses*/metrics/*/${nprepend}*.nii.gz) )
# len=${#norms}
# if [ ${len} -gt 0 ]; then
  # echo ">>> Subject already has normalized data, skipping..."
  # exit 0
# fi

# >>> Build within-subject anatomical template
# List images
echo ">>> Finding images for template building..."
IMG_LIST=( $(ls ${qsiprep_sub}/ses*/dwi/*/models/sub-*param-md_dwimap.nii.gz) )
len=${#IMG_LIST[@]}
if [ ${#IMG_LIST[@]} -lt 1 ]; then
	echo ">>> Error: No images to build template from"
 	exit 1
fi
# Template creation
echo ">>> Creating template"
if [ ${len} -gt 1 ]; then
	echo ">>> Multiple images found, running mri_robust_template"
	${FREESURFER_HOME}/bin/mri_robust_template \
	 --satit \
 	 --mov `echo ${IMG_LIST[@]}` \
	 --inittp 1 \
	 --iscale \
	 --template ${qsiprep_sub}/wd/template.nii.gz \
	 --subsample 200
elif [ ${len} -eq 1 ]; then
  	echo ">>> Only 1 image found, copying instead of creating a template"
  	cp ${IMG_LIST[0]} ${qsiprep_sub}/wd/template.nii.gz
else
  	echo ">>> ERROR: Number of images is inappropriate"
	exit 1
fi
${FSLDIR}/bin/fslreorient2std ${qsiprep_sub}/wd/template.nii.gz ${qsiprep_sub}/wd/template.nii.gz

# >>> Loop over sessions
sessions=( $(ls -d ${qsiprep_sub}/ses*) )
len=${#sessions[@]}
for (( i=0; i<${len}; i++ )); do
	ses=`echo ${sessions[i]} | xargs -n1 basename | cut -c 5-`

 	echo ">>> Surface-based projection: session $((${i}+1))"
 
 	# Mask
 	${FSLDIR}/bin/fslreorient2std ${sessions[i]}/dwi/*/models/*desc-brain_mask.nii.gz ${qsiprep_sub}/wd/mask.nii.gz
 
 	# b0-to-base registration (FreeSurfer)
	echo ">>> Running bbregister"
	B0IMG=( $(ls ${sessions[i]}/dwi/*/*desc-masked_b0ref.nii.gz) )
	${FSLDIR}/bin/fslreorient2std ${B0IMG} ${qsiprep_sub}/wd/i${i}_b0.nii.gz
	${FREESURFER_HOME}/bin/bbregister \
	--s ${subject} \
	--mov ${qsiprep_sub}/wd/i${i}_b0.nii.gz \
	--o ${qsiprep_sub}/wd/i${i}_b0_bbreg.nii.gz \
	--init-fsl \
	--reg ${qsiprep_sub}/wd/i${i}_fsregister.dat \
	--lta ${qsiprep_sub}/wd/i${i}_fsregister.lta \
	--dti
 
	metrics=( $(ls ${sessions[i]}/dwi/*/models/sub-*param-md_dwimap.nii.gz) )
 
 	echo ${metrics[@]}
 	lan=${#metrics[@]}
 	for (( j=0; j<${lan}; j++ )); do
 
  # Normalize metric
  in=${metrics[j]}

	# Reorient to FSL standard
	${FSLDIR}/bin/fslreorient2std ${in} ${qsiprep_sub}/wd/metric.nii.gz

	# Surface-based DTI metrics
  echo ">>> Projecting metrics to surface"

  for hemi in "lh" "rh"; do
 
	  #metric_name=`basename -- "${in}" .nii.gz`
	  metric_name='pyAFQ-md'

    echo ">>> Hemisphere: ${hemi}"
    # Generate graymid surfaces as targets of projections
    if [ ! -f ${fsdir_sub}/surf/${hemi}.graymid ]; then
      echo ">>> Generating graymid surfaces"
      ${FREESURFER_HOME}/bin/mris_expand \
			-thickness ${fsdir_sub}/surf/${hemi}.white \
			0.5 \
			${fsdir_sub}/surf/${hemi}.graymid
    fi

    # Multiply input image by a constant: MD values are very small, which causes trouble. Multiplying ensures that the project works properly
    ${FSLDIR}/bin/fslmaths ${qsiprep_sub}/wd/metric.nii.gz -mul 10000 ${qsiprep_sub}/wd/${hemi}_metric.nii.gz

		# Partial volume correction (probably overkill)
		#if [ ! -f ${fsdir_sub}/mri/gtmseg.mgz ]; then
		  # Generate geometric transformation matrix (~1h)
		#	echo ">>> Running gtmseg"
		#  ${FREESURFER_HOME}/bin/gtmseg --s ${subject}
		#fi
		# Run partial volume correction, retaining only voxels that are >50% likely to be grey matter (--mgx .5)
		#echo ">>> Running mri_gtmpvc"
		#${FREESURFER_HOME}/bin/mri_gtmpvc \
		#	--i ${qsiprep_sub}/wd/${hemi}_metric.nii.gz \
		#	--reg ${qsiprep_sub}/wd/i${i}_fsregister.lta \
		#	--seg ${fsdir_sub}/mri/gtmseg.mgz \
		#	--default-seg-merge \
		#	--auto-mask 1 .01 \
		#	--mgx .5 \
		#	--o ${qsiprep_sub}/wd/i${i}_gtmpvc.output
		#cp ${qsiprep_sub}/wd/i${i}_gtmpvc.output/mgx.ctxgm.nii.gz ${qsiprep_sub}/wd/${hemi}_metric_PVC.nii.gz

		# Without PVC
    # Target: fsaverage space (Vol2Surf > smooth > extract)
	  echo ">>> Projecting to fsaverage space (without PVC)"
    ${FREESURFER_HOME}/bin/mris_preproc \
			--iv ${qsiprep_sub}/wd/${hemi}_metric.nii.gz ${qsiprep_sub}/wd/i${i}_fsregister.dat \
			--target fsaverage \
			--out ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_s15.mgz \
			--hemi ${hemi} \
			--projfrac-avg 0.2 0.8 0.1 \
			--cortex-only \
			--fwhm 15
    ${FREESURFER_HOME}/bin/mri_segstats \
			--annot fsaverage ${hemi} aparc \
			--i ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_s15.mgz \
			--o ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.norm.stats \
			--surf white \
			--snr
		${FREESURFER_HOME}/bin/mri_segstats \
			--annot fsaverage ${hemi} aparc.a2009s \
			--i ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_s15.mgz \
			--o ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.a2009s.norm.stats \
			--surf white \
			--snr

		# Target: base T1w space (Vol2Surf > extract)
	  echo ">>> Projecting to base space (without PVC)"
    ${FREESURFER_HOME}/bin/mri_vol2surf \
			--src ${qsiprep_sub}/wd/${hemi}_metric.nii.gz \
			--out ${qsiprep_sub}/wd/i${i}_${hemi}_metric_T1w.mgz \
			--srcreg ${qsiprep_sub}/wd/i${i}_fsregister.dat \
			--hemi ${hemi} \
			--surf white \
			--projfrac-avg 0.2 0.8 0.1 \
			--cortex \
			--noreshape \
			--trgsubject ${subject}
    ${FREESURFER_HOME}/bin/mri_segstats \
			--annot ${subject} ${hemi} aparc \
			--i ${qsiprep_sub}/wd/i${i}_${hemi}_metric_T1w.mgz \
			--o ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.T1w.stats \
			--surf graymid \
			--snr
		${FREESURFER_HOME}/bin/mri_segstats \
			--annot ${subject} ${hemi} aparc.a2009s \
			--i ${qsiprep_sub}/wd/i${i}_${hemi}_metric_T1w.mgz \
			--o ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.a2009s.T1w.stats \
			--surf graymid \
			--snr
		${FREESURFER_HOME}/bin/mri_surf2surf \
			--hemi ${hemi} \
			--srcsubject ${subject} \
			--srcsurfval ${qsiprep_sub}/wd/i${i}_${hemi}_metric_T1w.mgz \
			--trgsubject ${subject} \
			--trgsurfval ${qsiprep_sub}/wd/i${i}_${hemi}_metric_T1w.curv \
			--trg_type curv \
			--noreshape

		# With PVC
    # Target: fsaverage space (Vol2Surf > smooth > extract)
	  #echo ">>> Projecting to fsaverage space (with PVC)"
    #${FREESURFER_HOME}/bin/mris_preproc \
		#	--iv ${qsiprep_sub}/wd/${hemi}_metric_PVC.nii.gz ${qsiprep_sub}/wd/i${i}_fsregister.dat \
		#	--target fsaverage \
		#	--out ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_PVC_s15.mgz \
		#	--hemi ${hemi} \
		#	--projfrac-avg 0.2 0.8 0.1 \
		#	--cortex-only \
		#	--fwhm 15
    #${FREESURFER_HOME}/bin/mri_segstats \
		#	--annot fsaverage ${hemi} aparc \
		#	--i ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_PVC_s15.mgz \
		#	--o ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.norm.PVC.stats \
		#	--surf white \
		#	--snr

    # Target: base T1w space (Vol2Surf > extract)
	  #echo ">>> Projecting to base space (with PVC)"
    #${FREESURFER_HOME}/bin/mri_vol2surf \
		#	--src ${qsiprep_sub}/wd/${hemi}_metric_PVC.nii.gz \
		#	--out ${qsiprep_sub}/wd/i${i}_${hemi}_metric_PVC_T1w.mgz \
		#	--srcreg ${qsiprep_sub}/wd/i${i}_fsregister.dat \
		#	--hemi ${hemi} \
		#	--surf white \
		#	--projfrac-avg 0.2 0.8 0.1 \
		#	--cortex \
		#	--noreshape \
		#	--trgsubject ${subject}
    #${FREESURFER_HOME}/bin/mri_segstats \
		#	--annot ${subject} ${hemi} aparc \
		#	--i ${qsiprep_sub}/wd/i${i}_${hemi}_metric_PVC_T1w.mgz \
		#	--o ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.PVC.T1w.stats \
		#	--surf graymid \
		#	--snr

		# Move final output
		echo ">>> Finalizing output"
		mkdir -p ${sessions[i]}/surfproj
		cp ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_s15.mgz ${sessions[i]}/surfproj/${hemi}_metric_norm_s15.mgz
		cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.norm.stats ${sessions[i]}/surfproj/${hemi}.${metric_name}.aparc.norm.stats
		cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.a2009s.norm.stats ${sessions[i]}/surfproj/${hemi}.${metric_name}.aparc.a2009s.norm.stats
		cp ${qsiprep_sub}/wd/i${i}_${hemi}_metric_T1w.mgz ${sessions[i]}/surfproj/${hemi}_metric_T1w.mgz
		cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.T1w.stats ${sessions[i]}/surfproj/${hemi}.${metric_name}.aparc.T1w.stats
		cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.a2009s.T1w.stats ${sessions[i]}/surfproj/${hemi}.${metric_name}.aparc.a2009s.T1w.stats

		cp ${qsiprep_sub}/wd/${hemi}.i${i}_${hemi}_metric_T1w.curv ${fsdir_sub}_${ses}.long.${subject}/surf/${hemi}.dtimd
		cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.T1w.stats ${fsdir_sub}_${ses}.long.${subject}/stats/${hemi}.${metric_name}.aparc.stats
		cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.aparc.a2009s.T1w.stats ${fsdir_sub}_${ses}.long.${subject}/stats/${hemi}.${metric_name}.aparc.a2009s.stats

		#cp ${qsiprep_sub}/wd/i${i}_${hemi}_metric_norm_PVC_s15.mgz ${sessions[i]}/metrics/freesurfer/${hemi}_metric_norm_PVC_s15.mgz
		#cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.norm.PVC.stats ${sessions[i]}/metrics/freesurfer/${hemi}.${metric_name}.norm.PVC.stats
		#cp ${qsiprep_sub}/wd/i${i}_${hemi}_metric_PVC_T1w.mgz ${sessions[i]}/metrics/freesurfer/${hemi}_metric_PVC_T1w.mgz
		#cp ${qsiprep_sub}/wd/i${i}_${hemi}.${metric_name}.PVC.T1w.stats ${sessions[i]}/metrics/freesurfer/${hemi}.${metric_name}.PVC.T1w.stats
 
   	done

 	done

done

# Clean up
echo ">>> Cleaning up intermediate output"
rm -r ${qsiprep_sub}/wd
echo ">>> DONE!"


