#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_fmriprep.sh

# Submits a subject to fmriprep. All sessions are processed.
# Resource management reference:
# ~13h, 5gb for 3 sessions

#SBATCH --job-name="fmriprep"
#SBATCH --time=20:00:00
#SBATCH --mem=20GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/fmriprep_25.1.3_cifti/logs/job.fmriprep.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/fmriprep_25.1.3_cifti/logs/job.fmriprep.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=21,30,82,102,186,221,275

# array vals: 0-286%25
# rerun: 102,275

#min=1
#max=60 
#timer=$(($RANDOM%($max-$min+1)+$min))
sleep 60

IDX=${SLURM_ARRAY_TASK_ID}

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

CHECKFILE=${BIDSDIR}/derivatives/fmriprep_25.1.3_cifti/sub-${SUB_ID}.html

if [[ -f ${CHECKFILE} ]]; then
	echo ">>> ${SUB_ID} already processed, exiting..."
	exit 1
fi

module load singularity
singularity run \
    --cleanenv --containall \
    --bind $(pwd)/templateflow:/templates:rw \
    $(pwd)/containers/fmriprep_25.1.3.simg \
    ${BIDSDIR} \
    ${BIDSDIR}/derivatives/fmriprep_25.1.3_cifti \
    participant \
    -w $(pwd)/wd/fmriprep_wf/sub-${SUB_ID} \
    --participant-label ${SUB_ID} \
    --mem_mb 20000 \
    --omp-nthreads 1 \
    --nthreads 2  \
    --level full \
    --skip_bids_validation \
    --fs-license $(pwd)/fs_license.txt \
    --task-id rest \
    --longitudinal \
    --fd-spike-threshold 0.5 \
    --output-spaces MNI152NLin6Asym:res-2 fsLR \
    --cifti-output 91k \
    --project-goodvoxels \
    -vv
    
# MNI152NLin2009cAsym:res-2
# --cifti-output 91k --project-goodvoxels

rm -r $(pwd)/wd/fmriprep_wf/sub-${SUB_ID}


