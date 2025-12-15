#!/bin/bash

# Run the full recon-all pipeline for each subject's sessions
# Resource management reference:
# ~4.5h per subject, 15gb, single session

#SBATCH --job-name="FS8_cross"
#SBATCH --time=16:00:00
#SBATCH --mem=25GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_cross.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/freesurfer_8.1.0/logs/job.fs_cross.%A_%a.err
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
	inputimg=`find ${fs_dir}/inputs/sub-${subject}/*_${timepoint}_T1w.nii.gz`
	outputdir=${fs_dir}/outputs/sub-${subject}_${timepoint}
	outputfile=${fs_dir}/outputs/sub-${subject}_${timepoint}/stats/aseg.stats
	if [[ -f $inputimg && ! -d $outputdir ]]; then

  		echo "Starting recon-all for ${subject}, ${timepoint}"
		$FREESURFER_HOME/bin/recon-all -all -i ${inputimg} -subjid sub-${subject}_${timepoint} -no-isrunning -threads 2 -deface

	elif [[  -f $inputimg && -d $outputdir && ! -f ${outputfile} ]]; then

  		echo "Continuing recon-all for sub-${subject}, ${timepoint}"
  		$FREESURFER_HOME/bin/recon-all -all -subjid sub-${subject}_${timepoint} -no-isrunning -threads 2 -deface
	
	elif [[ -f $outputfile ]]; then
	
		echo "Already processed sub-${subject}, ${timepoint}"
	
	else

  		echo "Exiting: No inputs to process for ${subject}, ${timepoint}!"
	
	fi

done
