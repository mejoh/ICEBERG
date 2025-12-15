#!/bin/bash

# Run ScLimbic on longitudinal output
# Resource management reference:
# ~5min for 3 sessions, 3gb

#SBATCH --job-name="FS8_sclimbic"
#SBATCH --time=00:30:00
#SBATCH --mem=5GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_sclimbic.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_sclimbic.%A_%a.err
#SBATCH --exclude=sphpc-cpu20

# Set the environment and select the FreeSurfer version your working group is working with, i.e., 5.3, 6.0, 7.1. 
#module unload FreeSurfer; module load FreeSurfer/${v}
module unload FreeSurfer; module load FreeSurfer/8.1.0
export fs_dir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.1.0
export SUBJECTS_DIR=${fs_dir}/outputs
export FS_ALLOW_DEEP=1
source $FREESURFER_HOME/SetUpFreeSurfer.sh

cd $SUBJECTS_DIR

#sleep 10

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=0

INPUT_SUBS=( $(find ${fs_dir}/inputs/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
subject=${INPUT_SUBS[${IDX}]}
SESSIONS=( "V0" "V2" "V4" )

for timepoint in ${SESSIONS[@]}; do
	CHECKFILE=${fs_dir}/outputs/sub-${subject}_${timepoint}.long.sub-${subject}/stats/sclimbic.stats
	# Require session-specific and base input
	if [[ -d sub-${subject}_${timepoint}.long.sub-${subject} && -d sub-${subject} && ! -f ${CHECKFILE} ]]; then

		$FREESURFER_HOME/bin/mri_sclimbic_seg -s sub-${subject}_${timepoint}.long.sub-${subject} --write_qa_stats

	else

		echo "Exiting: No inputs to process!"

	fi
done