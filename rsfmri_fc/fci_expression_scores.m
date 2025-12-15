% fci_expression_scores.m
% 20250916 Martin E. Johansson
% Calculate the dot product between group maps, generated with melodic, and
% subject-specific maps, generated with dual regression.

% MELODIC or GIFT maps
melodic = false;

% Path to dot_product.m
addpath('/network/iss/cenir/analyse/irm/users/martin.johansson/code/iceberg/rsfmri_fc')

% Directories
fc_dir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica';

if(melodic)
melodic_dir = {
    fullfile(fc_dir, 'melodic/g0-hc_g1-PDrbd')
    fullfile(fc_dir, 'melodic/g0-hc_g1-PDnrbd')
    fullfile(fc_dir, 'melodic/g0-hc_g1-iRBD_g2-PDnrbd')
    };
else
melodic_dir = {
    fullfile(fc_dir, 'gift/g0-hc_g1-PDrbd')
    fullfile(fc_dir, 'gift/g0-hc_g1-PDnrbd')
    fullfile(fc_dir, 'gift/g0-hc_g1-iRBD_g2-PDnrbd')
    };
end
for i = 1:numel(melodic_dir)
    dualreg_dir = fullfile(melodic_dir{i}, 'dualreg');

    % List subjects
    sub = cellstr(spm_select('List',dualreg_dir,'dr_stage1_subject0.*.txt'));
    sub = extractBetween(sub, 'dr_stage1_subject', '.txt');

    % Compute dot product between group- and subject-specific parameter
    % estimates. Note that this may also be done on z-scored maps.
    similarity = table();
    for j = 1:numel(sub)
        % Images can be 3D or 4D. They must have the same dimensions.
        % Mask can be either 3D or 4D.
        if(melodic)
            img01 = spm_select('FPList',melodic_dir{i},'melodic_IC.nii.gz');
            %img02 = spm_select('FPList',dualreg_dir,['dr_stage2_subject',sub{j},'.nii.gz']);
            %img02 = spm_select('FPList',dualreg_dir,['dr_stage2_subject',sub{j},'_Z.nii.gz']);
            img02 = spm_select('FPList',dualreg_dir,['dr_stage4_subject',sub{j},'_thresh.nii.gz']);
            mask = spm_select('FPList',dualreg_dir,['dr_stage4_subject',sub{j},'_mask.nii.gz']);
            % mask = spm_select('FPList',dualreg_dir,'mask.nii.gz');
        else
            img01 = spm_select('FPList',fullfile(melodic_dir{i},'gift_out_noZ'),'gift__mean_component_ica_s_all_.nii');
            %img02 = spm_select('FPList',dualreg_dir,['dr_stage2_subject',sub{j},'.nii.gz']);
            %img02 = spm_select('FPList',dualreg_dir,['dr_stage2_subject',sub{j},'_Z.nii.gz']);
            img02 = spm_select('FPList',dualreg_dir,['dr_stage4_subject',sub{j},'_thresh.nii.gz']);
            mask = spm_select('FPList',dualreg_dir,['dr_stage4_subject',sub{j},'_mask.nii.gz']);
            %mask = spm_select('FPList',dualreg_dir,'mask.nii.gz');
        end
        clear comp
        clear tmp
        comp = dot_product(img01,img02,mask);
        tmp = [table(sub(j),'VariableNames',{'dualregid'}), array2table(comp','VariableNames',cellstr(compose("comp%d", 1:length(comp))))];
        similarity = [similarity; tmp];
    end

    % Append subject IDs
    inputfiles = fullfile(fc_dir, 'melodic/inputfiles_all_subjects_sessions.txt');
    t = readtable(inputfiles, 'ReadVariableNames', false);
    sub_ids = [t(:,12), t(:,13)];
    sub_ids.Properties.VariableNames = {'subid', 'sesid'};
    output = [sub_ids, similarity];

    % Write to file
    fname = fullfile(melodic_dir{i}, ['expression_scores_', datestr(now, 'yyyy_mm_dd'), '.csv']);
    writetable(output, fname, 'Delimiter', ',')

end
