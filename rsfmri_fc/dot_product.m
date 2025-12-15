
function scalar = dot_product(img01, img02, mask)

% dot_product.m
% 20250911, Martin E. Johansson
% 
% Description:
% Calculate the dot product between two images. Quantifies the degree
% of similarity between the images. Used primarily to calculate the PDRP.
% See Eidelberg 2009, https://doi.org/10.1016/j.tins.2009.06.003 (see box
% 3). This involves calculate the subject-residual profile (SRP), which
% reflects subject-specific deviations from the subject mean for each
% component(row-centering) and group mean for each voxel
% (column-centering).
%
% Example usage:
% Calculate similarity between Z-scored group maps and subject-specific
% maps.
% >>> inputdir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/gift'; 
% >>> img01 = spm_select('FPList',fullfile(melodic_dir{i},'gift_out'),'gift__mean_component_ica_s_all_.nii');
% >>> img02 = spm_select('FPList',dualreg_dir,['dr_stage2_subject',sub{j},'_Z.nii.gz']);
% >>> mask = spm_select('FPList',inputdir,'mask.nii.gz');
% >>> dot_product(img01, img02, mask)
%
% *img01*: Group component map (group ICA). Can be 3D or 4D.
% *img02*: Subject-specific map (dual-regression). Can be 3D or 4D. Note
% that the number of volumes of img02 must match the number of volumes of
% img01!
% *mask*: Binary mask used to mask img01 and img02 before centering and
% dot product. Can be 3D or 4D. If 3D, the mask is replicated to match the
% number of volumes in img01/2. Note that if 4D, the volumes in the mask
% can be unique (e.g. thresholded subject-specific masks from step4 of
% dual-regression with the --thr argument).

% Read images
img01 = ft_read_mri(img01);
img02 = ft_read_mri(img02);
mask = ft_read_mri(mask);

% Check that image dimensions are consistent
if sum(img01.dim - img02.dim) ~= 0 && sum(img01.dim - mask.dim) ~= 0
    error('Error: inconsistent image dimensions %i %i\n', test(1), test(2))
end

% Check whether input data is 4D
if length(size(img01.anatomy)) == 4 && length(size(img02.anatomy)) == 4
    nvols = size(img01.anatomy, 4);
    fprintf('>>> 4D inputs: %i volumes detected \n', nvols)
elseif length(size(img01.anatomy)) == 3 && length(size(img01.anatomy)) == 3
    fprintf('>>> 3D inputs: 1 volume \n')
    nvols = 1;
end

% Check whether mask is 4D
if length(size(mask.anatomy)) == 4
    mask_nvols = size(mask.anatomy,4);
elseif length(size(mask.anatomy)) == 3
    mask_nvols = 1;
end

% Flatten to vector. Transpose so that columns represent voxels. If mask is
% 3D, replicate it to match nvols.
img01_vec = reshape(img01.anatomy, [], nvols)';
img02_vec = reshape(img02.anatomy, [], nvols)';
mask_vec = reshape(mask.anatomy, [], mask_nvols)';
if nvols > 1 && length(size(mask.anatomy)) == 3
    mask_vec = repmat(mask_vec,nvols,1);
end

% Calculate similarity
scalar = zeros(nvols, 1);
tmp1 = [];
tmp2 = [];
for i=1:nvols
    
    clear tmp1 tmp2
    
    % Mask values
    tmp1 = img01_vec(:, logical(mask_vec(i,:)));
    tmp2 = img02_vec(:, logical(mask_vec(i,:)));
    
    % Subject residual profile (SRP), a.k.a. centering. Follows Box 3 in
    % Eidelberg 2009. Remove the subject-specific mean of each component
    % (row-centering). Then remove the group mean from each voxel
    % (column-centering). Here, the median is used rather than the mean to
    % increase robustness given that we're unable to log-transform.
    tmp2 = tmp2 - median(tmp2,2);
    tmp2 = tmp2 - median(tmp1,1);
    
    % The centering approach was originally intended for log-transformed
    % images. rsfMRI data cannot be log-transformed due to negative values,
    % meaning that there is a difference compared to the PET method. How do
    % we deal with this? Note that a subtraction in log space is similar to
    % taking a ratio in normal space:
    % log(5.4) - log(4.3) = 0.2278
    % exp(0.2278) = 1.2558
    % 5.4 / 4.3 = 1.2558
    % Rather than centering through subtraction, it may be relevant to
    % center by taking ratios. However, this introduces a massive
    % difference between the subject-specific and group-level values, with
    % the former being a ratio of z-scores and the latter being simply
    % z-scores. This approach is therefore not viable unless adapted
    % further!
%     tmp2 = tmp2 ./ mean(tmp2,2);
%     tmp2 = tmp2 ./ mean(tmp1,1);
    
    scalar(i,1) = dot(tmp1(i,:), tmp2(i,:));
end

end
