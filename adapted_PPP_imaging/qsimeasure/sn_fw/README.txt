/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/README.txt

Hierarchical description of code, quality control, and output from Martin E. Johansson's free water extraction pipeline.

Code (in order of application):
|_ /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw
|__ qsimeasure2.sh - Generates DTIs using the three python scripts below.
|___ amico_noddi.py - FW extraction with NODDI.
|___ dipy_b0.py - Generating mean b0-images for ROI drawing.
|___ dipy_fw.py - FW (plus additional DTI metrics) extraction using Dipy.
|__ pasternak_fw.m - FW extraction using Ofer Pasternak's method.
|__ template_inputlist.R - Select age- and sex-matched patients and controls for template creation.
|__ template_generate.sh - antsMultivariateTemplateConstruction, with FSL_HCP1065_FA_1mm as the target (downsampled to 2mm).
|__ normalize_dti2mni.sh - Estimate and apply transformation from subject-specific DWI space to study-specific template space.
|__ normalize_dti2mni_sub.sh - Submit normalize_dti2mni.sh for each subject and session.
|__ assemble_images.sh - Concatenate and average b0 and DTI. The average b0 image is used to manually draw the SN.
|__ extract_sn_fw.sh - Extracts stats from the SN mask for a desired DTI.

Quality control:
|_ /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives
|__ quality_control_dwi.csv:  The 'exclude' column tells you which subjects's sessions are corrupted and should be excluded.
 
Output images:
|_ /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1
|__ sub*/ses*: Preprocessed DWI data derived using qsiprep.
|__ derivatives: Derivatives of preprocessed DWI data.
*NOTE: All non-normalized qsiprep output (including those below) have LPS orientation. 
fslreorient2std can be used to set them to standard RAS.

|___ dipy_b0: Mean b0 images, particularly from subjects used for template generation.
|____ sub-*/ses-* - Contains mean b0 images in study-template MNI space (n2 prefix) or subject-specific space (no prefix).
|____ assembled
|_____ *concat.nii.gz and *avg.nii.gz: Concatenated images in MNI space and their averages.  
|_____ *sn_mask.nii.gz: Mask of anterior and posterior SN.*

|___ amico_noddi: NODDI images derived using the dmri-amico package in python (https://github.com/daducci/AMICO)
|____ sub-*/ses-* - Contains NODDI images in study-template MNI space (n2 prefix) or subject-specific space (no prefix).
|____ assembled
|_____ *concat.nii.gz and *avg.nii.gz: Concatenated images in MNI space and their averages.
|_____ *concat.txt and *stats.txt: Image list and stats from the SN ROI.

|___ dipy_fw: FW images (plus other DTIs) derived using the dipy package in python.
|____ sub-*/ses-* - Contains dipy FW images in study-template MNI space (n2 prefix) or subject-specific space (no prefix).
|____ assembled
|_____ *concat.nii.gz and *avg.nii.gz: Concatenated images in MNI space and their averages
|_____ *concat.txt and *stats.txt: Image list and stats from the SN ROI.

|___ pasternak_fw: FW images derived using custom matlab scripts from Ofer Pasternak. NOTE! These images should ONLY be used as a reference to Vaillancourt's work. We do not have license to publish with this method.
|____ sub-*/ses-* - Contains Pasternak FW images in study-template MNI space (n2 prefix) or subject-specific space (no prefix).
|____ assembled
|_____ *concat.nii.gz and *avg.nii.gz: Concatenated images in MNI space and their averages. 
|_____ *concat.txt and *stats.txt: Image list and stats from the SN ROI.
|___ reg: Non-linear DWI-to-MNI and MNI-to-DWI transformations.

Study-specific template:
|_ /network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065
|__ inputfiles_B0_g0-hc_g1-PDnrbd.txt - Mean b0 images from 50 controls and 50 PD patients (non-RBD), matched for age and sex.
|__ standard_*.nii.gz - Target templates copied from the FSL data directory.
|__ T_template0.nii.gz - Final template in 2mm resolution.

Tabular data:
|_ /network/iss/cenir/analyse/irm/users/martin.johansson/tmp
|__ write_psnfw.R - Create tabular file.
|__ ICEBERG_psnfw_2025-11-17.csv - Contains mean (NZMean) and median (NZMed) FW values, derived using three different methods (dipy, pasternak, noddi), extracted from the bilateral anterior and posterior SN.

