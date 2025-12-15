#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/template_generate.sh

ANTSDIR="/network/iss/apps/software/scit/ANTs/2.5.4"
AFNIDIR="/network/iss/apps/software/scit/afni/24.3.06"
FSLDIR="/network/iss/apps/software/scit/fsl/6.0.7.15/share/fsl"
OUTPATH="/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065"
TEMPLATE="/network/iss/apps/software/scit/fsl/6.0.7.15/data/standard/FSL_HCP1065_FA_1mm.nii.gz"
INPUTLIST="/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/inputfiles_FA_g0-hc_g1-PDnrbd.txt"
cd ${OUTPATH}
cp ${TEMPLATE} ${OUTPATH}/standard_1mm.nii.gz
${AFNIDIR}/abin/3dresample -dxyz 2.0 2.0 2.0 -prefix standard_2mm.nii.gz -input standard_1mm.nii.gz
	
imgs=( `cat ${INPUTLIST}` )
${ANTSDIR}/bin/antsMultivariateTemplateConstruction.sh -d 3 -o T_ -a 1 -A 1 -c 5 -g 0.25 -i 4 -j 2 -k 1 -w 1 -m 100x70x50x10 -n 1 -r 1 -s CC -t GR -y 0 -z ${OUTPATH}/standard_2mm.nii.gz `echo ${imgs[@]}`

${FSLDIR}/bin/fslmaths T_template0.nii.gz -thr 0.001 -bin -fillh26 -ero T_template0_mask