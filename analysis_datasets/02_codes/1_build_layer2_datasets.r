# ------------------------------------------------------------------
# Project: OSE-DA-NT
# Script: 1_build_layer2_datasets.r
# Purpose: Build standardized Layer 2 datasets from CMRS Stata files
# ------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(haven)
  library(tibble)
})

build_layer2_dataset <- function(
  data,
  disagg_map,
  total_age_values = c("_T", "TOTAL", "ALL", "ALL_AGES", "0_59", "M0T59")
) {
  get_chr <- function(df, col_name) {
    if (col_name %in% names(df)) {
      as.character(df[[col_name]])
    } else {
      rep(NA_character_, nrow(df))
    }
  }

  get_num <- function(df, col_name) {
    if (col_name %in% names(df)) {
      suppressWarnings(as.numeric(df[[col_name]]))
    } else {
      rep(NA_real_, nrow(df))
    }
  }

  required_map_cols <- c(
    "CND_REGEX", "HELIX_SEX", "HELIX_AGE", "HELIX_RESIDENCE",
    "HELIX_WEALTH_QUINTILE", "HELIX_MATERNAL_EDU_LVL"
  )

  missing_map_cols <- setdiff(required_map_cols, names(disagg_map))
  if (length(missing_map_cols) > 0) {
    stop("disagg_map is missing required columns: ", paste(missing_map_cols, collapse = ", "))
  }

  # Build a compact mapping table with explicit analytical dimensions.
  map_prepped <- disagg_map %>%
    transmute(
      DISAGGREGATION_ID = as.character(.data$ID),
      DISAGGREGATION_CODE = as.character(.data$CND_REGEX),
      DISAGGREGATION_LABEL = as.character(.data$`Standard Disaggregations`),
      SEX = na_if(trimws(as.character(.data$HELIX_SEX)), ""),
      AGE = na_if(trimws(as.character(.data$HELIX_AGE)), ""),
      RESIDENCE = na_if(trimws(as.character(.data$HELIX_RESIDENCE)), ""),
      WEALTH = na_if(trimws(as.character(.data$HELIX_WEALTH_QUINTILE)), ""),
      EDUCATION = na_if(trimws(as.character(.data$HELIX_MATERNAL_EDU_LVL)), "")
    )

  duplicated_map_keys <- map_prepped %>%
    count(.data$DISAGGREGATION_ID, name = "n") %>%
    filter(!is.na(.data$DISAGGREGATION_ID), .data$n > 1)

  if (nrow(duplicated_map_keys) > 0) {
    warning(
      "disagg_map contains duplicated DISAGGREGATION_CODE values; using first occurrence for ",
      nrow(duplicated_map_keys),
      " key(s)."
    )

    map_prepped <- map_prepped %>%
      group_by(.data$DISAGGREGATION_ID) %>%
      slice(1L) %>%
      ungroup()
  }

  map_by_id <- map_prepped %>%
    select(.data$DISAGGREGATION_ID, .data$SEX, .data$AGE, .data$RESIDENCE, .data$WEALTH, .data$EDUCATION)

  map_by_code <- map_prepped %>%
    select(DISAGGREGATION_CODE, SEX, AGE, RESIDENCE, WEALTH, EDUCATION) %>%
    filter(!is.na(DISAGGREGATION_CODE), DISAGGREGATION_CODE != "") %>%
    group_by(DISAGGREGATION_CODE) %>%
    slice(1L) %>%
    ungroup()

  map_by_label <- map_prepped %>%
    select(DISAGGREGATION_LABEL, SEX, AGE, RESIDENCE, WEALTH, EDUCATION) %>%
    filter(!is.na(DISAGGREGATION_LABEL), DISAGGREGATION_LABEL != "") %>%
    group_by(DISAGGREGATION_LABEL) %>%
    slice(1L) %>%
    ungroup()

  data_prepped <- data %>%
    mutate(
      disagg_id_key = get_chr(., "standard_disagg"),
      disagg_code_key = get_chr(., "DISAGGREGATION_CODE"),
      disagg_label_key = get_chr(., "StandardDisaggregations"),
      DISAGGREGATION_CODE = coalesce(
        get_chr(., "DISAGGREGATION_CODE"),
        get_chr(., "StandardDisaggregations"),
        get_chr(., "standard_disagg")
      )
    )

  n_input_rows <- nrow(data_prepped)

  out <- data_prepped %>%
    left_join(map_by_id, by = c("disagg_id_key" = "DISAGGREGATION_ID"), suffix = c("", "_id")) %>%
    left_join(map_by_code, by = c("disagg_code_key" = "DISAGGREGATION_CODE"), suffix = c("", "_code")) %>%
    left_join(map_by_label, by = c("disagg_label_key" = "DISAGGREGATION_LABEL"), suffix = c("", "_label")) %>%
    mutate(
      SEX = coalesce(get_chr(., "SEX_id"), get_chr(., "SEX"), get_chr(., "SEX_code"), get_chr(., "SEX_label")),
      AGE = coalesce(get_chr(., "AGE_id"), get_chr(., "AGE"), get_chr(., "AGE_code"), get_chr(., "AGE_label")),
      RESIDENCE = coalesce(get_chr(., "RESIDENCE_id"), get_chr(., "RESIDENCE"), get_chr(., "RESIDENCE_code"), get_chr(., "RESIDENCE_label")),
      WEALTH = coalesce(get_chr(., "WEALTH_id"), get_chr(., "WEALTH"), get_chr(., "WEALTH_code"), get_chr(., "WEALTH_label")),
      EDUCATION = coalesce(get_chr(., "EDUCATION_id"), get_chr(., "EDUCATION"), get_chr(., "EDUCATION_code"), get_chr(., "EDUCATION_label")),
      REF_AREA = coalesce(
        get_chr(., "REF_AREA"),
        get_chr(., "ISO3Code"),
        get_chr(., "CND_Country_Code")
      ),
      TIME_PERIOD = coalesce(
        get_chr(., "TIME_PERIOD"),
        get_chr(., "CMRS_year"),
        get_chr(., "warehouse_year"),
        get_chr(., "middle_year")
      ),
      INDICATOR = coalesce(
        get_chr(., "INDICATOR"),
        get_chr(., "IndicatorCode"),
        get_chr(., "Indicator")
      ),
      VALUE = coalesce(
        get_num(., "VALUE"),
        get_num(., "r"),
        get_num(., "r_raw")
      )
    ) %>%
    select(-any_of(c(
      "SEX_id", "AGE_id", "RESIDENCE_id", "WEALTH_id", "EDUCATION_id",
      "SEX_code", "AGE_code", "RESIDENCE_code", "WEALTH_code", "EDUCATION_code",
      "SEX_label", "AGE_label", "RESIDENCE_label", "WEALTH_label", "EDUCATION_label",
      "disagg_id_key", "disagg_code_key", "disagg_label_key"
    )))

  if (nrow(out) != n_input_rows) {
    stop("Row count changed after join: expected ", n_input_rows, " rows, got ", nrow(out), ".")
  }

  unmapped_codes <- out %>%
    filter(
      !is.na(.data$DISAGGREGATION_CODE),
      is.na(.data$SEX), is.na(.data$AGE), is.na(.data$RESIDENCE),
      is.na(.data$WEALTH), is.na(.data$EDUCATION)
    ) %>%
    distinct(.data$DISAGGREGATION_CODE)

  if (nrow(unmapped_codes) > 0) {
    warning(
      nrow(unmapped_codes),
      " DISAGGREGATION_CODE value(s) were not found in disagg_map. Example: ",
      paste(utils::head(unmapped_codes$DISAGGREGATION_CODE, 20), collapse = ", ")
    )
  }

  # Standardize total-age representations to canonical _T.
  total_age_values_upper <- toupper(total_age_values)

  out <- out %>%
    mutate(
      age_original = .data$AGE,
      AGE = if_else(
        !is.na(.data$AGE) & toupper(.data$AGE) %in% total_age_values_upper,
        "_T",
        .data$AGE
      )
    )

  multi_total_age_indicators <- out %>%
    filter(!is.na(.data$age_original), .data$AGE == "_T") %>%
    group_by(.data$INDICATOR) %>%
    summarise(n_original_age_values = n_distinct(.data$age_original), .groups = "drop") %>%
    filter(.data$n_original_age_values > 1)

  if (nrow(multi_total_age_indicators) > 0) {
    warning(
      "Multiple original AGE values map to _T for ", nrow(multi_total_age_indicators),
      " indicator(s). Example: ",
      paste(utils::head(multi_total_age_indicators$INDICATOR, 10), collapse = ", ")
    )
  }

  out %>%
    select(-.data$age_original) %>%
    relocate(
      any_of(c("REF_AREA", "TIME_PERIOD", "INDICATOR", "SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION", "VALUE")),
      .before = everything()
    ) %>%
    as_tibble()
}

input_cmrs_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard"
disagg_map_path <- "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/reference_data_manager/indicators/reference_disaggregations.csv"
layer2_output_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_datasets"

if (!dir.exists(layer2_output_dir)) {
  dir.create(layer2_output_dir, recursive = TRUE)
}

disagg_map <- read_csv(disagg_map_path, show_col_types = FALSE)

layer2_input_files <- c(
  series_ane = "CMRS_SERIES_ANE.dta",
  series_ant = "CMRS_SERIES_ANT.dta",
  series_dant = "CMRS_SERIES_DANT.dta",
  series_sant = "CMRS_SERIES_SANT.dta",
  series_vas = "CMRS_SERIES_VAS.dta",
  ant = "CMRS_ANT.dta",
  bw = "CMRS_BW.dta",
  iod = "CMRS_IOD.dta",
  iycf = "CMRS_IYCF.dta"
)

for (dataset_name in names(layer2_input_files)) {
  input_path <- file.path(input_cmrs_dir, layer2_input_files[[dataset_name]])

  if (!file.exists(input_path)) {
    warning("Input file not found: ", input_path)
    next
  }

  source_data <- read_dta(input_path)
  layer2_data <- build_layer2_dataset(source_data, disagg_map)

  output_csv <- file.path(layer2_output_dir, paste0("layer2_", dataset_name, ".csv"))
  write_csv(layer2_data, output_csv)

  cat("Layer 2 dataset written:", output_csv, "\n")
}
