#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_xcpd.sh

# Submits a subject to xcp-d. All sessions are processed.
# Resource management reference:
# ~1.5h, 10gb for 3 sessions

#SBATCH --job-name="xcpd"
#SBATCH --time=04:00:00
#SBATCH --mem=16GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/xcpd_0.11.1/logs/job.xcpd.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/xcpd_0.11.1/logs/job.xcpd.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-286%50

# 21,30,82,102,186,221,275
# array vals: 0-286%25

### >>> xcpdatlases=$(pwd)/atlases/xcp_d
### >>> XCP-D attempts to take atlases from local installation in singularity image, but
### >>> fails. Setting the path of the atlas directory to a local copy of the atlases
### >>> seems to rectify this issue.
### >>> UPDATE: it might have been a problem caused by the --containall variable.
### >>> Removing this argument leads to succesful processing.

sleep 10

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=0

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
export SINGULARITYENV_TEMPLATEFLOW_HOME="/network/iss/cenir/analyse/irm/users/martin.johansson/templateflow"

CHECKFILE=${BIDSDIR}/derivatives/xcpd_0.11.1/sub-${SUB_ID}.html

if [[ -f ${CHECKFILE} ]]; then
	echo ">>> ${SUB_ID} already processed, exiting..."
	exit 1
fi

# NIFTI
module load singularity
singularity run \
	--cleanenv \
	--bind $(pwd)/templateflow:/templates:rw \
	$(pwd)/containers/xcpd_0.11.1.simg \
	${BIDSDIR}/derivatives/fmriprep_25.1.3 \
	${BIDSDIR}/derivatives/xcpd_0.11.1 \
	participant \
	-w $(pwd)/wd/xcpd_wf \
	--participant-label ${SUB_ID} \
	--mem-mb 16000 \
	--omp-nthreads 1 \
	--nthreads 2 \
	--fs-license-file $(pwd)/fs_license.txt \
	--aggregate-session-reports 3 \
	--resource-monitor \
	--report-output-level root \
	--task-id rest \
	--datasets aroma=${BIDSDIR}/derivatives/fmripost_aroma_0.0.12 \
	--input-type fmriprep \
	--mode none \
	--file-format nifti \
	--dummy-scans 5 \
	--despike n \
	--nuisance-regressors ./code/xcpd_confounds.yaml \
	--combine-runs n \
	--smoothing 0 \
	--motion-filter-type lp \
	--band-stop-min 6 \
	--motion-filter-order 4 \
	--head-radius auto \
	--fd-thresh 0.5 \
	--min-time 240 \
	--output-type censored \
	--lower-bpf 0.007 \
	--upper-bpf 0 \
	--bpf-order 2 \
	--atlases 4S156Parcels 4S256Parcels 4S456Parcels Glasser Tian \
	--min-coverage 0.5 \
	--linc-qc y \
	--abcc-qc y \
	--create-matrices all \
	--warp-surfaces-native2std n

# CIFTI	
#singularity run \
#	--cleanenv \
#	--bind $(pwd)/templateflow:/templates:rw \
#	$(pwd)/containers/xcpd_0.11.1.simg \
#	${BIDSDIR}/derivatives/fmriprep_25.1.3_cifti \
#	${BIDSDIR}/derivatives/xcpd_0.11.1_cifti \
#	participant \
#	-w $(pwd)/wd/xcpd_wf \
#	--participant-label ${SUB_ID} \
#	--mem-mb 16000 \
#	--omp-nthreads 1 \
#	--nthreads 2 \
#	--fs-license-file $(pwd)/fs_license.txt \
#	--aggregate-session-reports 3 \
#	--resource-monitor \
#	--report-output-level root \
#	--task-id rest \
#	--datasets aroma=${BIDSDIR}/derivatives/fmripost_aroma_0.0.12 \
#	--input-type fmriprep \
#	--mode none \
#	--file-format cifti \
#	--dummy-scans 5 \
#	--despike n \
#	--nuisance-regressors ./code/xcpd_confounds.yaml \
#	--combine-runs n \
#	--smoothing 8 \
#	--motion-filter-type lp \
#	--band-stop-min 6 \
#	--motion-filter-order 4 \
#	--head-radius auto \
#	--fd-thresh 0.5 \
#	--min-time 240 \
#	--output-type censored \
#	--lower-bpf 0.007 \
#	--upper-bpf 0 \
#	--bpf-order 2 \
#	--atlases 4S156Parcels 4S256Parcels 4S456Parcels Glasser Gordon HCP MIDB MyersLabonte Tian \
#	--min-coverage 0.5 \
#	--linc-qc y \
#	--abcc-qc y \
#	--create-matrices all \
#	--warp-surfaces-native2std y

rm -r $(pwd)/wd/xcpd_wf/sub-${SUB_ID}*
rm -r $(pwd)/wd/xcpd_wf/xcpd_d_0_11_wf/sub-${SUB_ID}*
