# fsl_randomise_covars
#
# Generate files required to build design matrices for randomise:
# - File with full paths to images used for merging
# - File with demeaned covariates
# - File with contrast matrix
#
# Files are generated to run the following analyses:
#
# - Two-sample t-test comparing HC and PD

library(tidyverse)
library(MatchIt)

# Functions
fsl_randomise_covars_byses <- function(
  fc_dir,
  featname,
  cope,
  clin_file,
  visit,
  output_dir,
  exclude = NULL
) {
  library(tidyverse)
  library(MatchIt)

  dir.create(output_dir, showWarnings = F, recursive = T)

  # Initialize data frame
  subs = dir(fc_dir, pattern = 'sub-')
  dfinit <- tibble(
    pseudonym = subs,
    visit = visit,
    num_sujet = subs %>%
      str_remove('sub-') %>%
      str_sub(1, 3),
    visit_num = str_remove(visit, 'ses-V') %>%
      as.numeric()
  )

  # Select baseline covars
  baseline_covars <- read_csv(
    clin_file,
    col_select = c(
      'num_sujet',
      'visit_num',
      'group',
      'group3',
      'age',
      'sex',
    ),
    show_col_types = FALSE
  ) %>%
    group_by(num_sujet) %>%
    na.omit() %>%
    summarise(across(everything(), first))

  # Add covariates
  df <- dfinit %>%
    left_join(
      baseline_covars[, c(
        'num_sujet',
        'group',
        'group3',
        'age',
        'sex'
      )],
      by = c('num_sujet')
    )

  # Exclusions based on manual quality control
  exclusions <- read_csv(
    '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/quality_control.csv',
    show_col_types = FALSE
  ) %>%
    mutate(
      pseudonym = str_c('sub-', subject),
      visit = str_c('ses-', session)
    ) %>%
    filter(exclude == 1) %>%
    select(pseudonym, visit) %>%
    unique() %>%
    mutate(exclude = 1)
  df <- df %>%
    left_join(exclusions, by = c('pseudonym', 'visit')) %>%
    mutate(exclude = if_else(is.na(exclude), 0, exclude)) %>%
    rename(failed_qc = exclude)

  # Add file paths
  df <- df %>%
    mutate(
      img_fp = file.path(
        fc_dir,
        pseudonym,
        visit,
        'estimates',
        featname,
        'stats',
        paste0(cope, '.nii.gz')
      ),
      img_exists = file.exists(img_fp),
    )

  # Exclude subjects lacking data
  df <- df %>%
    filter(failed_qc == 0, img_exists == TRUE) %>%
    select(-c(failed_qc, img_exists))

  # Define groups
  df_hc_only <- df %>%
    filter(group %in% c('Ctrl')) %>%
    mutate(
      G0 = 1
    ) %>%
    na.omit()
  df_irbd_only <- df %>%
    filter(group %in% c('iRBD')) %>%
    mutate(
      G0 = 1
    ) %>%
    na.omit()
  df_pd_only <- df %>%
    filter(group %in% c('PD') & group3 != 'PD_rbd') %>%
    mutate(
      G0 = 1
    ) %>%
    na.omit()
  df_pdr_only <- df %>%
    filter(group %in% c('PD') & group3 == 'PD_rbd') %>%
    mutate(
      G0 = 1
    ) %>%
    na.omit()
  df_hc_irbd <- df %>%
    filter(group %in% c('Ctrl', 'iRBD')) %>%
    mutate(
      G0 = if_else(group == 'Ctrl', 1, 0),
      G1 = if_else(group == 'iRBD', 1, 0)
    ) %>%
    na.omit()
  df_hc_pd <- df %>%
    filter(group3 != 'PD_rbd', group %in% c('Ctrl', 'PD')) %>%
    mutate(
      G0 = if_else(group == 'Ctrl', 1, 0),
      G1 = if_else(group == 'PD', 1, 0)
    ) %>%
    na.omit()
  df_hc_pdr <- df %>%
    filter(group3 %in% c('Ctrl', 'PD_rbd')) %>%
    mutate(
      G0 = if_else(group3 == 'Ctrl', 1, 0),
      G1 = if_else(group3 == 'PD_rbd', 1, 0)
    ) %>%
    na.omit()
  df_irbd_pd <- df %>%
    filter(group3 != 'PD', group %in% c('iRBD', 'PD')) %>%
    mutate(
      G0 = if_else(group == 'iRBD', 1, 0),
      G1 = if_else(group == 'PD', 1, 0)
    ) %>%
    na.omit()
  df_irbd_pdr <- df %>%
    filter(group3 %in% c('iRBD', 'PD_rbd')) %>%
    mutate(
      G0 = if_else(group3 == 'iRBD', 1, 0),
      G1 = if_else(group3 == 'PD_rbd', 1, 0)
    ) %>%
    na.omit()
  df_pd_pdr <- df %>%
    filter(group3 %in% c('PD_nrbd', 'PD_rbd')) %>%
    mutate(
      group = group3,
      G0 = if_else(group == 'PD_nrbd', 1, 0),
      G1 = if_else(group == 'PD_rbd', 1, 0)
    ) %>%
    na.omit()

  # Match datasets
  set.seed(325)
  match_fun <- function(input_df) {
    match_df <- input_df %>%
      select(num_sujet, G0, age, sex) %>%
      mutate(
        G0 = factor(G0),
        sex = factor(sex),
      ) %>%
      matchit(
        G0 ~ age + sex,
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
    match_df <- match_df %>%
      select(num_sujet) %>%
      mutate(matched = 1)
    match_df
  }
  df_hc_irbd <- df_hc_irbd %>%
    left_join(match_fun(.), by = 'num_sujet')
  df_hc_pd <- df_hc_pd %>%
    left_join(match_fun(.), by = 'num_sujet')
  df_hc_pdr <- df_hc_pdr %>%
    left_join(match_fun(.), by = 'num_sujet')
  df_irbd_pd <- df_irbd_pd %>%
    left_join(match_fun(.), by = 'num_sujet')
  df_irbd_pdr <- df_irbd_pdr %>%
    left_join(match_fun(.), by = 'num_sujet')
  df_pd_pdr <- df_pd_pdr %>%
    left_join(match_fun(.), by = 'num_sujet')
  df_hc_irbd_m <- df_hc_irbd %>% filter(matched == 1) %>% select(-matched)
  df_hc_pd_m <- df_hc_pd %>% filter(matched == 1) %>% select(-matched)
  df_hc_pdr_m <- df_hc_pdr %>% filter(matched == 1) %>% select(-matched)
  df_irbd_pd_m <- df_irbd_pd %>% filter(matched == 1) %>% select(-matched)
  df_irbd_pdr_m <- df_irbd_pdr %>% filter(matched == 1) %>% select(-matched)
  df_pd_pdr_m <- df_pd_pdr %>% filter(matched == 1) %>% select(-matched)

  # Select and demean
  sel_demean_func <- function(input_df, type = 'two.sample') {
    if (type == 'two.sample') {
      tmp <- input_df %>%
        select(G0, G1, age, sex) %>%
        mutate(
          age = age - mean(age),
          sex = sex - mean(sex),
          across(where(is.numeric), \(x) round(x, digits = 3))
        )
    } else if (type == 'one.sample') {
      tmp <- input_df %>%
        select(G0, age, sex) %>%
        mutate(
          age = age - mean(age),
          sex = sex - mean(sex),
          across(where(is.numeric), \(x) round(x, digits = 3))
        )
    }
    tmp
  }
  df_hc_only_s <- sel_demean_func(df_hc_only, type = 'one.sample')
  df_irbd_only_s <- sel_demean_func(df_irbd_only, type = 'one.sample')
  df_pd_only_s <- sel_demean_func(df_pd_only, type = 'one.sample')
  df_pdr_only_s <- sel_demean_func(df_pdr_only, type = 'one.sample')
  df_hc_irbd_s <- sel_demean_func(df_hc_irbd)
  df_hc_pd_s <- sel_demean_func(df_hc_pd)
  df_hc_pdr_s <- sel_demean_func(df_hc_pdr)
  df_irbd_pd_s <- sel_demean_func(df_irbd_pd)
  df_irbd_pdr_s <- sel_demean_func(df_irbd_pdr)
  df_hc_irbd_m_s <- sel_demean_func(df_hc_irbd_m)
  df_hc_pd_m_s <- sel_demean_func(df_hc_pd_m)
  df_hc_pdr_m_s <- sel_demean_func(df_hc_pdr_m)
  df_irbd_pd_m_s <- sel_demean_func(df_irbd_pd_m)
  df_irbd_pdr_m_s <- sel_demean_func(df_irbd_pdr_m)
  df_pd_pdr_s <- sel_demean_func(df_pd_pdr)
  df_pd_pdr_m_s <- sel_demean_func(df_pd_pdr_m)

  # Write to file
  write_files_func <- function(full_df, reduced_df, outputpath, label) {
    write_delim(
      full_df[, 'img_fp'],
      file.path(outputpath, str_c('imgs__', label, '.txt')),
      col_names = F
    )
    write_delim(
      reduced_df,
      file.path(outputpath, str_c('covs__', label, '.txt')),
      col_names = F
    )
  }
  write_files_func(df_hc_only, df_hc_only_s, output_dir, 'g0-hc_only')
  write_files_func(df_irbd_only, df_irbd_only_s, output_dir, 'g0-irbd_only')
  write_files_func(df_pd_only, df_pd_only_s, output_dir, 'g0-pd_only')
  write_files_func(df_pdr_only, df_pdr_only_s, output_dir, 'g0-pdr_only')
  write_files_func(
    df_hc_irbd,
    df_hc_irbd_s,
    output_dir,
    'g0-hc_g1-irbd_match-n'
  )
  write_files_func(
    df_hc_irbd_m,
    df_hc_irbd_m_s,
    output_dir,
    'g0-hc_g1-irbd_match-y'
  )
  write_files_func(df_hc_pd, df_hc_pd_s, output_dir, 'g0-hc_g1-pd_match-n')
  write_files_func(df_hc_pd_m, df_hc_pd_m_s, output_dir, 'g0-hc_g1-pd_match-y')
  write_files_func(df_hc_pdr, df_hc_pdr_s, output_dir, 'g0-hc_g1-pdr_match-n')
  write_files_func(
    df_hc_pdr_m,
    df_hc_pdr_m_s,
    output_dir,
    'g0-hc_g1-pdr_match-y'
  )
  write_files_func(
    df_irbd_pd,
    df_irbd_pd_s,
    output_dir,
    'g0-irbd_g1-pd_match-n'
  )
  write_files_func(
    df_irbd_pd_m,
    df_irbd_pd_m_s,
    output_dir,
    'g0-irbd_g1-pd_match-y'
  )
  write_files_func(
    df_irbd_pdr,
    df_irbd_pdr_s,
    output_dir,
    'g0-irbd_g1-pdr_match-n'
  )
  write_files_func(
    df_irbd_pdr_m,
    df_irbd_pdr_m_s,
    output_dir,
    'g0-irbd_g1-pdr_match-y'
  )
  write_files_func(df_pd_pdr, df_pd_pdr_s, output_dir, 'g0-pd_g1-pdr_match-n')
  write_files_func(
    df_pd_pdr_m,
    df_pd_pdr_m_s,
    output_dir,
    'g0-pd_g1-pdr_match-y'
  )

  # tmp <- df.s %>% filter(HC == 1) %>% select(-PD)
  # tmp %>%
  #   write_delim(
  #     .,
  #     paste0(outputdir, '/posthoc_gHC__covs__unpaired_ttest_unmatched.txt'),
  #     col_names = F
  #   )
  # tmp <- df.s %>% filter(PD == 1) %>% select(-HC)
  # tmp %>%
  #   write_delim(
  #     .,
  #     paste0(outputdir, '/posthoc_gPD__covs__unpaired_ttest_unmatched.txt'),
  #     col_names = F
  #   )

  # Write contrasts
  # Contrasts
  rbind(
    c(1, -1, 0, 0),
    c(-1, 1, 0, 0)
  ) %>%
    write.table(
      .,
      file.path(output_dir, str_c('cons____two_sample_ttest.txt')),
      col.names = F,
      row.names = F,
      quote = F
    )
  rbind(
    c(1, 0, 0)
  ) %>%
    write.table(
      .,
      file.path(output_dir, str_c('cons____one_sample_ttest.txt')),
      col.names = F,
      row.names = F,
      quote = F
    )
}

fsl_swe_covars <- function(
  rand_dir,
  swe_dir,
  cope,
  comparison
) {
  # Initialize output directory
  dir.create(
    file.path(swe_dir, paste0('seed-', cope), comparison),
    showWarnings = F,
    recursive = T
  )

  # Load image paths
  imgs_v0 <- list.files(
    path = file.path(rand_dir, paste0('seed-', cope, '_ses-V0')),
    pattern = paste0('imgs__', comparison, '.txt'),
    full.names = T
  ) %>%
    read_lines()
  imgs_v2 <- list.files(
    path = file.path(rand_dir, paste0('seed-', cope, '_ses-V2')),
    pattern = paste0('imgs__', comparison, '.txt'),
    full.names = T
  ) %>%
    read_lines()
  imgs_v4 <- list.files(
    path = file.path(rand_dir, paste0('seed-', cope, '_ses-V4')),
    pattern = paste0('imgs__', comparison, '.txt'),
    full.names = T
  ) %>%
    read_lines()
  imgs_all <- c(imgs_v0, imgs_v2, imgs_v4)

  # Load covariates
  covs_v0 <- list.files(
    path = file.path(rand_dir, paste0('seed-', cope, '_ses-V0')),
    pattern = paste0('covs__', comparison, '.txt'),
    full.names = T
  ) %>%
    read_delim(col_names = F, show_col_types = FALSE) %>%
    mutate(time = 1)
  covs_v2 <- list.files(
    path = file.path(rand_dir, paste0('seed-', cope, '_ses-V2')),
    pattern = paste0('covs__', comparison, '.txt'),
    full.names = T
  ) %>%
    read_delim(col_names = F, show_col_types = FALSE) %>%
    mutate(time = 2)
  covs_v4 <- list.files(
    path = file.path(rand_dir, paste0('seed-', cope, '_ses-V4')),
    pattern = paste0('covs__', comparison, '.txt'),
    full.names = T
  ) %>%
    read_delim(col_names = F, show_col_types = FALSE) %>%
    mutate(time = 3)

  # Create new design matrix for TIME (0,1,2) x GROUP (0,1) analysis using SwE
  # Alternative 1: Model separate time points for each group
  # Alternative 2: Model average and slope for each group (assumes linear trend of time)
  # A1 has the potential to capture non-linear effects over time, but at the cost of degrees of freedom.
  # A2 has more power to detect linear effects, but cannot capture non-linear effects.
  # Over the 5 years of the study, we expect non-linear effects to be minimal, so A2 is preferred.
  # See https://groups.google.com/g/swe-toolbox/c/YZ-A_hlzHHA
  # https://groups.google.com/g/swe-toolbox/c/ccGc9aMayfA
  covs_all <- bind_rows(covs_v0, covs_v2, covs_v4) %>%
    mutate(
      group = case_when(
        X1 == 1 ~ 1,
        X2 == 1 ~ 2
      ),
      a1_g0t0 = if_else(time == 1 & X1 == 1, 1, 0),
      a1_g0t1 = if_else(time == 2 & X1 == 1, 1, 0),
      a1_g0t2 = if_else(time == 3 & X1 == 1, 1, 0),
      a1_g1t0 = if_else(time == 1 & X2 == 1, 1, 0),
      a1_g1t1 = if_else(time == 2 & X2 == 1, 1, 0),
      a1_g1t2 = if_else(time == 3 & X2 == 1, 1, 0),
      a2_g0avg = if_else(X1 == 1, 1, 0),
      a2_g0t = case_when(
        time == 1 & X1 == 1 ~ -1,
        time == 2 & X1 == 1 ~ 0,
        time == 3 & X1 == 1 ~ 1,
        TRUE ~ 0
      ),
      a2_g1avg = if_else(X2 == 1, 1, 0),
      a2_g1t = case_when(
        time == 1 & X2 == 1 ~ -1,
        time == 2 & X2 == 1 ~ 0,
        time == 3 & X2 == 1 ~ 1,
        TRUE ~ 0
      )
    )
  # Separate continuous covariates
  a1_matrix <- covs_all %>%
    select(starts_with('a1'), X3, X4)
  a2_matrix <- covs_all %>%
    select(starts_with('a2'), X3, X4)

  # Create contrasts
  a1_contrasts_t <- rbind(
    c(1, 0, -1, -1, 0, 1, 0, 0), # g1>g0, t2>t0
    c(0, 1, -1, 0, -1, 1, 0, 0), # g1>g0, t2>t1
    c(1, -1, 0, -1, 1, 0, 0, 0), # g1>g0, t1>t0
    c(-1, 0, 0, 1, 0, 0, 0, 0), # g1>g0 at t0
    c(0, -1, 0, 0, 1, 0, 0, 0), # g1>g0 at t1
    c(0, 0, -1, 0, 0, 1, 0, 0), # g1>g0 at t2
    c(-1, -1, -1, 1, 1, 1, 0, 0), # g1>g0
    c(-1, 1, 0, -1, 1, 0, 0, 0), # t1>t0
    c(-1, 0, 1, -1, 0, 1, 0, 0), # t2>t0
    c(0, -1, 1, 0, -1, 1, 0, 0), # t2>t1
    c(-1, 1, 0, 0, 0, 0, 0, 0), # g0: t1>t0
    c(-1, 0, 1, 0, 0, 0, 0, 0), # g0: t2>t0
    c(0, -1, 1, 0, 0, 0, 0, 0), # g0: t2>t1
    c(0, 0, 0, -1, 1, 0, 0, 0), # g1: t1>t0
    c(0, 0, 0, -1, 0, 1, 0, 0), # g1: t2>t0
    c(0, 0, 0, 0, -1, 1, 0, 0) # g1: t2>t1
  )
  a1_contrasts_f <- rbind(
    c(1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), # Test whether change over time differs between groups
    c(0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), # Test where groups differ at any time point
    c(0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0), # Test for overall group effect
    c(0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0) # Test for overall time effect
  )
  a2_contrasts_t <- rbind(
    c(-1, 0, 1, 0, 0, 0), # g1>g0 avg
    c(1, 0, -1, 0, 0, 0), # g1<g0 avg
    c(0, -1, 0, 1, 0, 0), # g1>g0 slope
    c(0, 1, 0, -1, 0, 0), # g1<g0 slope
    c(1, 0, 0, 0, 0, 0), # g0 avg
    c(0, 1, 0, 0, 0, 0), # g0 slope
    c(0, 0, 1, 0, 0, 0), # g1 avg
    c(0, 0, 0, 1, 0, 0), # g1 slope
    c(-1, 0, 0, 0, 0, 0), # -g0 avg
    c(0, -1, 0, 0, 0, 0), # -g0 slope
    c(0, 0, -1, 0, 0, 0), # -g1 avg
    c(0, 0, 0, -1, 0, 0) # -g1 slope
  )
  a2_contrasts_f <- rbind(
    c(1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), # Test for differences in slopes between groups (equivalent to a1's F1)
    c(0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0) # Test for overall group average effect (equivalent to a1's F2)
  )

  # Create subject design file
  subs <- imgs_all %>%
    str_split('/') %>%
    map_chr(., \(x) x[which(grepl('sub-', x))]) %>%
    str_remove('sub-') %>%
    str_sub(1, 3) %>%
    as.numeric()
  subject_design <- tibble(
    sub = subs,
    visit = covs_all$time,
    group = covs_all$group
  )

  # Write to file
  write_lines(
    imgs_all,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('imgs.txt')
    )
  )
  write_delim(
    a1_matrix,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('a1_covs.txt')
    ),
    col_names = F
  )
  write.table(
    a1_contrasts_t,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('a1_cons_t.txt')
    ),
    col.names = F,
    row.names = F,
    quote = F
  )
  write.table(
    a1_contrasts_f,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('a1_cons_f.txt')
    ),
    col.names = F,
    row.names = F,
    quote = F
  )
  write_delim(
    a2_matrix,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('a2_covs.txt')
    ),
    col_names = F
  )
  write.table(
    a2_contrasts_t,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('a2_cons_t.txt')
    ),
    col.names = F,
    row.names = F,
    quote = F
  )
  write.table(
    a2_contrasts_f,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('a2_cons_f.txt')
    ),
    col.names = F,
    row.names = F,
    quote = F
  )
  write_delim(
    subject_design,
    file.path(
      swe_dir,
      paste0('seed-', cope),
      comparison,
      paste0('sub.txt')
    ),
    col_names = F
  )
}

# Directories and parameters
fc_dir = '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based'
rand_dir = file.path(fc_dir, 'derivatives/randomise')
clin_file = '/home/martin.johansson/ownCloud/ICM_DCCN/data/ICEBERG_mj_2025-09-15.csv'
# Seed choice
seed <- 'striatum'
if (seed == 'striatum') {
  # Striatum
  cope_numbers = c('1', '3', '15') #, '16')
  cope_names = c('PP', 'PA', 'PAsubPP') #, 'PPsubPA')
  featname = 'fsl_granularity2_gs1_v2.feat'
} else if (seed == 'cerebellum') {
  # Cerebellum
  cope_numbers = c('1', '3', '5') #, '6')
  cope_names = c('CB12', 'CB56', 'CB56subCB12') #, 'CB12subCB56')
  featname = 'fsl_cb_gs1.feat'
}
visits = c('ses-V0', 'ses-V2', 'ses-V4')

# Randomise
for (i in 1:length(cope_numbers)) {
  for (j in 1:length((visits))) {
    cope = str_c('cope', cope_numbers[i])
    visit = visits[j]
    output_dir = file.path(rand_dir, paste0('seed-', cope_names[i], '_', visit))
    fsl_randomise_covars_byses(
      fc_dir = fc_dir,
      featname = featname,
      cope = cope,
      clin_file = clin_file,
      visit = visit,
      output_dir = output_dir
    )
  }
}

# SwE
swe_dir = file.path(fc_dir, 'derivatives/swe')
comparisons = list.dirs(
  file.path(rand_dir, str_c('seed-', cope_names[1], '_ses-V0')),
  full.names = F,
  recursive = F
)
comparisons = comparisons[str_detect(comparisons, 'g1-')]
for (i in 1:length(cope_names)) {
  for (j in 1:length(comparisons)) {
    fsl_swe_covars(
      rand_dir = rand_dir,
      swe_dir = swe_dir,
      cope = cope_names[i],
      comparison = comparisons[j]
    )
  }
}
