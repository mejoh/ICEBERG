#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fci_melodic.sh

#SBATCH --job-name="melodic"
#SBATCH --time=04:00:00
#SBATCH --mem=14GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/logs/job.melodic.%A_%a.out
#SBATCH --error=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/logs/job.melodic.%A_%a.err
#SBATCH --array=0-7

IDX=${SLURM_ARRAY_TASK_ID}

export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

MELODICDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic"
INPUT_LISTS=( `ls ${MELODICDIR}/inputfiles_g*.txt` )
INPUT_LIST=${INPUT_LISTS[${IDX}]}

DIRNAME=`echo ${INPUT_LIST} | xargs -n1 basename | sed -e "s/inputfiles_//" -e "s/.txt//"`
mkdir -p ${MELODICDIR}/${DIRNAME}
${FSLDIR}/bin/melodic \
	-i ${INPUT_LIST} \
 	-o ${MELODICDIR}/${DIRNAME} \
 	--tr=2.19 \
 	--nobet \
 	-a concat \
 	-m /network/iss/cenir/analyse/irm/users/martin.johansson/templateflow/tpl-MNI152NLin6Asym/tpl-MNI152NLin6Asym_res-02_desc-brain_mask.nii.gz  \
 	--report \
 	--Oall \
 	-d 40 \

 	# --mmthresh 0.5
