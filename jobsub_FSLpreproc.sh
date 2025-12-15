#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/jobsub_FSLpreproc.sh

# Submits a subject to FSL FEAT. All sessions are processed.
# Resource management reference:
# ~?? min, ??gb for 3 sessions

#SBATCH --job-name="FEAT"
#SBATCH --time=4:00:00
#SBATCH --mem=8GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/derivatives/fsl_6.0.7.15/logs/job.FEAT.%A_%a.out
#SBATCH --error=iceberg/data/bids4/derivatives/fsl_6.0.7.15/logs/job.FEAT.%A_%a.err
#SBATCH --array=14

# array vals: 0-286%25

module load FSL/6.0.7.15
export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh
module add FreeSurfer/8.1.0

#sleep 10

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=0

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
SESSIONS=( "V0" "V2" "V4" )
FSF="${BIDSDIR}/derivatives/fsl_6.0.7.15/preproc.fsf"

for SES_ID in ${SESSIONS[@]}; do

	# Check inputs
	ANAT=${BIDSDIR}/derivatives/fmriprep_25.1.3/sourcedata/freesurfer/sub-${SUB_ID}/mri/T1.mgz
	ANAT_B=${BIDSDIR}/derivatives/fmriprep_25.1.3/sourcedata/freesurfer/sub-${SUB_ID}/mri/brain.mgz
	FUNC=${BIDSDIR}/sub-${SUB_ID}/ses-${SES_ID}/func/sub-${SUB_ID}_ses-${SES_ID}_task-rest_bold.nii.gz
	FMAP_MAG=${BIDSDIR}/sub-${SUB_ID}/ses-${SES_ID}/fmap/sub-${SUB_ID}_ses-${SES_ID}_magnitude1.nii.gz
	FMAP_PHASE=${BIDSDIR}/sub-${SUB_ID}/ses-${SES_ID}/fmap/sub-${SUB_ID}_ses-${SES_ID}_phasediff.nii.gz
	if [[ ! -f ${ANAT} || ! -f ${ANAT_B} || ! -f ${FUNC} || ! -f ${FMAP_MAG} || ! -f ${FMAP_PHASE} ]]; then
		echo ">>> ANAT or FUNC or FMAP missing, exiting..."
		echo $ANAT
		echo $ANAT_B
		echo $FUNC
		echo $FMAP_MAG
		echo $FMAP_PHASE
		exit 1
	fi
	
	# Initialize directory
	PREPROCDIR=${BIDSDIR}/derivatives/fsl_6.0.7.15/sub-${SUB_ID}/ses-${SES_ID}
	mkdir -p ${PREPROCDIR}
	
	# Retrieve files that require some processing before FEAT
	${FREESURFER_HOME}/bin/mri_convert ${ANAT} ${PREPROCDIR}/anat.nii.gz
	${FREESURFER_HOME}/bin/mri_convert ${ANAT_B} ${PREPROCDIR}/anat_brain.nii.gz
	${FSLDIR}/bin/fslreorient2std ${PREPROCDIR}/anat.nii.gz ${PREPROCDIR}/anat.nii.gz
	${FSLDIR}/bin/fslreorient2std ${PREPROCDIR}/anat_brain.nii.gz ${PREPROCDIR}/anat_brain.nii.gz
	${FREESURFER_HOME}/bin/mri_synthstrip -i ${FMAP_MAG} -o ${PREPROCDIR}/fmap_mag_brain.nii.gz -t 2
	${FSLDIR}/bin/fsl_prepare_fieldmap SIEMENS ${FMAP_PHASE} ${PREPROCDIR}/fmap_mag_brain.nii.gz ${PREPROCDIR}/fmap_rads 2.46
	
	# Generate confounds file
	# Take confounds from fmriprep
	#CONFS=${BIDSDIR}/derivatives/fmriprep_25.1.3/sub-${SUB_ID}/ses-${SES_ID}/func/sub-${SUB_ID}_ses-${SES_ID}_task-rest_desc-confounds_timeseries.tsv
	# Remove first 5 rows
	#cat ${CONFS} | awk '{print $1,$2}' | awk 'NR > 5 { print }' > test.txt
	
	
	# Edit preprocessing design template
	cp ${FSF} ${PREPROCDIR}/preproc.fsf
	sed -i "s#<OUTPUTDIR>#${PREPROCDIR}/preproc#g" ${PREPROCDIR}/preproc.fsf
	sed -i "s#<IMG_BOLD>#${FUNC}#g" ${PREPROCDIR}/preproc.fsf
	sed -i "s#<IMG_FMAP_RADS>#${PREPROCDIR}/fmap_rads.nii.gz#g" ${PREPROCDIR}/preproc.fsf
	sed -i "s#<IMG_FMAP_MAG>#${PREPROCDIR}/fmap_mag_brain.nii.gz#g" ${PREPROCDIR}/preproc.fsf
	sed -i "s#<IMG_ANAT_BRAIN>#${PREPROCDIR}/anat_brain.nii.gz#g" ${PREPROCDIR}/preproc.fsf
	
	# Perform preprocessing
	${FSLDIR}/bin/feat ${PREPROCDIR}/preproc.fsf
	
done












