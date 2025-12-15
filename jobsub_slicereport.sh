#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_slicereport.sh

# Submits a subject to BIDSCOIN's slicereport plugin. All sessions are processed.
# Resource management reference:
# ~?? min, 300MB for 3 sessions

#SBATCH --job-name="slicereport"
#SBATCH --time=00:15:00
#SBATCH --mem=1000MB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/slicereport_bidscoin_4.6.2/logs/job.slicereport.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/slicereport_bidscoin_4.6.2/logs/job.slicereport.%A_%a.err
#SBATCH --exclude=sphpc-cpu20

# array vals: 0-286%25

#IDX=${SLURM_ARRAY_TASK_ID}
#IDX=0

SLICEREPORT_DIR=/network/iss/home/martin.johansson/.local/bin/
BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat"
#INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
#SUB_ID=${INPUT_SUBS[${IDX}]}

#module load miniforge
#conda activate py312

REPORTDIR="${BIDSDIR}/derivatives/slicereport_bidscoin_4.6.2"

# Anatomical
# ${SLICEREPORT_DIR}/slicereport \
# 	${BIDSDIR} \
# 	anat/*acq-UNIm_T1w.nii.gz \
# 	-r ${REPORTDIR}/anat/orig
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR}/derivatives/fmriprep_25.1.3/sourcedata/freesurfer \
#	mri/orig.mgz \
#	-r ${REPORTDIR}/anat/freesurfer \
#	-p ${SUB_ID}

# Functional
# ${SLICEREPORT_DIR}/slicereport \
# 	${BIDSDIR} \
# 	func/*task-rest_bold.nii.gz \
# 	-r ${REPORTDIR}/func/orig
# 	--suboperations " -Tmean"
# ${SLICEREPORT_DIR}/slicereport \
# 	${BIDSDIR}/derivatives/fmriprep_25.1.3 \
# 	func/*task-rest_space-MNI152NLin6Asym_res-2_boldref.nii.gz \
# 	-r ${REPORTDIR}/func/fmriprep
#${SLICEREPORT_DIR}/slicereport \
#	/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based \
#	estimates/fsl_granularity2_gs1.feat/mask.nii.gz \
#	-r ${REPORTDIR}/func/fc_seed_based	
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR}/derivatives/xcpd_0.11.0 \
#	func/*task-rest_space-MNI152NLin6Asym_res-2_stat-alff_boldmap.nii.gz \
#	-r ${REPORTDIR}/func/xcpd/alff \
#	-p ${SUB_ID}
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR}/derivatives/xcpd_0.11.0 \
#	func/*task-rest_space-MNI152NLin6Asym_res-2_stat-reho_boldmap.nii.gz \
#	-r ${REPORTDIR}/func/xcpd/reho \
#	-p ${SUB_ID}

# DWI
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR} \
#	dwi/*dir-AP_run-0*_dwi.nii.gz \
#	-r ${REPORTDIR}/dwi/orig \
#	-p ${SUB_ID} \
#	--suboperations " -Tmean"
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR}/derivatives/qsiprep_1.0.1 \
#	dwi/*space-ACPC_dwiref.nii.gz \
#	-r ${REPORTDIR}/dwi/qsiprep
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR}/derivatives/qsirecon_1.1.0/derivatives/qsirecon-NODDI \
#	dwi/*space-ACPC_model-noddi_param-icvf_desc-modulated_dwimap.nii.gz \
#	-r ${REPORTDIR}/dwi/qsirecon
#${SLICEREPORT_DIR}/slicereport \
#	${BIDSDIR}/derivatives/qsiprep_1.0.1/derivatives/pasternak_fw \
#	*pasternak_FW.nii.gz \
#	-r ${REPORTDIR}/dwi/pasternak_fw

# DaT
${SLICEREPORT_DIR}/slicereport \
	${BIDSDIR}/derivatives/dat_extraction \
	*trc-123IFPCIT_rec-ChangReoIY30Norm_space-T1w_spect.nii.gz \
	-r ${REPORTDIR}/IYNorm
${SLICEREPORT_DIR}/slicereport \
	${BIDSDIR}/derivatives/dat_extraction \
	*trc-123IFPCIT_rec-ChangReoRBVNorm_space-T1w_spect.nii.gz \
	-r ${REPORTDIR}/RBVNorm

















