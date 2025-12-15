#!/bin/bash

# Usage

usage (){

	cat <<USAGE
	
	Usage:
	
	`basename $0` -d <path> -p <subid> -t <template> <other options>
	
	Description:
	
	Normalize qsimeasure.py output to MNI-space
	
	Compulsory arguments:
	
	-d: BIDS directory
	
	-p: Subject ID
	
	-t: Template (FMRIB58_FA, HCP1065_FA, HCP1065_MD)
	
	Examples:
	
	1. /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/normalize_dti2mni.sh -d /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4 -p sub-075CJ -t HCP1065_FA
	
	2. /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/normalize_dti2mni_sub.sh
	
USAGE

	exit 1

}

# >>> Provide help
[ "$1" == "" ] && usage >&2
[ "$1" == "-h" ] && usage >&2
[ "$1" == "--help" ] && usage >&2

# >>> Get command-line options
while getopts ":d:p:t:" OPT; do
	case "${OPT}" in
		d)
			echo ">>> -d ${OPTARG}"
			optD=${OPTARG}
		;;
		p)
			echo ">>> -p ${OPTARG}"
			optP=${OPTARG}
		;;
		t)
			echo ">>> -t ${OPTARG}"
			optT=${OPTARG}
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
export ANTSDIR="/network/iss/apps/software/scit/ANTs/2.5.4"
module unload FreeSurfer; module load FreeSurfer/8.1.0
export fs_dir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.1.0
export SUBJECTS_DIR=${fs_dir}/outputs
export FS_ALLOW_DEEP=1
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export SUBJECTS_DIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.1.0/outputs"
export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

bidsdir=${optD}    # bidsdir="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
subject=${optP}    # subject="sub-075CJ"
template=${optT}   # template="HCP1065_FA"
qsiprepdir=${bidsdir}/derivatives/qsiprep_1.0.1
pasternakfwdir="${qsiprepdir}/derivatives/pasternak_fw"
dipyfwdir="${qsiprepdir}/derivatives/dipy_fw"
dipyb0dir="${qsiprepdir}/derivatives/dipy_b0"
amiconoddidir="${qsiprepdir}/derivatives/amico_noddi"
wddir="${qsiprepdir}/derivatives/wd/${subject}"
regdir="${qsiprepdir}/derivatives/reg/${subject}"
mkdir -p ${wddir}
mkdir -p ${regdir}

echo ">>> Template: ${optT}"
# Check mandatory arguments
if [ ! "$bidsdir" ] || [ ! "$subject" ] || [ ! "$template" ]; then
  echo ">>> Error: arguments -d, -p, and -t must be provided"
  usage >&2
fi
# Set template
if [ ${template} == "HCP1065_FA" ]; then
	echo ">>> Using HCP1065_FA (study-specific) as target in normalizations"
	# MNI_img: used to estimate normalization
	MNI_img="/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/T_template0.nii.gz"
	# MNI_img_downsampled: used to visualization purposes (template2mni normalization)
	MNI_img_downsampled="/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/T_template0.nii.gz"
	# MNI_mask: used to define the voxel-size of the output image
	MNI_mask="/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/T_template0_mask.nii.gz"
	nprepend="n2"
	IMGTYPE="FA"
elif [ ${template} == "HCP1065_MD" ]; then
	echo ">>> Using HCP1065_MD_1mm (study-specific) as target in normalizations. CURRENTLY NOT SUPPORTED! EXITING!"
	MNI_img=""
	MNI_img_downsampled=""
	MNI_mask=""
	nprepend="n3"
	IMGTYPE="MD"
	exit 1
elif [ ${template} == "FMRIB58_FA" ]; then
	echo ">>> Using FMRIB58_FA_1mm (study-specific) as target in normalizations. CURRENTLY NOT SUPPORTED! EXITING!"
	MNI_img=""
	MNI_img_downsampled=""
	MNI_mask=""
	nprepend="n1"
	IMGTYPE="FA"
	exit 1
else
  	echo ">>> Error: Template option invalid"
  	usage >&2
fi
# Check QSIprep output
if [ ! -f "${qsiprepdir}/${subject}.html" ]; then
	echo ">>> Error: QSIprep output missing"
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
IMG_LIST=( $(ls ${qsiprepdir}/derivatives/dipy_fw/${subject}/*/sub-*dipy-${IMGTYPE}.nii.gz) )
len=${#IMG_LIST[@]}
if [ ${#IMG_LIST[@]} -lt 1 ]; then
 	echo ">>> Error: No images of type ${IMGTYPE}"
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
 	--template ${wddir}/template.nii.gz \
 	--subsample 200
elif [ ${len} -eq 1 ]; then
  	echo ">>> Only 1 image found, copying"
  	cp ${IMG_LIST[0]} ${wddir}/template.nii.gz
else
  	echo ">>> ERROR: Number of images is inappropriate"
	exit 1
fi
${FSLDIR}/bin/fslreorient2std ${wddir}/template.nii.gz ${wddir}/template.nii.gz

# >>> Estimate template-to-MNI transformation
# Note on the anatomy of a antsRegistration call:
# The command specifies multiple transformations.
# In the call below, there are 3 transformations (--transform), followed by specifications
# for each one: --transform Rigid, --transform Affine, --transform SyN. The order of the
# transformations specifies how they are concatenated in the final composite transform.
echo ">>> Estimating transform: template to MNI"
template2mni=${regdir}/${nprepend}_ants_template_to_mniComposite.h5
if [ ! -f ${template2mni} ]; then
 	echo ">>> No template2mni transform found, estimating..."
 	${ANTSDIR}/bin/antsRegistration --collapse-output-transforms 1 --dimensionality 3 --float 1 --initial-moving-transform [ ${MNI_img}, ${wddir}/template.nii.gz, 1 ] --initialize-transforms-per-stage 0 --interpolation LanczosWindowedSinc --output [ ${regdir}/${nprepend}_ants_template_to_mni, ${wddir}/ants_template_to_mni_Warped.nii.gz ] --transform Rigid[ 0.1 ] --metric Mattes[ ${MNI_img}, ${wddir}/template.nii.gz, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 10 ] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 --use-histogram-matching 1 --transform Affine[ 0.1 ] --metric Mattes[ ${MNI_img}, ${wddir}/template.nii.gz, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 20 ] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 --use-histogram-matching 1 --transform SyN[ 0.1, 3.0, 0.0 ] --metric CC[ ${MNI_img}, ${wddir}/template.nii.gz, 1, 4, None, 1 ] --convergence [ 100x70x50x20, 1e-06, 10 ] --smoothing-sigmas 3.0x2.0x1.0x0.0vox --shrink-factors 8x4x2x1 --use-histogram-matching 1 --winsorize-image-intensities [ 0.005, 0.995 ] --write-composite-transform 1 -v
else
 	echo ">>> Using previously estimated template2mni transformation for normalizations"
fi

# >>> Estimate IMG-to-template transformation
for (( i=0; i<${len}; i++ )); do
 	echo ">>> Estimating transform: IMG to template $((${i}+1))"
 	${FSLDIR}/bin/fslreorient2std ${IMG_LIST[i]} ${wddir}/i${i}_img.nii.gz
  ${ANTSDIR}/bin/antsRegistration --collapse-output-transforms 1 --dimensionality 3 --float 1 --initial-moving-transform [ ${wddir}/template.nii.gz, ${wddir}/i${i}_img.nii.gz, 1 ] --initialize-transforms-per-stage 0 --interpolation LanczosWindowedSinc --output [ ${wddir}/i${i}_img_to_template, ${wddir}/i${i}_img_to_template_Rigid.nii.gz ] --transform Rigid[ 0.1 ] --metric Mattes[ ${wddir}/template.nii.gz, ${wddir}/i${i}_img.nii.gz, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 10 ] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 --use-histogram-matching 1 --winsorize-image-intensities [ 0.005, 0.995 ] --write-composite-transform 1 -v
  # Normalize metric (for quality control purposes only)
 	${ANTSDIR}/bin/antsApplyTransforms --default-value 0 --float 1 --input ${wddir}/i${i}_img.nii.gz --interpolation LanczosWindowedSinc --output ${wddir}/i${i}_img_to_mni_Warped.nii.gz --reference-image ${MNI_mask} --transform ${template2mni} --transform ${wddir}/i*_img_to_templateComposite.h5 --transform identity
done
img2template=( $(ls ${wddir}/i*_img_to_templateComposite.h5) )

# >>> Loop over sessions (unpack tensor, normalize, qc)
sessions=( $(find ${qsiprepdir}/${subject}/ses* -maxdepth 0 -type d | xargs -n1 basename) )
len=${#sessions[@]}
for (( i=0; i<${len}; i++ )); do

 	echo ">>> Applying transformation: IMG to MNI, session $((${i}+1))"
 
 	# Unpack Pasternak's tensors
 	tensor=${pasternakfwdir}/${subject}/${sessions[i]}/${subject}_${sessions[i]}_pasternak_TensorFWCorrected.nii.gz
 	if [ -f ${tensor} ]; then
		${FSLDIR}/bin/fslmaths ${tensor} -tensor_decomp `echo ${tensor} | sed 's/.nii.gz/_dcmp/'`
 	fi
 	tensor=${pasternakfwdir}/${subject}/${sessions[i]}/${subject}_${sessions[i]}_pasternak_*TensorDTINoNeg.nii.gz
 	if [ -f ${tensor} ]; then
		${FSLDIR}/bin/fslmaths ${tensor} -tensor_decomp `echo ${tensor} | sed 's/.nii.gz/_dcmp/'`
 	fi
 
 	# Mask
 	${FSLDIR}/bin/fslreorient2std ${qsiprepdir}/${subject}/${sessions[i]}/dwi/*desc-brain_mask.nii.gz ${wddir}/mask.nii.gz
 
	# If the MD template is used, normalize MD images. Otherwise, normalize FW images. 
 	if [ ${template} == "HCP1065_MD" ]; then
		metrics=""
 	else
		#metrics=( $(ls ${pasternakfwdir}/${subject}/${sessions[i]}/sub-*_FW.nii.gz) $(ls ${dipyfwdir}/${subject}/${sessions[i]}/sub-*_dipy-FW.nii.gz) $(ls ${amiconoddidir}/${subject}/${sessions[i]}/fit_FWF.nii.gz) $(ls ${dipyb0dir}/${subject}/${sessions[i]}/sub-*_dipy-b0mean.nii.gz) )
 		metrics=( ${dipyb0dir}/${subject}/${sessions[i]}/${subject}_${sessions[i]}_dipy-b0mean.nii.gz ${pasternakfwdir}/${subject}/${sessions[i]}/${subject}_${sessions[i]}_pasternak_FW.nii.gz ${dipyfwdir}/${subject}/${sessions[i]}/${subject}_${sessions[i]}_dipy-FW.nii.gz ${amiconoddidir}/${subject}/${sessions[i]}/fit_FWF.nii.gz )
 	fi
 
 	echo ${metrics[@]}
 	lan=${#metrics[@]}
 	for (( j=0; j<${lan}; j++ )); do
 
  	# Normalize metric
  	in=${metrics[j]}
  	if [[ ! -f ${in} ]]; then
  		echo ">>> Missing metric for ${subject}, ${sessions[i]}: ${in}"
  		continue
  	fi
  	dn=`dirname ${in}`
  	bn=`basename ${in}`
		on=${dn}/${nprepend}_${bn}
	
		${FSLDIR}/bin/fslreorient2std ${in} ${wddir}/metric.nii.gz
		${FSLDIR}/bin/fslmaths ${wddir}/metric.nii.gz -mas ${wddir}/mask.nii.gz ${wddir}/metric.nii.gz
		echo ">>> Applying transform: ${bn} to MNI"
		${ANTSDIR}/bin/antsApplyTransforms --default-value 0 --float 1 --input ${wddir}/metric.nii.gz --interpolation LanczosWindowedSinc --output ${on} --reference-image ${MNI_mask} --transform ${template2mni} --transform ${img2template[i]} --transform identity
	
 	done
 
 	# QC
 	# IMG 2 within-subject template
 	cd ${wddir}
 	if [[ -f "i${i}_img_to_template_Rigid.nii.gz template.nii.gz" ]]; then
 	 ${FSLDIR}/bin/slicer i${i}_img_to_template_Rigid.nii.gz template.nii.gz -L -s 2 -z 0.35 sla.png -z 0.36 slb.png -z 0.37 slc.png -z 0.38 sld.png -z 0.39 sle.png -z 0.45 slf.png -z 0.55 slg.png -z 0.65 slh.png
 	 ${FSLDIR}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png img_to_template.png
 	 ${FSLDIR}/bin/slicer template.nii.gz i${i}_img_to_template_Rigid.nii.gz -L -s 2 -z 0.35 sla.png -z 0.36 slb.png -z 0.37 slc.png -z 0.38 sld.png -z 0.39 sle.png -z 0.45 slf.png -z 0.55 slg.png -z 0.65 slh.png
 	 ${FSLDIR}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png template_to_img.png
 	 ${FSLDIR}/bin/pngappend template_to_img.png - img_to_template.png ${regdir}/reg_${nprepend}_i${i}_img2template.png; rm -f sl?.png
  fi
 	# IMG 2 MNI template
 	if [[ -f "i${i}_img_to_mni_Warped.nii.gz" ]]; then
 	 ${FSLDIR}/bin/slicer i${i}_img_to_mni_Warped.nii.gz ${MNI_img_downsampled} -L -s 2 -z 0.35 sla.png -z 0.36 slb.png -z 0.37 slc.png -z 0.38 sld.png -z 0.39 sle.png -z 0.45 slf.png -z 0.55 slg.png -z 0.65 slh.png
 	 ${FSLDIR}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png img_to_MNI.png
 	 ${FSLDIR}/bin/slicer ${MNI_img_downsampled} i${i}_img_to_mni_Warped.nii.gz -L -s 2 -z 0.35 sla.png -z 0.36 slb.png -z 0.37 slc.png -z 0.38 sld.png -z 0.39 sle.png -z 0.45 slf.png -z 0.55 slg.png -z 0.65 slh.png
 	 ${FSLDIR}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png MNI_to_img.png
 	 ${FSLDIR}/bin/pngappend MNI_to_img.png - img_to_MNI.png ${regdir}/reg_${nprepend}_i${i}_img2mni.png; rm -f sl?.png
  fi

done

# ${FSLDIR}/bin/immv ${wddir}/ants_template_to_mni_Warped.nii.gz ${regdir}/${nprepend}_template_to_mni_Warped.nii.gz
cp ${wddir}/ants_template_to_mni_Warped.nii.gz ${regdir}/${nprepend}_template_to_mni_Warped.nii.gz

# >>> QC
# Within-subject template 2 MNI template
cd ${regdir}
${FSLDIR}/bin/slicer ${MNI_img} ${regdir}/${nprepend}_template_to_mni_Warped.nii.gz -L -s 2 -z 0.30 sla.png -z 0.31 slb.png -z 0.32 slc.png -z 0.33 sld.png -z 0.34 sle.png -z 0.45 slf.png -z 0.55 slg.png -z 0.65 slh.png
${FSLDIR}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png mni_to_template.png
${FSLDIR}/bin/slicer ${regdir}/${nprepend}_template_to_mni_Warped.nii.gz ${MNI_img} -L -s 2 -z 0.30 sla.png -z 0.31 slb.png -z 0.32 slc.png -z 0.33 sld.png -z 0.34 sle.png -z 0.45 slf.png -z 0.55 slg.png -z 0.65 slh.png
${FSLDIR}/bin/pngappend sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png template_to_mni.png
${FSLDIR}/bin/pngappend template_to_mni.png - mni_to_template.png reg_${nprepend}_template2mni.png; rm -f sl?.png mni_to_template.png; rm template_to_mni.png

# Clean up
rm -r ${wddir}

