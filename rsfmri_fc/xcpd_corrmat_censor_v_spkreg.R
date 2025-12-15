library(tidyverse)
library(ggcorrplot)
library(ggpubr)


SUB <- c('sub-158SM_ses-V0', 'sub-160DM_ses-V2', 'sub-162LJ_ses-V0')
TYPE <- c('censor', 'spkreg')
PARC <- c('4S156Parcels', '4S256Parcels', '4S456Parcels', 'Glasser', 'Tian')

DATDIR <- "~/Documents/work/ICM/data/XCPD"

for (sub in SUB) {
  for (parc in PARC) {
    print(paste0("Processing: ", sub, " - ", parc))
    # Construct the file path
    file_path_01 <- file.path(DATDIR, TYPE[1], paste0(sub, "_task-rest_space-MNI152NLin6Asym_seg-", parc, "_stat-mean_timeseries.tsv"))
    file_path_02 <- file.path(DATDIR, TYPE[2], paste0(sub, "_task-rest_space-MNI152NLin6Asym_seg-", parc, "_stat-mean_timeseries.tsv"))
    
    # Check if the file exists
    if (file.exists(file_path_01)) {
      print(paste0("File found: ", file_path_01))
    } else {
      print(paste0("File not found: ", file_path_01))
    }
    
    # Load
    df_01 <- read_delim(file_path_01, col_names = TRUE, col_types = cols()) %>%
      select(!starts_with('Cerebellar'))
    corrmat_01 <- cor(df_01, method = 'pearson')
    colnames(corrmat_01) <- NULL
    rownames(corrmat_01) <- NULL
    corrplot_01 <- ggcorrplot(corrmat_01,
                              title = paste0("Corrmat: ", TYPE[1]))
    
    df_02 <- read_delim(file_path_02, col_names = TRUE, col_types = cols()) %>%
      select(!starts_with('Cerebellar'))
    corrmat_02 <- cor(df_02, method = 'pearson')
    colnames(corrmat_02) <- NULL
    rownames(corrmat_02) <- NULL
    corrplot_02 <- ggcorrplot(corrmat_02,
                              title = paste0("Corrmat: ", TYPE[2]))
    
    corrmat_diff <- corrmat_01 - corrmat_02
    corrplot_diff <- ggcorrplot(corrmat_diff,
                                title = paste0("Difference: ", TYPE[1], " - ", TYPE[2]))
    
    ggarrange(corrplot_01, corrplot_02, corrplot_diff,
              ncol = 3, nrow = 1,
              common.legend = TRUE, legend = "bottom") %>%
      ggexport(filename = paste0(DATDIR, '/corrmat/', sub, "_", parc, "_corrmat.png"),
               width = 3000, height = 1000)
    
  }
  }
