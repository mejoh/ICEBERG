#!/bin/bash

usage (){

	cat <<USAGE
	
	Usage: 
	
	`basename $0` -d -i -m
	
	Description: 

	Extract summary statistics from regions-of-interest.

	Compulsory arguments: 
	
	-d: Data directory (output of assemble_images.sh)
	
	-i: Image type
	
	-m: Index mask

	Example: /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/extract_sn_fw.sh -d /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1/derivatives/dipy_fw/assembled -i dipy-FW -m /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1/derivatives/dipy_b0/assembled/sn_mask_v2.nii.gz



USAGE

	exit 1

}

# Provide help
[ "$1" == "" ] && usage >&2
[ "$1" == "-h" ] && usage >&2
[ "$1" == "--help" ] && usage >&2

# Get command-line options
while getopts ":d:i:m:" OPT; do

	case "${OPT}" in 
		d)
			echo ">>> -d ${OPTARG}"
			optD=${OPTARG}
		;;
		i)
			echo ">>> -i ${OPTARG}"
			optI=${OPTARG}
		;;
		m)
			echo ">>> -m ${OPTARG}"
			optM=${OPTARG}
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

# Set up environment
export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh
export AFNIDIR=/network/iss/apps/software/scit/afni/24.3.06
DATADIR=${optD} # optD=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1/derivatives/dipy_fw/assembled
IMG=${optI}     # optI=dipy-FW
MASK=${optM}    # optM=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1/derivatives/dipy_b0/assembled/sn_mask.nii.gz
NORM="n2"
#mkdir -p ${DATADIR}/wd
#cd ${DATADIR}/wd
#rm $(pwd)/*

# Bilateral masks
#${FSLDIR}/bin/fslmaths ${MASK} -thr 1 -uthr 2 -bin bi_aSN
#${FSLDIR}/bin/fslmaths ${MASK} -thr 3 -uthr 4 -bin bi_pSN

# Unilateral masks
#${FSLDIR}/bin/fslmaths ${MASK} -thr 1 -uthr 1 -bin R_aSN
#${FSLDIR}/bin/fslmaths ${MASK} -thr 2 -uthr 2 -bin L_aSN
#${FSLDIR}/bin/fslmaths ${MASK} -thr 3 -uthr 3 -bin R_pSN
#${FSLDIR}/bin/fslmaths ${MASK} -thr 4 -uthr 4 -bin L_pSN

#MASKLIST=(bi_aSN bi_pSN R_aSN L_aSN R_pSN L_pSN)

# Extract stats for each mask
#for m in ${MASKLIST[@]}; do
#
#	echo ">>> MASK: ${m}"
#	${FSLDIR}/bin/fslstats -t ${DATADIR}/${NORM}_${IMG}_ses-all_concat.nii.gz -k ${m}.nii.gz -m | tr -d "[:blank:]" > avg_${m}.txt
#	${FSLDIR}/bin/fslstats -t ${DATADIR}/${NORM}_${IMG}_ses-all_concat.nii.gz -k ${m}.nii.gz -s | tr -d "[:blank:]" > sd_${m}.txt
#	echo ">>> done"
#
#done

# Combine to single file
#for i in avg sd; do
#
#	fn=${DATADIR}/${NORM}_${IMG}_ses-all_stats-${i}.csv
#  echo "IMG,aSN_${i},pSN_${i},R_aSN_${i},L_aSN_${i},R_pSN_${i},L_pSN_${i}" > ${fn}
#  paste -d , ../${NORM}_${IMG}_ses-all_concat.txt ${i}_bi_aSN.txt ${i}_bi_pSN.txt ${i}_R_aSN.txt ${i}_L_aSN.txt ${i}_R_pSN.txt ${i}_L_pSN.txt >> ${fn}
#
#done

${AFNIDIR}/abin/3dROIstats \
 -nzmean \
 -nzmedian \
 -nzsigma \
 -minmax \
 -key \
 -nomeanout \
 -nobriklab \
 -mask ${MASK} \
 ${DATADIR}/${NORM}_${IMG}_ses-all_concat.nii.gz > ${DATADIR}/${NORM}_${IMG}_ses-all_stats.txt

#rm -r wd





