#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_fmripost_aroma.sh

# Submits a subject to fmriprep. All sessions are processed.
# Resource management reference:
# ~1.5h, 6gb for 3 sessions

#SBATCH --job-name="fmripost"
#SBATCH --time=03:30:00
#SBATCH --mem=8GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/fmripost_aroma_0.0.12/logs/job.fmripost.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/fmripost_aroma_0.0.12/logs/job.fmripost.%A_%a.err
#SBATCH --array=88,92,102,110,261,266,275

# array vals: 0-286%25
# rerun: 88,92,102,110,261,266,275

sleep 10

IDX=${SLURM_ARRAY_TASK_ID}

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

CHECKFILE=${BIDSDIR}/derivatives/fmripost_aroma_0.0.12/sub-${SUB_ID}.html

if [[ -f ${CHECKFILE} ]]; then
	echo ">>> ${SUB_ID} already processed, exiting..."
	exit 1
fi

module load singularity
singularity run \
    --cleanenv --containall \
    --bind $(pwd)/templateflow:/templates:rw \
    $(pwd)/containers/fmripost_aroma_0.0.12.simg \
    ${BIDSDIR} \
    ${BIDSDIR}/derivatives/fmripost_aroma_0.0.12 \
    participant \
    -w $(pwd)/wd/fmripost_wf/sub-${SUB_ID} \
    --participant-label ${SUB_ID} \
    --mem_mb 8000 \
    --omp-nthreads 2 \
    --nthreads 2  \
    --skip_bids_validation \
    --task-id rest \
    --derivatives fmriprep=${BIDSDIR}/derivatives/fmriprep_25.1.3 \
    --dummy-scans 5
    
rm -r $(pwd)/wd/fmripost_wf/sub-${SUB_ID}
    
