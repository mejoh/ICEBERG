% reorganize_datscans(inputdir, outputdir)
% Martin E. Johansson 14052025
% 
% 

function reorganize_datscans(inputdir, outputdir)

%inputdir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/DAT/DICOM_orig';
%outputdir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/DAT/DICOM_edit';

raw_data = dir(inputdir);
for i = 3:size(raw_data,1)
    c = struct();
    c.id = raw_data(i).name;
    c.name = ['sub-', char(extractBetween(c.id,'DAT_SPECT_','_V'))];
    c.visit = ['ses-petV', extractAfter(c.id,'_V')];
    
    newdir = fullfile(outputdir, c.name, c.visit);
    if exist(newdir, 'dir')
        delete(newdir)
    end
    mkdir(newdir)
    
    dicoms = cellstr(spm_select('FPList', fullfile(raw_data(i).folder,raw_data(i).name), '.*.dcm$'));
    for d = 1:numel(dicoms)
        copyfile(dicoms{d,1},newdir)
    end
    
end


end