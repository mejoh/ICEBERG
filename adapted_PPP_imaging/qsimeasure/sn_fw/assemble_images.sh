#!/bin/bash

# DIPY-B0: For visualization and ROI-building
# FSL-FA vs DIPY-FA: Between-software convergence
# FSL-MD vs DIPY-MD: Between-software convergence
# AMICO_NODDI-FW vs DIPY FW: Between-software convergence
# DIPY-FA vs DIPY-FAc: Effect of correction

usage (){

	cat <<USAGE
	
	Usage: 
	
	`basename $0` -m -i -n
	
	Description: 

	Assemble DWI MODALITYs through various stages of 
	by-group/by-session merging and subtraction

	Compulsory arguments: 
	
	-m: Modality <dipy_b0, dipy_FW, amico_noddi, pasternak_fw>
	
	-i: Image type <see below for options per modality>
			dipy_b0: dipy-b0mean
			dipy_fw: dipy-FW, dipy-FA, dipy-FAc, dipy-MD, dipy-MDc, fsl_FA, fsl_MD
			amico_noddi: FIT_FWF, FIT_NDI, FIT_ODI
			pasternak_fw: FW, dcmp_FA, dcmp_MD
	
	-n: Normalization type <n1, n2>

	Example:

	/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/assemble_images.sh -m dipy_b0 -i dipy-b0mean -n n2

USAGE

	exit 1

}

# Provide help
[ "$1" == "" ] && usage >&2
[ "$1" == "-h" ] && usage >&2
[ "$1" == "--help" ] && usage >&2

# Get command-line options
while getopts ":m:i:n:" OPT; do

	case "${OPT}" in 
		m)
			echo ">>> -m ${OPTARG}"
			optM=${OPTARG}
		;;
		i)
			echo ">>> -i ${OPTARG}"
			optI=${OPTARG}
		;;
		n)
			echo ">>> -n ${OPTARG}"
			optN=${OPTARG}
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
MODALITY=${optM}
IMG=${optI}
NORM=${optN}
MODALITYDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1/derivatives/${MODALITY}"
DIR=${MODALITYDIR}/assembled
mkdir -p ${DIR}
cd ${DIR}
rm ./${NORM}_${IMG}*

if [[ ${MODALITY} == "amico_noddi" && ${IMG} == "FIT_FWF" ]] || [[ ${MODALITY} == "amico_noddi" && ${IMG} == "FIT_ODI" ]] || [[ ${MODALITY} == "amico_noddi" && ${IMG} == "FIT_NDI" ]] || [[ ${MODALITY} == "dipy_b0" && ${IMG} == "dipy-b0mean" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "dipy-FW" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "dipy-FA" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "dipy-FAc" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "dipy-MD" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "dipy-MDc" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "fsl_FA" ]] || [[ ${MODALITY} == "dipy_fw" && ${IMG} == "fsl_MD" ]] || [[ ${MODALITY} == "pasternak_fw" && ${IMG} == "pasternak_FW" ]] || [[ ${MODALITY}=="pasternak_fw" && ${IMG}=="dcmp_FA" ]]|| [[ ${MODALITY}=="pasternak_fw" && ${IMG}=="dcmp_MD" ]]; then 
	echo ">>> IMG type compatible with modality"
else
  echo ">>> Error: IMG type not compatible with modality"
  usage >&2
fi

if [[ ${NORM} == "n1" || ${NORM} == "n2" ]]; then
	echo ">>> Normalization type correctly specified"
else
	echo ">>> Error: Incorrect normalization type specified"
fi

# Img search pattern differs by img type
if [ ${MODALITY} == "amico_noddi" ]; then
	SPTN="${NORM}_${IMG}.nii.gz"
else
	SPTN="${NORM}_sub-*_${IMG}.nii.gz"
fi

# 
if [[ ${MODALITY} == 'dipy_b0' && ${IMG} == "dipy-b0mean" ]]; then
	echo ">>> Assembling b0 average from template input list"
	TEMPLATEINPUTLIST="/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/inputfiles_B0_g0-hc_g1-PDnrbd.txt"
	fnames=( `cat $TEMPLATEINPUTLIST | sed -r "s/(.*)\//\1\/${NORM}_/"` )
	${FSLDIR}/bin/fslmerge -t ${NORM}_${IMG}_ses-template_concat `echo ${fnames[@]}`
	${FSLDIR}/bin/fslmaths ${NORM}_${IMG}_ses-template_concat -Tmean ${NORM}_${IMG}_ses-template_avg
	printf '%s\n' ${fnames[@]} > ${NORM}_${IMG}_ses-template_concat.txt
fi

SESSIONS=( "V0" "V2" "V4" )
for i in ${SESSIONS[@]}; do
	echo ">>> Assembling ${i}"
	imglist=( `ls ${MODALITYDIR}/sub-*/ses-${i}/${SPTN}` )
	${FSLDIR}/bin/fslmerge -t ${NORM}_${IMG}_ses-${i}_concat `echo ${imglist[@]}`
	${FSLDIR}/bin/fslmaths ${NORM}_${IMG}_ses-${i}_concat -Tmean ${NORM}_${IMG}_ses-${i}_avg
	printf '%s\n' ${imglist[@]} > ${NORM}_${IMG}_ses-${i}_concat.txt
done

echo ">>> Assembling all"
imglist=( `ls ${MODALITYDIR}/sub-*/ses-*/${SPTN}` )
${FSLDIR}/bin/fslmerge -t ${NORM}_${IMG}_ses-all_concat `echo ${imglist[@]}`
${FSLDIR}/bin/fslmaths ${NORM}_${IMG}_ses-all_concat -Tmean ${NORM}_${IMG}_ses-all_avg
printf '%s\n' ${imglist[@]} > ${NORM}_${IMG}_ses-all_concat.txt

echo ">>> Done!"



