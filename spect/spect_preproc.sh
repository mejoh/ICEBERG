#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/spect/spect_preproc.sh

# Description:
# Extract standardized uptake values of DaT from 123IFPCIT SPECT scans.
# - Fix S-I orientation reversal in SPECT DICOMs.
# - Co-register CT with T1w.
# - Denormalize atlas to T1w.
# - Skull-strip T1w.
# - Tissue-type segmentation of T1w.
# - Subcortical segmentation of T1w.
# - Create low-int-high binding compartments for PVC.
# - Perform interative Yang correction.
# - Perform RBV correction.
# - Normalize corrected uptake values relative to reference region (lateral occipital cortex).
# - Extract values from the striatum and globus pallidus.

# TODO:
# - Subjects without CT fail, even for IY correction. Why?

# Submits a subject for DaT extraction. All sessions are processed.
# Resource management reference:
# 2 CPUs: 3.5h, 6gb for 3 sessions

#SBATCH --job-name="DaT_xtrct"
#SBATCH --time=06:00:00
#SBATCH --mem=9GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids_dat2/logs/job.spect_preproc.%A_%a.out
#SBATCH --error=iceberg/data/bids_dat2/logs/job.spect_preproc.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-199%40

# array vals: 0-199%25
# 70: Good test case with single session
# 28: Good test case without anatomical
# 28,70,148,66,12


echo ">>> Running spect_preproc.sh (Johansson M.E., 2025-27-11)"

## Set up environment
echo ">>> Setting up environment"
export ANTSDIR="/network/iss/apps/software/scit/ANTs/2.5.4"
export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh
module unload FreeSurfer; module load FreeSurfer/8.1.0
export fs_dir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.1.0
export SUBJECTS_DIR=${fs_dir}/outputs
export FS_ALLOW_DEEP=1
source $FREESURFER_HOME/SetUpFreeSurfer.sh
export AFNIDIR=/network/iss/apps/software/scit/afni/24.3.06

## Initialize
IDX=${SLURM_ARRAY_TASK_ID}
#IDX=70
echo ">>> Initializing"
THREADS=2
PIPELINE_NAME="dat_extraction"
BIDSDIR=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat2
SUBJECTS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename) )
SUB_ID=${SUBJECTS[${IDX}]}
SESSIONS=( $(find ${BIDSDIR}/${SUB_ID}/ses-* -maxdepth 0 | xargs -n1 basename) )
ALTSUB="sub-034HX" # NOTE: Ensure that gtmseg is run for this participant before submitting jobs!

for ((i=0; i<${#SESSIONS[@]}; i++)); do

SES_ID=${SESSIONS[i]}

echo ">>> Processing ${SUB_ID} ${SES_ID}"

OUTDIR=${BIDSDIR}/derivatives/${PIPELINE_NAME}/${SUB_ID}/${SES_ID}
WDIR=${BIDSDIR}/derivatives/${PIPELINE_NAME}/${SUB_ID}/${SES_ID}/wd
mkdir -p ${WDIR}

## Set up files
IMG_T1w="${SUBJECTS_DIR}/${SUB_ID}/mri/nu.mgz"
IMG_T1w_ASEG="${SUBJECTS_DIR}/${SUB_ID}/mri/aparc.DKTatlas+aseg.mgz"
IMG_CT="${BIDSDIR}/${SUB_ID}/${SES_ID}/ct/${SUB_ID}_${SES_ID}_rec-standard_run-01_ct.nii"
IMG_SPECT="${BIDSDIR}/${SUB_ID}/${SES_ID}/spect/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReo_run-01_spect.nii"
JSON_SPECT="${BIDSDIR}/${SUB_ID}/${SES_ID}/spect/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReo_run-01_spect.json"
IMG_AAL="/network/iss/cenir/software/irm/spm12/toolbox/AAL3/AAL3v1.nii"
IMG_MNI="/network/iss/cenir/software/irm/spm12/canonical/single_subj_T1.nii" #/network/iss/cenir/software/irm/spm12/canonical/avg152T1.nii
cp ${IMG_CT} ${WDIR}/ct_orig.nii
cp ${IMG_SPECT} ${WDIR}/spect_orig.nii
${FSLDIR}/bin/fslreorient2std ${WDIR}/spect_orig.nii ${WDIR}/spect_orig.nii.gz
gunzip -f ${WDIR}/spect_orig.nii.gz
cp ${IMG_AAL} ${WDIR}/atlas_orig.nii
cp ${IMG_MNI} ${WDIR}/mni_orig.nii
SWITCH_T1w=0

## Initial data checks
# Is the SPECT data Chang-corrected using the correct coefficient?
if [[ ! -f ${IMG_SPECT} ]]; then
  echo ">>> ERROR: No SPECT image. Exiting..."
 continue	
fi
if [[ ! -f ${IMG_T1w} ]]; then

	# Option 1: Skip subject entirely
  #echo ">>> ERROR: No anatomical image. Exiting..."
  #continue	

  # Option 2: Use a representative subject in place of missing data. Tests with
  # sub-034HX as target and sub-053BF as moving yields satisfactory results.
  echo ">>> WARNING: No anatomical found. Using ${ALTSUB} as replacement..."
  SWITCH_T1w=1
  IMG_T1w="${SUBJECTS_DIR}/${ALTSUB}/mri/nu.mgz"
  IMG_T1w_ASEG="${SUBJECTS_DIR}/${ALTSUB}/mri/aparc.DKTatlas+aseg.mgz"

fi
STRING=`jq -r '.ImageComments' ${JSON_SPECT}`
TEST='Chang AC: 0.11/10.0'
if [[ ${STRING} != *$TEST* ]]; then 
 echo ">>> ERROR: Incorrect Chang correction. Exiting..."
 continue
fi

## Convert FreeSurfer output to nifti and standard orientation scheme
${FREESURFER_HOME}/bin/mri_convert ${IMG_T1w} ${WDIR}/t1w.nii.gz
${FREESURFER_HOME}/bin/mri_convert ${IMG_T1w_ASEG} ${WDIR}/t1w_aseg.nii.gz
${FSLDIR}/bin/fslreorient2std ${WDIR}/t1w.nii.gz ${WDIR}/t1w.nii.gz
${FSLDIR}/bin/fslreorient2std ${WDIR}/t1w_aseg.nii.gz ${WDIR}/t1w_aseg.nii.gz

## Coregistration
if [[ -f ${WDIR}/ct_orig.nii ]]; then
 # SPECT-to-CT-to-T1w
 echo ">>> Co-registering SPECT-to-T1w using CT-to-T1w transform"
 ${ANTSDIR}/bin/antsRegistration --dimensionality 3 --float 1 --interpolation Linear --output [ ${WDIR}/ct_to_t1w, ${WDIR}/ct_to_t1w.nii.gz ] --winsorize-image-intensities [ 0.005, 0.995 ] --use-histogram-matching 0 --initial-moving-transform [${WDIR}/t1w.nii.gz, ${WDIR}/ct_orig.nii, 1] --transform Rigid[ 0.1 ] --metric MI[${WDIR}/t1w.nii.gz, ${WDIR}/ct_orig.nii, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 10 ] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox
 ${ANTSDIR}/bin/antsApplyTransforms --default-value 0 --float 1 --input ${WDIR}/spect_orig.nii --interpolation Linear --output ${WDIR}/spect_to_t1w.nii --output-data-type int --reference-image ${WDIR}/t1w.nii.gz --transform ${WDIR}/ct_to_t1w0GenericAffine.mat --transform identity

 cd ${WDIR}
 THR=`${FSLDIR}/bin/fslstats ${WDIR}/spect_to_t1w.nii -R | awk '{print $2}' | sed 's/.$//'`
 THR=`echo ${THR%.*}`
 THR=`echo "${THR} * 0.3" | bc`
 ${FSLDIR}/bin/fslmaths ${WDIR}/spect_to_t1w.nii -thr ${THR} ${WDIR}/spect_to_t1w_thr.nii.gz
 ${FSLDIR}/bin/slicer ${WDIR}/t1w.nii.gz ${WDIR}/ct_to_t1w.nii.gz -L -s 2 -z 0.46 slz.png -z 0.48 slx.png  -z 0.50 sla.png -z 0.52 slb.png -z 0.54 slc.png -z 0.56 sld.png -z 0.58 sle.png -z 0.60 slf.png -z 0.62 slg.png -z 0.64 slh.png
 ${FSLDIR}/bin/pngappend slz.png + slx.png + sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png ct_to_t1w.png
 ${FSLDIR}/bin/slicer ${WDIR}/t1w.nii.gz ${WDIR}/spect_to_t1w_thr.nii.gz -L -s 2 -z 0.46 slz.png -z 0.48 slx.png -z 0.50 sla.png -z 0.52 slb.png -z 0.54 slc.png -z 0.56 sld.png -z 0.58 sle.png -z 0.60 slf.png -z 0.62 slg.png -z 0.64 slh.png
 ${FSLDIR}/bin/pngappend slz.png + slx.png + sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png spect_to_t1w.png
 ${FSLDIR}/bin/pngappend ct_to_t1w.png - spect_to_t1w.png coreg_results.png; rm -f sl?.png
else
 # SPECT-to-T1w (not recommended! DaT tends to land below the striatum after coreg)
 echo ">>> WARNING: Missing CT. Co-registering SPECT-to-T1w directly (suboptimal)"
 ${ANTSDIR}/bin/antsRegistration --dimensionality 3 --float 1 --interpolation Linear --output [ ${WDIR}/spect_to_t1w, ${WDIR}/spect_to_t1w.nii.gz ] --winsorize-image-intensities [ 0.005, 0.995 ] --use-histogram-matching 0 --initial-moving-transform [${WDIR}/t1w.nii.gz, ${WDIR}/spect_orig.nii, 1] --transform Rigid[ 0.1 ] --metric MI[${WDIR}/t1w.nii.gz, ${WDIR}/spect_orig.nii, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 10 ] --shrink-factors 8x4x2x1 --smoothing-sigmas 3x2x1x0vox
 ${ANTSDIR}/bin/antsApplyTransforms --default-value 0 --float 1 --input ${WDIR}/spect_orig.nii --interpolation Linear --output ${WDIR}/spect_to_t1w.nii --reference-image ${WDIR}/t1w.nii.gz --transform ${WDIR}/spect_to_t1w0GenericAffine.mat --transform identity

 cd ${WDIR}
 THR=`${FSLDIR}/bin/fslstats ${WDIR}/spect_to_t1w.nii -R | awk '{print $2}' | sed 's/.$//'`
 THR=`echo ${THR%.*}`
 THR=`echo "${THR} * 0.3" | bc`
 ${FSLDIR}/bin/fslmaths ${WDIR}/spect_to_t1w.nii -thr ${THR} ${WDIR}/spect_to_t1w_thr.nii.gz
 ${FSLDIR}/bin/slicer ${WDIR}/t1w.nii.gz ${WDIR}/spect_to_t1w_thr.nii.gz -L -s 2 -z 0.46 slz.png -z 0.48 slx.png -z 0.50 sla.png -z 0.52 slb.png -z 0.54 slc.png -z 0.56 sld.png -z 0.58 sle.png -z 0.60 slf.png -z 0.62 slg.png -z 0.64 slh.png
 ${FSLDIR}/bin/pngappend slz.png + slx.png + sla.png + slb.png + slc.png + sld.png + sle.png + slf.png + slg.png + slh.png spect_to_t1w.png
 ${FSLDIR}/bin/pngappend spect_to_t1w.png coreg_results.png; rm -f sl?.png
fi

## Atlas denormalization: AAL-to-T1w (applicable to any atlas-mni combination)
echo ">>> Denormalizing atlas to T1w space"
${ANTSDIR}/bin/antsRegistration --collapse-output-transforms 1 --dimensionality 3 --float 1 --interpolation LanczosWindowedSinc --output [ ${WDIR}/t1w_to_mni, ${WDIR}/t1w_to_mni.nii.gz ] --winsorize-image-intensities [ 0.005, 0.995 ] --use-histogram-matching 1 --initial-moving-transform [${WDIR}/mni_orig.nii, ${WDIR}/t1w.nii.gz, 1] --transform Rigid[ 0.1 ] --metric MI[${WDIR}/mni_orig.nii, ${WDIR}/t1w.nii.gz, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 10 ] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 --transform Affine[ 0.1 ] --metric MI[${WDIR}/mni_orig.nii, ${WDIR}/t1w.nii.gz, 1, 32, Regular, 0.25 ] --convergence [ 1000x500x250x100, 1e-06, 20 ] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 --transform SyN[ 0.1, 3.0, 0.0 ] --metric CC[${WDIR}/mni_orig.nii, ${WDIR}/t1w.nii.gz, 1, 4, None, 1 ] --convergence [ 100x70x50x20, 1e-06, 10 ] --smoothing-sigmas 3.0x2.0x1.0x0.0vox --shrink-factors 8x4x2x1 --write-composite-transform 1
${ANTSDIR}/bin/antsApplyTransforms --default-value 0 --float 0 --input ${WDIR}/atlas_orig.nii --interpolation GenericLabel --output ${WDIR}/denorm_atlas.nii.gz --reference-image ${WDIR}/t1w.nii.gz --transform ${WDIR}/t1w_to_mniInverseComposite.h5 --transform identity

## Create compartments (possible to choose which parcellation to use: first, fs, or denormalized atlas)
echo ">>> Generating tissue compartments and sub-cortical segmentation"
${FREESURFER_HOME}/bin/mri_synthstrip -i ${WDIR}/t1w.nii.gz -o ${WDIR}/t1w_brain.nii.gz -m ${WDIR}/t1w_brain_mask.nii.gz -t ${THREADS}
${FSLDIR}/bin/fast -o ${WDIR}/fast -g -N ${WDIR}/t1w_brain.nii.gz
${FSLDIR}/bin/run_first_all -i ${WDIR}/t1w_brain.nii.gz -b -s L_Caud,R_Caud,L_Puta,R_Puta,L_Accu,R_Accu,L_Pall,R_Pall -o ${WDIR}/first
############################################################################
# Reference table for segmentations                                        #
# __FIRST__                                                                #
# Caud: R=50, L=11 # Put: R=51, L=12 # NAcc: R=58, L=26 # GP: R=52, L=13   #
# __ASEG__                                                                 #
# Caud: R=50, L=11 # Put: R=51, L=12 # NAcc: R=58, L=26 # GP: R=52, L=13   #
# __AAL___                                                                 #
# Caud: R=76, L=75 # Put: R=78, L=77 # NAcc: R=158, L=157 # GP: R=80, L=79 #
############################################################################
# GM: High
SEG="t1w_aseg" # "first_all_none_firstseg" or "t1w_aseg"
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 49.9 -uthr 50.1 -bin ${WDIR}/c1_high.nii.gz # R_Caud
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 50.9 -uthr 51.1 -bin -add ${WDIR}/c1_high.nii.gz ${WDIR}/c1_high.nii.gz	# R_Put
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 57.9 -uthr 58.1 -bin -add ${WDIR}/c1_high.nii.gz ${WDIR}/c1_high.nii.gz	# R_NAcc
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 10.9 -uthr 11.1 -bin -add ${WDIR}/c1_high.nii.gz ${WDIR}/c1_high.nii.gz	# L_Caud
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 11.9 -uthr 12.1 -bin -add ${WDIR}/c1_high.nii.gz ${WDIR}/c1_high.nii.gz	# L_Put
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 25.9 -uthr 26.1 -bin -add ${WDIR}/c1_high.nii.gz ${WDIR}/c1_high.nii.gz	# L_NAcc
# GM: Intermediate
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 51.9 -uthr 52.1 -bin ${WDIR}/c1_inter.nii.gz # R_GP
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 12.9 -uthr 13.1 -bin -add ${WDIR}/c1_inter.nii.gz ${WDIR}/c1_inter.nii.gz	# L_GP
# GM: Low
${FSLDIR}/bin/fslmaths ${WDIR}/fast_pve_1.nii.gz -thr 0.8 -sub ${WDIR}/c1_high.nii.gz -sub ${WDIR}/c1_inter.nii.gz -thr 0 ${WDIR}/c1_low.nii.gz
# WM
${FSLDIR}/bin/fslmaths ${WDIR}/fast_pve_2.nii.gz -thr 0.8 -bin -sub ${WDIR}/c1_high.nii.gz -sub ${WDIR}/c1_inter.nii.gz -sub ${WDIR}/c1_low.nii.gz -thr 0 -bin ${WDIR}/c2_wm.nii.gz
# CSF
${FSLDIR}/bin/fslmaths ${WDIR}/fast_pve_0.nii.gz -thr 0.8 -bin -sub ${WDIR}/c1_high.nii.gz -sub ${WDIR}/c1_inter.nii.gz -sub ${WDIR}/c1_low.nii.gz -sub ${WDIR}/c2_wm.nii.gz -thr 0 -bin ${WDIR}/c0_csf.nii.gz
# Unzip for PVC
gunzip -f ${WDIR}/c1_high.nii.gz
gunzip -f ${WDIR}/c1_inter.nii.gz
gunzip -f ${WDIR}/c1_low.nii.gz
gunzip -f ${WDIR}/c2_wm.nii.gz
gunzip -f ${WDIR}/c0_csf.nii.gz

## YeB atlas segmentations (currently not implemented)
echo ">>> NOT YET IMPLEMENTED: Denormalizing YeB atlas to T1w space"
# <in progress>

## Partial volume correction
# Iterative Yang
echo ">>> Performing partial volume correction: iterative Yang"
cd /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/dat
ITER=30
matlab -batch "iterative_yang_func('${BIDSDIR}/derivatives/dat_extraction','${SUB_ID}','${SES_ID}', ${ITER})" -logfile ${BIDSDIR}/logs/iterativeYang_${SUB_ID}_${SES_ID}_log.txt
# RBV and SGTM (FreeSurfer)
echo ">>> Performing partial volume correction: RBV"
if [ ! -f ${SUBJECTS_DIR}/${SUB_ID}/mri/gtmseg.mgz ]; then
	# Generate geometric transformation matrix (~1h)
	${FREESURFER_HOME}/bin/gtmseg --s ${SUB_ID} --threads ${THREADS}
fi
${AFNIDIR}/abin/3dresample -input ${WDIR}/ct_orig.nii -master ${WDIR}/spect_orig.nii -prefix ${WDIR}/ct_downsample.nii.gz
if [ ${SWITCH_T1w} -eq 0 ]; then
	${FREESURFER_HOME}/bin/mri_coreg --s ${SUB_ID} --mov ${WDIR}/ct_downsample.nii.gz --reg ${WDIR}/ct_to_t1w.reg.lta --ref nu.mgz --no-ref-mask --movout ${WDIR}/ct_downsample_to_t1w.nii.gz
	${FREESURFER_HOME}/bin/mri_gtmpvc --i ${WDIR}/spect_orig.nii --reg ${WDIR}/ct_to_t1w.reg.lta --psf 8.838725614 --seg ${SUBJECTS_DIR}/${SUB_ID}/mri/gtmseg.mgz --default-seg-merge --rbv --auto-mask 1 .01 --no-rescale --no-reduce-fov --threads 2 --o ${WDIR}/gtmpvc.output # --no-rescale is necessary beacuase pons is not included in ctab!
else
	${FREESURFER_HOME}/bin/mri_coreg --s ${ALTSUB} --mov ${WDIR}/ct_downsample.nii.gz --reg ${WDIR}/ct_to_t1w.reg.lta --ref nu.mgz --no-ref-mask --movout ${WDIR}/ct_downsample_to_t1w.nii.gz
	${FREESURFER_HOME}/bin/mri_gtmpvc --i ${WDIR}/spect_orig.nii --reg ${WDIR}/ct_to_t1w.reg.lta --psf 8.838725614 --seg ${SUBJECTS_DIR}/${ALTSUB}/mri/gtmseg.mgz --default-seg-merge --rbv --auto-mask 1 .01 --no-rescale --no-reduce-fov --threads 2 --o ${WDIR}/gtmpvc.output # --no-rescale is necessary beacuase pons is not included in ctab!
fi
${FSLDIR}/bin/fslreorient2std ${WDIR}/gtmpvc.output/rbv.nii.gz ${WDIR}/gtmpvc.output/rbv_reo.nii.gz
${AFNIDIR}/abin/3dresample -input ${WDIR}/gtmpvc.output/rbv_reo.nii.gz -master ${WDIR}/spect_to_t1w.nii -prefix ${WDIR}/spect_to_t1w_corrRBV.nii.gz
${FSLDIR}/bin/fslmaths ${WDIR}/spect_to_t1w_corrRBV.nii.gz -mas ${WDIR}/t1w_brain_mask.nii.gz -thr 0 ${WDIR}/spect_to_t1w_corrRBV.nii.gz

## Normalize relative to occipital cortex
echo ">>> Normalizing corrected SPECT data by uptake in occipital cortex"
${FSLDIR}/bin/fslmaths ${WDIR}/denorm_atlas.nii.gz -thr 46.9 -uthr 58.1 -mul ${WDIR}/fast_seg_1.nii.gz -bin ${WDIR}/mask_aal_occipital.nii.gz
REFVAL=`${FSLDIR}/bin/fslstats ${WDIR}/spect_to_t1w_corrIY${ITER}.nii -k ${WDIR}/mask_aal_occipital.nii.gz -M`
${FSLDIR}/bin/fslmaths ${WDIR}/spect_to_t1w_corrIY${ITER}.nii -div ${REFVAL} ${WDIR}/spect_to_t1w_corrIY${ITER}Norm.nii
echo ${REFVAL} > ${WDIR}/refval_corrIY${ITER}Norm.txt
REFVAL=`${FSLDIR}/bin/fslstats ${WDIR}/spect_to_t1w_corrRBV.nii.gz -k ${WDIR}/mask_aal_occipital.nii.gz -M`
${FSLDIR}/bin/fslmaths ${WDIR}/spect_to_t1w_corrRBV.nii.gz -div ${REFVAL} ${WDIR}/spect_to_t1w_corrRBVNorm.nii.gz
echo ${REFVAL} > ${WDIR}/refval_corrRBVNorm.txt

## Extract values. This step is best done using the same approach as was used for compartment creation. However,
# note that RBV processing will always rely on the ASEG segmentation, even if it later relies on FIRST output during extraction!
echo ">>> Extracting stats from ROIs and writing to tables"
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 50.9 -uthr 51.1 -bin ${WDIR}/mask_roi.nii.gz										# R_Put
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 11.9 -uthr 12.1 -bin -mul 2 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz	# L_Put
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 49.9 -uthr 50.1 -bin -mul 3 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz 	# R_Caud
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 10.9 -uthr 11.1 -bin -mul 4 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz	# L_Caud
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 57.9 -uthr 58.1 -bin -mul 5 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz	# R_NAcc
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 25.9 -uthr 26.1 -bin -mul 6 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz	# L_NAcc
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 51.9 -uthr 52.1 -bin -mul 7 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz	# R_GP
${FSLDIR}/bin/fslmaths ${WDIR}/${SEG}.nii.gz -thr 12.9 -uthr 13.1 -bin -mul 8 -add ${WDIR}/mask_roi.nii.gz ${WDIR}/mask_roi.nii.gz	# L_GP
cat > ${WDIR}/roi-striatum_dseg.csv << EOF
index,label
1,R_PUTA
2,L_PUTA
3,R_CAUD
4,L_CAUD
5,R_NACC
6,L_NACC
7,R_GP
8,L_GP
EOF

${AFNIDIR}/abin/3dROIstats -nzmean -nzmedian -nzsigma -minmax -nomeanout -nobriklab -mask ${WDIR}/mask_roi.nii.gz ${WDIR}/spect_to_t1w_corrIY${ITER}Norm.nii > ${WDIR}/spect_to_t1w_corrIY${ITER}Norm_dat.txt
${AFNIDIR}/abin/3dROIstats -nzmean -nzmedian -nzsigma -minmax -nomeanout -nobriklab -mask ${WDIR}/mask_roi.nii.gz ${WDIR}/spect_to_t1w_corrRBVNorm.nii.gz > ${WDIR}/spect_to_t1w_corrRBVNorm_dat.txt

## Final output
echo ">>> Organizing final output"
cp ${WDIR}/t1w.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_T1w.nii.gz
cp ${WDIR}/t1w_aseg.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_T1w_aseg.nii.gz
cp ${WDIR}/first_all_none_firstseg.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_T1w_firstseg.nii.gz
cp ${WDIR}/denorm_atlas.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_T1w_atlas.nii.gz
cp ${WDIR}/mask_aal_occipital.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_roi-occipital.nii.gz
cp ${WDIR}/mask_roi.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_roi-striatum.nii.gz
cp ${WDIR}/roi-striatum_dseg.csv ${OUTDIR}/${SUB_ID}_${SES_ID}_roi-striatum_dseg.csv
cp ${WDIR}/spect_to_t1w.nii ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReo_space-T1w_spect.nii
gzip -f ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReo_space-T1w_spect.nii
cp ${WDIR}/spect_to_t1w_corrIY${ITER}.nii ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoIY${ITER}_space-T1w_spect.nii
gzip -f ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoIY${ITER}_space-T1w_spect.nii
cp ${WDIR}/spect_to_t1w_corrIY${ITER}Norm.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoIY${ITER}Norm_space-T1w_spect.nii.gz 
cp ${WDIR}/spect_to_t1w_corrRBV.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoRBV_space-T1w_spect.nii.gz
cp ${WDIR}/spect_to_t1w_corrRBVNorm.nii.gz ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoRBVNorm_space-T1w_spect.nii.gz
cp ${WDIR}/gtmpvc.output/gtm.stats.dat ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoSGTM_stat-dat_spect.txt
cp ${WDIR}/spect_to_t1w_corrIY${ITER}Norm_dat.txt ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoIY${ITER}Norm_stat-dat_spect.txt
cp ${WDIR}/spect_to_t1w_corrRBVNorm_dat.txt ${OUTDIR}/${SUB_ID}_${SES_ID}_trc-123IFPCIT_rec-ChangReoRBVNorm_stat-dat_spect.txt
cp ${WDIR}/iY_convergence.png ${OUTDIR}
cp ${WDIR}/finalSimulation.nii ${OUTDIR}/iY_final_simulation.nii
gzip -f ${OUTDIR}/iY_final_simulation.nii
cp ${WDIR}/refval_corrIY${ITER}Norm.txt ${OUTDIR}
cp ${WDIR}/refval_corrRBVNorm.txt ${OUTDIR}
cp ${WDIR}/coreg_results.png ${OUTDIR}

echo ">>> Removing intermediate otuput"
#rm -r ${WDIR}

echo ">>> Done!"

done
