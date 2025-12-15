#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/project_to_surface_sub.sh

# Submits one projection-script per subject

BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
QSIPREPDIR="${BIDSDIR}/derivatives/qsirecon_1.1.1/derivatives/qsirecon-PYAFQ"
WDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/wd/tmp"
SCRIPT="/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/project_to_surface.sh"
SCRIPTPREPEND=""
LIST_SUBJECTS=( `find ${QSIPREPDIR}/sub-* -maxdepth 0 -type d -printf "%f\n"` )
LEN=${#LIST_SUBJECTS[@]}
for (( i=0; i<${LEN}; i++ )); do 

	# Check for pre-existinging output
	#CHECKFILE=${QSIPREPDIR}/${LIST_SUBJECTS[i]}/ses-V0/surfproj/lh.pyAFQ-md.aparc.a2009s.T1w.stats
	#if [[ -f ${CHECKFILE} ]]; then
	#	echo ">>> ${LIST_SUBJECTS[i]} already processed, exiting..."
	#	exit 1
	#fi

	echo "Processing ${LIST_SUBJECTS[i]} $((${i}+1))/${LEN}"
	qscript="${WDIR}/job_${i}_qsub.sh"
	rm -f $qscript
	exe="${SCRIPT} -d ${BIDSDIR} -p ${LIST_SUBJECTS[i]}"
	echo '#!/bin/sh' > $qscript
	echo -e "$SCRIPTPREPEND" >> $qscript
	echo -e "$exe" >> $qscript
	echo -e "$SCRIPTPREPEND" >> $qscript
	#id=`qsub -o ${QSIPREPDIR}/logs -e ${QSIPREPDIR}/logs -N qproj-${TEMPLATE}_${LIST_SUBJECTS[i]} -l 'nodes=1:ppn=1,walltime=03:00:00,mem=4gb' $qscript | awk '{print $1}'`
	id=`sbatch --job-name proj2surf_${LIST_SUBJECTS[i]} --time=03:00:00 --mem=4gb --nodes=1 --ntasks-per-node=1 --cpus-per-task=1 --output=${QSIPREPDIR}/logs/o_proj2surf_${LIST_SUBJECTS[i]}.txt --error=${QSIPREPDIR}/logs/e_proj2surf_${LIST_SUBJECTS[i]}.txt $qscript | rev | cut -f1 -d\ | rev`
	sleep 0.5
	rm $qscript
done
