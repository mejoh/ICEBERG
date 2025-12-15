#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fcs_3dLMEr.sh

# Estimate seed-based
# Resource management reference:
# ~??h, ??gb

#SBATCH --job-name="3dLMEr"
#SBATCH --time=20:00:00
#SBATCH --mem=80GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --partition=medium
#SBATCH --chdir="/project/3022026.01/users/marjoh"
#SBATCH --output=iceberg/fc_seed_based/logs/job.3dLMEr.%A.out
#SBATCH --error=iceberg/fc_seed_based/logs/job.3dLMEr.%A.err

module unload afni; module load afni/2022
module unload R; module load R/4.1.0
module load R-packages/4.1.0
njobs = 32

roi=0
group_comparison=1
clinical_correlation=1

# Mask: whole or roi
if [[ $roi -eq 1 ]]; then
	mask=""
else
	mask=""
fi

# Group comparison
outputdir=""
cd ${outputdir}
dataTable=""
cp $mask $(pwd)/mask.nii.gz
cp dataTable $(pwd)

/opt/afni/2022/3dLMEr \
	-prefix ${outputdir}/group2_t3_reg2_div2 \
	-jobs $njobs \
	-resid ${outputdir}/group2_t3_reg2_div2_resid \
	-mask $mask \
	-model '1+Group*YearsToFollowUp*Region*Division+Age+Sex+(1+YearsToFollowUp|Subj)' \
	-qVars 'YearsToFollowUp,Age' \
	
	-gltCode Group_Reg_Div_Time 'Group : -1*Ctrl 1*Diag Region : -1*put 1*caud Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Ctrl_Reg_Div_Time 'Group : 1*Ctrl Region : -1*put 1*caud Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Diag_Reg_Div_Time 'Group : 1*Diag Region : -1*put 1*caud Division : -1*p 1*a YearsToFollowUp :' \
	
	-gltCode Group_Put_Div_Time 'Group : -1*Ctrl 1*Diag Region : 1*put Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Ctrl_Put_Div_Time 'Group : 1*Ctrl Region : 1*put Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Diag_Put_Div_Time 'Group : 1*Diag Region : 1*put Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Group_Put_P_Time 'Group : -1*Ctrl 1*Diag Region : 1*put Division : 1*p YearsToFollowUp :' \
	-gltCode Ctrl_Put_P_Time 'Group : 1*Ctrl Region : 1*put Division : 1*p YearsToFollowUp :' \
	-gltCode Diag_Put_P_Time 'Group : 1*Diag Region : 1*put Division : 1*p YearsToFollowUp :' \
	-gltCode Group_Put_A_Time 'Group : -1*Ctrl 1*Diag Region : 1*put Division : 1*a YearsToFollowUp :' \
	-gltCode Ctrl_Put_A_Time 'Group : 1*Ctrl Region : 1*put Division : 1*a YearsToFollowUp :' \
	-gltCode Diag_Put_A_Time 'Group : 1*Diag Region : 1*put Division : 1*a YearsToFollowUp :' \
	-gltCode Group_Put_Time 'Group : -1*Ctrl 1*Diag Region : 1*put YearsToFollowUp :' \
	-gltCode Ctrl_Put_Time 'Group : 1*Ctrl Region : 1*put YearsToFollowUp :' \
	-gltCode Diag_Put_Time 'Group : 1*Diag Region : 1*put YearsToFollowUp :' \
	-gltCode Group_Put_P 'Group : -1*Ctrl 1*Diag Region : 1*put Division : 1*p' \
	-gltCode Ctrl_Put_P 'Group : 1*Ctrl Region : 1*put Division : 1*p' \
	-gltCode Diag_Put_P 'Group : 1*Diag Region : 1*put Division : 1*p' \
	-gltCode Group_Put_A 'Group : -1*Ctrl 1*Diag Region : 1*put Division : 1*a' \
	-gltCode Ctrl_Put_A 'Group : 1*Ctrl Region : 1*put Division : 1*a' \
	-gltCode Diag_Put_A 'Group : 1*Diag Region : 1*put Division : 1*a' \
	-gltCode Group_Put 'Group : -1*Ctrl 1*Diag Region : 1*put' \
	-gltCode Ctrl_Put 'Group : 1*Ctrl Region : 1*put' \
	-gltCode Diag_Put 'Group : 1*Diag Region : 1*put' \
	
	-gltCode Group_Cau_Div_Time 'Group : -1*Ctrl 1*Diag Region : 1*caud Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Ctrl_Cau_Div_Time 'Group : 1*Ctrl Region : 1*caud Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Diag_Cau_Div_Time 'Group : 1*Diag Region : 1*caud Division : -1*p 1*a YearsToFollowUp :' \
	-gltCode Group_Cau_P_Time 'Group : -1*Ctrl 1*Diag Region : 1*caud Division : 1*p YearsToFollowUp :' \
	-gltCode Ctrl_Cau_P_Time 'Group : 1*Ctrl Region : 1*caud Division : 1*p YearsToFollowUp :' \
	-gltCode Diag_Cau_P_Time 'Group : 1*Diag Region : 1*caud Division : 1*p YearsToFollowUp :' \
	-gltCode Group_Cau_A_Time 'Group : -1*Ctrl 1*Diag Region : 1*caud Division : 1*a YearsToFollowUp :' \
	-gltCode Ctrl_Cau_A_Time 'Group : 1*Ctrl Region : 1*caud Division : 1*a YearsToFollowUp :' \
	-gltCode Diag_Cau_A_Time 'Group : 1*Diag Region : 1*caud Division : 1*a YearsToFollowUp :' \
	-gltCode Group_Cau_Time 'Group : -1*Ctrl 1*Diag Region : 1*caud YearsToFollowUp :' \
	-gltCode Ctrl_Cau_Time 'Group : 1*Ctrl Region : 1*caud YearsToFollowUp :' \
	-gltCode Diag_Cau_Time 'Group : 1*Diag Region : 1*caud YearsToFollowUp :' \
	-gltCode Group_Cau_P 'Group : -1*Ctrl 1*Diag Region : 1*caud Division : 1*p' \
	-gltCode Ctrl_Cau_P 'Group : 1*Ctrl Region : 1*caud Division : 1*p' \
	-gltCode Diag_Cau_P 'Group : 1*Diag Region : 1*caud Division : 1*p' \
	-gltCode Group_Cau_A 'Group : -1*Ctrl 1*Diag Region : 1*caud Division : 1*a' \
	-gltCode Ctrl_Cau_A 'Group : 1*Ctrl Region : 1*caud Division : 1*a' \
	-gltCode Diag_Cau_A 'Group : 1*Diag Region : 1*caud Division : 1*a' \
	-gltCode Group_Cau 'Group : -1*Ctrl 1*Diag Region : 1*caud' \
	-gltCode Ctrl_Cau 'Group : 1*Ctrl Region : 1*caud' \
	-gltCode Diag_Cau 'Group : 1*Diag Region : 1*caud' \

	-dataTable `cat $dataTable`

# Clinical correlation
#<in progress>





