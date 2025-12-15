#!/bin/bash

# /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/spect/spect_bids.sh

# Martin E. Johansson, 2025-11-18
# Organize SPECT data into bids-like directory structure.
# NOTE: Many subjects will have several runs of reconstructed SPECT data. However, we only want
# the reconstructed data that Alexis Baron and Martin Johansson prepared in 2025. After manually
# cleaning the multiple runs, I noticed that the most recent reconstruction appears to always
# be run-01. It would therefore be possible to simply leave the multiple runs and only take
# run-01 data for processing.

# Set up environment
#source /network/iss/home/martin.johansson/bidscoin/bin/activate
export FSLDIR=/network/iss/apps/software/scit/fsl/6.0.7.15
export PATH=$PATH:$FSLDIR/share/fsl/bin
export PATH=$PATH:$FSLDIR/bin
source $FSLDIR/etc/fslconf/fsl.sh
export IRMDIR=/network/iss/cenir/software/irm

# Directories
SRC="/network/iss/cenir/analyse/irm/studies/ICEBERG/Park_CPV/ICEBERG_Datscan/reco_240925"
INPUT_SUBS=( $(find ${SRC}/* -maxdepth 0 | xargs -n1 basename) )
BIDSDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat2"
mkdir -p ${BIDSDIR}

echo ">>> SRC: ${SRC}"
echo ">>> Target: ${BIDSDIR}"

# Convert DICOM-to-NIFTI
for (( i=0; i<${#INPUT_SUBS[@]}; i++ )); do

	echo ">>> ID in SRC: ${INPUT_SUBS[i]}"

	S=${INPUT_SUBS[i]}
	arrIN=(${S//_/ })
	SNAME="sub-${arrIN[7]}${arrIN[6]}"
	VNAME="ses-${arrIN[8]}"
	mkdir -p ${BIDSDIR}/${SNAME}/${VNAME}/tmp
	mkdir -p ${BIDSDIR}/${SNAME}/${VNAME}/ct
	mkdir -p ${BIDSDIR}/${SNAME}/${VNAME}/spect

	echo ">>> ID in target: ${SNAME}/${VNAME}"

	echo ">>> Creating symlinks to raw dicoms..."
	dicomdir=`ls -d ${SRC}/${S}/DICOM/*/*`
	cp -rs ${dicomdir}/. ${BIDSDIR}/${SNAME}/${VNAME}/tmp

	echo ">>> Fixing DICOM..."
	cd /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/dat
	matlab -batch "spect_fix_dicom('${BIDSDIR}/${SNAME}/${VNAME}/tmp')" -logfile ${BIDSDIR}/${SNAME}/${VNAME}/log_spect_fix_dicom.txt

	echo ">>> Running DCM2NIIX..."
	${FSLDIR}/bin/dcm2niix -o ${BIDSDIR}/${SNAME}/${VNAME}/tmp -z n -b y -ba y -f '%p_%t_%s_%c_%d' ${BIDSDIR}/${SNAME}/${VNAME}/tmp

	CORR_SPECT=( `find ${BIDSDIR}/${SNAME}/${VNAME}/tmp/*_corr` )
	for (( j=0; j<${#CORR_SPECT[@]}; j++ )); do
		${IRMDIR}/bin/c3d ${CORR_SPECT[j]} -o ${BIDSDIR}/${SNAME}/${VNAME}/tmp/${j}_corr_spect.nii
	done

	echo ">>> Copying output to target directories..."

	# CT scan with standard parameters
	CT_STD_NII=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/1.1_Cerveau*CTCerveauTOMO*.nii` )
	CT_STD_JSON=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/1.1_Cerveau*CTCerveauTOMO*.json` )
	for (( j=0; j<${#CT_STD_NII[@]}; j++ )); do
		if [[ -f ${CT_STD_NII[j]}  ]]; then
			cp ${CT_STD_NII[j]} ${BIDSDIR}/${SNAME}/${VNAME}/ct/${SNAME}_${VNAME}_rec-standard_run-0$((j + 1))_ct.nii
			cp ${CT_STD_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/ct/${SNAME}_${VNAME}_rec-standard_run-0$((j + 1))_ct.json
		fi
	done

	# CT scan with bone parameters
	CT_BONE_NII=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/1.1_Cerveau*CTBone_Recon*.nii` )
	CT_BONE_JSON=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/1.1_Cerveau*CTBone_Recon*.json` )
	for (( j=0; j<${#CT_BONE_NII[@]}; j++ )); do
		if [[ -f ${CT_BONE_NII[j]} ]]; then 
			cp ${CT_BONE_NII[j]} ${BIDSDIR}/${SNAME}/${VNAME}/ct/${SNAME}_${VNAME}_rec-bone_run-0$((j + 1))_ct.nii
			cp ${CT_BONE_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/ct/${SNAME}_${VNAME}_rec-bone_run-0$((j + 1))_ct.json
		fi
	done

	# Reconstructed and attenuation corrected SPECT
	SPECT_CHANG_NII=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/User*ReconCorr_Chang_AC_0.11_10.0_*.nii` )
	SPECT_CHANG_JSON=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/User*ReconCorr_Chang_AC_0.11_10.0_*.json` )
	SPECT_CHANG_NII_CORR=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/*_corr_spect.nii` )
	for (( j=0; j<${#SPECT_CHANG_NII[@]}; j++ )); do

		if [[ -f ${SPECT_CHANG_NII[j]} ]]; then
			cp ${SPECT_CHANG_NII[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-Chang_run-0$((j + 1))_spect.nii
			cp ${SPECT_CHANG_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-Chang_run-0$((j + 1))_spect.json

			# NOTE: SPECT is reconstructed with the reversed Superior-Inferior orientation. 
			# Fix 1: Conform dicom information to dictionary
			cp ${SPECT_CHANG_NII_CORR[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-ChangReo_run-0$((j + 1))_spect.nii
			cp ${SPECT_CHANG_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-ChangReo_run-0$((j + 1))_spect.json
			#REO="${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-ChangReoNEW_run-0$((j + 1))_spect.nii"
			#${FSLDIR}/bin/fslreorient2std ${REO} ${REO}.gz
			#gunzip -f ${REO}.gz

			# Fix 2: Rewrite transforms according to https://fsl.fmrib.ox.ac.uk/fsl/docs/other/orientation.html
			# (probably ruins overlap with CT, might be bad...)
			#ORIG="${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-Chang_run-0$((j + 1))_spect.nii"
			#REO="${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-ChangReo_run-0$((j + 1))_spect.nii"
			#cp $ORIG $REO
			#gzip ${REO}
			#REO=${REO}.gz
			#fslorient -deleteorient ${REO}
			#fslswapdim ${REO} x y -z ${REO}
			#fslorient -setqform 1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 ${REO}
			#fslorient -setqformcode 1 ${REO}
			#fslorient -getqform ${REO}
			#fslorient -copyqform2sform ${REO}
			#fslreorient2std ${REO} ${REO}
			#gunzip ${REO}
			#cp ${SPECT_CHANG_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-ChangReo_run-0$((j + 1))_spect.json
		fi

	done

	# Optional: non-corrected SPECT. Leaving orientation broken.
	SPECT_NC_NII=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/User*ReconCorr_NC*.nii` )
	SPECT_NC_JSON=( `ls ${BIDSDIR}/${SNAME}/${VNAME}/tmp/User*ReconCorr_NC*.json` )
	for (( j=0; j<${#SPECT_NC_NII[@]}; j++ )); do
		if [[ -f ${SPECT_NC_NII[j]} ]]; then 
			cp ${SPECT_NC_NII[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-NC_run-0$((j + 1))_spect.nii
			cp ${SPECT_NC_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-NC_run-0$((j + 1))_spect.json

			#ORIG="${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-NC_run-0$((j + 1))_spect.nii"
			#REO="${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-NCReo_run-0$((j + 1))_spect.nii"
			#cp $ORIG $REO
			#gzip ${REO}
			#REO=${REO}.gz
			#fslorient -deleteorient ${REO}
			#fslswapdim ${REO} x y -z ${REO}
			#fslorient -setqform 1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 ${REO}
			#fslorient -setqformcode 1 ${REO}
			#fslorient -getqform ${REO}
			#fslorient -copyqform2sform ${REO}
			#fslreorient2std ${REO} ${REO}
			#gunzip ${REO}
			#cp ${SPECT_CHANG_JSON[j]} ${BIDSDIR}/${SNAME}/${VNAME}/spect/${SNAME}_${VNAME}_trc-123IFPCIT_rec-NCReo_run-0$((j + 1))_spect.json

		fi
	done

	echo ">>> Removing intermediate output..."
	rm -r ${BIDSDIR}/${SNAME}/${VNAME}/tmp

	echo ">>> Done!"

done

