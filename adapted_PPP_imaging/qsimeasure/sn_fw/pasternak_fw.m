function [] = pasternak_fw()

% Coded by Ofer Pasternak: ofer@bwh.harvard.edu
% 20251112 - Edited for ICEBERG cohort by Martin E. Johansson: martin.johansson@donders.ru.nl

% Applies a free water correction on DWI data.
% The input file is assumed to be a nii.gz image, with .bval and .bvec
% files. Preferably accompanied by a binary mask image.

% Add free water toolbox
addpath('/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/free_water_imaging');
addpath('/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/free_water_imaging/FWFunctions');

% Define subjects
InputDir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsiprep_1.0.1'; 
cases=cellstr(spm_select('List',InputDir,'dir','sub.*'));

%%  SET THE BELOW PARAMETERS TO MATCH YOUR FILES
%   Set fname_in, fname_out, mask, bvak and bvec for each dataset. 
for i=1:numel(cases)

    sessions = cellstr(spm_select('List', fullfile(InputDir, cases{i}), 'dir', 'ses-*'));
    for s=1:numel(sessions)
        
        % Images
        mask = spm_select('FPList', fullfile(InputDir, cases{i}, sessions{s}, 'dwi'), '.*desc-brain_mask.nii.gz');  % If your data is not already masked, supply a mask here.
        fname_in = spm_select('FPList', fullfile(InputDir, cases{i}, sessions{s}, 'dwi'), '.*desc-preproc_dwi.nii.gz');
        bval = spm_select('FPList', fullfile(InputDir, cases{i}, sessions{s}, 'dwi'), '.*desc-preproc_dwi.bval');
        bvec = spm_select('FPList', fullfile(InputDir, cases{i}, sessions{s}, 'dwi'), '.*desc-preproc_dwi.bvec');
        
        % Do the images exist?
        imgs_exist = exist(mask,'file') && exist(fname_in,'file') && exist(bval,'file') && exist(bvec,'file');
        if ~imgs_exist
            fprintf('>>> Files missing: %s %s\n', cases{i}, sessions{s})
            continue
        end
        
        OutputDir = fullfile(InputDir, 'derivatives', 'pasternak_fw', cases{i}, sessions{s});
        previous_output = spm_select('FPList', OutputDir, '^sub.*FW.nii.gz');
        if exist(previous_output, 'file')
            fprintf('>>> Already processed: %s %s\n', cases{i}, sessions{s})
            continue
        else
            [~, ~, ~] = mkdir(OutputDir);
        end
        fname_out = fullfile(OutputDir, [cases{i}, '_', sessions{s}, '_pasternak']); % The prefix of files to be saved.
        Inputs = {fname_in;fname_out;mask;bval;bvec};
        
        %freeWaterNii(fname_in,fname_out,mask,bval,bvec);
        qsubfeval(@freeWaterNii, Inputs{:}, 'memreq',6*1024^3,'timreq',0.5*60*60, 'backend', 'slurm');
        
    end

end
%% EXPLANATION OF OUPUT

% In outDIR the following files will be saved:


% XXX_FW.nii.gz -                  A file with the free-water map

% XXX_FW_TensorFWCorrected.nii.gz - A file with the tensor map after
%                               correcting for free-water

% XXX_FW_TensorDTINoNeg.nii.gz       A file with a tensor map that is NOT
% corrected for free-water, but has the same negative eigenvalue
% correction that was used as pre-processing for the free-water.

% XXX_FW.mat  -                 The final output in Matlab format

% To create scalar maps from the tensor files, use:
% fslmaths XXX_TensorFWCorrected.nii.gz -tensor_decomp output_FWCorrected
% or
% fslmaths XXX_TensorDTINoNeg.nii.gz -tensor_decomp output_DTI


