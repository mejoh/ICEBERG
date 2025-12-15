#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/spect/spect_tabularize.sh

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat2/derivatives/dat_extraction"
SUBJECTS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename) )

# Stats tables from 3dROIstats
REC=( "ChangReoIY30Norm" "ChangReoRBVNorm" )
for ((i=0; i<${#REC[@]}; i++)); do
 
 OUTFILE=${BIDSDIR}/dat_rec-${REC[i]}_spect.csv
 echo "subject,session,mean_put_r,sigma_put_r,min_put_r,max_put_r,median_put_r,mean_put_l,sigma_put_l,min_put_l,max_put_l,median_put_l,mean_caud_r,sigma_caud_r,min_caud_r,max_caud_r,median_caud_r,mean_caud_l,sigma_caud_l,min_caud_l,max_caud_l,median_caud_l,mean_nacc_r,sigma_nacc_r,min_nacc_r,max_nacc_r,median_nacc_r,mean_nacc_l,sigma_nacc_l,min_nacc_l,max_nacc_l,median_nacc_l,mean_gp_r,sigma_gp_r,min_gp_r,max_gp_r,median_gp_r,mean_gp_l,sigma_gp_l,min_gp_l,max_gp_l,median_gp_l" > ${OUTFILE}
 
 for ((j=0; j<${#SUBJECTS[@]}; j++)); do
  
  SUB_ID=${SUBJECTS[j]}
  SESSIONS=( $(find ${BIDSDIR}/${SUB_ID}/ses-* -maxdepth 0 | xargs -n1 basename) )
  
  for ((k=0; k<${#SESSIONS[@]}; k++)); do
   
   SES_ID=${SESSIONS[k]}
   TABLE=${BIDSDIR}/${SUB_ID}/${SES_ID}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-${REC[i]}_stat-dat_spect.txt
   
   if [[ -f ${TABLE} ]]; then
    
    # Format table contents and print to output
    OUTLINE="${SUB_ID},${SES_ID}"
    OUTLINE="${OUTLINE},`cat ${TABLE} | cut -f3- | sed 's/\t/,/g' | sed '2q;d'`"
    echo ${OUTLINE} >> ${OUTFILE}

   fi
  
  done
 
 done

done

# SGTM
REC=( "ChangReoSGTM" )
REGIONS=( "Right-Putamen" "Left-Putamen" "Left-Caudate" "Right-Caudate" "Right-Accumbens-area" "Left-Accumbens-area" "Left-Pallidum" "Right-Pallidum" )
for ((i=0; i<${#REC[@]}; i++)); do
 
 OUTFILE=${BIDSDIR}/dat_rec-${REC[i]}_spect.csv
 echo "subject,session,mean_put_r,sigma_put_r,mean_put_l,sigma_put_l,mean_caud_r,sigma_caud_r,mean_caud_l,sigma_caud_l,mean_nacc_r,sigma_nacc_r,mean_nacc_l,sigma_nacc_l,mean_gp_r,sigma_gp_r,mean_gp_l,sigma_gp_l" > ${OUTFILE}
 
 for ((j=0; j<${#SUBJECTS[@]}; j++)); do
  
  SUB_ID=${SUBJECTS[j]}
  SESSIONS=( $(find ${BIDSDIR}/${SUB_ID}/ses-* -maxdepth 0 | xargs -n1 basename) )
  
  for ((k=0; k<${#SESSIONS[@]}; k++)); do
   
   SES_ID=${SESSIONS[k]}
   TABLE=${BIDSDIR}/${SUB_ID}/${SES_ID}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-${REC[i]}Norm_stat-dat_spect.txt
   
   if [[ -f ${TABLE} ]]; then

       # Calculate mean values from reference region (lateral occipital cortex)
        REFVAL_MEAN_RH=`cat ${TABLE} | grep ctx-rh-lateraloccipital | awk '{print $7}'`
        REFVAL_MEAN_LH=`cat ${TABLE} | grep ctx-lh-lateraloccipital | awk '{print $7}'`
        REFVAL_MEAN_BI=`echo "scale=3; ${REFVAL_MEAN_RH} + ${REFVAL_MEAN_LH}" | bc`
        REFVAL_MEAN_BI=`echo "scale=3; ${REFVAL_MEAN_BI} / 2" | bc`

        REFVAL_SIGMA_RH=`cat ${TABLE} | grep ctx-rh-lateraloccipital | awk '{print $8}'`
        REFVAL_SIGMA_LH=`cat ${TABLE} | grep ctx-lh-lateraloccipital | awk '{print $8}'`
        REFVAL_SIGMA_BI=`echo "scale=3; ${REFVAL_SIGMA_RH} + ${REFVAL_SIGMA_LH}" | bc`
        REFVAL_SIGMA_BI=`echo "scale=3; ${REFVAL_SIGMA_BI} / 2" | bc`

        # Normalize values and print to output file
        OUTLINE=( ${SUB_ID} ${SES_ID} )
        for R in ${REGIONS[@]}; do
            TMP01=`cat ${TABLE} | grep ${R} | awk '{print $7}'`
            TMP01_NORM=`echo "scale=3; ${TMP01} / ${REFVAL_MEAN_BI}" | bc`
            TMP02=`cat ${TABLE} | grep ${R} | awk '{print $8}'`
            TMP02_NORM=`echo "scale=3; ${TMP02} / ${REFVAL_SIGMA_BI}" | bc`
            OUTLINE+=( ${TMP01_NORM} ${TMP02_NORM} )
        done

        echo ${OUTLINE[@]} | sed 's/\s/,/g' >> ${OUTFILE}

   fi
  
  done
 
 done

done
