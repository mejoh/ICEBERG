#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/cope_maths.sh

fc_dir='/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based'

subs=( `ls -d ${fc_dir}/sub-* | xargs -n1 basename` )
for s in ${subs[@]}; do
	visits=( `ls -d ${fc_dir}/${s}/ses-* | xargs -n1 basename` )
	for v in ${visits[@]}; do
	
			echo ">>> Processing $s: $v"
			
			est_dir=${fc_dir}/${s}/${v}/estimates/fsl_granularity2_gs1.feat/stats
			
			# Anterior putamen > Posterior putamen
			cope1=${est_dir}/cope1.nii.gz
			cope2=${est_dir}/cope2.nii.gz
			cope2sub1=${est_dir}/deriv_cope2sub1.nii.gz
			fslmaths ${cope2} -sub ${cope1} ${cope2sub1}
			
			# Caudate > Putamen
			cope3=${est_dir}/cope3.nii.gz
			cope6=${est_dir}/cope6.nii.gz
			cope6sub3=${est_dir}/deriv_cope6sub3.nii.gz
			fslmaths ${cope6} -sub ${cope3} ${cope6sub3}

	done
done
