#!/bin/bash

# SPECT and CT data have multiple runs for plenty of subjects. These need to be dealt with before processing to ensure use
# of most recent version of reconstructions. Use the code below to identify subjects that need to be dealt with. Place
# the unused data in 'extra_data'.
# Guidelines and rules:
# - Generally, the most recent reconstruction is run-01.
# - When there are identical images, use the set with lowest run number.


# SPECT
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V0/spect/sub-*_ses-V0_trc-123IFPCIT_rec-ChangReo_run-03_spect.nii
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V0/spect/sub-*_ses-V0_trc-123IFPCIT_rec-ChangReo_run-02_spect.nii

ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V2/spect/sub-*_ses-V2_trc-123IFPCIT_rec-ChangReo_run-04_spect.nii
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V2/spect/sub-*_ses-V2_trc-123IFPCIT_rec-ChangReo_run-03_spect.nii
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V2/spect/sub-*_ses-V2_trc-123IFPCIT_rec-ChangReo_run-02_spect.nii

ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V4/spect/sub-*_ses-V4_trc-123IFPCIT_rec-ChangReo_run-04_spect.nii
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V4/spect/sub-*_ses-V4_trc-123IFPCIT_rec-ChangReo_run-03_spect.nii
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V4/spect/sub-*_ses-V4_trc-123IFPCIT_rec-ChangReo_run-02_spect.nii

# CT
ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V0/ct/sub-*_ses-V0_rec-standard_run-02_ct.nii

ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V2/ct/sub-*_ses-V2_rec-standard_run-02_ct.nii # 0 subjects

ls /network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids_dat/sub-*/ses-V4/ct/sub-*_ses-V4_rec-standard_run-02_ct.nii