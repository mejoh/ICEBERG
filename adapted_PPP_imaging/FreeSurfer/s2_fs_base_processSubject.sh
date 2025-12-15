#!/bin/bash

# Creates an unbiased template for each subject based on multiple timepoints
# Note that subjects with only single timepoints must still be processed through this pipeline

# Run the base recon-all pipeline for each subject
# Resource management reference:
# ~2.5h per subject, 12gb

#SBATCH --job-name="FS8_base"
#SBATCH --time=10:00:00
#SBATCH --mem=25GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_base.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_base.%A_%a.err
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

t1=sub-${subject}_V0
t2=sub-${subject}_V2
t3=sub-${subject}_V4

outputfile=${fs_dir}/outputs/sub-${subject}/stats/aseg.stats
if [[ -f $outputfile ]]; then
	echo ">>> Already processed, exiting..."
	exit 1
fi


if [[ -d $t1 && -d $t2 && -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t1} -tp ${t2} -tp ${t3} -all -threads 2 -no-isrunning
	
elif [[ -d $t1 && -d $t2 && ! -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t1} -tp ${t2} -all -threads 2 -no-isrunning
	
elif [[ -d $t1 && ! -d $t2 && -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t1} -tp ${t3} -all -threads 2 -no-isrunning
	
elif [[ ! -d $t1 && -d $t2 && -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t2} -tp ${t3} -all -threads 2 -no-isrunning
	
elif [[ -d $t1 && ! -d $t2 && ! -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t1} -all -threads 2 -no-isrunning
	
elif [[ ! -d $t1 && -d $t2 && ! -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t2} -all -threads 2 -no-isrunning
	
elif [[ ! -d $t1 && ! -d $t2 && -d $t3 ]]; then

	$FREESURFER_HOME/bin/recon-all -base sub-${subject} -tp ${t3} -all -threads 2 -no-isrunning
	
elif [[ ! -d $t1 && ! -d $t2 && ! -d $t3 ]]; then

	echo ">>> No inputs to be processed! Exiting..."
	
fi
