% @DESCRIPTION: Correction of SPECT images using the iterative Yang method.
% @AUTHOR: Emma Biondetti. Edited by Martin Johansson.
% @DATE: 21/11/2025

function [] = iterative_yang_func(indir, subject, session, iter)

defaults = spm_get_defaults;
spm_jobman('initcfg');

%% Input data
%indir="/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat2/derivatives/dat_extraction";
%subs = cellstr(spm_select('List', indir, 'dir', 'sub-.*'));
subs = cellstr(subject);
for i = 1:numel(subs)
    %ses = cellstr(spm_select('List', fullfile(indir, subs{i}), 'dir', 'ses-.*'));
    ses = cellstr(session);
    for j = 1:numel(ses)
        
        fprintf('>>> Processing %s %s\n', subs{i}, ses{j})
        
        img_spect = spm_select('FPList', fullfile(indir, subs{i}, ses{j}, 'wd'), 'spect_to_t1w.nii');
        c0_csf = spm_select('FPList', fullfile(indir, subs{i}, ses{j}, 'wd'), 'c0_csf.nii');
        c1_low = spm_select('FPList', fullfile(indir, subs{i}, ses{j}, 'wd'), 'c1_low.nii');
        c1_inter = spm_select('FPList', fullfile(indir, subs{i}, ses{j}, 'wd'), 'c1_inter.nii');
        c1_high = spm_select('FPList', fullfile(indir, subs{i}, ses{j}, 'wd'), 'c1_high.nii');
        c2_wm = spm_select('FPList', fullfile(indir, subs{i}, ses{j}, 'wd'), 'c2_wm.nii');
        
        if ~isempty(img_spect) && ~isempty(c0_csf) && ~isempty(c1_low) && ~isempty(c1_inter) && ~isempty(c1_high) && ~isempty(c2_wm)
        
            % Partial volume correction using the iterative Yang method
            FWHM=8.838725614; % the average value observed among patients on the old machine
            Target = img_spect;
            labelledROIs = c0_csf;
            ROIs = {c2_wm c1_high c1_inter c1_low};
            PSFsize = [15 15 15];
            PSFsd = FWHM/(2*sqrt(2*log(2)));
            ite = iter; % Originally 8, but complete convergence can take as long as ~25
    
            [img_corr, ~, allMeanValue, allNormValue, finalSimulation] = IterativeYang2(Target, labelledROIs, ROIs, PSFsize, PSFsd, ite);
    
            [outdir, bn, ~] = fileparts(img_spect);
            bn = [bn,'_corrIY', num2str(iter)];
            n1header = spm_vol(img_spect);
            n1header.fname = fullfile(outdir, [bn '.nii']);
            spm_write_vol(n1header, img_corr);
            bn = 'finalSimulation';
            n1header.fname = fullfile(outdir, [bn '.nii']);
            spm_write_vol(n1header, finalSimulation);
            
            % Plot convergence
            xval = 1:length(allMeanValue);
            tiledlayout(2,1)
            nexttile
            hold on
            grid on
            for k = 2:size(allMeanValue,2)
                    yval = allMeanValue(:,k) - mean(allMeanValue(:,k));
                    plot(xval,yval)
            end
            xlabel('Iteration')
            ylabel('Binding')
            title('Mean corrected binding (demeaned)')
            
            nexttile
            hold on
            grid on
            for k = 2:size(allNormValue,2)
                yval = allNormValue(:,k) - mean(allNormValue(:,k));
                plot(xval,yval)
            end
            xlabel('Iteration')
            ylabel('Binding')
            title('Normalized mean corrected binding (demeaned)')
            saveas(gcf, fullfile(outdir, 'iY_convergence.png'));
        
        else
            
            fprintf('>>> WARNING: Missing data, skipping...\n')
        
        end
        
    end
    
end

end

%% Function for the application of the Iterative Yang method
% @INPUT:
% - Target: the image for which to correct the partial volume effect
% - ROIs: cell array of binary masks
% - labelled ROIs:  char of mask with indices
% - PSFsize: 3x1 vector with the 3-D Gaussian kernel size (x y z) [voxel]
% - PSFsd: standard deviation (sigma) for the Gaussian kernel [voxel]
% determined as PSFsd = FWHM/(2*sqrt(2*log(2)))
% - ite: number of iterations (in general ~8 is sufficient, but closer to ~25 is better)

function [imageiY, iY, allMeanValue, allNormValue, finalSimulation]=IterativeYang2(Target,labelledROIs,ROIs,PSFsize,PSFsd,ite)

% Load target volume
target_vol = spm_vol(Target);
target_vol = spm_read_vols(target_vol);

% Load index mask
headerLabelledROI = spm_vol(labelledROIs);
imageLabelledROI = spm_read_vols(headerLabelledROI);
imageLabelledROI = round(imageLabelledROI);
Labels = unique(imageLabelledROI)';

% Load binary masks and 0 each element found in the index mask
headerROI = [];
imageROI = [];
for i=1:length(ROIs)
    
    headerROI{i} = spm_vol(ROIs{i});
    imageROI{i} = spm_read_vols(headerROI{i});
    imageROI{i}(imageLabelledROI ~= 0) = 0;
    
end

%% Initialize values for the iterative Yang algorithm
% Calculate mean values per index and ROI
meanvalue = zeros(1, length(Labels)+length(ROIs));

for j=2:length(Labels)
    meanvalue(j) = mean(target_vol(imageLabelledROI==Labels(j)));
end

for j=1:length(ROIs)
    meanvalue(length(Labels)+j)=mean(target_vol(imageROI{j}==1));
end

initialMeanValue=meanvalue;
fprintf('Initial mean values:\n');
disp(initialMeanValue);

%% Run the iterative Yang algorithm

% Normalize relative to mean value in white matter
AriY = meanvalue ./ meanvalue(length(Labels)+1);
fprintf('Initial normalized mean values:\n');
disp(AriY);

allMeanValue = initialMeanValue;
allNormValue = AriY;
finalSimulation = [];
for i = 1:ite
    
    % Simulation: Define a temporary image that will hold mean values at each
    % compartment defined by the index and binary masks
    imagec = zeros(size(target_vol));
    
    % Add mean CSF value to each voxel across the brain
    for j = 2:length(Labels)
        tempROI = zeros(size(target_vol));
        tempROI(imageLabelledROI == Labels(j)) = 1;
        AriY(isnan(AriY)) = 0;
        imagec = imagec + AriY(j) .* tempROI;
    end
    
    % For each ROI, add its mean value to voxels corresponding to mask
    for j=1:length(ROIs)
        imagec = imagec + AriY(length(Labels)+j) .* imageROI{j};
    end
    
    % Weight the target volume by smoothed compartment values
    Smimagec = smooth3(imagec, 'gaussian', PSFsize, PSFsd);
    imageInter = (imagec ./ Smimagec) .* target_vol;
    imageInter(isnan(imageInter)) = 0;
    
    % Recalculate mean values per index and ROI 
    for j=2:length(Labels)
        meanvalue(j)=mean(imageInter(imageLabelledROI == Labels(j)));
    end
    
    for j=1:length(ROIs)
        meanvalue(length(Labels)+j) = mean(imageInter(imageROI{j} == 1));
    end
    
    fprintf('Iteration: %i\n', i);
    fprintf('Indices:\n');
    disp(Labels)
    fprintf('Binary masks:\n');
    disp(numel(imageROI))
    fprintf('Mean values:\n');
    disp(meanvalue);
    fprintf('Normalized mean values:\n');
    AriY = meanvalue ./ meanvalue(length(Labels)+1);
    disp(AriY);
    
    allMeanValue = [allMeanValue; meanvalue];
    allNormValue = [allNormValue; AriY];
    finalSimulation = Smimagec;
    
end

% Weight the target volume by iteratively refined compartment values
imageiY = imagec ./ Smimagec .* target_vol;
imageiY(isnan(imageiY)) = 0;
iY = [initialMeanValue; meanvalue];

end
