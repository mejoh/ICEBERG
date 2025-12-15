#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_qsirecon.sh

# Submits a subject to qsiprep. All sessions are processed.
# Resource management reference:
# 2 CPUs, multishell_scalarfest: ~7h, 8gb for 3 sessions (yields a lot of unnecessary output, best to run separate)
# 2 CPUs, dsi_studio_autotrack: ~7h, 7gb for 2 sessions (corticostriatal tract and MD maps)
# 2 CPUs, pyafq_tractometry: ~30min, 5gb for 2 sessions (yields nicely visualized tracts, has MD, but not corticostriatal)*
# 2 CPUs, mrtrix_multishell_msmt_ACT-hsvs: ~34h, 7gb (yields connectivity matrix)*
#* The two most relevant pipelines for me: pyAFQ has MD maps from DIPY, is nice for QC, and runs quickly. MRtrix is hugely resource intense, but
#  produces the niceset customisable connectivity metrics

#SBATCH --job-name="qsirecon"
#SBATCH --time=50:00:00
#SBATCH --mem=16GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=5
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/qsirecon_1.1.1/logs/job.qsirecon.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/qsirecon_1.1.1/logs/job.qsirecon.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-286%40

# array vals: 0-286%25

sleep 5

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=59

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

# Check for pre-existing data
# PyAFQ
# CHECKFILE=${BIDSDIR}/derivatives/qsirecon_1.1.1/derivatives/qsirecon-PYAFQ/sub-${SUB_ID}
# MRtric
NSES=( `ls -d ${BIDSDIR}/derivatives/qsirecon_1.1.1/derivatives/qsirecon-MRtrix3_act-HSVS/sub-${SUB_ID}/ses-*` )
NSES=${#NSES[@]}
NCHECKFILES=( `ls -d ${BIDSDIR}/derivatives/qsirecon_1.1.1/derivatives/qsirecon-MRtrix3_act-HSVS/sub-${SUB_ID}/ses-*/dwi/*_connectivity.mat` )
NCHECKFILES=${#NCHECKFILES[@]}

if [[ ${NCHECKFILES} -eq ${NSES} ]]; then
	echo ">>> ${SUB_ID} already processed, exiting..."
	exit 1
fi

echo ">>> ${SUB_ID} lacks output, processing..."

module load singularity
# singularity run \
# 	--cleanenv --containall \
# 	--bind $(pwd)/templateflow:/templates:rw \
# 	$(pwd)/containers/qsirecon_1.1.1.simg \
# 	${BIDSDIR}/derivatives/qsiprep_1.0.1 \
# 	${BIDSDIR}/derivatives/qsirecon_1.1.1 \
# 	participant \
# 	-w $(pwd)/wd/qsirecon_wf \
# 	--participant-label ${SUB_ID} \
# 	--mem 14000 \
# 	--omp-nthreads 1 \
# 	--nprocs 16 \
# 	--fs-license-file $(pwd)/fs_license.txt \
# 	--fs-subjects-dir ${BIDSDIR}/derivatives/fmriprep_25.1.3/sourcedata/freesurfer \
# 	--b0-threshold 100 \
# 	--output-resolution 2 \
# 	--recon-spec pyafq_tractometry \
# 	--input-type qsiprep \
# 	--atlases 4S156Parcels 4S256Parcels 4S456Parcels \
# 	-v -v

# See https://xcp-d.readthedocs.io/en/latest/usage.html#external-atlases for custom atlas
singularity run \
	--cleanenv --containall \
	--bind $(pwd)/templateflow:/templates:rw \
	$(pwd)/containers/qsirecon_1.1.1.simg \
	${BIDSDIR}/derivatives/qsiprep_1.0.1 \
	${BIDSDIR}/derivatives/qsirecon_1.1.1 \
	participant \
	-w $(pwd)/wd/qsirecon_wf \
	--participant-label ${SUB_ID} \
	--mem 16000 \
	--omp-nthreads 1 \
	--nprocs 5 \
	--fs-license-file $(pwd)/fs_license.txt \
	--fs-subjects-dir ${BIDSDIR}/derivatives/fmriprep_25.1.3/sourcedata/freesurfer \
	--b0-threshold 100 \
	--output-resolution 2 \
	--recon-spec mrtrix_multishell_msmt_ACT-hsvs \
	--input-type qsiprep \
	--datasets custom_atlas=/network/iss/cenir/analyse/irm/users/martin.johansson/atlases/combined_King_Tian_Schaefer \
	--atlases CustomGlasser CustomSchaefer100  \
	-v -v
	
# Atlases: AAL116 AICHA384Ext Brainnetome246Ext Gordon333Ext 4S156Parcels	
# 4S options: 156, 256, 356, 456, 556, 656, 756, 856, 956, 1056
# Utility: reorient_fslstd
# Scalars: multishell_scalarfest (dipy_dki, dsi_studio_gqi, amico_noddi, dipy_3dshore, TORTOISE)
# Tractography: mrtrix_multishell_msmt_ACT-hsvs, mrtrix_singleshell_ss3t_ACT-hsvs, pyafq_tractometry, mrtrix_multishell_msmt_pyafq_tractometry, dsi_studio_autotrack, ss3t_fod_autotrack

rm $(pwd)/iceberg/data/bids4/derivatives/qsirecon_1.1.1/derivatives/qsirecon-MRtrix3_act-HSVS/sub-${SUB_ID}/ses*/dwi/*_model-ifod2_streamlines.tck.gz
rm -r $(pwd)/wd/qsirecon_wf/qsirecon_1_1_wf/sub-${SUB_ID}*


