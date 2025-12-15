#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/<NAME>.sh

# Submits a subject to <NAME> All sessions are processed.
# Resource management reference:
# ~?? min, ??gb for 3 sessions

#SBATCH --job-name="<NAME>"
#SBATCH --time=XX:00:00
#SBATCH --mem=XXGB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/<NAME>/logs/job.<NAME>.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/<NAME>/logs/job.<NAME>.%A_%a.out
#SBATCH --array=0-286%25

# array vals: 0-286%25

sleep 60

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=0

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}

<CODE HERE>

