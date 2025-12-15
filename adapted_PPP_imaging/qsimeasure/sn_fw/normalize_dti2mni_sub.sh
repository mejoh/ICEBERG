#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/normalize_dti2mni_sub.sh

# Submits one normalization-script per subject

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
QSIPREPDIR="${BIDSDIR}/derivatives/qsiprep_1.0.1"
WDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/wd/qsiprep_tmp"
NORM="/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/sn_fw/normalize_dti2mni.sh"
TEMPLATE="HCP1065_FA" #HCP1065_FA or HCP1065_MD or FMRIB58
SCRIPTPREPEND=""
LIST_SUBJECTS=( `find ${QSIPREPDIR}/sub-* -maxdepth 0 -type d -printf "%f\n"` )
LEN=${#LIST_SUBJECTS[@]}
for (( i=0; i<${LEN}; i++ )); do 
	echo "Processing ${LIST_SUBJECTS[i]} $((${i}+1))/${LEN}"
	qscript="${WDIR}/job_${i}_sbatch.sh"
	rm -f $qscript
	exe="${NORM} -d ${BIDSDIR} -p ${LIST_SUBJECTS[i]} -t ${TEMPLATE}"
	echo '#!/bin/sh' > $qscript
	echo -e "$SCRIPTPREPEND" >> $qscript
	echo -e "$exe" >> $qscript
	echo -e "$SCRIPTPREPEND" >> $qscript
	#id=`qsub -o ${QSIPREPDIR}/logs -e ${QSIPREPDIR}/logs -N qnorm-${TEMPLATE}_${LIST_SUBJECTS[i]} -l 'nodes=1:ppn=1,walltime=03:00:00,mem=4gb' $qscript | awk '{print $1}'`
	id=`sbatch --job-name norm-dti2mni_${LIST_SUBJECTS[i]} --time=01:30:00 --mem=4gb --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --output=${QSIPREPDIR}/logs/job.norm-dti2mni.%A_%a.out --error=${QSIPREPDIR}/logs/job.norm-dti2mni.%A_%a.err $qscript | rev | cut -f1 -d\ | rev`
	sleep 0.5
	rm $qscript
done
