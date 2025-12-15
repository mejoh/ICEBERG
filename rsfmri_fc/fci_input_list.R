library(tidyverse)
library(MatchIt)
library(tidymodels)

# Assemble all participants and sessions. Specify intput files and check
# whether they exist.
bidsdir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4'
fc_dir <- file.path(
  '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based'
)
subs <- list.dirs(bidsdir, full.names = FALSE, recursive = FALSE)
subs <- subs[grepl('sub-', subs)]
sess <- c('ses-V0', 'ses-V2', 'ses-V4')
df_img <- crossing(subs, sess) %>%
  rename(subject = subs, visit = sess) %>%
  mutate(
    InputFile = file.path(
      fc_dir,
      subject,
      visit,
      'estimates',
      'func_data.nii.gz'
    ),
    InputFile_exists = file.exists(InputFile),
    num_sujet = str_sub(subject, 5, 7),
    visit_char = str_sub(visit, 5, 6)
  )

# Select data to be used for matching
clindir <- '/home/martin.johansson/ownCloud/ICM_DCCN/data'
df_clin <- read_csv(
  file.path(clindir, 'ICEBERG_mj_2025-09-15.csv'),
  show_col_types = FALSE
)
clinvars <- c(
  'num_sujet',
  'group',
  'group2',
  'group3',
  'irbdc_converter',
  'irbdc_converted_to',
  'visit_char',
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
  filter(visit_char %in% c('V0', 'V2', 'V4'))

# Exclusions based on manual quality control
exclusions <- read_csv(
  '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/quality_control.csv',
  show_col_types = FALSE
) %>%
  mutate(subject = str_c('sub-', subject), session = str_c('ses-', session)) %>%
  filter(exclude == 1) %>%
  select(subject, session) %>%
  rename(visit = session) %>%
  unique() %>%
  mutate(exclude = 1)

# Motion for further exclusion
qc_metrics <- read_delim(
  '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/mriqc_25.0.0rc0/bold/group_bold.tsv',
  show_col_types = FALSE
) %>%
  separate(
    col = bids_name,
    into = c('subject', 'visit', 'task', 'modality'),
    sep = '_'
  ) %>%
  select(-c(task, modality)) %>%
  select(subject, visit, fd_mean)

# Merge data sets and exclude:
# - subjects without group
# - subjects without functional data
# - subjects excluded based on manual QC
# - subjects with mean FD > 0.5
df <- df_img %>%
  left_join(df_clin_s, by = c('num_sujet', 'visit_char')) %>%
  left_join(exclusions, by = c('subject', 'visit')) %>%
  left_join(qc_metrics, by = c('subject', 'visit')) %>%
  mutate(exclude = ifelse(is.na(exclude), 0, exclude)) %>%
  filter(
    !is.na(group),
    InputFile_exists == TRUE,
    exclude == 0,
    fd_mean < 0.4
  ) %>%
  select(-c(num_sujet, visit_char, InputFile_exists, exclude))

# Match
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
df %>%
  filter(visit == 'ses-V0') %>%
  group_by(group3) %>%
  summarise(n = n())
# Set up matched groups to derive different types of patterns
# that can distinguish diagnoses
# iRBD-related pattern: Extra
match_hc_irbd <- match_fun(df, 'ses-V0', c('Ctrl', 'iRBD'))
# PD-related pattern: Extra
match_hc_pd <- df %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('Ctrl', 'PD_nrbd'))
# Equal subjects from all three groups* <- Most relevant for masking cortico-striatal analyses
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
tmp <- df %>%
  filter(visit == 'ses-V0', subject %in% match_hc_irbd_pd) %>%
  select(subject, visit, group3, fd_mean) %>%
  mutate(
    group3 = factor(
      group3,
      levels = c('Ctrl', 'iRBD', 'PD_nrbd'),
      labels = c('HC', 'iRBD', 'PD_nrbd')
    )
  )
tmp %>% ggplot(aes(x = group3, y = fd_mean)) + geom_boxplot()
m <- lm(fd_mean ~ group3, data = tmp)
anova(m)
# Pull subject IDs
match_hc_irbd <- match_hc_irbd %>%
  pull(subject)
match_hc_pd <- match_hc_pd %>%
  pull(subject)
# *PDRBD-related pattern* <- Most relevant for phenoconversion where PD-RBD is the endstage
match_hc_pd_rbd <- df %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('Ctrl', 'PD_rbd')) %>%
  pull(subject)
# *PDRBD-related pattern*, but with iRBD as reference. Probably less interesting than above because converters are included in iRBD group
match_irbd_pd_rbd <- df %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('iRBD', 'PD_rbd')) %>%
  pull(subject)
# RBD-related pattern within PD: EXTRA. Relevant for investigating RBD in PD.
match_pd_pd_rbd <- df %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('PD_nrbd', 'PD_rbd')) %>%
  pull(subject)
# iRBDconverter-related pattern* <- Maybe relevant for phenoconversion as well, though small samnple
match_irbd_conv <- df %>%
  filter(group == 'iRBD') %>%
  mutate(group = if_else(irbdc_converter == 1, 'conv', 'nonconv')) %>%
  match_fun(., 'ses-V0', c('nonconv', 'conv')) %>%
  pull(subject)
# iRBDconverter-related pattern vs PDRBD* <- Maybe relevant for phenoconversion as well, though small samnple
match_irbd_conv_pd_rbd <- df %>%
  filter(
    group3 %in% c('iRBD', 'PD_rbd'),
    (group3 == 'iRBD' & irbdc_converter == 1) | group3 == 'PD_rbd'
  ) %>%
  mutate(group = group3) %>%
  match_fun(., 'ses-V0', c('iRBD', 'PD_rbd')) %>%
  pull(subject)

# Subset data
df.s <- df %>%
  filter(visit == 'ses-V0')
df.s %>%
  filter(subject %in% match_hc_irbd) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-hc_g1-iRBD.txt'
  )
df.s %>%
  filter(subject %in% match_hc_pd) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-hc_g1-PDnrbd.txt'
  )
df.s %>%
  filter(subject %in% match_hc_irbd_pd) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-hc_g1-iRBD_g2-PDnrbd.txt'
  )
df.s %>%
  filter(subject %in% match_hc_pd_rbd) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-hc_g1-PDrbd.txt'
  )
df.s %>%
  filter(subject %in% match_irbd_pd_rbd) %>%
  pull(InputFile) %>%
  write(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-iRBD_g1-PDrbd.txt'
  )
df.s %>%
  filter(subject %in% match_pd_pd_rbd) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-PDnrbd_g1-PDrbd.txt'
  )
df.s %>%
  filter(subject %in% match_irbd_conv) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-iRBDnconv_g1-iRBDconv.txt'
  )
df.s %>%
  filter(subject %in% match_irbd_conv_pd_rbd) %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_g0-iRBDconv_g1-PDrbd.txt'
  )
df %>%
  pull(InputFile) %>%
  write_lines(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_ica/melodic/inputfiles_all_subjects_sessions.txt'
  )
