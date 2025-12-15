% spect_fix_dicom(fp_dicom)
% M.E. Johansson (20251203)
%
% Iterates through dicoms in a folder and re-writes those that have been
% attenuation corrected with the appropriate threshold value.
%

function spect_fix_dicom(fp_dicom)
% fp_dicom='/network/iss/cenir/analyse/irm/users/martin.johansson/wd/tmp/2017_01_17_ICEBERG_DAT_SPECT_MJ_108_V0/DICOM/25100714/22200000'

fprintf('>>> Processing directory: %s\n', fp_dicom)

path = dir(fp_dicom);

for i = 3:size(path,1)

    spect_info = dicominfo([path(i,1).folder,'/',path(i,1).name], 'UseDictionaryVR', true);

    if isfield(spect_info, 'ImageComments')
        if contains(spect_info.ImageComments, 'Chang AC: 0.11/10.0')
            fprintf('>>> Correcting DICOM: %s\n', path(i,1).name)
            spect_vol = dicomread([path(i,1).folder,'/',path(i,1).name]);
            spect_out = [path(i,1).folder,'/',path(i,1).name,'_corr'];
            dicomwrite(spect_vol, spect_out, spect_info, 'CreateMode', 'Copy');
            fprintf('Done!\n')
        end
    end

end

end