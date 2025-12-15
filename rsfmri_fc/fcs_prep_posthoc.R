extract_stats <- function(valsdir, grouping = NULL) {
  library(tidyverse)

  # Find files
  filenames <- list.files(valsdir, pattern = '*avg_agg.txt', full.names = TRUE)

  # Define cleaning function
  clean_file <- function(file, grouping = NULL) {
    # Read file
    contents <- read_delim(file, col_names = FALSE, show_col_types = FALSE)

    # Rearrange contents
    contents <- contents %>%
      mutate(
        subid = str_extract(X1, 'sub-\\d+'),
        subid = str_remove(subid, 'sub-'),
        sessid = str_extract(X1, 'ses-\\w+'),
        sessid = str_remove(sessid, 'ses-V'),
        copeid = str_extract(X1, 'cope\\d+')
      ) %>%
      relocate(subid, sessid, copeid) %>%
      select(-X1)
    colnames(contents)[4:ncol(contents)] <- paste0(
      'clust',
      seq(1, ncol(contents) - 3)
    )

    # Add grouping if provided
    if (!is.null(grouping)) {
      contents <- contents %>%
        left_join(grouping, by = c('subid' = 'num_sujet'))
    } else {
      contents <- contents %>%
        mutate(group = 'all')
    }

    plot_dat <- contents %>%
      pivot_longer(
        cols = starts_with('clust'),
        names_to = 'cluster',
        values_to = 'value'
      )
    g <- plot_dat %>%
      ggplot(aes(x = sessid, y = value, fill = group)) +
      geom_boxplot(alpha = 0.5) +
      theme_bw() +
      labs(
        title = paste0(
          str_extract(file, 'seed-\\w+'),
          '_',
          str_extract(file, 'g0-\\w+_'),
          str_extract(file, 'g1-\\w+_'),
          str_extract(file, 'tstat\\d+')
        ),
        x = 'Timepoint',
        y = 'Value'
      ) +
      facet_wrap(~cluster, scales = 'free_y') +
      scale_fill_viridis_d(option = 'mako', begin = 0.3, end = 0.6)

    # Define new filename
    newfile <- str_replace(file, '_agg.txt', '_agg2.csv')
    newplotfile <- str_replace(file, '_agg.txt', '_agg2.png')
    # Prepare output
    output <- list(
      inputfile = file,
      outputfile = newfile,
      data = contents,
      plot = g,
      plotfile = newplotfile
    )
    # Finish
    return(output)
  }

  # Process files
  files_cleaned <- filenames %>%
    map(\(x) clean_file(x, grouping))

  # Write cleaned files
  dump <- map(files_cleaned, function(x) {
    write_csv(x$data, x$outputfile)
    ggsave(x$plotfile, plot = x$plot, width = 10, height = 6)
  })
}

randomise <- FALSE
if (randomise) {
  analysisdir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/randomise'
  ses <- c('V0', 'V2', 'V4')
} else {
  analysisdir <- '/network/iss/cenir/analyse/irm/users/martin.johansson/iceberg/stats/fc_seed_based/derivatives/swe'
  ses <- c('V0')
}
striatum <- FALSE
if (striatum) {
  seeds <- c('PA', 'PAsubPP', 'PP')
} else {
  seeds <- c('CB12', 'CB56', 'CB56subCB12')
}

grouping <- read_csv(
  '/home/martin.johansson/ownCloud/ICM_DCCN/data/ICEBERG_mj_2025-10-14.csv',
  col_select = c('num_sujet', 'group3'),
  show_col_types = FALSE
) %>%
  group_by(num_sujet) %>%
  summarise(
    group = first(group3, na_rm = TRUE)
  )

for (i in seq_along(seeds)) {
  cat(i, ': ', seeds[i], '\n', sep = '')
  if (randomise) {
    resultsdir <- paste0(analysisdir, '/seed-', seeds[i], '_ses-', ses)
    comparisons <- list.files(resultsdir, full.names = TRUE)
  } else {
    resultsdir <- paste0(analysisdir, '/seed-', seeds[i])
    comparisons <- list.files(resultsdir, full.names = TRUE)
  }
  for (j in seq_along(comparisons)) {
    cat('|_', j, ': ', comparisons[j], '\n', sep = '')
    valsdir <- file.path(
      comparisons[j],
      'vals'
    )
    extract_stats(valsdir, grouping)
  }
}
