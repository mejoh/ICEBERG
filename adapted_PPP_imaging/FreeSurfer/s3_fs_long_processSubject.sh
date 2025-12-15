#!/bin/bash

# Re-run the full recon-all pipeline for each subject's sessions,
# using base as a starting point for the 

# Run the base recon-all pipeline for each subject
# Resource management reference:
# ~2h per session (~8 for 3 sessions), 16gb

#SBATCH --job-name="FS8_long"
#SBATCH --time=20:00:00
#SBATCH --mem=21GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_long.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_long.%A_%a.err
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
	CHECKFILE=${fs_dir}/outputs/sub-${subject}_${timepoint}.long.sub-${subject}/stats/aseg.stats
	# Require session-specific and base input
	if [[ -d sub-${subject}_${timepoint} && -d sub-${subject} && ! -f ${CHECKFILE} ]]; then

		$FREESURFER_HOME/bin/recon-all -long sub-${subject}_${timepoint} sub-${subject} -all -threads 2 -no-isrunning

	else

		echo "Exiting: No inputs to be processed!"

	fi
done
