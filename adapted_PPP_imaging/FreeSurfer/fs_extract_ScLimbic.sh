#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/ICEBERG/adapted_PPP_imaging/FreeSurfer/fs_extract_ScLimbic.sh

module unload FreeSurfer; module load FreeSurfer/8.1.0
export fs_dir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.1.0
export SUBJECTS_DIR=${fs_dir}/outputs
export FS_ALLOW_DEEP=1
source $FREESURFER_HOME/SetUpFreeSurfer.sh
cd $SUBJECTS_DIR

echo 'SubjID,L_NucleusAccumbens_scl,R_NucleusAccumbens_scl,L_HypoThal_noMB_scl,R_HypoThal_noMB_scl,L_Fornix_scl,R_Fornix_scl,L_MammillaryBody_scl,R_MammillaryBody_scl,L_BasalForebrain_scl,R_BasalForebrain_scl,L_SeptalNuc_scl,R_SeptalNuc_scl,eTIV' > $(pwd)/metrics/measures/ScLimbic.csv

for subj_id in $(ls -d sub-*.long*); do # <<< may need to change this so that it selects subjects with FS output

 printf "%s,"  "${subj_id}" >> $(pwd)/metrics/measures/ScLimbic.csv
 if [[ -f ${subj_id}/stats/sclimbic.stats ]]; then

   for x in Left-Nucleus-Accumbens Right-Nucleus-Accumbens Left-HypoThal-noMB Right-HypoThal-noMB Left-Fornix Right-Fornix Left-MammillaryBody Right-MammillaryBody Left-Basal-Forebrain Right-Basal-Forebrain Left-SeptalNuc Right-SeptalNuc; do

    printf "%g," `grep -w ${x} ${subj_id}/stats/sclimbic.stats | awk '{print $4}'` >> $(pwd)/metrics/measures/ScLimbic.csv

   done
   printf "%g" `cat ${subj_id}/stats/sclimbic.stats | grep EstimatedTotalIntraCranialVol | awk -F, '{print $4}'` >> $(pwd)/metrics/measures/ScLimbic.csv
else
   echo ">>> Missing file: ${subj_id}"
   for x in Left-Nucleus-Accumbens Right-Nucleus-Accumbens Left-HypoThal-noMB Right-HypoThal-noMB Left-Fornix Right-Fornix Left-MammillaryBody Right-MammillaryBody Left-Basal-Forebrain Right-Basal-Forebrain Left-SeptalNuc Right-SeptalNuc; do

     printf "%s," "NA" >> $(pwd)/metrics/measures/ScLimbic.csv

   done
   printf "%s" "NA" >> $(pwd)/metrics/measures/ScLimbic.csv
fi

echo "" >> $(pwd)/metrics/measures/ScLimbic.csv

done
