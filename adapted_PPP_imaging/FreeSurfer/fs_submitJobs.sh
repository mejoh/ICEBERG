#!/bin/bash
# /network/iss/cenir/analyse/irm/users/martin.johansson/code/ICEBERG/adapted_PPP_imaging/FreeSurfer/fs_submitJobs.sh

### Description: 
### Submit one job per subject. Edit the 
### fs_*_processSubject.sh scripts so that it 
### runs the FS longitudinal pipeline from start to finish.
### Note that subjects that already have output will not be processed by FS

# OPTS
cross=0
base=0
long=1
sclimbic=0

# Variables that are passed to jobs
#version=8.1.0
#fs_dir=/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/freesurfer_${version}

# Submit a job for each subject
if [ $cross -eq 1 ]; then

  # Estimated resources: ~4.5h per subject, 15gb
	# ??Note that some subjects can take much longer (+??h)

	#cd ${fs_dir}/inputs
	#subjects=( `ls -d *sub-*` )
	#subjects=("sub-016CB" "sub-090BG" "sub-156DC")
	#timepoints=( "V0" "V2" "V4" )
	
	#for s in ${subjects[@]}; do 
	#	for t in ${timepoints[@]}; do
	#		echo "Processing: ${s}, ${t}"
	#		sbatch \
	#		--job-name="FS8_cross_${s}_${t}" \
	#		--time=06:00:00 \
	#		--mem=18GB \
	#		--nodes=1 \
	#		--ntasks=1 \
	#		--cpus-per-task=2 \
	#		--partition=medium \
	#		--chdir="/network/iss/cenir/analyse/irm/users/martin.johansson" \
	#		--output=iceberg/data/bids4/derivatives/freesurfer_${version}/logs/job.fs_cross.%A_%a.out \
	#		--error=iceberg/data/bids4/derivatives/freesurfer_${version}/logs/job.fs_cross.%A_%a.err \
	#		--export=v=${version},fs_dir=${fs_dir},subject=${s},timepoint=${t} \
	#		code/iceberg/adapted_PPP_imaging/FreeSurfer/s1_fs_cross_processSubject.sh
	#	done
	#done
	
	sbatch \
		--array=0-286%50 \
		/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/FreeSurfer/s1_fs_cross_processSubject.sh
	
fi

if [ $base -eq 1 ]; then

  # Estimated resources: ~2.5h per subject, 12gb
	# Note that some subjects can take much longer (+?h)

	#cd ${fs_dir}/inputs
	#subjects=( `ls -d *sub-POMU*` )
	#subjects=("sub-016CB" "sub-090BG" "sub-156DC")
	
	#for s in ${subjects[@]}; do
	#		echo "Processing: ${s}"
	#		sbatch \
	#		--job-name="FS8_base_${s}_${t}" \
	#		--time=04:00:00 \
	#		--mem=14GB \
	#		--nodes=1 \
	#		--ntasks=1 \
	#		--cpus-per-task=2 \
	#		--partition=medium \
	#		--chdir="/network/iss/cenir/analyse/irm/users/martin.johansson" \
	#		--output=iceberg/data/bids4/derivatives/freesurfer_${version}/logs/job.fs_base.%A_%a.out \
	#		--error=iceberg/data/bids4/derivatives/freesurfer_${version}/logs/job.fs_base.%A_%a.err \
	#		--export=v=${version},fs_dir=${fs_dir},subject=${s} \
	#		code/iceberg/adapted_PPP_imaging/FreeSurfer/s2_fs_base_processSubject.sh
	#done
	
	sbatch \
		--array=0-286%50 \
		/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/FreeSurfer/s2_fs_base_processSubject.sh
	# 276,277,278,281,282,283,284
	# --array=0-286%40

fi

if [ $long -eq 1 ]; then

  # Estimated resources: ~1h per subject, 12gb

	#cd ${fs_dir}/inputs
	#subjects=( `ls -d *sub-*` )
	#subjects=("sub-016CB" "sub-090BG" "sub-156DC")
	#timepoints=( "V0" "V2" "V4" )
	
	#for s in ${subjects[@]}; do 
	#	for t in ${timepoints[@]}; do
	#		echo "Processing: ${s}, ${t}"
	#		sbatch \
	#		--job-name="FS8_long_${s}_${t}" \
	#		--time=02:00:00 \
	#		--mem=14GB \
	#		--nodes=1 \
	#		--ntasks=1 \
	#		--cpus-per-task=2 \
	#		--partition=medium \
	#		--chdir="/network/iss/cenir/analyse/irm/users/martin.johansson" \
	#		--output=iceberg/data/bids4/derivatives/freesurfer_${version}/logs/job.fs_long.%A_%a.out \
	#		--error=iceberg/data/bids4/derivatives/freesurfer_${version}/logs/job.fs_long.%A_%a.err \
	#		--export=v=${version},fs_dir=${fs_dir},subject=${s},timepoint=${t} \
	#		code/iceberg/adapted_PPP_imaging/FreeSurfer/s3_fs_long_processSubject.sh
	#	done
	#done
	
	sbatch \
		--array=0-286%50 \
		/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/FreeSurfer/s3_fs_long_processSubject.sh
		
	# Test: --array=21,30,82,102,186,221,275
	# Full: --array=0-286%40

fi

if [ $sclimbic -eq 1 ]; then
	sbatch \
		--array=0-286%20 \
		/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/adapted_PPP_imaging/FreeSurfer/s4_fs_sclimbic_processSubject.sh
fi

