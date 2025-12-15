#!/bin/bash

# Copy all T1s of a subjec to a single folder

bidsdir="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
outdir="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.0.0/inputs"
qcdir="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_8.0.0/qc/t1refs/"
cd $bidsdir 
#subs=`cat /project/3024006.02/templates/template_50HC50PD/list.txt`
subs=( `ls -d sub-*` )
visits=( "V0" "V2" "V4" )

for s in ${subs[@]}; do
	for v in ${visits[@]}; do

		echo "Processing ${s}, ses-${v}"

		T1w=${bidsdir}/${s}/ses-${v}/anat/${s}_ses-${v}_acq-UNIm_T1w.nii.gz
	
		# Copy T1w
		if [[ (-f $T1w && ! -f ${outdir}/${s}/${s}_${v}_T1w.nii.gz) ]]; then
		
			echo ">>> Copying T1w..."
			mkdir -p ${outdir}/${s}
			cp $T1w ${outdir}/${s}/${s}_${v}_T1w.nii.gz
			slices ${outdir}/${s}/${s}_${v}_T1w.nii.gz -o ${qcdir}/${s}_${v}_T1ref.gif
	
		# Report if T1w image is not available
		elif [[ (! -f $T1w) ]]; then
	
			echo ">>> Warning: T1w image not found, continuing..."
		
		fi
	
		echo "DONE"

	done
done

