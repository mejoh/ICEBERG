#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fsl_randomise_imgs.sh

# Run after fsl_randomise_covars.R

# This script will do two things:
# 1. Generate images
	# - Per contrast, session, and group comparison
# 2. Build design matrices from fsl_randomise_covars.R output
	# - Unpaired t-tests: group comparisons
	# - One-sample t-tests: post-hoc testing for each group, separate for positive and negative
# 3. Write scripts

# Set paths and parameters
groupdir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/randomise
cd ${groupdir}
#MASK_ROI="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/parieto_premotor/mask_dilM1.nii.gz"
MASK_ROI="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/SMN/mask_dilM1.nii.gz"
#MASK_ROI="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/combined_SMN_parieto_premotor/mask_dilM1.nii.gz"
#MASK_ROI="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/dccn_parieto_premotor/mask_dilM1.nii.gz"
MASK_WHOLE=/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow/tpl-MNI152NLin6Asym/tpl-MNI152NLin6Asym_res-02_desc-brain_mask.nii.gz
rand="randomise_parallel"
rand_opts="-m ${MASK_WHOLE} -n 5000 -T -c 3.1 -R --uncorrp --glm_output -N"

# Generate images by contrasts, groups, and time points
cope=(PP PA PAsubPP)
#cope=(PP PA PAsubPP CB12 CB56 CB56subCB12)
ses=(ses-V0 ses-V2 ses-V4)
for c in ${cope[@]}; do
 for s in ${ses[@]}; do 

  echo ">>> Analyzing $c, $s"
 
 cope_dir=${groupdir}/seed-${c}_${s}
 
 # Merge images
 echo ">>> |_ Merging..."
 img_files=( `ls ${cope_dir}/imgs__*.txt` )
 for i in ${img_files[@]}; do
  img_name=`echo $i | xargs -n 1 basename | sed 's/.txt//g'`
  echo ">>> |__ ${img_name}..."
  fslmerge -t ${cope_dir}/${img_name} `cat ${i}`
 done
  
 # Generate .con files
 echo ">>> |_ Genering .con files..."
 con_files=( `ls ${cope_dir}/cons__*.txt` )
 for t in ${con_files[@]}; do
  DN=$(dirname ${t})
  BN=$(basename ${t})
  CN=${BN/.txt/.con}
  Text2Vest ${DN}/${BN} ${cope_dir}/${CN}
 done
 
 # Generate .mat files
 echo ">>> |_ Genering .mat files..."
 mat_files=( `ls ${cope_dir}/covs__*.txt` )
 for m in ${mat_files[@]}; do
  DN=$(dirname ${m})
  BN=$(basename ${m})
  CN=${BN/.txt/.mat}
  Text2Vest ${DN}/${BN} ${cope_dir}/${CN}
 done 
 
 # Generate randomise commands
 # Group comparisons
 echo ">>> |_ Genering randomise scripts..."
 echo ">>> |__ Two-group comparisons..."
 img_files01=( `ls ${cope_dir}/imgs__*match-n.nii.gz` )
 img_files02=( `ls ${cope_dir}/imgs__*match-y.nii.gz` )
 img_files=( ${img_files01[@]} ${img_files02[@]}  )
 for i in ${img_files[@]}; do
  comparison=`echo $i | xargs -n 1 basename | sed 's/imgs__//g' | sed 's/.nii.gz//g'`
  output_dir=${cope_dir}/${comparison}
  mkdir -p ${output_dir}
  img="imgs__${comparison}.nii.gz"
  mat="covs__${comparison}.mat"
  con="cons____two_sample_ttest.con"
  randcmd="${rand} -i ${cope_dir}/${img} -o ${output_dir}/rand_ -d ${cope_dir}/${mat} -t ${cope_dir}/${con} ${rand_opts}"
  cmd_file="cmd__${comparison}.txt"
  printf '#!/bin/bash\n' > ${cope_dir}/${cmd_file}
  printf "\n${randcmd}\n" >> ${cope_dir}/${cmd_file}
  printf "\nrm ${output_dir}/*SEED*\n\n" >> ${cope_dir}/${cmd_file}
 done
 # Single-group comparisons
 echo ">>> |__ Single-group comparisons..."
 img_files=( `ls ${cope_dir}/imgs__*only.nii.gz` )
 for i in ${img_files[@]}; do
    # Positive
  comparison=`echo $i | xargs -n 1 basename | sed 's/imgs__//g' | sed 's/.nii.gz//g'`
  output_dir=${cope_dir}/${comparison}
  mkdir -p ${output_dir}
  img="imgs__${comparison}.nii.gz"
  img_neg="imgs__${comparison}_neg.nii.gz"
  fslmaths ${cope_dir}/${img} -mul -1 ${cope_dir}/${img_neg}
  cp `echo ${cope_dir}/${img} | sed 's/.nii.gz/.txt/g'` `echo ${cope_dir}/${img} | sed 's/.nii.gz/_neg.txt/g'`
  mat="covs__${comparison}.mat"
  mat_neg="covs__${comparison}_neg.mat"
  cp ${cope_dir}/${mat} ${cope_dir}/${mat_neg}
  con="cons____one_sample_ttest.con"
  randcmd="${rand} -i ${cope_dir}/${img} -o ${output_dir}/rand_ -d ${cope_dir}/${mat} -t ${cope_dir}/${con} -1 ${rand_opts}"
  cmd_file="cmd__${comparison}.txt"
  printf '#!/bin/bash\n' > ${cope_dir}/${cmd_file}
  printf "\n${randcmd}\n" >> ${cope_dir}/${cmd_file}
  printf "\nrm ${output_dir}/*SEED*\n\n" >> ${cope_dir}/${cmd_file}
    # Negative
  comparison=`echo $i | xargs -n 1 basename | sed 's/imgs__//g' | sed 's/.nii.gz/_neg/g'`
  output_dir=${cope_dir}/${comparison}
  mkdir -p ${output_dir}
  randcmd="${rand} -i ${cope_dir}/${img_neg} -o ${output_dir}/rand_ -1 -d ${cope_dir}/${mat} -t ${cope_dir}/${con} ${rand_opts}"
  cmd_file="cmd__${comparison}.txt"
  printf '#!/bin/bash\n' > ${cope_dir}/${cmd_file}
  printf "\n${randcmd}\n" >> ${cope_dir}/${cmd_file}
  printf "\nrm ${output_dir}/*SEED*\n\n" >> ${cope_dir}/${cmd_file}
 done

 echo ">>> |_ Done!"
 
 done
done


