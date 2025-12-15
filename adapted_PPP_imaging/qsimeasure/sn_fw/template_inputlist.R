# 1. Get subject IDs and demographics
# 2. Check for presence of baseline DTI data
# 3. Omit subjects without DTI and demographics data
# 4. MatchIt propensity score matching
# 5. Write subject list

library(tidyverse)
library(MatchIt)

# Assemble all participants and sessions. Specify intput files and check
# whether they exist.
bidsdir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4'
b0_dir <- file.path(
  bidsdir,
  'derivatives/qsiprep_1.0.1/derivatives/dipy_b0'
)
fw_dir <- file.path(
  bidsdir,
  'derivatives/qsiprep_1.0.1/derivatives/dipy_fw'
)
subs <- list.dirs(bidsdir, full.names = FALSE, recursive = FALSE)
subs <- subs[grepl('sub-', subs)]
sess <- c('ses-V0', 'ses-V2', 'ses-V4')
df_img <- crossing(subs, sess) %>%
  rename(subject = subs, visit = sess) %>%
  mutate(
    dwi_b0_fp = file.path(
      b0_dir,
      subject,
      visit,
      str_c(subject, '_', visit, '_dipy-b0mean.nii.gz')
    ),
    dwi_fa_fp = file.path(
      fw_dir,
      subject,
      visit,
      str_c(subject, '_', visit, '_dipy-FA.nii.gz')
    ),
    dwi_b0_exists = file.exists(dwi_b0_fp),
    dwi_fa_exists = file.exists(dwi_fa_fp),
    num_sujet = str_sub(subject, 5, 7),
    visit_num = as.numeric(str_sub(visit, 6, 6))
  )

# Select data to be used for matching
clindir <- '/home/martin.johansson/Nextcloud/ICM_DCCN/data/'
df_clin <- read_csv(
  file.path(clindir, 'ICEBERG_mj_2025-11-06.csv'),
  show_col_types = FALSE
)
clinvars <- c(
  'num_sujet',
  'group',
  'group2',
  'group3',
  'irbdc_converter',
  'irbdc_converted_to',
  'visit_num',
  'years_to_followup',
  'age',
  'sex',
  'disdur_years',
  'up3_off_total',
  'moca_total',
  'LEDD_total'
)
df_clin_s <- df_clin %>%
  select(all_of(clinvars)) %>%
  filter(visit_num %in% c(0, 2, 4))

# Exclusions based on manual quality control
# Some have inferior hyperintensities. This does not affect DTIs, but does
# affect B0 images. Therefore, take only subjects that have both good DTI and
# good B0, so we can make sure that the FA template and mean B0 come from
# the same subjects.
exclusions <- read_csv(
  '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/quality_control_dwi.csv',
  show_col_types = FALSE
) %>%
  mutate(
    num_sujet = str_pad(num_sujet, width = 3, side = 'left', pad = '0'),
    exclude = case_when(
      exclude == 1 ~ 1,
      exclude == 0 & str_detect(dwi_inspection, 'SDC') ~ 1,
      exclude == 0 & !str_detect(dwi_inspection, 'Motion') ~ 0
    )
  ) %>%
  filter(exclude == 1) %>%
  select(num_sujet, visit_num) %>%
  unique() %>%
  mutate(exclude = 1)

# Motion for further exclusion
# qc_metrics <- read_delim(
#   '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/mriqc_25.0.0rc0/bold/group_bold.tsv',
#   show_col_types = FALSE
# ) %>%
#   separate(
#     col = bids_name,
#     into = c('subject', 'visit', 'task', 'modality'),
#     sep = '_'
#   ) %>%
#   select(-c(task, modality)) %>%
#   select(subject, visit, fd_mean)

# Merge data sets and exclude:
# - subjects without group
# - subjects without dti data
# - subjects excluded based on manual QC
df <- df_img %>%
  left_join(df_clin_s, by = c('num_sujet', 'visit_num')) %>%
  left_join(exclusions, by = c('num_sujet', 'visit_num')) %>%
  mutate(exclude = ifelse(is.na(exclude), 0, exclude)) %>%
  filter(
    !is.na(group),
    dwi_b0_exists == TRUE,
    dwi_fa_exists == TRUE,
    exclude == 0
  ) %>%
  select(-c(num_sujet, visit_num, dwi_b0_exists, dwi_fa_exists, exclude))

# Match
df %>%
  filter(visit == 'ses-V0') %>%
  group_by(group3) %>%
  summarise(n = n())

set.seed(325)
match_fun <- function(input_df, timepoint, groups) {
  match_df <- input_df %>%
    filter(visit == timepoint, group %in% groups) %>%
    mutate(
      group = factor(group),
      sex = factor(sex),
    ) %>%
    matchit(
      group ~ age + sex,
      data = .,
      method = 'optimal',
      distance = 'glm',
      link = 'probit',
      estimand = 'ATT',
      tol = 1e-4
    )
  summary(match_df) %>% print()
  plot(match_df)
  match_df <- match.data(match_df)
  match_df
}

# Equal number of HC, iRBD, and PD_nrbd
match_hc_irbd <- df %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('Ctrl', 'iRBD'))
match_hc_pd <- df %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('Ctrl', 'PD_nrbd'))
set_hc <- nrow(match_hc_irbd %>% filter(group == 'Ctrl'))
set_irbd <- nrow(match_hc_irbd %>% filter(group == 'iRBD'))
set_pd <- nrow(match_hc_pd %>% filter(group == 'PD_nrbd'))
n_per_group <- min(c(set_hc, set_irbd, set_pd))
match_hc_irbd_pd <- match_hc_irbd %>%
  filter(group == 'iRBD') %>%
  bind_rows(match_hc_pd) %>%
  group_by(group) %>%
  slice_sample(n = n_per_group) %>%
  ungroup() %>%
  pull(subject)

# Subset data
df.s <- df %>%
  filter(visit == 'ses-V0')
df.s %>%
  filter(subject %in% match_hc_pd$subject) %>%
  pull(dwi_fa_fp) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/inputfiles_FA_g0-hc_g1-PDnrbd.txt'
  )
df.s %>%
  filter(subject %in% match_hc_pd$subject) %>%
  pull(dwi_b0_fp) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/inputfiles_B0_g0-hc_g1-PDnrbd.txt'
  )
df.s %>%
  filter(subject %in% match_hc_irbd_pd) %>%
  pull(dwi_fa_fp) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/inputfiles_FA_g0-hc_g1-iRBD_g2-PDnrbd.txt'
  )
df.s %>%
  filter(subject %in% match_hc_irbd_pd) %>%
  pull(dwi_b0_fp) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/templates/FA_HCP1065/inputfiles_B0_g0-hc_g1-iRBD_g2-PDnrbd.txt'
  )
