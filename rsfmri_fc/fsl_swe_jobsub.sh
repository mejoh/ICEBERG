#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fsl_swe_jobsub.sh
# rm -r /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/swe/seed-*/g0*/*
# rm -r /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/swe/seed-*/g0*/vals

# Submits a subject to qsiprep. All sessions are processed.
# Resource management reference:
# ~? h ? min, max 6 gb for whole-brain mask
# 9 h 0 min, 2gb for SMN mask with 999 bootstraps (12 t-cons, 2 f-cons)
# A single iteration of 999 boostraps take approx 2h with the whole-brain mask.

#SBATCH --job-name="SwE"
#SBATCH --time=45:00:00
#SBATCH --mem=6GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/stats/fc_seed_based/derivatives/swe/logs/job.swe.%A_%a.out
#SBATCH --error=iceberg/stats/fc_seed_based/derivatives/swe/logs/job.swe.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-11

# --array=0-11

export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=59

# PA PP PAsubPP CB12 CB56 CB56subCB12
SEED='PAsubPP'
TYPE=a2
#MASK="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/parieto_premotor/mask_dilM1.nii.gz"
#MASK="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/SMN/mask_dilM1.nii.gz"
#MASK="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/combined_SMN_parieto_premotor/mask_dilM1.nii.gz"
#MASK="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/ROIs/dccn_parieto_premotor/mask_dilM1.nii.gz"
MASK="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow/tpl-MNI152NLin6Asym/tpl-MNI152NLin6Asym_res-02_desc-brain_mask.nii.gz"
SWEDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/swe/seed-${SEED}"
INPUT_COMPS=( $(find ${SWEDIR}/g0* -maxdepth 0 | xargs -n1 basename) )
COMP=${INPUT_COMPS[${IDX}]}

CHECKFILE=${SWEDIR}/${COMP}/swe_${TYPE}__fstat1.nii.gz

if [[ -d ${CHECKFILE} ]]; then
	echo ">>> ${COMP} already processed, exiting..."
	exit 1
fi

cd ${SWEDIR}/${COMP}
echo ">>> Comparison: ${COMP}"
echo ">>> Type: ${TYPE}"
echo ">>> Mask: ${MASK}"

fslmerge -t imgs `cat imgs.txt`

Text2Vest a1_covs.txt a1_covs.mat
Text2Vest a1_cons_f.txt a1_cons_f.fsf
Text2Vest a1_cons_t.txt a1_cons_t.con

Text2Vest a2_covs.txt a2_covs.mat
Text2Vest a2_cons_f.txt a2_cons_f.fsf
Text2Vest a2_cons_t.txt a2_cons_t.con

Text2Vest sub.txt sub.sub

${FSLDIR}/bin/swe \
 -i imgs.nii.gz \
 -o swe_${TYPE}__ \
 -d ${TYPE}_covs.mat \
 -t ${TYPE}_cons_t.con \
 -f ${TYPE}_cons_f.fsf \
 -s sub.sub \
 -m ${MASK} \
 --modified \
 -T -c 0.001 -F 0.001 -R -E --uncorrp --glm_output -D -N \
 --wb -n 999
