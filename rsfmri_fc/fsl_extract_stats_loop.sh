#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fsl_extract_stats_loop.sh

randomise=1
striatum=1

if [[ ${randomise} -eq 1 ]]; then
	RANDDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/randomise"
	SES=("V0" "V2" "V4")
else
	RANDDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/swe"
	SES=("V0")
fi
if [[ ${striatum} -eq 1 ]]; then
	SEED=("PP" "PA" "PAsubPP")
else
	SEED=("CB12" "CB56" "CB56subCB12")
fi

LOGDIR="${RANDDIR}/logs"

for C in ${SEED[@]}; do
	for T in ${SES[@]}; do
		if [[ ${randomise} -eq 1 ]]; then
			SEEDDIR=${RANDDIR}/seed-${C}_ses-${T}
			GROUP_COMPARISONS=( `find ${SEEDDIR} -mindepth 1 -maxdepth 1 -type d -name g0* | xargs -n 1 basename` )
		else
			SEEDDIR=${RANDDIR}/seed-${C}
			GROUP_COMPARISONS=( `find ${SEEDDIR} -mindepth 1 -maxdepth 1 -type d -name g0* | xargs -n 1 basename` )
		fi
		for A in ${GROUP_COMPARISONS[@]}; do
			if [[ ${randomise} -eq 1 ]]; then
				DAT=${SEEDDIR}/imgs__${A}.nii.gz
				FN=${SEEDDIR}/imgs__${A}.txt
			else
				DAT=${SEEDDIR}/${A}/imgs.nii.gz
				FN=${SEEDDIR}/${A}/imgs.txt
			fi
			RESULTSDIR=${SEEDDIR}/${A}
			CORRP=( `ls ${RESULTSDIR}/*tfce_corrp_*stat*.nii.gz` )
			#TSTAT=( `ls ${RESULTSDIR}/*tfce_tstat*.nii.gz` )
			OUTDIR=${RESULTSDIR}/vals
			mkdir -p ${OUTDIR}
			for(( i=0; i<${#CORRP[@]}; i++ )); do
				STAT=`echo ${CORRP[i]} | sed 's/_corrp//g'`
				BN=`basename ${CORRP[i]}`
				BN=${BN%%.*}
				OBN=${OUTDIR}/${BN}_stats
				cmd="/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc/fsl_extract_stats.sh -d ${DAT} -n ${FN} -p ${CORRP[i]} -t ${STAT} -o ${OBN}"
				echo '#!/bin/bash' > ${OUTDIR}/script_${BN}.txt
				printf "\n${cmd}\n\n" >> ${OUTDIR}/script_${BN}.txt
				# # # qsub \
					# # # -o ${LOGDIR} \
					# # # -e ${LOGDIR} \
					# # # -N "stxtrct_${BN}" \
					# # # -l "nodes=1:ppn=1,walltime=00:10:00,mem=5gb" \
					# # # ${OUTDIR}/script_${BN}.txt
				sbatch \
					--output ${LOGDIR}/job.stxtrct_tt.%A_%a.out \
					--error ${LOGDIR}/job.stxtrct_tt.%A_%a.err \
					--job-name "stxtrct_${BN}_tt" \
					--nodes=1 --cpus-per-task 1 --ntasks-per-node=1 --mem=5G --time=00:10:00 \
					${OUTDIR}/script_${BN}.txt
			done 
		done
	done
done

