#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fci_dualreg.sh

#SBATCH --job-name="dualreg"
#SBATCH --time=20:00:00
#SBATCH --mem=14GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/logs/job.dualreg.%A_%a.out
#SBATCH --error=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/logs/job.dualreg.%A_%a.err
#SBATCH --array=0-2

melodic=0

# 0-7

IDX=${SLURM_ARRAY_TASK_ID}

export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

# MELODIC
if [[ ${melodic} -eq 1 ]]; then
	MELODICDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic"
	GROUPDIRS=( `ls -d ${MELODICDIR}/g0*` )
	GROUPDIR=${GROUPDIRS[${IDX}]}
	MELODIC_IC=${GROUPDIR}/melodic_IC.nii.gz
	INPUTFILES="${MELODICDIR}/inputfiles_all_subjects_sessions.txt"
# GIFT
else
	MELODICDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift"
	GROUPDIRS=( `ls -d ${MELODICDIR}/g0*` )
	GROUPDIR=${GROUPDIRS[${IDX}]}
	MELODIC_IC=${GROUPDIR}/gift_out_noZ/gift__mean_component_ica_s_all_.nii
	INPUTFILES=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_all_subjects_sessions.txt
fi

# Start with clean directory
DUALREGDIR=${GROUPDIR}/dualreg
if [[ -d $DUALREGDIR ]]; then
	rm -r ${DUALREGDIR}
fi

# Run dual-regression
${FSLDIR}/bin/dual_regression \
	${MELODIC_IC} \
	1 \
	-1 \
	0 \
	--thr \
	${DUALREGDIR} \
	`cat ${INPUTFILES}`
