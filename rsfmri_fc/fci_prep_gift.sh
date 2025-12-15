#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fci_prep_gift.sh

# Prepare a GIFT-compatible BIDS-like directory to run group ICA on.

TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

#TXTFILE="inputfiles_g0-hc_g1-PDnrbd.txt"
#TYPE="g0-hc_g1-PDnrbd"
#TXTFILE="inputfiles_g0-hc_g1-PDrbd.txt"
#TYPE="g0-hc_g1-PDrbd"
TXTFILE="inputfiles_g0-hc_g1-iRBD_g2-PDnrbd.txt"
TYPE="g0-hc_g1-iRBD_g2-PDnrbd"
INPUTFILES="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/${TXTFILE}"

# Prepare intermediate data storage and output directories
mkdir -p /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift/${TYPE}
cd /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift/${TYPE}
CWD=`pwd`
GIFT_DIR=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift/${TYPE}
GIFT_DATA="${CWD}/gift_bids/"
GIFT_OUT="${CWD}/gift_out/"
mkdir -p ${GIFT_DATA}
mkdir -p ${GIFT_OUT}
echo "participant_id" > ${GIFT_DATA}/participants.tsv
cp /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift/task-rest_bold.json ${GIFT_DATA}/.
cp /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift/dataset_description.json ${GIFT_DATA}/.

# Define test subject(s), preprocessed data, and prepare BIDS-like directories
#SUB=( "033VS" "054LC" "078AP" "092FA" "102FP" "118DH" "168VE" )
cp ${INPUTFILES} ${GIFT_DATA}/${TXTFILE}
SUB=( `cat ${GIFT_DATA}/${TXTFILE} | cut -d '/' -f 12 | sed 's/sub-//g'` )
SES="V0"
for i in ${SUB[@]}; do
echo "sub-${i}" >> ${GIFT_DATA}/participants.tsv
FUNC="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/sub-${i}/ses-${SES}/estimates/func_data.nii.gz"
ANAT="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/xcpd_0.11.1/sub-${i}/anat/sub-${i}_acq-UNIm_space-MNI152NLin6Asym_desc-preproc_T1w.nii.gz"
if [[ ! -f ${ANAT} ]]; then
	ANAT="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/xcpd_0.11.1/sub-${i}/ses-${SES}/anat/sub-${i}_ses-${SES}_acq-UNIm_space-MNI152NLin6Asym_desc-preproc_T1w.nii.gz"
fi
mkdir -p ${GIFT_DATA}/sub-${i}/ses-${SES}/anat
mkdir -p ${GIFT_DATA}/sub-${i}/ses-${SES}/func

# Copy images into new BIDS-directory and remove space/desc fields (GIFT doesn't support those)
# Optionally transform to MNI152NLin2009cAsym (not necessary)
cp ${ANAT} ${GIFT_DATA}/sub-${i}/ses-${SES}/anat/sub-${i}i-${SES}_acq-UNIm_T1w.nii.gz
#antsApplyTransforms \
#    -d 3 \
#    -i ${ANAT} \
#    -o ${GIFT_DATA}/sub-${i}/ses-${SES}/anat/sub-${i}_ses-${SES}_acq-UNIm_T1w.nii.gz  \
#    -t ${TEMPLATEFLOW_HOME}/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_from-MNI152NLin6Asym_mode-image_xfm.h5 \
#    -r ${TEMPLATEFLOW_HOME}/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-01_desc-brain_mask.nii.gz \
#    --interpolation LanczosWindowedSinc \
#    --float \
#    -v 1
cp ${FUNC} ${GIFT_DATA}/sub-${i}/ses-${SES}/func/sub-${i}_ses-${SES}_task-rest_bold.nii.gz
#antsApplyTransforms \
#	-d 3 \
#    -e 3 \
#    -i ${FUNC} \
#    -o ${GIFT_DATA}/sub-${i}/ses-${SES}/func/sub-${i}_ses-${SES}_task-rest_bold.nii.gz  \
#    -t ${TEMPLATEFLOW_HOME}/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_from-MNI152NLin6Asym_mode-image_xfm.h5 \
#    -r ${TEMPLATEFLOW_HOME}/tpl-MNI152NLin2009cAsym/tpl-MNI152NLin2009cAsym_res-02_desc-brain_mask.nii.gz \
#    --interpolation LanczosWindowedSinc \
#    --float \
#    -v 1

done

# Run GIFT (currently not functional on the cluster, complains that my existing data directory does, in fact, not exist!)
# GIFT can be run through the Matlab GUI instead.
#sudo docker pull trends/gift-bids:v4.0.5.3
#sudo docker run -ti --rm \
#    -v /tmp:/tmp \
#    -v /var/tmp:/var/tmp \
#    trends/gift-bids:v4.0.5.3 \
#    ${GIFT_DATA} \
#    ${GIFT_OUT} \
#    participant \
#    --participant_label sub-${SUB} \
#    --config /network/iss/cenir/analyse/irm/users/martin.johansson/test/gift/cfg/config_spatial_ica_bids.m
