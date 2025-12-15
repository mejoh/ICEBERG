#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_qsiprep.sh

# Submits a subject to qsiprep. All sessions are processed.
# Resource management reference:
# 2 cores: ~35h, 12gb for 3 sessions*
# 4 cores: ~19, 18gb for 3 sessions
# *SYNTHSEG CRASHES DUE TO OOM, memory from seff is not entirely reliable

#SBATCH --job-name="qsiprep"
#SBATCH --time=30:00:00
#SBATCH --mem=30GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/qsiprep_1.0.1/logs/job.qsiprep.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/qsiprep_1.0.1/logs/job.qsiprep.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-286%40

# array vals: 0-286%25
# 56-66

sleep 10

IDX=${SLURM_ARRAY_TASK_ID}

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

CHECKFILE=${BIDSDIR}/derivatives/qsiprep_1.0.1/sub-${SUB_ID}.html

if [[ -f ${CHECKFILE} ]]; then
	echo ">>> ${SUB_ID} already processed, exiting..."
	exit 1
fi

module load singularity
singularity run \
    --cleanenv --containall \
    $(pwd)/containers/qsiprep_1.0.1.simg \
    --output-resolution 2 \
    ${BIDSDIR} \
    ${BIDSDIR}/derivatives/qsiprep_1.0.1 \
    participant \
    -w $(pwd)/wd/qsiprep_wf \
    --participant-label ${SUB_ID} \
    --mem 28000 \
    --omp-nthreads 1 \
    --nthreads 4 \
    --skip-bids-validation \
    --fs-license-file $(pwd)/fs_license.txt \
    --subject-anatomical-reference first-alphabetically \
    --anat-modality T1w \
    --anatomical-template MNI152NLin2009cAsym \
    --b0-threshold 100 \
    --denoise-method dwidenoise \
    --unringing-method mrdegibbs \
    --hmc-model eddy \
    --eddy-config $(pwd)/code/qsiprep_eddy_params.json \
    --pepolar-method TOPUP \
    --denoise-after-combining
    
    # 'unbiased' yields highly variable template results, some very poor
    # 'intramodal' arguments will fail jobs for subjects with only one session
    #--unbiased
    #--intramodal-template-iters 5
    #--intramodal-template-transform Rigid
    
rm -r $(pwd)/wd/qsiprep_wf/qsiprep_1_0_wf/sub_${SUB_ID}*



