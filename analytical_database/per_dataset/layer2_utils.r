suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(readr)
  library(haven)
  library(tibble)
})

cmrs_input_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard"
disagg_map_path <- "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/reference_data_manager/indicators/reference_disaggregations.csv"
layer2_output_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_database"

if (!dir.exists(layer2_output_dir)) {
  dir.create(layer2_output_dir, recursive = TRUE)
}

get_chr_col <- function(df, col_name) {
  if (col_name %in% names(df)) {
    as.character(df[[col_name]])
  } else {
    rep(NA_character_, nrow(df))
  }
}

get_num_col <- function(df, col_name) {
  if (col_name %in% names(df)) {
    suppressWarnings(as.numeric(df[[col_name]]))
  } else {
    rep(NA_real_, nrow(df))
  }
}

# ---------------------------------------------------------------------------
# Prepare the disaggregation reference exactly as DW-Production does
# (mirrors 1a_cmrs_prep_reference_disagg_prep.R)
# ---------------------------------------------------------------------------
read_disagg_map <- function(path = disagg_map_path) {
  raw <- readr::read_csv(path, col_types = cols(.default = col_character()), show_col_types = FALSE) %>%
    as_tibble() %>%
    mutate(across(everything(), as.character))

  raw %>%
    mutate(
      HELIX_SEX              = coalesce(.data$HELIX_SEX, ""),
      HELIX_AGE              = coalesce(.data$HELIX_AGE, ""),
      HELIX_WEALTH_QUINTILE  = coalesce(.data$HELIX_WEALTH_QUINTILE, ""),
      HELIX_RESIDENCE        = coalesce(.data$HELIX_RESIDENCE, ""),
      HELIX_MATERNAL_EDU_LVL = coalesce(.data$HELIX_MATERNAL_EDU_LVL, ""),
      HELIX_HEAD_OF_HOUSE    = if ("HELIX_HEAD_OF_HOUSE" %in% names(.)) coalesce(.data$HELIX_HEAD_OF_HOUSE, "") else "",
      HELIX_CODE = paste0(
        .data$HELIX_SEX, "|", .data$HELIX_AGE, "|", .data$HELIX_WEALTH_QUINTILE, "|",
        .data$HELIX_RESIDENCE, "|", .data$HELIX_MATERNAL_EDU_LVL, "|", .data$HELIX_HEAD_OF_HOUSE
      ),
      standard_disagg_key = str_trim(coalesce(.data$ID, ""))
    ) %>%
    filter(.data$HELIX_CODE != "|||||") %>%
    filter(!is.na(.data$standard_disagg_key), .data$standard_disagg_key != "") %>%
    distinct()
}

# ---------------------------------------------------------------------------
# Build Layer 2 dataset — follows DW-Production join & dimension logic
# (mirrors 1b–1f import scripts)
# ---------------------------------------------------------------------------
build_layer2_dataset <- function(data, disagg_map) {

  # Prepare the join-ready reference (keep only needed cols, deduplicate by key)
  disagg_ref <- disagg_map %>%
    transmute(
      standard_disagg_key = .data$standard_disagg_key,
      HELIX_SEX              = .data$HELIX_SEX,
      HELIX_AGE              = .data$HELIX_AGE,
      HELIX_WEALTH_QUINTILE  = .data$HELIX_WEALTH_QUINTILE,
      HELIX_RESIDENCE        = .data$HELIX_RESIDENCE,
      HELIX_MATERNAL_EDU_LVL = .data$HELIX_MATERNAL_EDU_LVL,
      HELIX_HEAD_OF_HOUSE    = .data$HELIX_HEAD_OF_HOUSE
    ) %>%
    distinct(.data$standard_disagg_key, .keep_all = TRUE)

  n_input_rows <- nrow(data)

  # Join on numeric ID (standard_disagg → map ID), matching DW-Production
  out <- data %>%
    mutate(across(everything(), as.character)) %>%
    mutate(standard_disagg_key = str_trim(coalesce(get_chr_col(., "standard_disagg"), ""))) %>%
    left_join(disagg_ref, by = "standard_disagg_key")

  if (nrow(out) != n_input_rows) {
    stop("Row count changed after mapping join: expected ", n_input_rows, " rows, got ", nrow(out), ".")
  }

  # Track which rows matched the disagg reference (at least one HELIX field non-empty)
  out <- out %>%
    mutate(
      HELIX_SEX              = coalesce(.data$HELIX_SEX, ""),
      HELIX_AGE              = coalesce(.data$HELIX_AGE, ""),
      HELIX_WEALTH_QUINTILE  = coalesce(.data$HELIX_WEALTH_QUINTILE, ""),
      HELIX_RESIDENCE        = coalesce(.data$HELIX_RESIDENCE, ""),
      HELIX_MATERNAL_EDU_LVL = coalesce(.data$HELIX_MATERNAL_EDU_LVL, ""),
      HELIX_HEAD_OF_HOUSE    = coalesce(.data$HELIX_HEAD_OF_HOUSE, ""),
      disagg_ref_match = (
        .data$HELIX_SEX != "" | .data$HELIX_AGE != "" |
        .data$HELIX_WEALTH_QUINTILE != "" | .data$HELIX_RESIDENCE != "" |
        .data$HELIX_MATERNAL_EDU_LVL != "" | .data$HELIX_HEAD_OF_HOUSE != ""
      )
    )

  message(
    "Rows matched to disagg reference: ",
    sum(out$disagg_ref_match, na.rm = TRUE), " of ", nrow(out)
  )

  # Assign dimension columns — default to "_T" when field is empty, matching DW-Production
  out <- out %>%
    mutate(
      SEX       = if_else(.data$HELIX_SEX != "",              .data$HELIX_SEX, "_T"),
      AGE       = if_else(.data$HELIX_AGE != "",              .data$HELIX_AGE, "_T"),
      RESIDENCE = if_else(.data$HELIX_RESIDENCE != "",        .data$HELIX_RESIDENCE, "_T"),
      WEALTH    = if_else(.data$HELIX_WEALTH_QUINTILE != "",  .data$HELIX_WEALTH_QUINTILE, "_T"),
      EDUCATION = if_else(.data$HELIX_MATERNAL_EDU_LVL != "", .data$HELIX_MATERNAL_EDU_LVL, "_T"),
      REF_AREA    = coalesce(get_chr_col(., "REF_AREA"), get_chr_col(., "ISO3Code"), get_chr_col(., "CND_Country_Code")),
      TIME_PERIOD = coalesce(get_chr_col(., "TIME_PERIOD"), get_chr_col(., "CMRS_year"), get_chr_col(., "warehouse_year"), get_chr_col(., "middle_year")),
      INDICATOR   = coalesce(get_chr_col(., "INDICATOR"), get_chr_col(., "IndicatorCode"), get_chr_col(., "Indicator")),
      VALUE       = coalesce(get_num_col(., "VALUE"), get_num_col(., "r"), get_num_col(., "r_raw"))
    )

  out %>%
    select(-any_of(c(
      "standard_disagg_key", "disagg_ref_match",
      "HELIX_SEX", "HELIX_AGE", "HELIX_WEALTH_QUINTILE",
      "HELIX_RESIDENCE", "HELIX_MATERNAL_EDU_LVL", "HELIX_HEAD_OF_HOUSE",
      "HELIX_CODE"
    ))) %>%
    relocate(any_of(c("REF_AREA", "TIME_PERIOD", "INDICATOR", "SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION", "VALUE")), .before = everything()) %>%
    as_tibble()
}

run_single_dataset <- function(dataset_file, output_file) {
  disagg_map <- read_disagg_map()
  source_data <- haven::read_dta(file.path(cmrs_input_dir, dataset_file))
  layer2 <- build_layer2_dataset(source_data, disagg_map)
  output_path <- file.path(layer2_output_dir, output_file)
  readr::write_csv(layer2, output_path)
  message("Wrote: ", output_path)
  invisible(layer2)
}
