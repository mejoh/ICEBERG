#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_mriqc.sh

# Submits a subject to mriqc. All sessions are processed.
# Resource management reference:
# "bold": ~30 min, 8.5gb for 3 sessions (tested across multiple random subjets)
# "t1w": 30 min, 5gb for 3 sessions (tested across a single subject)
# "dwi": <60 min, 6gb for 3 session (tested across a single subject)
# For info on the specific image quality metrics (IQMs):
# http://preprocessed-connectomes-project.org/quality-assessment-protocol/
# https://mriqc.readthedocs.io/en/latest/measures.html

#SBATCH --job-name="mriqc"
#SBATCH --time=03:00:00
#SBATCH --mem=11GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/mriqc_25.0.0rc0/logs/job.mriqc.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/mriqc_25.0.0rc0/logs/job.mriqc.%A_%a.err
#SBATCH --array=0-286%25

# array vals: 0-286%25

sleep 60

IDX=${SLURM_ARRAY_TASK_ID}

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

MODALITY="T1w"

module load singularity
if [[ $MODALITY == "bold" ]]; then
singularity run \
    --cleanenv --containall \
    $(pwd)/containers/mriqc_25.0.0rc0.simg \
    ${BIDSDIR} \
    ${BIDSDIR}/derivatives/mriqc_25.0.0rc0/bold \
    participant \
    -w $(pwd)/wd/mriqc_wf \
    --participant-label ${SUB_ID} \
    --verbose-reports \
    --mem_gb 10 \
    --ants-nthreads 1 \
    --nprocs 1 \
    -m bold \
    --min-bold-length 10
elif [[ $MODALITY == "T1w" ]]; then
singularity run \
    --cleanenv --containall \
    $(pwd)/containers/mriqc_25.0.0rc0.simg \
    ${BIDSDIR} \
    ${BIDSDIR}/derivatives/mriqc_25.0.0rc0/t1w \
    participant \
    -w $(pwd)/wd/mriqc_wf \
    --participant-label ${SUB_ID} \
    --verbose-reports \
    --mem_gb 10 \
    --ants-nthreads 1 \
    --nprocs 1 \
    -m T1w
elif [[ $MODALITY == "dwi" ]]; then
singularity run \
    --cleanenv --containall \
    $(pwd)/containers/mriqc_25.0.0rc0.simg \
    ${BIDSDIR} \
    ${BIDSDIR}/derivatives/mriqc_25.0.0rc0/dwi \
    participant \
    -w $(pwd)/wd/mriqc_wf \
    --participant-label ${SUB_ID} \
    --verbose-reports \
    --mem_gb 10 \
    --ants-nthreads 1 \
    --nprocs 1 \
    -m dwi    
else
	echo "Incorrect modality specified. Exiting!"
	exit 0
fi

rm -r $(pwd)/wd/mriqc_wf/${SUB_ID}

# Generate group report after all subjects have been processed:
# cd /network/iss/cenir/analyse/irm/users/martin.johansson
# BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
# singularity run --cleanenv --containall $(pwd)/containers/mriqc_25.0.0rc0.simg ${BIDSDIR} ${BIDSDIR}/derivatives/mriqc_25.0.0rc0/t1w group



