#!/bin/bash

#SBATCH --job-name="bidsorg"
#SBATCH --time=00:15:00
#SBATCH --mem=1000MB
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --partition=medium
#SBATCH --chdir="/network/iss/cenir/analyse/irm/users/martin.johansson"
#SBATCH --output=iceberg/data/bids4/logs/job.bidsorg.%A_%a.out
#SBATCH --error=iceberg/data/bids4/logs/job.bidsorg.%A_%a.err
#SBATCH --array=0-286%40

# Fix manually:
# 020RJ: dwi, too many runs + reversed PE gradients on scans and fmap

module load ANTs/2.5.4
module load FSL/6.0.7.15

MPRAGEise=1
FLAIR_REORIENT=1

BIDSDIR="/network/iss/cenir/analyse/irm/studies/ICEBERG/CENIR/bids/src"
INPUT_SUBS=( $(find ${BIDSDIR}/sub-* -maxdepth 0 | xargs -n1 basename) )
TARGETDIR="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4"
mkdir -p ${TARGETDIR}

# Copy top directory files
cp ${BIDSDIR}/dataset_description.json ${TARGETDIR}
cp ${BIDSDIR}/participants.tsv ${TARGETDIR}

#for i in ${INPUT_SUBS[@]:9:5}; do
IDX=${SLURM_ARRAY_TASK_ID}
echo ">>> Task ID ${IDX}"
i=${INPUT_SUBS[$IDX]}
echo ">>> Processing subject ${i}"
    for v in "ses-V0" "ses-V2" "ses-V4"; do
    echo ">>> Session: ${v}"

        sub_id=`echo ${i} | grep -o -P '(?<=sub-).*'`
        ses_nr=`echo ${v} | grep -o -P '(?<=ses-V).*'`
        fmap_suffix=${sub_id}${ses_nr}
        COPYDIR=${BIDSDIR}/${i}/${v}
        NEWDIR=${TARGETDIR}/${i}/${v}
        if [ -d ${COPYDIR} ]; then
        echo ">>> Source directory ${COPYDIR} exists, proceeding..."

            # Copy anat
            ANATLIST=( "T1w" "inv-2_MP2RAGE" "FLAIR" )
            mkdir -p ${NEWDIR}/anat
            for anat in ${ANATLIST[@]}; do
                echo ">>> Modality: anat - ${anat}"
                IMGLIST=""
                IMGLIST=( $(find ${COPYDIR}/anat/sub-*${anat}* -maxdepth 0 | xargs -n1 basename) )
                if [ ${#IMGLIST[@]} -eq 0 ]; then
                    echo ">>> No images found, moving on..."
                    continue
                fi
                for k in ${IMGLIST[@]}; do
                    cp ${COPYDIR}/anat/${k} ${NEWDIR}/anat
                done

                # Check runs
                if [[ ${IMGLIST[-1]} == *"run"* ]]; then
                    resolve=1
                    check_runs=( $(find ${NEWDIR}/anat/*run*${anat}.nii -maxdepth 0 | xargs -n1 basename) )
                else 
                    resolve=0
                fi 
                # Resolve multiple runs by renaming the last run and removing the others
                if [ ${resolve} -gt 0 ]; then
                    echo ">>> Multiple runs found, resolving..."
                    last_run=${check_runs[-1]}
                    last_run=`echo ${last_run} | sed 's|.nii||g'`
                    newname=`echo ${last_run} | sed 's|_run-0[0-9]||g'`
                    mv ${NEWDIR}/anat/${last_run}.nii ${NEWDIR}/anat/${newname}.nii
                    mv ${NEWDIR}/anat/${last_run}.json ${NEWDIR}/anat/${newname}.json
                    rm ${NEWDIR}/anat/*run*${anat}*

                fi
                echo ">>> Done!"
            done

            # MPRAGEise the MP2RAGE UNI anatomical scan to enable further processing
            # https://github.com/UNFmontreal/unpitou-rage
            # https://github.com/srikash/MPRAGEise/blob/main/MPRAGEise.py
            if [[ ${MPRAGEise} -eq 1 ]] && [[ -f "${NEWDIR}/anat/${i}_${v}_acq-UNI_T1w.nii" ]] && [[ -f "${NEWDIR}/anat/${i}_${v}_inv-2_MP2RAGE.nii" ]]; then
                echo ">>> MPRAGEising MP2RAGE scans"
                # Source MP2RAGE scans will be stored in extra_data
                mkdir -p ${NEWDIR}/extra_data
                # Copy scans to extra_data
                cp ${NEWDIR}/anat/${i}_${v}_acq-UNI_T1w.nii ${NEWDIR}/extra_data/tmpUNI.nii
                cp ${NEWDIR}/anat/${i}_${v}_inv-2_MP2RAGE.nii ${NEWDIR}/extra_data/tmpINV2.nii
                # Step 1: Bias-correct the INV2 scan
                N4BiasFieldCorrection -d 3 -i ${NEWDIR}/extra_data/tmpINV2.nii -o ${NEWDIR}/extra_data/tmpINV2_N4.nii
                # Step 2: Calculate the min and max intensity, then take the difference between them
                min=`fslstats ${NEWDIR}/extra_data/tmpINV2_N4.nii -R | awk '{ print $1 }'`
                max=`fslstats ${NEWDIR}/extra_data/tmpINV2_N4.nii -R | awk '{ print $2 }'`
                diff=( $max - $min )
                # Step 3: Scale the INV2 to [0,1] range <(img - min) / (max - min)>
                fslmaths ${NEWDIR}/extra_data/tmpINV2_N4.nii -sub $min -div $diff ${NEWDIR}/extra_data/tmpINV2_N4_Scaled.nii.gz
                # Step 4: Multiply UNI and scaled INV2 to create an MPRAGEish image
                fslmaths ${NEWDIR}/extra_data/tmpUNI.nii ${NEWDIR}/extra_data/tmpUNI.nii.gz
                fslmaths ${NEWDIR}/extra_data/tmpUNI.nii.gz -mul ${NEWDIR}/extra_data/tmpINV2_N4_Scaled.nii.gz ${NEWDIR}/extra_data/tmpUNI_MPRAGEish.nii.gz
                # Move output into the anat folder and make a json sidecar
                mv ${NEWDIR}/extra_data/tmpUNI_MPRAGEish.nii.gz ${NEWDIR}/anat/${i}_${v}_acq-UNIm_T1w.nii.gz
                cp ${NEWDIR}/anat/${i}_${v}_acq-UNI_T1w.json ${NEWDIR}/anat/${i}_${v}_acq-UNIm_T1w.json
                # Move source MP2RAGE scans into extra_data
                mv ${NEWDIR}/anat/${i}_${v}_acq-UNI_T1w.nii ${NEWDIR}/extra_data/${i}_${v}_acq-UNI_T1w.nii
                mv ${NEWDIR}/anat/${i}_${v}_acq-UNI_T1w.json ${NEWDIR}/extra_data/${i}_${v}_acq-UNI_T1w.json
                mv ${NEWDIR}/anat/${i}_${v}_inv-2_MP2RAGE.nii ${NEWDIR}/extra_data/${i}_${v}_inv-2_MP2RAGE.nii
                mv ${NEWDIR}/anat/${i}_${v}_inv-2_MP2RAGE.json ${NEWDIR}/extra_data/${i}_${v}_inv-2_MP2RAGE.json
                # Remove intermediate output
                rm ${NEWDIR}/extra_data/tmp*
                echo ">>> Done!"
            fi
            
            # Reorient FLAIR
            if [[ ${FLAIR_REORIENT} -eq 1 ]] && [[ -f "${NEWDIR}/anat/${i}_${v}_FLAIR.nii" ]]; then
            	fslreorient2std ${NEWDIR}/anat/${i}_${v}_FLAIR.nii ${NEWDIR}/anat/${i}_${v}_FLAIR.nii
            fi

            # Copy fmap
            FMAPLIST=( "magnitude1" "magnitude2" "phasediff" )
            mkdir -p ${NEWDIR}/fmap
            for fmap in ${FMAPLIST[@]}; do
                echo ">>> Modality: fmap - ${fmap}"
                IMGLIST=""
                IMGLIST=( $(find ${COPYDIR}/fmap/sub-*${fmap}* -maxdepth 0 | xargs -n1 basename) )
                if [ ${#IMGLIST[@]} -eq 0 ]; then
                    echo ">>> No images found, moving on..."
                    continue
                fi
                for k in ${IMGLIST[@]}; do
                    cp ${COPYDIR}/fmap/${k} ${NEWDIR}/fmap
                done

                # Check runs
                if [[ ${IMGLIST[-1]} == *"run"* ]]; then
                    resolve=1
                    check_runs=( $(find ${NEWDIR}/fmap/*run*${fmap}.nii -maxdepth 0 | xargs -n1 basename) )
                else 
                    resolve=0
                fi 
                # Resolve multiple runs by renaming the last run and removing the others
                if [ ${resolve} -gt 0 ]; then
                    echo ">>> Multiple runs found, resolving..."
                    last_run=${check_runs[-1]}
                    last_run=`echo ${last_run} | sed 's|.nii||g'`
                    newname=`echo ${last_run} | sed 's|_run-0[0-9]||g'`
                    mv ${NEWDIR}/fmap/${last_run}.nii ${NEWDIR}/fmap/${newname}.nii
                    mv ${NEWDIR}/fmap/${last_run}.json ${NEWDIR}/fmap/${newname}.json
                    rm ${NEWDIR}/fmap/*run*${fmap}

                fi
                echo ">>> Done!"
            done

            # Add fieldmap-related info to .json files
                # Add information for phasediff
            echo ">>> Adding fieldmap-related info to fmap files!"
            E1=`cat ${NEWDIR}/fmap/${i}_${v}_magnitude1.json | jq '.EchoTime'`
            E2=`cat ${NEWDIR}/fmap/${i}_${v}_magnitude2.json | jq '.EchoTime'`
            cat ${NEWDIR}/fmap/${i}_${v}_phasediff.json | jq '. += {"EchoTime1" : "ECHOTIME1"}'| jq '. += {"EchoTime2" : "ECHOTIME2"}' | jq '. += {"IntendedFor" : "FUNC_RUN01"}' | jq '. += {"B0FieldIdentifier" : "phasediff_fmap0"}' > ${NEWDIR}/fmap/${i}_${v}_phasediff_new.json
            sed -i "s|ECHOTIME1|${E1}|g" "${NEWDIR}/fmap/${i}_${v}_phasediff_new.json"
            sed -i "s|ECHOTIME2|${E2}|g" "${NEWDIR}/fmap/${i}_${v}_phasediff_new.json"
            sed -i "s|fmap0|fmap${fmap_suffix}|g" "${NEWDIR}/fmap/${i}_${v}_phasediff_new.json"
            sed -i "s|FUNC_RUN01|${NEWDIR}/func/${i}_${v}_task-rest_bold.nii.gz|g" "${NEWDIR}/fmap/${i}_${v}_phasediff_new.json"
            mv ${NEWDIR}/fmap/${i}_${v}_phasediff_new.json ${NEWDIR}/fmap/${i}_${v}_phasediff.json
            echo ">>> Done!"

            # Copy dwi
            DWILIST=( "dir-AP" )
            mkdir -p ${NEWDIR}/dwi
            for dwi in ${DWILIST[@]}; do
                echo ">>> Modality: dwi - ${dwi}"
                IMGLIST=""
                IMGLIST=( $(find ${COPYDIR}/dwi/sub-*${dwi}* -maxdepth 0 | xargs -n1 basename) )
                if [ ${#IMGLIST[@]} -eq 0 ]; then
                    echo ">>> No images found, moving on..."
                    continue
                fi
                for k in ${IMGLIST[@]}; do
                    cp ${COPYDIR}/dwi/${k} ${NEWDIR}/dwi
                done

                # Check runs
                if [[ ${IMGLIST[-1]} == *"run-06"* ]]; then
                    resolve=1
                    check_runs=( $(find ${NEWDIR}/dwi/*${dwi}*run*.nii -maxdepth 0 | xargs -n1 basename) )
                else 
                    resolve=0
                fi 
                # Resolve multiple runs by renaming the last 3 runs and removing the others
                if [ ${resolve} -gt 0 ]; then
                    echo ">>> Multiple runs found, resolving..."
                    last_run=${check_runs[-1]}
                    last_run=`echo ${last_run} | sed 's|.nii||g'`
                    last_run_nr=`echo ${last_run} | grep -o -P '(?<=_run-0).*(?=_dwi)'`
                    viable_run_nrs=( $(($last_run_nr - 2)) $(($last_run_nr - 1)) $(($last_run_nr)) )
                    final_run_nrs=( 1 2 3 )
                    for (( vrn=1; vrn<4; vrn++ )); do
                        newname=`echo ${last_run} | sed "s|_run-0${viable_run_nrs[vrn]}|_run-0${final_run_nrs[vrn]}|g"`
                        mv ${NEWDIR}/dwi/${last_run}.nii ${NEWDIR}/dwi/${newname}.nii
                        mv ${NEWDIR}/dwi/${last_run}.json ${NEWDIR}/dwi/${newname}.json
                        mv ${NEWDIR}/dwi/${last_run}.bval ${NEWDIR}/dwi/${newname}.bval
                        mv ${NEWDIR}/dwi/${last_run}.bvec ${NEWDIR}/dwi/${newname}.bvec
                    done

                    rm ${NEWDIR}/dwi/*${dwi}*run-0[4-9]*

                fi
                echo ">>> Done!"
            done

            DWILIST=( "dir-PA" )
            mkdir -p ${NEWDIR}/dwi
            for dwi in ${DWILIST[@]}; do
                echo ">>> Modality: fmap for dwi - ${dwi}"
                IMGLIST=""
                IMGLIST=( $(find ${COPYDIR}/dwi/sub-*${dwi}* -maxdepth 0 | xargs -n1 basename) )
                if [ ${#IMGLIST[@]} -eq 0 ]; then
                    echo ">>> No images found, moving on..."
                    continue
                fi
                for k in ${IMGLIST[@]}; do
                    cp ${COPYDIR}/dwi/${k} ${NEWDIR}/dwi
                done

                # Check runs
                if [[ ${IMGLIST[-1]} == *"run"* ]]; then
                    resolve=1                    
                    check_runs=( $(find ${NEWDIR}/dwi/*${dwi}*run*.nii -maxdepth 0 | xargs -n1 basename) )
                else                     
                    resolve=0
                fi 
                # Resolve multiple runs by renaming the last run and removing the others
                if [ ${resolve} -gt 0 ]; then
                    echo ">>> Multiple runs found, resolving..."
                    last_run=${check_runs[-1]}
                    last_run=`echo ${last_run} | sed 's|.nii||g'`
                    newname=`echo ${last_run} | sed 's|_run-0[0-9]||g'`
                    mv ${NEWDIR}/dwi/${last_run}.nii ${NEWDIR}/dwi/${newname}.nii
                    mv ${NEWDIR}/dwi/${last_run}.json ${NEWDIR}/dwi/${newname}.json
                    mv ${NEWDIR}/dwi/${last_run}.bval ${NEWDIR}/dwi/${newname}.bval
                    mv ${NEWDIR}/dwi/${last_run}.bvec ${NEWDIR}/dwi/${newname}.bvec
                    rm ${NEWDIR}/dwi/*${dwi}*run*

                fi
                echo ">>> Moving dwi fmaps to correct directory and adding information to .json files"
                # Move dwi fmap to correct folder
                mv ${NEWDIR}/dwi/${i}_${v}_${dwi}_dwi.nii ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi.nii
                mv ${NEWDIR}/dwi/${i}_${v}_${dwi}_dwi.json ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi.json
                mv ${NEWDIR}/dwi/${i}_${v}_${dwi}_dwi.bval ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi.bval
                mv ${NEWDIR}/dwi/${i}_${v}_${dwi}_dwi.bvec ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi.bvec
                # Add fieldmap-related info to .json files
                    # Add IntendedFor and B0FieldID info to fieldmap
                cat ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi.json  | jq '. += {"IntendedFor" : [ "DWI_RUN01","DWI_RUN02","DWI_RUN03" ]}' | jq '. += {"B0FieldIdentifier" : "pepolar_fmap0"}' > ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi_new.json
                for r in 1 2 3; do
                    sed -i "s|DWI_RUN0${r}|${NEWDIR}/dwi/${i}_${v}_dir-AP_run-0${r}_dwi.nii.gz|g" "${NEWDIR}/fmap/${i}_${v}_${dwi}_epi_new.json"
                done
                sed -i "s|fmap0|fmap${fmap_suffix}|g" "${NEWDIR}/fmap/${i}_${v}_${dwi}_epi_new.json"
                mv ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi_new.json ${NEWDIR}/fmap/${i}_${v}_${dwi}_epi.json
                    # Add B0FieldSource to dwi
                for r in 1 2 3; do
                    cat ${NEWDIR}/dwi/${i}_${v}_dir-AP_run-0${r}_dwi.json | jq '. += {"B0FieldSource" : "FIELDSOURCE"}' > ${NEWDIR}/dwi/${i}_${v}_dir-AP_run-0${r}_dwi_new.json
                    sed -i "s|FIELDSOURCE|pepolar_fmap${fmap_suffix}|g" "${NEWDIR}/dwi/${i}_${v}_dir-AP_run-0${r}_dwi_new.json"
                    mv ${NEWDIR}/dwi/${i}_${v}_dir-AP_run-0${r}_dwi_new.json ${NEWDIR}/dwi/${i}_${v}_dir-AP_run-0${r}_dwi.json
                done
            echo ">>> Done!"
            done

            # Copy func
            FUNCLIST=( "bold" )
            mkdir -p ${NEWDIR}/func
            for func in ${FUNCLIST[@]}; do
                echo ">>> Modality: func - ${funcs}"
                IMGLIST=""
                IMGLIST=( $(find ${COPYDIR}/func/sub-*${func}* -maxdepth 0 | xargs -n1 basename) )
                if [ ${#IMGLIST[@]} -eq 0 ]; then
                    echo ">>> No images found, moving on..."
                    continue
                fi
                for k in ${IMGLIST[@]}; do
                    cp ${COPYDIR}/func/${k} ${NEWDIR}/func
                done
                # Check runs
                if [[ ${IMGLIST[-1]} == *"run"* ]]; then
                    resolve=1
                    check_runs=( $(find ${NEWDIR}/func/*run*${func}.nii -maxdepth 0 | xargs -n1 basename) )
                else 
                    resolve=0
                fi 
                # Resolve multiple runs by renaming the last run and removing the others
                if [ ${resolve} -gt 0 ]; then
                    last_run=${check_runs[-1]}
                    last_run=`echo ${last_run} | sed 's|.nii||g'`
                    newname=`echo ${last_run} | sed 's|_run-0[0-9]||g'`
                    mv ${NEWDIR}/func/${last_run}.nii ${NEWDIR}/func/${newname}.nii
                    mv ${NEWDIR}/func/${last_run}.json ${NEWDIR}/func/${newname}.json
                    rm ${NEWDIR}/func/*run*${func}*

                fi
            echo ">>> Done!"
            done
            # Add B0FieldSource to func
            echo ">>> Adding fmap-related info to .json files of func"
            cat ${NEWDIR}/func/${i}_${v}_task-rest_bold.json | jq '. += {"B0FieldSource" : "FIELDSOURCE"}' > ${NEWDIR}/func/${i}_${v}_task-rest_bold_new.json
            sed -i "s|FIELDSOURCE|phasediff_fmap${fmap_suffix}|g" "${NEWDIR}/func/${i}_${v}_task-rest_bold_new.json"
            mv ${NEWDIR}/func/${i}_${v}_task-rest_bold_new.json ${NEWDIR}/func/${i}_${v}_task-rest_bold.json
            echo ">>> Done!"
        fi

    done

    # Compress niftis
    echo ">>> Compressing .NII files"
    IMGLIST=( `ls ${TARGETDIR}/${i}/*/*/sub-*.nii` )
    for t in ${IMGLIST[@]}; do
        gzip ${t}
    done
    echo ">>> Done!"

#done
