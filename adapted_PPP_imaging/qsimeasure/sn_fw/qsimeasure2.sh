#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/qsimeasure2.sh

# Submits a subject to qsiprep. All sessions are processed.
# Resource management reference:
# 1 cores: ~?h, ?gb for 3 sessions*

#SBATCH --job-name="qsimeasure"
#SBATCH --time=01:00:00
#SBATCH --mem=10GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/qsiprep_1.0.1/logs/job.qsimeasure.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/qsiprep_1.0.1/logs/job.qsimeasure.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-282%30

# array vals: 0-282%25
# 56-66

sleep 0.5

IDX=${SLURM_ARRAY_TASK_ID}

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 -type d | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

cd /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/qsimeasure
source .venv/bin/activate

force=0
dti_method='amico_noddi' # dipy_b0 dipy_fw amico_noddi

echo ">>> Processing sub-${SUB_ID}, ${dti_method}"

nses=`ls -d ${BIDSDIR}/sub-${SUB_ID}/ses*/dwi/sub*desc-preproc_dwi.nii.gz | wc -l`
if [[ $dti_method == "dipy_b0" ]]; then
    noutput=`ls ${BIDSDIR}/derivatives/${dti_method}/sub-${SUB_ID}/ses*/sub*dipy-b0mean.nii.gz | wc -l`
    if [[ $nses -eq $noutput && force -eq 0 ]]; then
        echo ">>> Already processed, exiting..."
        exit 1
    fi
    cmd="python3 /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/dipy_b0.py $BIDSDIR $SUB_ID"
elif [[ $dti_method == "dipy_fw" ]]; then
    noutput=`ls ${BIDSDIR}/derivatives/${dti_method}/sub-${SUB_ID}/ses*/sub*dipy-FW.nii.gz | wc -l`
    if [[ $nses -eq $noutput && force -eq 0 ]]; then
        echo ">>> Already processed, exiting..."
        exit 1
    fi
    cmd="python3 /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/dipy_fw.py $BIDSDIR $SUB_ID"
elif [[ $dti_method == "amico_noddi" ]]; then
    noutput=`ls ${BIDSDIR}/derivatives/${dti_method}/sub-${SUB_ID}/ses*/fit_FWF.nii.gz | wc -l`
    if [[ $nses -eq $noutput && force -eq 0 ]]; then
        echo ">>> Already processed, exiting..."
        exit 1
    fi
    cmd="python3 /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/amico_noddi.py $BIDSDIR $SUB_ID"
else
    echo ">>> Invalid DTI method specified, exiting..."
fi

$cmd
