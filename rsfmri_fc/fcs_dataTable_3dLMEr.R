dataTable_3dLMEr_single <- function(
  cope = 'cope1.nii.gz',
  granularity = 2,
  fcdir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based',
  fcdir_alt = '/project/3022026.01/users/marjoh/iceberg/fc_seed_based'
) {
  library(tidyverse)

  #cope <- 'cope1.nii.gz'
  #FCDIR <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based'

  # List of subjects with seed-based FC output
  subs <- dir(fcdir, pattern = 'sub-.*', full.names = FALSE)

  # Clinical data
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
    'visit_num',
    'years_to_followup',
    'age',
    'sex',
    'disdur_years',
    'up3_off_total',
    'up3_off_bradyrig',
    'up3_off_bradyrig_mas',
    'moca_total',
    'LEDD_total'
  )
  df_clin_s <- df_clin %>%
    select(all_of(clinvars)) %>%
    filter(visit_num %in% c(0, 2, 4))

  # Initialize data frame
  df_all <- tibble(
    Subj = character(),
    Subj_nr = character(),
    Group = character(),
    Group_detail = character(),
    Group_RBD = character(),
    Visit = character(),
    VisitNr = numeric(),
    YearsToFollowUp = numeric(),
    Age = numeric(),
    Sex = character(),
    YearsSinceDiag = numeric(),
    Up3Total = numeric(),
    Up3BradyRig = numeric(),
    MAS = character(),
    MoCA = numeric(),
    LEDD = numeric(),
    InputFile = character()
  )

  for (i in 1:length(subs)) {
    # Define subject
    sub <- subs[i]
    sub_num <- sub %>% str_sub(5, 7)
    cat('>>> Processing', sub, '(', i, 'of', length(subs), ')\n')
    # Check if subject is in clinical data and exclude if not
    excluded <- if_else(
      nrow(df_clin_s %>% filter(num_sujet == sub_num)) == 0,
      TRUE,
      FALSE
    )
    if (excluded) {
      cat('>>>  Subject', sub, 'not in clinical data, skipping...\n')
      next
    }
    # List visits
    visits <- dir(file.path(fcdir, sub), pattern = 'ses-.*', full.names = FALSE)
    for (j in 1:length(visits)) {
      # Collect data
      visit <- visits[j]
      visit_num <- str_remove(visit, 'ses-V') %>% as.numeric()
      cat('>>>  Visit:', visit, '(', j, 'of', length(visits), ')\n')
      tmp <- c()
      tmp <- df_clin_s %>%
        filter(num_sujet == sub_num)
      tmp_ba <- tmp %>% slice(1)
      tmp_Subj <- sub %>% as.character()
      tmp_Subj_nr <- sub_num %>% as.character()
      tmp_Group <- tmp_ba$group %>% as.character()
      tmp_Group_detail <- tmp_ba$group2 %>% as.character()
      tmp_Group_RBD <- tmp_ba$group3 %>% as.character()
      tmp_Visit <- visit %>% as.character()
      tmp_VisitNr <- visit_num %>% as.numeric()
      tmp_YearsToFollowUp <- tmp %>%
        filter(visit_num == tmp_VisitNr) %>%
        pull(years_to_followup) %>%
        as.numeric()
      tmp_Age <- tmp_ba$age %>% as.numeric()
      tmp_Sex <- tmp_ba$sex %>% as.character()
      tmp_YearsSinceDiag <- tmp_ba$disdur_years %>% as.numeric()
      tmp_Up3Total <- tmp %>%
        filter(visit_num == tmp_VisitNr) %>%
        pull(up3_off_total) %>%
        as.numeric()
      tmp_Up3BradyRig <- tmp %>%
        filter(visit_num == tmp_VisitNr) %>%
        pull(up3_off_bradyrig) %>%
        as.numeric()
      tmp_MAS <- tmp_ba$up3_off_bradyrig_mas %>% as.character()
      tmp_MoCA <- tmp %>%
        filter(visit_num == tmp_VisitNr) %>%
        pull(moca_total) %>%
        as.numeric()
      tmp_LEDD <- tmp %>%
        filter(visit_num == tmp_VisitNr) %>%
        pull(LEDD_total) %>%
        as.numeric()
      tmp_InputFile <- dir(
        file.path(
          fcdir,
          sub,
          visit,
          'estimates',
          str_c('fsl_granularity', granularity, '_gs1.feat'),
          'stats'
        ),
        pattern = str_c('^', cope),
        full.names = TRUE
      )
      if (identical(tmp_InputFile, character(0))) {
        tmp_InputFile <- NA
      }
      tmp_InputFile <- str_replace(tmp_InputFile, fcdir, fcdir_alt)
      # Assemble into data frame
      df_sub <- tibble(
        Subj = tmp_Subj,
        Subj_nr = tmp_Subj_nr,
        Group = tmp_Group,
        Group_detail = tmp_Group_detail,
        Group_RBD = tmp_Group_RBD,
        Visit = tmp_Visit,
        VisitNr = tmp_VisitNr,
        YearsToFollowUp = tmp_YearsToFollowUp,
        Age = tmp_Age,
        Sex = tmp_Sex,
        YearsSinceDiag = tmp_YearsSinceDiag,
        Up3Total = tmp_Up3Total,
        Up3BradyRig = tmp_Up3BradyRig,
        MAS = tmp_MAS,
        MoCA = tmp_MoCA,
        LEDD = tmp_LEDD,
        InputFile = tmp_InputFile
      )
      # Append to overall data frame
      df_all <- bind_rows(df_all, df_sub)
    }
  }
  return(df_all)
}

# Assemble data table
df_c1 <- dataTable_3dLMEr_single(cope = 'cope1.nii.gz') %>%
  mutate(Region = 'put', Division = 'pos', cope = 1)
df_c2 <- dataTable_3dLMEr_single(cope = 'cope2.nii.gz') %>%
  mutate(Region = 'put', Division = 'ant', cope = 2)
df_c3 <- dataTable_3dLMEr_single(cope = 'cope4.nii.gz') %>%
  mutate(Region = 'cau', Division = 'pos', cope = 4)
df_c4 <- dataTable_3dLMEr_single(cope = 'cope5.nii.gz') %>%
  mutate(Region = 'cau', Division = 'ant', cope = 5)
df_c7 <- dataTable_3dLMEr_single(cope = 'cope7.nii.gz') %>%
  mutate(Region = 'put', Division = 'asubp', cope = 7)
df_c8 <- dataTable_3dLMEr_single(cope = 'cope8.nii.gz') %>%
  mutate(Region = 'cau', Division = 'asubp', cope = 8)
df_3dLMEr <- df_c1 %>%
  bind_rows(df_c2) %>%
  bind_rows(df_c3) %>%
  bind_rows(df_c4) %>%
  bind_rows(df_c7) %>%
  bind_rows(df_c8)

# Exclude subjects based on quality control
exclusions <- read_csv(
  '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/quality_control.csv',
  show_col_types = FALSE
) %>%
  mutate(subject = str_c('sub-', subject), session = str_c('ses-', session)) %>%
  filter(exclude == 1) %>%
  select(subject, session) %>%
  rename(Subj = subject, Visit = session) %>%
  unique() %>%
  mutate(exclude = 1)
df_3dLMEr <- df_3dLMEr %>%
  left_join(exclusions) %>%
  mutate(exclude = if_else(is.na(exclude), 0, exclude)) %>%
  filter(exclude == 0)

# Feature engineering
df_3dLMEr <- df_3dLMEr %>%
  mutate(
    Visit = str_remove(Visit, 'ses-'),
    Sex = if_else(Sex == 0, 'male', 'female'),
    across(where(is.numeric), \(x) round(x, 3))
  ) %>%
  arrange(Subj, Visit, Region, Division)

# Write out data tables for 3dLMEr analyses
df_3dLMEr_group <- df_3dLMEr %>%
  filter(Division %in% c('pos', 'ant')) %>%
  select(
    Subj,
    Group,
    Visit,
    YearsToFollowUp,
    Region,
    Division,
    Age,
    Sex,
    InputFile
  ) %>%
  na.omit()
df_3dLMEr_group %>%
  filter(Group %in% c('Ctrl', 'iRBD')) %>%
  mutate(Group = if_else(Group == 'Ctrl', 'G0', 'G1')) %>%
  write_tsv(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/3dLMEr/dataTable_g0-HC_g1-iRBD_comparison.txt',
    col_names = TRUE
  )
df_3dLMEr_group %>%
  filter(Group %in% c('Ctrl', 'PD')) %>%
  mutate(Group = if_else(Group == 'Ctrl', 'G0', 'G1')) %>%
  write_tsv(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/3dLMEr/dataTable_g0-HC_g1-PD_comparison.txt',
    col_names = TRUE
  )
df_3dLMEr_group %>%
  filter(Group %in% c('iRBD', 'PD')) %>%
  mutate(Group = if_else(Group == 'iRBD', 'G0', 'G1')) %>%
  write_tsv(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/3dLMEr/dataTable_g0-iRBD_g1-PD_comparison.txt',
    col_names = TRUE
  )
df_3dLMEr_group %>%
  filter(Group %in% c('Ctrl', 'iRBD', 'PD')) %>%
  mutate(
    Group = case_when(
      Group == 'Ctrl' ~ 'G0',
      Group == 'iRBD' ~ 'G1',
      Group == 'PD' ~ 'G2'
    )
  ) %>%
  write_tsv(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/3dLMEr/dataTable_g0-HC_g1-iRBD_g2-PD_comparison.txt',
    col_names = TRUE
  )

# df_3dLMEr_clin <- df_3dLMEr %>%
#   filter(Division %in% c('p', 'a')) %>%
#   filter(Group == 'PD') %>%
#   select(
#     Subj,
#     Visit,
#     Up3Total,
#     MoCA,
#     LEDD,
#     Region,
#     Division,
#     Age,
#     Sex,
#     YearsSinceDiag,
#     InputFile
#   ) %>%
#   na.omit()
# write_tsv(
#   df_3dLMEr_clin,
#   '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/3dLMEr/dataTable_clinical_correlation.txt',
#   col_names = TRUE
# )
