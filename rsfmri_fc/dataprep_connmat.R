library(tidyverse)
library(R.matlab)
library(reshape2)

qrec_dir <- "/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/qsirecon_1.1.1/derivatives/qsirecon-MRtrix3_act-HSVS"
xcpd_dir <- "/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/data/bids4/derivatives/xcpd_0.11.1"

# Qsirecon connectivity matrix
assemble_struc_conn <- function(fp_qrec_mat) {
  qrec_rois <- c('SomMot', 'PUT', 'Snc_PBP_VTA', 'Snr', 'Region')
  qrec_mat <- readMat(fp_qrec_mat)
  qrec_mat_lab <- unlist(qrec_mat$atlas.CustomSchaefer100.region.labels) %>%
    str_replace_all('-', '_')
  qrec_mat_lab[qrec_mat_lab == "PUT_DA_l"] <- 'PUT_DA_lh'
  qrec_roi_idx <- qrec_mat_lab[grepl(
    paste(qrec_rois, collapse = '|'),
    qrec_mat_lab
  )]
  # 4 options for connectivity matrix:
  # https://osf.io/preprints/osf/c67kn_v1
  # count - number of streamlines connecting each pair of regions
  # meanlength - mean length of streamlines connecting each pair of regions
  # sift - make streamlines proportional to cross-sectional area of fibers
  # invnodevol - scale by the inverse of the mean of the node volumes
  # qrec_conn <- qrec_mat$atlas.CustomSchaefer100.sift.radius2.count.connectivity
  qrec_conn <- qrec_mat$atlas.CustomSchaefer100.sift.invnodevol.radius2.count.connectivity
  # qrec_conn <- qrec_mat$atlas.CustomSchaefer100.radius2.count.connectivity
  # qrec_conn <- qrec_mat$atlas.CustomSchaefer100.radius2.meanlength.connectivity
  colnames(qrec_conn) <- qrec_mat_lab
  rownames(qrec_conn) <- qrec_mat_lab
  qrec_conn[lower.tri(qrec_conn, diag = TRUE)] <- Inf
  qrec_conn <- melt(
    qrec_conn,
    varnames = c('from', 'to'),
    value.name = 'conn'
  ) %>%
    filter(!is.infinite(conn)) %>%
    as_tibble()
  qrec_conn <- qrec_conn %>%
    filter(from %in% qrec_roi_idx & to %in% qrec_roi_idx)
  qrec_conn <- qrec_conn %>%
    mutate(
      from_to = paste0(from, '__', to),
      modality = 'dwi',
      method = 'qsirecon',
      metric = 'sift_count',
    ) %>%
    pivot_wider(
      id_cols = c('modality', 'method', 'metric'),
      names_from = c('from_to'),
      values_from = 'conn'
    )

  # Add subject identifiers
  qrec_conn <- qrec_conn %>%
    mutate(
      num_sujet = str_extract(fp_qrec_mat, 'sub-\\d+'),
      num_sujet = str_remove(num_sujet, 'sub-'),
      visit_num = str_extract(fp_qrec_mat, 'ses-\\w+'),
      visit_num = str_remove(visit_num, 'ses-V')
    ) %>%
    relocate(num_sujet, visit_num)

  return(qrec_conn)
}
subs <- dir(
  qrec_dir,
  pattern = '^sub-[0-9][0-9][0-9][A-Z][A-Z]$',
  recursive = FALSE,
  full.names = FALSE
)
dat_sc <- c()
for (i in 1:length(subs)) {
  sessions <- dir(
    file.path(qrec_dir, subs[i]),
    pattern = '^ses-V[0-9]$',
    recursive = FALSE,
    full.names = FALSE
  )
  for (j in 1:length(sessions)) {
    fp_qrec_mat <- file.path(
      qrec_dir,
      subs[i],
      sessions[j],
      "dwi",
      paste0(subs[i], "_", sessions[j], "_dir-AP_space-ACPC_connectivity.mat")
    )
    if (file.exists(fp_qrec_mat)) {
      cat("Adding:", subs[i], sessions[j], "\n")
      tmp <- assemble_struc_conn(fp_qrec_mat)
      dat_sc <- bind_rows(dat_sc, tmp)
    } else {
      cat("File does not exist:", subs[i], sessions[j], "\n")
    }
  }
}
write_csv(
  dat_sc,
  paste0(
    '/home/martin.johansson/Nextcloud/ICM_DCCN/data/ICEBERG_conn-sc_',
    today(),
    '.csv'
  )
)

# XCP-D functional connectivity matrix
assemble_func_conn <- function(fp_xcpd_ts_schaeffer, fp_xcpd_ts_tian) {
  # XCP-D timeseries
  # Load and prepare timeseries
  ts_schaeffer <- read_delim(fp_xcpd_ts_schaeffer, show_col_types = FALSE)
  ts_schaeffer <- ts_schaeffer %>%
    select(
      contains('SomMot') |
        contains('Snc_PBP_VTA') |
        ends_with('Snr') |
        contains('Cerebellar_Region')
    )
  ts_tian <- read_delim(fp_xcpd_ts_tian, show_col_types = FALSE)
  ts_tian <- ts_tian %>%
    select(starts_with('PUT'))
  ts_all <- bind_cols(ts_schaeffer, ts_tian)
  colnames(ts_all) <- colnames(ts_all) %>% str_replace_all('-', '_')
  colnames(ts_all)[colnames(ts_all) == "PUT_DA_l"] <- 'PUT_DA_lh'
  ts_all <- ts_all %>% mutate(across(everything(), as.numeric))

  # Computing bilateral timeseries to ease subsequent analyses
  ts_all <- ts_all %>%
    mutate(
      SomMot_RH = (RH_SomMot_1 +
        RH_SomMot_2 +
        RH_SomMot_3 +
        RH_SomMot_4 +
        RH_SomMot_5 +
        RH_SomMot_6 +
        RH_SomMot_7 +
        RH_SomMot_8) /
        8,
      SomMot_LH = (LH_SomMot_1 +
        LH_SomMot_2 +
        LH_SomMot_3 +
        LH_SomMot_4 +
        LH_SomMot_5 +
        LH_SomMot_6) /
        6,
      SomMot_bi = (SomMot_LH + SomMot_RH) / 2,
      PUT_DP_bi = (PUT_DP_lh + PUT_DP_rh) / 2,
      PUT_DA_bi = (PUT_DA_lh + PUT_DA_rh) / 2,
      PUT_VP_bi = (PUT_VP_lh + PUT_VP_rh) / 2,
      PUT_VA_bi = (PUT_VA_lh + PUT_VA_rh) / 2,
      PUT_P_bi = (PUT_DP_bi + PUT_VP_bi) / 2,
      PUT_A_bi = (PUT_DA_bi + PUT_VA_bi) / 2,
      SNc_PBP_VTA_bi = (LH_SNc_PBP_VTA + RH_SNc_PBP_VTA) / 2,
      CB12_bi = (Cerebellar_Region1 + Cerebellar_Region2) / 2,
      CB56_bi = (Cerebellar_Region5 + Cerebellar_Region6) / 2
    )

  # Force characters to NA and replace with constant 0. This
  # will conveniently yield an NA result from cor()
  ts_all[is.na(ts_all)] <- 0

  # Compute connectivity matrix
  xcpd_conn <- cor(ts_all, method = 'pearson')
  xcpd_conn[lower.tri(xcpd_conn, diag = TRUE)] <- Inf
  xcpd_conn <- melt(
    xcpd_conn,
    varnames = c('from', 'to'),
    value.name = 'conn'
  ) %>%
    filter(!is.infinite(conn)) %>%
    as_tibble()
  xcpd_conn <- xcpd_conn %>%
    mutate(
      from_to = paste0(from, '__', to),
      modality = 'func',
      method = 'xcpd',
      metric = 'pearson_r'
    ) %>%
    pivot_wider(
      id_cols = c('modality', 'method', 'metric'),
      names_from = c('from_to'),
      values_from = 'conn'
    )

  # Add subject identifiers
  xcpd_conn <- xcpd_conn %>%
    mutate(
      num_sujet = str_extract(fp_xcpd_ts_schaeffer, 'sub-\\d+'),
      num_sujet = str_remove(num_sujet, 'sub-'),
      visit_num = str_extract(fp_xcpd_ts_schaeffer, 'ses-\\w+'),
      visit_num = str_remove(visit_num, 'ses-V')
    ) %>%
    relocate(num_sujet, visit_num)

  return(xcpd_conn)
}
subs <- dir(
  xcpd_dir,
  pattern = '^sub-[0-9][0-9][0-9][A-Z][A-Z]$',
  recursive = FALSE,
  full.names = FALSE
)
dat_fc <- c()
for (i in 1:length(subs)) {
  sessions <- dir(
    file.path(xcpd_dir, subs[i]),
    pattern = '^ses-V[0-9]$',
    recursive = FALSE,
    full.names = FALSE
  )
  for (j in 1:length(sessions)) {
    fp_xcpd_ts_schaeffer <- file.path(
      xcpd_dir,
      subs[i],
      sessions[j],
      "func",
      paste0(
        subs[i],
        '_',
        sessions[j],
        '_task-rest_space-MNI152NLin6Asym_seg-4S156Parcels_stat-mean_timeseries.tsv'
      )
    )
    fp_xcpd_ts_tian <- file.path(
      xcpd_dir,
      subs[i],
      sessions[j],
      "func",
      paste0(
        subs[i],
        '_',
        sessions[j],
        '_task-rest_space-MNI152NLin6Asym_seg-Tian_stat-mean_timeseries.tsv'
      )
    )
    if (file.exists(fp_xcpd_ts_schaeffer) & file.exists(fp_xcpd_ts_tian)) {
      cat("Adding:", subs[i], sessions[j], "\n")
      tmp <- assemble_func_conn(fp_xcpd_ts_schaeffer, fp_xcpd_ts_tian)
      dat_fc <- bind_rows(dat_fc, tmp)
    } else {
      cat("File does not exist:", subs[i], sessions[j], "\n")
    }
  }
}
write_csv(
  dat_fc,
  paste0(
    '/home/martin.johansson/Nextcloud/ICM_DCCN/data/ICEBERG_conn-fc_',
    today(),
    '.csv'
  )
)

# Combine structural and functional connectivity
#dat_conn <- bind_rows(dat_sc, dat_fc)

# Save to file
# write_csv(
#   dat_conn,
#   paste0(
#     '/home/martin.johansson/ownCloud/ICM_DCCN/data/ICEBERG_conn_',
#     today(),
#     '.csv'
#   )
# )
