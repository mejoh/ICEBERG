#!/bin/bash

usage (){

	cat <<USAGE
	
	Usage: 
	
	`basename $0` -d -o
	
	Description: 

	Extract summary statistics from surface-based DTI images. Requires
	that subject have already been normalized and FreeSurfer output has
	been generated (i.e., output from mri_segstats per subject and 
	session).

	Compulsory arguments: 
	
	-d: Qsiprep derivatives directory
	
	-o: Output directory
	
	-m: Metric (pyAFQ-md)
	
	-s: Space in which the stats are extracted (T1w or norm)
	
	Example 1: /network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/qsimeasure/extract_surface_DTI.sh -d /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsirecon_1.1.1/derivatives/qsirecon-PYAFQ -o /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsirecon_1.1.1/derivatives/qsirecon-PYAFQ -m pyAFQ-md -s T1w

USAGE

	exit 1

}

# Provide help
[ "$1" == "" ] && usage >&2
[ "$1" == "-h" ] && usage >&2
[ "$1" == "--help" ] && usage >&2

# Get command-line options
while getopts ":d:o:m:s:" OPT; do

	case "${OPT}" in 
		d)
			echo ">>> -d ${OPTARG}"
			optD=${OPTARG}
		;;
		o)
			echo ">>> -o ${OPTARG}"
			optO=${OPTARG}
		;;
		m)
			echo ">>> -m ${OPTARG}"
			optM=${OPTARG}
		;;
		s)
			echo ">>> -s ${OPTARG}"
			optS=${OPTARG}
		;;
		\?)
			echo ">>> Error: Invalid option -${OPTARG}."
			usage >&2
		;;
		:)
			echo ">>>> Error: Option -${OPTARG} requires an argument."
			usage >&2
		;;
	esac

done

INDIR=${optD}
cd ${INDIR}
SUBJECTS=( `find ${INDIR}/sub-* -maxdepth 0 -type d | sed 's#.*/##'` )
OUTDIR=${optO}
MEASURESDIR=${OUTDIR}/derivatives && mkdir -p ${MEASURESDIR}
METRIC=${optM}
SPACE=${optS}

echo 'SubjID,Timepoint,L_bankssts_dti,L_caudalanteriorcingulate_dti,L_caudalmiddlefrontal_dti,L_cuneus_dti,L_entorhinal_dti,L_fusiform_dti,L_inferiorparietal_dti,L_inferiortemporal_dti,L_isthmuscingulate_dti,L_lateraloccipital_dti,L_lateralorbitofrontal_dti,L_lingual_dti,L_medialorbitofrontal_dti,L_middletemporal_dti,L_parahippocampal_dti,L_paracentral_dti,L_parsopercularis_dti,L_parsorbitalis_dti,L_parstriangularis_dti,L_pericalcarine_dti,L_postcentral_dti,L_posteriorcingulate_dti,L_precentral_dti,L_precuneus_dti,L_rostralanteriorcingulate_dti,L_rostralmiddlefrontal_dti,L_superiorfrontal_dti,L_superiorparietal_dti,L_superiortemporal_dti,L_supramarginal_dti,L_frontalpole_dti,L_temporalpole_dti,L_transversetemporal_dti,L_insula_dti,R_bankssts_dti,R_caudalanteriorcingulate_dti,R_caudalmiddlefrontal_dti,R_cuneus_dti,R_entorhinal_dti,R_fusiform_dti,R_inferiorparietal_dti,R_inferiortemporal_dti,R_isthmuscingulate_dti,R_lateraloccipital_dti,R_lateralorbitofrontal_dti,R_lingual_dti,R_medialorbitofrontal_dti,R_middletemporal_dti,R_parahippocampal_dti,R_paracentral_dti,R_parsopercularis_dti,R_parsorbitalis_dti,R_parstriangularis_dti,R_pericalcarine_dti,R_postcentral_dti,R_posteriorcingulate_dti,R_precentral_dti,R_precuneus_dti,R_rostralanteriorcingulate_dti,R_rostralmiddlefrontal_dti,R_superiorfrontal_dti,R_superiorparietal_dti,R_superiortemporal_dti,R_supramarginal_dti,R_frontalpole_dti,R_temporalpole_dti,R_transversetemporal_dti,R_insula_dti,VertexArea_mm2' > ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
echo 'SubjID,Timepoint,L_bankssts_dti,L_caudalanteriorcingulate_dti,L_caudalmiddlefrontal_dti,L_cuneus_dti,L_entorhinal_dti,L_fusiform_dti,L_inferiorparietal_dti,L_inferiortemporal_dti,L_isthmuscingulate_dti,L_lateraloccipital_dti,L_lateralorbitofrontal_dti,L_lingual_dti,L_medialorbitofrontal_dti,L_middletemporal_dti,L_parahippocampal_dti,L_paracentral_dti,L_parsopercularis_dti,L_parsorbitalis_dti,L_parstriangularis_dti,L_pericalcarine_dti,L_postcentral_dti,L_posteriorcingulate_dti,L_precentral_dti,L_precuneus_dti,L_rostralanteriorcingulate_dti,L_rostralmiddlefrontal_dti,L_superiorfrontal_dti,L_superiorparietal_dti,L_superiortemporal_dti,L_supramarginal_dti,L_frontalpole_dti,L_temporalpole_dti,L_transversetemporal_dti,L_insula_dti,R_bankssts_dti,R_caudalanteriorcingulate_dti,R_caudalmiddlefrontal_dti,R_cuneus_dti,R_entorhinal_dti,R_fusiform_dti,R_inferiorparietal_dti,R_inferiortemporal_dti,R_isthmuscingulate_dti,R_lateraloccipital_dti,R_lateralorbitofrontal_dti,R_lingual_dti,R_medialorbitofrontal_dti,R_middletemporal_dti,R_parahippocampal_dti,R_paracentral_dti,R_parsopercularis_dti,R_parsorbitalis_dti,R_parstriangularis_dti,R_pericalcarine_dti,R_postcentral_dti,R_posteriorcingulate_dti,R_precentral_dti,R_precuneus_dti,R_rostralanteriorcingulate_dti,R_rostralmiddlefrontal_dti,R_superiorfrontal_dti,R_superiorparietal_dti,R_superiortemporal_dti,R_supramarginal_dti,R_frontalpole_dti,R_temporalpole_dti,R_transversetemporal_dti,R_insula_dti,VertexArea_mm2' > ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SD.csv
echo 'SubjID,Timepoint,L_bankssts_dti,L_caudalanteriorcingulate_dti,L_caudalmiddlefrontal_dti,L_cuneus_dti,L_entorhinal_dti,L_fusiform_dti,L_inferiorparietal_dti,L_inferiortemporal_dti,L_isthmuscingulate_dti,L_lateraloccipital_dti,L_lateralorbitofrontal_dti,L_lingual_dti,L_medialorbitofrontal_dti,L_middletemporal_dti,L_parahippocampal_dti,L_paracentral_dti,L_parsopercularis_dti,L_parsorbitalis_dti,L_parstriangularis_dti,L_pericalcarine_dti,L_postcentral_dti,L_posteriorcingulate_dti,L_precentral_dti,L_precuneus_dti,L_rostralanteriorcingulate_dti,L_rostralmiddlefrontal_dti,L_superiorfrontal_dti,L_superiorparietal_dti,L_superiortemporal_dti,L_supramarginal_dti,L_frontalpole_dti,L_temporalpole_dti,L_transversetemporal_dti,L_insula_dti,R_bankssts_dti,R_caudalanteriorcingulate_dti,R_caudalmiddlefrontal_dti,R_cuneus_dti,R_entorhinal_dti,R_fusiform_dti,R_inferiorparietal_dti,R_inferiortemporal_dti,R_isthmuscingulate_dti,R_lateraloccipital_dti,R_lateralorbitofrontal_dti,R_lingual_dti,R_medialorbitofrontal_dti,R_middletemporal_dti,R_parahippocampal_dti,R_paracentral_dti,R_parsopercularis_dti,R_parsorbitalis_dti,R_parstriangularis_dti,R_pericalcarine_dti,R_postcentral_dti,R_posteriorcingulate_dti,R_precentral_dti,R_precuneus_dti,R_rostralanteriorcingulate_dti,R_rostralmiddlefrontal_dti,R_superiorfrontal_dti,R_superiorparietal_dti,R_superiortemporal_dti,R_supramarginal_dti,R_frontalpole_dti,R_temporalpole_dti,R_transversetemporal_dti,R_insula_dti,VertexArea_mm2' > ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SNR.csv

for SUB in ${SUBJECTS[@]}; do

	SESSIONS=( `find ${INDIR}/${SUB}/ses-* -maxdepth 0 -type d | sed 's#.*/##'` )
	
	for SES in ${SESSIONS[@]}; do
	
		printf "%s,"  "${SUB}" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
		printf "%s,"  "${SUB}" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SD.csv
		printf "%s,"  "${SUB}" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SNR.csv
	
		printf "%s,"  "${SES}" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
		printf "%s,"  "${SES}" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SD.csv
		printf "%s,"  "${SES}" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SNR.csv
		
		for SIDE in lh rh; do
		
		if [[ ${METRIC} -eq "pyAFQ" ]];then
			STATS=${INDIR}/${SUB}/${SES}/surfproj/${SIDE}.${METRIC}.aparc.${SPACE}.stats
		elif [[ ${METRIC} -eq "fsl-MD" ]]; then 
			STATS=${INDIR}/${SUB}/${SES}/metrics/freesurfer/${SIDE}.*_${METRIC}.${SPACE}.stats
		fi

		for x in bankssts caudalanteriorcingulate caudalmiddlefrontal cuneus entorhinal fusiform inferiorparietal inferiortemporal isthmuscingulate lateraloccipital lateralorbitofrontal lingual medialorbitofrontal middletemporal parahippocampal paracentral parsopercularis parsorbitalis parstriangularis pericalcarine postcentral posteriorcingulate precentral precuneus rostralanteriorcingulate rostralmiddlefrontal superiorfrontal superiorparietal superiortemporal supramarginal frontalpole temporalpole transversetemporal insula; do
		
			if [ -f ${STATS} ]; then

				printf "%g," `grep -w ${x} ${STATS} | awk '{print $6}'` >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
				printf "%g," `grep -w ${x} ${STATS} | awk '{print $7}'` >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SD.csv
				printf "%g," `grep -w ${x} ${STATS} | awk '{print $11}'` >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SNR.csv
			
			else
			
				printf "%s," "NA" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
				printf "%s," "NA" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SD.csv
				printf "%s," "NA" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SNR.csv
			
			fi

		done
		
		if [ -f ${STATS} ]; then
			printf "%g" `cat ${STATS} | grep VertexArea_mm2 | awk -F ' ' '{print $3}'` >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
		else
			printf "%s" "NA" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
		fi
	
	done
	
	echo "" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_Mean.csv
	echo "" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SD.csv
	echo "" >> ${MEASURESDIR}/SurfaceMeasures_${METRIC}_${SPACE}_SNR.csv
	
	done
	
done




