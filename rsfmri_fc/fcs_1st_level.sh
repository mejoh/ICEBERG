#!/bin/bash

# sbatch /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fcs_1st_level.sh

# Estimate seed-based
# Resource management reference:
# ~2h, 5gb for 3 sessions

#SBATCH --job-name="seedFC"
#SBATCH --time=01:45:00
#SBATCH --mem=10GB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/stats/fc_seed_based/logs/job.1st.%A_%a.out
#SBATCH --error=iceberg/stats/fc_seed_based/logs/job.1st.%A_%a.err
#SBATCH --exclude=sphpc-cpu20
#SBATCH --array=0-286%40

# array vals: 0-286%25

sleep 10

export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh

IDX=${SLURM_ARRAY_TASK_ID}
#IDX=0

FMRIPREPDIR="$(pwd)/iceberg/data/bids4/derivatives/fmriprep_25.1.3"
XCPDDIR="$(pwd)/iceberg/data/bids4/derivatives/xcpd_0.11.1"
FCDIR="$(pwd)/iceberg/stats/fc_seed_based"
INPUT_SUBS=( $(find ${FCDIR}/sub-* -maxdepth 0 | xargs -n1 basename | cut -c 5-) )
SUB_ID=${INPUT_SUBS[${IDX}]}
SESSIONS=( `ls -d ${FCDIR}/sub-${SUB_ID}/ses-* | xargs -n1 basename` )

for (( i=0; i<${#SESSIONS[@]}; i++ )); do

	# Initialize output directory
	TSDIR="${FCDIR}/sub-${SUB_ID}/${SESSIONS[i]}/timeseries"
	ESTDIR="${FCDIR}/sub-${SUB_ID}/${SESSIONS[i]}/estimates"
	mkdir -p ${ESTDIR}/tmp

	# Check for pre-existinging output
	CHECKFILE=${ESTDIR}/fsl_cb_gs1.feat/stats/cope6.nii.gz
	if [[ -f ${CHECKFILE} ]]; then
		echo ">>> ${SUB_ID} already processed, exiting..."
		exit 1
	fi
	
	# Prepare data
	MASK=${FMRIPREPDIR}/sub-${SUB_ID}/${SESSIONS[i]}/func/sub-${SUB_ID}_${SESSIONS[i]}_task-rest_space-MNI152NLin6Asym_res-2_desc-brain_mask.nii.gz
	BOLDREF=${FMRIPREPDIR}/sub-${SUB_ID}/${SESSIONS[i]}/func/sub-${SUB_ID}_${SESSIONS[i]}_task-rest_space-MNI152NLin6Asym_res-2_boldref.nii.gz
	INPUT=${XCPDDIR}/sub-${SUB_ID}/${SESSIONS[i]}/func/sub-${SUB_ID}_${SESSIONS[i]}_task-rest_space-MNI152NLin6Asym_res-2_desc-denoised_bold.nii.gz
	if [[ ! -f "${ESTDIR}/func_data.nii.gz" ]]; then
		${FSLDIR}/bin/fslmaths ${MASK} ${ESTDIR}/tmp/mask
		${FSLDIR}/bin/fslmaths ${BOLDREF} ${ESTDIR}/tmp/boldref
		${FSLDIR}/bin/fslmaths ${INPUT} ${ESTDIR}/tmp/init_func
		${FSLDIR}/bin/fslmaths ${ESTDIR}/tmp/init_func -add ${ESTDIR}/tmp/boldref -mas ${ESTDIR}/tmp/mask ${ESTDIR}/tmp/func_data

		# In FEAT, steps are taken to make a mask and boldref for susan. These steps are not necessary
		# given that we have pre-masked data from fmriprep and xcp-d
		# SUSAN masking
		#robustint=`${FSLDIR}/bin/fslstats $OUTPUT -p 2 -p 98 | cut -d' ' -f2-`; echo ${robustint} 
		#intthr=`echo "${robustint}*0.1" | bc`; echo ${intthr}
		#${FSLDIR}/bin/fslmaths ${ESTDIR}/tmp/func_data -thr ${intthr} -Tmin -bin ${ESTDIR}/tmp/susan_mask -odt char
		#${FSLDIR}/bin/fslmaths ${ESTDIR}/tmp/susan_mask -dilF ${ESTDIR}/tmp/susan_mask
		#${FSLDIR}/bin/fslmaths ${ESTDIR}/tmp/func_data -mas ${ESTDIR}/tmp/susan_mask ${ESTDIR}/tmp/func_data_thr
		# Boldref
		#${FSLDIR}/bin/fslmaths ${ESTDIR}/tmp/func_data_thr -Tmean ${ESTDIR}/tmp/mean_func

		# Smoothing. FWHM = sigma*sqrt(8*ln(2)) = sigma*2.3548. FSL rounds to 3.355
		echo "FSL: susan smoothing"
		FWHM=8
		smoothing_extent_sigma=`echo $(echo ${FWHM} / 2.355 | bc -l)`; echo ${smoothing_extent_sigma}
		medianint=`${FSLDIR}/bin/fslstats ${ESTDIR}/tmp/func_data -k ${ESTDIR}/tmp/mask -p 50`; echo ${medianint}
		bt=`echo "${medianint}*0.75" | bc`; echo ${bt}
		${FSLDIR}/bin/susan \
			${ESTDIR}/tmp/func_data \
			${bt} ${smoothing_extent_sigma} \
			3 1 1 \
			${ESTDIR}/tmp/boldref \
			${bt} \
			${ESTDIR}/tmp/func_data_smooth
		${FSLDIR}/bin/fslmaths \
			${ESTDIR}/tmp/func_data_smooth \
			-mas ${ESTDIR}/tmp/mask \
			${ESTDIR}/tmp/func_data_smooth

		# Grand mean scaling
		echo "FSL: grand mean scaling"
		scaling_factor=`echo "10000 / ${medianint}" | bc -l`; echo ${scaling_factor}
		${FSLDIR}/bin/fslmaths ${ESTDIR}/tmp/func_data_smooth -mul ${scaling_factor} ${ESTDIR}/tmp/func_data_smooth_intnorm
		${FSLDIR}/bin/immv ${ESTDIR}/tmp/func_data_smooth_intnorm.nii.gz ${ESTDIR}/func_data.nii.gz
	else
		echo "Found previously generated func_data. Will use this one!"
	fi
	
	rm -r ${ESTDIR}/tmp

	# Copy 1st_level design template and change relevant settings
	# Granularity level 1: putamen and caudate (2 regions)
	# DES1="fsl_granularity1_gs1"
	# cp ${FCDIR}/designs/${DES1}.fsf ${ESTDIR}/${DES1}.fsf
	# sed -i "s#<OUTPUTDIR>#${ESTDIR}/${DES1}#g" ${ESTDIR}/${DES1}.fsf
	# sed -i "s#<N_VOLS>#`fslnvols ${ESTDIR}/func_data.nii.gz`#g" ${ESTDIR}/${DES1}.fsf
	# sed -i "s#<N_VOXELS>#`fslstats ${ESTDIR}/func_data.nii.gz -v | awk '{print $1}'`#g" ${ESTDIR}/${DES1}.fsf
	# sed -i "s#<FUNC_IMG>#${ESTDIR}/func_data.nii.gz#g" ${ESTDIR}/${DES1}.fsf
	# sed -i "s#<TS_PUT>#${TSDIR}/ts_PUT_bi.csv#g" ${ESTDIR}/${DES1}.fsf # Cope1
	# sed -i "s#<TS_CAU>#${TSDIR}/ts_CAU_bi.csv#g" ${ESTDIR}/${DES1}.fsf # Cope2
	# sed -i "s#<TS_GS>#${TSDIR}/ts_global_signal.csv#g" ${ESTDIR}/${DES1}.fsf
	# sed -i "s#set fmri(overwrite_yn) 0#set fmri(overwrite_yn) 1#g" ${ESTDIR}/${DES1}.fsf
	
	# ***Granularity level 2: putamen and caudate and nucleus accumbens (5 regions)
	 DES2="fsl_granularity2_gs1_v2"
	 cp ${FCDIR}/designs/${DES2}.fsf ${ESTDIR}/${DES2}.fsf
	 sed -i "s#<OUTPUTDIR>#${ESTDIR}/${DES2}#g" ${ESTDIR}/${DES2}.fsf
	 sed -i "s#<N_VOLS>#`fslnvols ${ESTDIR}/func_data.nii.gz`#g" ${ESTDIR}/${DES2}.fsf
	 sed -i "s#<N_VOXELS>#`fslstats ${ESTDIR}/func_data.nii.gz -v | awk '{print $1}'`#g" ${ESTDIR}/${DES2}.fsf
	 sed -i "s#<FUNC_IMG>#${ESTDIR}/func_data.nii.gz#g" ${ESTDIR}/${DES2}.fsf
	 sed -i "s#<TS_PUT_P>#${TSDIR}/ts_PUT_P_bi.csv#g" ${ESTDIR}/${DES2}.fsf   # EV1
	 sed -i "s#<TS_PUT_A>#${TSDIR}/ts_PUT_A_bi.csv#g" ${ESTDIR}/${DES2}.fsf   # EV2
	 sed -i "s#<TS_CAU_P>#${TSDIR}/ts_CAU_P_bi.csv#g" ${ESTDIR}/${DES2}.fsf   # EV3
	 sed -i "s#<TS_CAU_A>#${TSDIR}/ts_CAU_A_bi.csv#g" ${ESTDIR}/${DES2}.fsf   # EV4
	 sed -i "s#<TS_NAc>#${TSDIR}/ts_NAc_bi.csv#g" ${ESTDIR}/${DES2}.fsf       # EV5
	 sed -i "s#<TS_GS>#${TSDIR}/ts_global_signal.csv#g" ${ESTDIR}/${DES2}.fsf # EV6
	 sed -i "s#set fmri(overwrite_yn) 0#set fmri(overwrite_yn) 1#g" ${ESTDIR}/${DES2}.fsf
	
	# Granularity level 3: putamen and caudate (8 regions)
	# DES3="fsl_granularity3_putamen_gs1"
	# cp ${FCDIR}/designs/${DES3}.fsf ${ESTDIR}/${DES3}.fsf
	# sed -i "s#<OUTPUTDIR>#${ESTDIR}/${DES3}#g" ${ESTDIR}/${DES3}.fsf
	# sed -i "s#<N_VOLS>#`fslnvols ${ESTDIR}/func_data.nii.gz`#g" ${ESTDIR}/${DES3}.fsf
	# sed -i "s#<N_VOXELS>#`fslstats ${ESTDIR}/func_data.nii.gz -v | awk '{print $1}'`#g" ${ESTDIR}/${DES3}.fsf
	# sed -i "s#<FUNC_IMG>#${ESTDIR}/func_data.nii.gz#g" ${ESTDIR}/${DES3}.fsf
	# sed -i "s#<TS_PUT_DP>#${TSDIR}/ts_PUT_DP_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope1
	# sed -i "s#<TS_PUT_VP>#${TSDIR}/ts_PUT_VP_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope2
	# sed -i "s#<TS_PUT_DA>#${TSDIR}/ts_PUT_DA_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope3
	# sed -i "s#<TS_PUT_VA>#${TSDIR}/ts_PUT_VA_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope4
	# #sed -i "s#<TS_CAU_P>#${TSDIR}/ts_CAU_P_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope5
	# #sed -i "s#<TS_CAU_A>#${TSDIR}/ts_CAU_A_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope6
	# #sed -i "s#<TS_CAU_b>#${TSDIR}/ts_CAU_body_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope7
	# #sed -i "s#<TS_CAU_t>#${TSDIR}/ts_CAU_tail_bi.csv#g" ${ESTDIR}/${DES3}.fsf # Cope5 or Cope8
	# sed -i "s#<TS_GS>#${TSDIR}/ts_global_signal.csv#g" ${ESTDIR}/${DES3}.fsf
	# sed -i "s#set fmri(overwrite_yn) 0#set fmri(overwrite_yn) 1#g" ${ESTDIR}/${DES3}.fsf

	# ***Cerebellum
	#DES4="fsl_cb_gs1"
	#cp ${FCDIR}/designs/${DES4}.fsf ${ESTDIR}/${DES4}.fsf
	#sed -i "s#<OUTPUTDIR>#${ESTDIR}/${DES4}#g" ${ESTDIR}/${DES4}.fsf
	#sed -i "s#<N_VOLS>#`fslnvols ${ESTDIR}/func_data.nii.gz`#g" ${ESTDIR}/${DES4}.fsf
	#sed -i "s#<N_VOXELS>#`fslstats ${ESTDIR}/func_data.nii.gz -v | awk '{print $1}'`#g" ${ESTDIR}/${DES4}.fsf
	#sed -i "s#<FUNC_IMG>#${ESTDIR}/func_data.nii.gz#g" ${ESTDIR}/${DES4}.fsf
	#sed -i "s#<TS_CB12>#${TSDIR}/ts_Cerebellar_Region12_bi.csv#g" ${ESTDIR}/${DES4}.fsf   # EV1
	#sed -i "s#<TS_CB56>#${TSDIR}/ts_Cerebellar_Region56_bi.csv#g" ${ESTDIR}/${DES4}.fsf   # EV2
	#sed -i "s#<TS_GS>#${TSDIR}/ts_global_signal.csv#g" ${ESTDIR}/${DES4}.fsf # EV3
	#sed -i "s#set fmri(overwrite_yn) 0#set fmri(overwrite_yn) 1#g" ${ESTDIR}/${DES4}.fsf

	# Carry out first level analysis
	# ${FSLDIR}/bin/feat ${ESTDIR}/${DES1}.fsf
	# ${FSLDIR}/bin/feat ${ESTDIR}/${DES2}.fsf
	# ${FSLDIR}/bin/feat ${ESTDIR}/${DES3}.fsf
	${FSLDIR}/bin/feat ${ESTDIR}/${DES4}.fsf
	
	rm ${ESTDIR}/fsl*.feat/stats/res4d.nii.gz
	rm ${ESTDIR}/fsl*.feat/filtered_func_data.nii.gz
	
done


