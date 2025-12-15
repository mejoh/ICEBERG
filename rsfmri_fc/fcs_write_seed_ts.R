library(tidyverse)

# Function to generate seed-based time series from xcpd output
generate_seed_ts <- function(
  xcpd_dir = NULL,
  fmriprep_dir = NULL,
  output_dir = NULL,
  sub = NULL,
  ses = NULL,
  global_signal = TRUE,
  n_dummy = 5,
  censor = TRUE
) {
  # Specify time series data
  ts_file <- file.path(
    xcpd_dir,
    sub,
    ses,
    'func',
    paste0(
      sub,
      '_',
      ses,
      '_task-rest_space-MNI152NLin6Asym_seg-Tian_stat-mean_timeseries.tsv'
    )
  )
  ts_file2 <- file.path(
    xcpd_dir,
    sub,
    ses,
    'func',
    paste0(
      sub,
      '_',
      ses,
      '_task-rest_space-MNI152NLin6Asym_seg-4S156Parcels_stat-mean_timeseries.tsv'
    )
  )

  # Specify global signal and motion outlier files if required
  if (global_signal) {
    gs_file <- file.path(
      fmriprep_dir,
      sub,
      ses,
      'func',
      paste0(sub, '_', ses, '_task-rest_desc-confounds_timeseries.tsv')
    )
    mo_file <- file.path(
      xcpd_dir,
      sub,
      ses,
      'func',
      paste0(sub, '_', ses, '_task-rest_outliers.tsv')
    )
  }

  # Read and time series data
  ts <- read_tsv(ts_file, col_names = TRUE, show_col_types = FALSE)
  ts2 <- read_tsv(ts_file2, col_names = TRUE, show_col_types = FALSE) %>%
    select(matches('Cerebellar_Region[1,2,5,6]$'), contains('SNc_PBP_VTA'))
  ts <- bind_cols(ts, ts2)
  # Fix column names
  colnames(ts) <- str_replace_all(colnames(ts), '-', '_')
  # Fix error in naming of PUT_DA_lh
  ts <- ts %>%
    rename(
      PUT_DA_lh = PUT_DA_l,
      SNc_PBP_VTA_rh = RH_SNc_PBP_VTA,
      SNc_PBP_VTA_lh = LH_SNc_PBP_VTA
    )
  # Select columns of interest and compute averages for bilateral and anterior/posterior regions
  # Averages are based on Fig 4A in Tian et al. (2020) Nat Neu
  ts <- ts %>%
    select(
      starts_with('PUT'),
      starts_with('CAU'),
      starts_with('NAc'),
      contains('Cerebellar_Region'),
      contains('SNc_PBP_VTA')
    )
  # If NAs are present, skip ahead. NOTE: The more regions you add, the more likely this is to happen.
  check_na <- sapply(ts, is.numeric) %>% all()
  if (!check_na) {
    cat(paste0(
      '>>> ERROR: Non-numeric values found in a time series file ',
      ts_file
    ))
    print(check_na)
    stop()
  }
  ts <- ts %>%
    mutate(
      PUT_A_lh = (PUT_VA_lh + PUT_DA_lh) / 2,
      PUT_P_lh = (PUT_VP_lh + PUT_DP_lh) / 2,
      PUT_lh = (PUT_A_lh + PUT_P_lh) / 2,
      PUT_A_rh = (PUT_VA_rh + PUT_DA_rh) / 2,
      PUT_P_rh = (PUT_VP_rh + PUT_DP_rh) / 2,
      PUT_rh = (PUT_A_rh + PUT_P_rh) / 2
    ) %>%
    mutate(
      CAU_A_lh = (CAU_VA_lh + CAU_DA_lh) / 2,
      CAU_P_lh = (CAU_body_lh + CAU_tail_lh) / 2,
      CAU_lh = (CAU_A_lh + CAU_P_lh) / 2,
      CAU_A_rh = (CAU_VA_rh + CAU_DA_rh) / 2,
      CAU_P_rh = (CAU_body_rh + CAU_tail_rh) / 2,
      CAU_rh = (CAU_A_rh + CAU_P_rh) / 2
    ) %>%
    mutate(
      PUT_VA_bi = (PUT_VA_rh + PUT_VA_lh) / 2,
      PUT_VP_bi = (PUT_VP_rh + PUT_VP_lh) / 2,
      PUT_DA_bi = (PUT_DA_rh + PUT_DA_lh) / 2,
      PUT_DP_bi = (PUT_DP_rh + PUT_DP_lh) / 2,
      PUT_A_bi = (PUT_A_rh + PUT_A_lh) / 2,
      PUT_P_bi = (PUT_P_rh + PUT_P_lh) / 2,
      PUT_bi = (PUT_rh + PUT_lh) / 2
    ) %>%
    mutate(
      CAU_VA_bi = (CAU_VA_rh + CAU_VA_lh) / 2,
      CAU_DA_bi = (CAU_DA_rh + CAU_DA_lh) / 2,
      CAU_body_bi = (CAU_body_rh + CAU_body_lh) / 2,
      CAU_tail_bi = (CAU_tail_rh + CAU_tail_lh) / 2,
      CAU_A_bi = (CAU_A_lh + CAU_A_rh) / 2,
      CAU_P_bi = (CAU_P_lh + CAU_P_rh) / 2,
      CAU_bi = (CAU_A_bi + CAU_P_bi) / 2
    ) %>%
    mutate(
      NAc_lh = (NAc_shell_lh + NAc_core_lh) / 2,
      NAc_rh = (NAc_shell_rh + NAc_core_rh) / 2,
      NAc_bi = (NAc_lh + NAc_rh) / 2
    ) %>%
    mutate(
      Cerebellar_Region12_bi = (Cerebellar_Region1 + Cerebellar_Region2) / 2,
      Cerebellar_Region56_bi = (Cerebellar_Region5 + Cerebellar_Region6) / 2,
      SNc_PBP_VTA_bi = (SNc_PBP_VTA_rh + SNc_PBP_VTA_lh) / 2
    )

  regressors <- c(
    'PUT_lh',
    'PUT_rh',
    'PUT_bi',
    'CAU_lh',
    'CAU_rh',
    'CAU_bi',
    'PUT_A_lh',
    'PUT_P_lh',
    'PUT_A_rh',
    'PUT_P_rh',
    'PUT_A_bi',
    'PUT_P_bi',
    'CAU_A_lh',
    'CAU_P_lh',
    'CAU_A_rh',
    'CAU_P_rh',
    'CAU_A_bi',
    'CAU_P_bi',
    'PUT_VA_lh',
    'PUT_VP_lh',
    'PUT_DA_lh',
    'PUT_DP_lh',
    'PUT_VA_rh',
    'PUT_VP_rh',
    'PUT_DA_rh',
    'PUT_DP_rh',
    'PUT_VA_bi',
    'PUT_VP_bi',
    'PUT_DA_bi',
    'PUT_DP_bi',
    'CAU_VA_lh',
    'CAU_DA_lh',
    'CAU_body_lh',
    'CAU_tail_lh',
    'CAU_VA_rh',
    'CAU_DA_rh',
    'CAU_body_rh',
    'CAU_tail_rh',
    'CAU_VA_bi',
    'CAU_DA_bi',
    'CAU_body_bi',
    'CAU_tail_bi',
    'NAc_lh',
    'NAc_rh',
    'NAc_bi',
    'Cerebellar_Region1',
    'Cerebellar_Region2',
    'Cerebellar_Region5',
    'Cerebellar_Region6',
    'Cerebellar_Region12_bi',
    'Cerebellar_Region56_bi',
    'SNc_PBP_VTA_rh',
    'SNc_PBP_VTA_lh',
    'SNc_PBP_VTA_bi'
  )

  # If a global signal file is provided, read and process it
  if (global_signal) {
    # Load global signal data
    gs <- read_tsv(gs_file, col_names = TRUE, show_col_types = FALSE) %>%
      select('global_signal')
    mo <- read_tsv(mo_file, col_names = TRUE, show_col_types = FALSE)
    # Remove dummy scans from global signal
    gs <- gs %>%
      slice(n_dummy + 1:n())
    # Remove time points marked as outliers
    if (censor) {
      gs <- gs %>%
        bind_cols(mo) %>%
        filter(framewise_displacement == 0) %>%
        select(global_signal)
    }
    # Add global signal to the time series data
    ts <- ts %>%
      bind_cols(gs)

    regressors <- c(regressors, 'global_signal')
  }

  # Demean and round the time series data
  ts <- ts %>%
    mutate(
      across(
        everything(),
        ~ scale(., center = TRUE, scale = FALSE) %>% as.vector
      ),
      across(everything(), ~ round(., 6))
    )

  # Write the processed time series data to CSV files
  timeseries_dir <- file.path(output_dir, sub, ses, 'timeseries')
  #if (dir.exists(timeseries_dir)) {
  #  unlink(timeseries_dir, recursive = TRUE)
  #}
  dir.create(timeseries_dir, recursive = TRUE, showWarnings = FALSE)

  for (i in 1:length(regressors)) {
    print(paste0(
      '>>> ',
      sub,
      ', ',
      ses,
      ': ',
      'regressor ',
      i,
      ', ',
      regressors[i]
    ))
    fname <- file.path(timeseries_dir, paste0('ts_', regressors[i], '.csv'))
    ts %>%
      select(all_of(regressors[i])) %>%
      write_csv(fname, col_names = FALSE)
  }
  print(paste0('>>> ', sub, ', ', ses, ': writing compiled time series file'))
  fname <- file.path(timeseries_dir, paste0('ts_all.csv'))
  ts %>%
    write_csv(fname, col_names = TRUE)
}

# Directories
xcpd_dir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/xcpd_0.11.1'
fmriprep_dir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/fmriprep_25.1.3'
output_dir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based'

# Subjects
subs <- list.dirs(xcpd_dir, full.names = FALSE, recursive = FALSE)
subs <- subs[str_detect(subs, '^sub-')]

# Loop over subjects and sessions to generate seed-based time series
for (i in 1:length(subs)) {
  sub <- subs[i]
  sessions <- list.dirs(
    file.path(xcpd_dir, sub),
    full.names = FALSE,
    recursive = FALSE
  )
  sessions <- sessions[str_detect(sessions, '^ses-')]
  for (j in 1:length(sessions)) {
    ses <- sessions[j]
    try(generate_seed_ts(
      xcpd_dir,
      fmriprep_dir,
      output_dir,
      sub,
      ses,
      global_signal = TRUE,
      n_dummy = 5,
      censor = TRUE
    ))
  }
}
