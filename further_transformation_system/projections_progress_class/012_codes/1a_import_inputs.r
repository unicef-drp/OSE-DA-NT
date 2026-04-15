#------------------------------------------------------------------------------
# Build NT projection inputs
# - Country series inputs: analysis_datasets `cmrs2_series_accepted.parquet`
#   (includes BW_LBW modelled series)
# - Country non-series inputs: analysis_datasets `cmrs2_ant_accepted.parquet`,
#   `cmrs2_iycf_accepted.parquet`
# - Regional inputs: DW-Production regional aggregation outputs from `2b`–`2j`
#------------------------------------------------------------------------------

if (!exists("outputdir_projections")) {
  stop("outputdir_projections is not defined. Run from 1_execute.r or define paths first.")
}
if (!exists("interdir")) {
  stop("interdir is not defined. Run from 1_execute.r or define paths first.")
}
if (!exists("analysisDatasetsInputDir")) {
  stop("analysisDatasetsInputDir is not defined. Run from 1_execute.r or define paths first.")
}

outputdir_projections_input <- file.path(outputdir_projections, "input")
dir.create(outputdir_projections_input, recursive = TRUE, showWarnings = FALSE)

projection_input_dir <- file.path(outputdir_projections, "projection_input")
dir.create(projection_input_dir, recursive = TRUE, showWarnings = FALSE)

if (!exists("read_csv_all_char", mode = "function") ||
    !exists("normalize_missing", mode = "function") ||
    !exists("assert_file_exists", mode = "function")) {
  nt_functions_path <- if (exists("projectFolder")) {
    file.path(projectFolder, "01_dw_prep", "012_codes", "nt", "00_nt_functions.R")
  } else {
    NA_character_
  }

  if (!is.na(nt_functions_path) && file.exists(nt_functions_path)) {
    source(nt_functions_path)
  }
}

if (!exists("normalize_missing", mode = "function")) {
  normalize_missing <- function(x) {
    x <- trimws(as.character(x))
    x[x %in% c("", ".", "NA", "N/A", "NULL")] <- NA_character_
    x
  }
}

if (!exists("read_csv_all_char", mode = "function")) {
  read_csv_all_char <- function(path) {
    readr::read_csv(path, show_col_types = FALSE) %>%
      dplyr::mutate(dplyr::across(dplyr::everything(), as.character))
  }
}

if (!exists("assert_file_exists", mode = "function")) {
  assert_file_exists <- function(path, label = basename(path)) {
    if (!file.exists(path)) {
      stop(
        "Required file missing: ", label, " at ", path,
        ". Run the main NT production pipeline first.",
        call. = FALSE
      )
    }
    invisible(path)
  }
}

# Country-level inputs from analysis_datasets (parquet)
country_series_path <- file.path(analysisDatasetsInputDir, "cmrs2_series_accepted.parquet")
country_ant_path <- file.path(analysisDatasetsInputDir, "cmrs2_ant_accepted.parquet")
country_iycf_path <- file.path(analysisDatasetsInputDir, "cmrs2_iycf_accepted.parquet")

# Regional inputs and crosswalks still from DW-Production
groups_path <- file.path(interdir, "groups_for_agg.csv")
regional_overweight_path <- file.path(interdir, "agg_indicator", "Regional_Output_NT_ANT_WHZ_PO2_MOD.xlsx")
regional_anemia_path <- file.path(interdir, "agg_indicator", "Regional_Output_NT_ANE_WOM_15_49_MOD.xlsx")
regional_stunting_path <- file.path(interdir, "agg_indicator", "Regional_Output_NT_ANT_HAZ_NE2_MOD.xlsx")
regional_lbw_path <- file.path(interdir, "agg_indicator", "Regional_Output_NT_BW_LBW.xlsx")
regional_wasting_path <- file.path(interdir, "agg_domain", "agg_ant_wasting.csv")

for (path in c(
  country_series_path,
  country_ant_path,
  country_iycf_path,
  groups_path,
  regional_overweight_path,
  regional_anemia_path,
  regional_stunting_path,
  regional_lbw_path,
  regional_wasting_path
)) {
  assert_file_exists(path, basename(path))
}

projection_indicator_labels <- c(
  NT_ANT_WHZ_PO2_MOD = "Overweight prevalence (weight-for-height > +2 SD)",
  NT_ANE_WOM_15_49_MOD = "Anemia prevalence in women aged 15-49 years",
  NT_ANT_WHZ_NE2 = "Wasting prevalence (weight-for-height <-2 SD)",
  NT_ANT_HAZ_NE2_MOD = "Stunting prevalence (height-for-age <-2 SD)",
  NT_BW_LBW = "Low birth weight prevalence",
  NT_BF_EXBF = "Exclusive breastfeeding (0-5 months)"
)

# The analysis_datasets parquets standardise AGE to "_T" for the widest
# applicable age range of each indicator.  All downstream scripts must
# filter on AGE == "_T" rather than indicator-specific codes.
projection_indicator_age <- c(
  NT_ANT_WHZ_PO2_MOD = "_T",
  NT_ANE_WOM_15_49_MOD = "_T",
  NT_ANT_WHZ_NE2 = "_T",
  NT_ANT_HAZ_NE2_MOD = "_T",
  NT_BW_LBW = "_T",
  NT_BF_EXBF = "_T"
)

coalesce_existing_cols <- function(data, candidates, default = NA_character_) {
  values <- lapply(candidates, function(col_name) {
    if (col_name %in% names(data)) {
      as.character(data[[col_name]])
    } else {
      rep(NA_character_, nrow(data))
    }
  })

  out <- if (length(values) > 0) {
    Reduce(dplyr::coalesce, values)
  } else {
    rep(NA_character_, nrow(data))
  }

  if (length(default) == 1) {
    default <- rep(default, nrow(data))
  }

  dplyr::coalesce(out, as.character(default))
}

standardize_projection_rows <- function(data) {
  # Parquet values are converted to percent in read_analysis_parquet_as_char().
  # Regional aggregation outputs and the LBW series CSV are already on the
  # percent scale (0-100). No rescaling is needed here.

  desired_cols <- c(
    "IndicatorCode", "Indicator", "REF_AREA", "Geographic area", "REPORTING_LVL",
    "SEX", "AGE", "WEALTH_QUINTILE", "RESIDENCE", "MATERNAL_EDU_LVL", "HEAD_OF_HOUSE",
    "TIME_PERIOD", "OBS_VALUE", "DATA_SOURCE", "DATA_SOURCE_PRIORITY", "OBS_STATUS", "OBS_CONF",
    "LOWER_BOUND", "UPPER_BOUND", "OBS_FOOTNOTE", "SERIES_FOOTNOTE", "SOURCE_LINK", "CUSTODIAN",
    "INPUT_SOURCE"
  )

  data %>%
    mutate(across(where(is.character), normalize_missing)) %>%
    mutate(
      REPORTING_LVL = case_when(
        REPORTING_LVL %in% c("Country", "C") ~ "C",
        REPORTING_LVL %in% c("Regional", "R") ~ "R",
        REPORTING_LVL %in% c("Global", "G") ~ "G",
        TRUE ~ coalesce(REPORTING_LVL, "C")
      ),
      DATA_SOURCE_PRIORITY = if_else(
        !is.na(DATA_SOURCE_PRIORITY) & trimws(DATA_SOURCE_PRIORITY) != "",
        DATA_SOURCE_PRIORITY,
        if_else(REPORTING_LVL == "C", "1", NA_character_)
      ),
      TIME_PERIOD = as.character(suppressWarnings(as.integer(TIME_PERIOD))),
      OBS_VALUE = as.character(suppressWarnings(as.numeric(OBS_VALUE))),
      LOWER_BOUND = as.character(suppressWarnings(as.numeric(LOWER_BOUND))),
      UPPER_BOUND = as.character(suppressWarnings(as.numeric(UPPER_BOUND)))
    ) %>%
    filter(!is.na(REF_AREA), REF_AREA != "", !is.na(TIME_PERIOD), !is.na(OBS_VALUE)) %>%
    select(any_of(desired_cols))
}

# Read analysis_datasets parquet files, mapping columns to projection format.
# Parquet indicator codes omit the NT_ prefix used by the downstream pipeline,
# so we prepend it here. Values are stored as proportions (0-1) and must be
# converted to percent (0-100) to match the scale the rest of the pipeline expects.
# When `indicators` is supplied (bare codes without NT_ prefix), arrow filters
# at the file level via predicate pushdown, avoiding loading the full parquet.
# Only the columns needed downstream are selected, skipping 60+ unused columns.
parquet_keep_cols <- c(
  "IndicatorCode", "REF_AREA", "TIME_PERIOD", "SEX", "AGE",
  "RESIDENCE", "WEALTH", "EDUCATION", "HEAD_OF_HOUSEHOLD",
  "r", "ll", "ul",
  "CountryName", "DataSourceDecision", "DATA_SOURCE_PRIORITY",
  "Subnational_Status"
)

read_analysis_parquet_as_char <- function(path, indicators = NULL) {
  ds <- arrow::open_dataset(path)

  if (!is.null(indicators)) {
    ds <- ds %>% dplyr::filter(IndicatorCode %in% indicators)
  }

  df <- ds %>%
    dplyr::select(dplyr::any_of(parquet_keep_cols)) %>%
    dplyr::collect()

  # Keep national-level rows only (Subnational_Status == "0" or NA).
  # Sub-national estimates must be excluded for the projections pipeline.
  # Series data has Subnational_Status = NA (all national), so NA is kept.
  if ("Subnational_Status" %in% names(df)) {
    df <- df %>% dplyr::filter(is.na(Subnational_Status) | as.character(Subnational_Status) == "0")
  }

  df <- df %>%
    dplyr::rename_with(
      ~ dplyr::case_when(
        . == "r" ~ "OBS_VALUE",
        . == "WEALTH" ~ "WEALTH_QUINTILE",
        . == "EDUCATION" ~ "MATERNAL_EDU_LVL",
        . == "HEAD_OF_HOUSEHOLD" ~ "HEAD_OF_HOUSE",
        . == "ll" ~ "LOWER_BOUND",
        . == "ul" ~ "UPPER_BOUND",
        TRUE ~ .
      )
    )

  # Convert proportion columns to percent
  for (col in c("OBS_VALUE", "LOWER_BOUND", "UPPER_BOUND")) {
    if (col %in% names(df)) {
      df[[col]] <- as.numeric(df[[col]]) * 100
    }
  }

  df %>%
    dplyr::mutate(
      IndicatorCode = paste0("NT_", IndicatorCode),
      REPORTING_LVL = "C",
      dplyr::across(dplyr::everything(), as.character)
    )
}

# Series indicators needed (bare codes, without NT_ prefix)
series_indicators <- c("ANT_WHZ_PO2_MOD", "ANE_WOM_15_49_MOD", "ANT_HAZ_NE2_MOD", "BW_LBW")
country_series_raw <- read_analysis_parquet_as_char(country_series_path, indicators = series_indicators)

# Anemia indicator (ANE_WOM_15_49_MOD) uses SEX = "F" in the parquet because
# the target population is women 15-49.  Remap to "_T" so downstream filters
# that check SEX == "_T" retain these rows.
country_series_raw <- country_series_raw %>%
  dplyr::mutate(SEX = dplyr::if_else(IndicatorCode == "NT_ANE_WOM_15_49_MOD" & SEX == "F", "_T", SEX))

country_non_series_raw <- dplyr::bind_rows(
  read_analysis_parquet_as_char(country_ant_path, indicators = "ANT_WHZ_NE2"),
  read_analysis_parquet_as_char(country_iycf_path, indicators = "BF_EXBF")
)
groups_for_agg <- read_csv_all_char(groups_path)

# Remove confidential rows that are only intended for aggregation, not public use.
if ("DataSourceDecision" %in% names(country_series_raw)) {
  country_series_raw <- country_series_raw %>%
    filter(is.na(DataSourceDecision) | DataSourceDecision != "Accepted and Confidential")
}

groups_lookup <- groups_for_agg %>%
  mutate(
    REF_AREA = coalesce_existing_cols(., c("Region_Code", "REF_AREA")),
    regional_name = coalesce_existing_cols(., c("Region", "Class", "REF_AREA"))
  ) %>%
  transmute(REF_AREA, regional_name) %>%
  filter(!is.na(REF_AREA), REF_AREA != "") %>%
  distinct()

country_series <- country_series_raw %>%
  filter(IndicatorCode %in% c("NT_ANT_WHZ_PO2_MOD", "NT_ANE_WOM_15_49_MOD", "NT_ANT_HAZ_NE2_MOD", "NT_BW_LBW")) %>%
  mutate(
    IndicatorCode = as.character(IndicatorCode),
    Indicator = coalesce_existing_cols(., c("Indicator", "INDICATOR_NAME"), projection_indicator_labels[IndicatorCode]),
    REF_AREA = coalesce_existing_cols(., c("REF_AREA")),
    `Geographic area` = coalesce_existing_cols(., c("Geographic area", "GEOGRAPHIC_AREA", "COUNTRY_NAME", "CountryName", "Country"), REF_AREA),
    REPORTING_LVL = coalesce_existing_cols(., c("REPORTING_LVL"), "C"),
    SEX = coalesce_existing_cols(., c("SEX"), "_T"),
    AGE = coalesce_existing_cols(., c("AGE"), unname(projection_indicator_age[IndicatorCode])),
    WEALTH_QUINTILE = coalesce_existing_cols(., c("WEALTH_QUINTILE"), "_T"),
    RESIDENCE = coalesce_existing_cols(., c("RESIDENCE"), "_T"),
    MATERNAL_EDU_LVL = coalesce_existing_cols(., c("MATERNAL_EDU_LVL"), "_T"),
    HEAD_OF_HOUSE = coalesce_existing_cols(., c("HEAD_OF_HOUSE"), "_T"),
    TIME_PERIOD = coalesce_existing_cols(., c("TIME_PERIOD")),
    OBS_VALUE = coalesce_existing_cols(., c("OBS_VALUE")),
    DATA_SOURCE = coalesce_existing_cols(., c("DATA_SOURCE"), "CMRS series"),
    DATA_SOURCE_PRIORITY = coalesce_existing_cols(., c("DATA_SOURCE_PRIORITY"), "1"),
    OBS_STATUS = coalesce_existing_cols(., c("OBS_STATUS"), "F"),
    OBS_CONF = coalesce_existing_cols(., c("OBS_CONF"), NA_character_),
    LOWER_BOUND = coalesce_existing_cols(., c("LOWER_BOUND"), NA_character_),
    UPPER_BOUND = coalesce_existing_cols(., c("UPPER_BOUND"), NA_character_),
    OBS_FOOTNOTE = coalesce_existing_cols(., c("OBS_FOOTNOTE", "SERIES_FOOTNOTE"), NA_character_),
    SERIES_FOOTNOTE = coalesce_existing_cols(., c("SERIES_FOOTNOTE", "OBS_FOOTNOTE"), NA_character_),
    SOURCE_LINK = coalesce_existing_cols(., c("SOURCE_LINK"), NA_character_),
    CUSTODIAN = coalesce_existing_cols(., c("CUSTODIAN"), "UNICEF"),
    INPUT_SOURCE = "2a_country_series_for_agg"
  ) %>%
  filter(
    REPORTING_LVL %in% c("C", "Country"),
    SEX == "_T",
    WEALTH_QUINTILE == "_T",
    RESIDENCE == "_T",
    MATERNAL_EDU_LVL == "_T",
    HEAD_OF_HOUSE == "_T",
    AGE == "_T"
  ) %>%
  # Hardcoded exclusion: BHR overweight should not be included in projections outputs.
  filter(!(IndicatorCode == "NT_ANT_WHZ_PO2_MOD" & REF_AREA == "BHR")) %>%
  standardize_projection_rows()

country_non_series <- country_non_series_raw %>%
  filter(IndicatorCode %in% c("NT_ANT_WHZ_NE2", "NT_BF_EXBF")) %>%
  mutate(
    IndicatorCode = as.character(IndicatorCode),
    Indicator = coalesce_existing_cols(., c("Indicator", "INDICATOR_NAME"), projection_indicator_labels[IndicatorCode]),
    REF_AREA = coalesce_existing_cols(., c("REF_AREA")),
    `Geographic area` = coalesce_existing_cols(., c("Geographic area", "GEOGRAPHIC_AREA", "COUNTRY_NAME", "CountryName", "Country"), REF_AREA),
    REPORTING_LVL = coalesce_existing_cols(., c("REPORTING_LVL"), "C"),
    SEX = coalesce_existing_cols(., c("SEX"), "_T"),
    AGE = coalesce_existing_cols(., c("AGE"), unname(projection_indicator_age[IndicatorCode])),
    WEALTH_QUINTILE = coalesce_existing_cols(., c("WEALTH_QUINTILE"), "_T"),
    RESIDENCE = coalesce_existing_cols(., c("RESIDENCE"), "_T"),
    MATERNAL_EDU_LVL = coalesce_existing_cols(., c("MATERNAL_EDU_LVL"), "_T"),
    HEAD_OF_HOUSE = coalesce_existing_cols(., c("HEAD_OF_HOUSE"), "_T"),
    TIME_PERIOD = coalesce_existing_cols(., c("TIME_PERIOD")),
    OBS_VALUE = coalesce_existing_cols(., c("OBS_VALUE")),
    DATA_SOURCE = coalesce_existing_cols(., c("DATA_SOURCE"), "Preferred survey"),
    DATA_SOURCE_PRIORITY = coalesce_existing_cols(., c("DATA_SOURCE_PRIORITY"), "1"),
    OBS_STATUS = coalesce_existing_cols(., c("OBS_STATUS"), "F"),
    OBS_CONF = coalesce_existing_cols(., c("OBS_CONF"), NA_character_),
    LOWER_BOUND = coalesce_existing_cols(., c("LOWER_BOUND"), NA_character_),
    UPPER_BOUND = coalesce_existing_cols(., c("UPPER_BOUND"), NA_character_),
    OBS_FOOTNOTE = coalesce_existing_cols(., c("OBS_FOOTNOTE"), NA_character_),
    SERIES_FOOTNOTE = coalesce_existing_cols(., c("SERIES_FOOTNOTE"), NA_character_),
    SOURCE_LINK = coalesce_existing_cols(., c("SOURCE_LINK"), NA_character_),
    CUSTODIAN = coalesce_existing_cols(., c("CUSTODIAN"), "UNICEF"),
    INPUT_SOURCE = "2a_country_non_series_for_agg"
  ) %>%
  filter(
    REPORTING_LVL %in% c("C", "Country"),
    SEX == "_T",
    WEALTH_QUINTILE == "_T",
    RESIDENCE == "_T",
    MATERNAL_EDU_LVL == "_T",
    HEAD_OF_HOUSE == "_T",
    AGE == "_T"
  ) %>%
  standardize_projection_rows()

read_regional_projection_input <- function(path, indicator_code, source_label) {
  regional_data <- if (grepl("\\.xlsx$", path, ignore.case = TRUE)) {
    readxl::read_excel(path) %>% mutate(across(everything(), as.character))
  } else {
    read_csv_all_char(path)
  }

  regional_data %>%
    mutate(REF_AREA = coalesce_existing_cols(., c("REF_AREA", "Class", "Region_Code"))) %>%
    filter(!is.na(REF_AREA), REF_AREA != "") %>%
    {
      if (any(c("IndicatorCode", "INDICATOR") %in% names(.))) {
        ind_col <- intersect(c("IndicatorCode", "INDICATOR"), names(.))[1]
        filter(., .data[[ind_col]] == indicator_code)
      } else {
        .
      }
    } %>%
    left_join(groups_lookup, by = "REF_AREA") %>%
    mutate(
      IndicatorCode = indicator_code,
      Indicator = projection_indicator_labels[[indicator_code]],
      `Geographic area` = coalesce_existing_cols(., c("Geographic area", "Region", "regional_name", "Class"), REF_AREA),
      REPORTING_LVL = if_else(REF_AREA == "UNSDG_REGION_GLOBAL", "G", "R"),
      SEX = coalesce_existing_cols(., c("SEX"), "_T"),
      AGE = unname(projection_indicator_age[[indicator_code]]),
      WEALTH_QUINTILE = "_T",
      RESIDENCE = "_T",
      MATERNAL_EDU_LVL = "_T",
      HEAD_OF_HOUSE = "_T",
      TIME_PERIOD = coalesce_existing_cols(., c("TIME_PERIOD", "time"), NA_character_),
      OBS_VALUE = coalesce_existing_cols(., c("OBS_VALUE"), NA_character_),
      DATA_SOURCE = source_label,
      DATA_SOURCE_PRIORITY = NA_character_,
      OBS_STATUS = NA_character_,
      OBS_CONF = NA_character_,
      LOWER_BOUND = coalesce_existing_cols(., c("LOWER_BOUND"), NA_character_),
      UPPER_BOUND = coalesce_existing_cols(., c("UPPER_BOUND"), NA_character_),
      OBS_FOOTNOTE = coalesce_existing_cols(., c("OBS_FOOTNOTE"), NA_character_),
      SERIES_FOOTNOTE = coalesce_existing_cols(., c("OBS_FOOTNOTE", "SERIES_FOOTNOTE"), NA_character_),
      SOURCE_LINK = NA_character_,
      CUSTODIAN = "UNICEF",
      INPUT_SOURCE = "regional_aggregate"
    ) %>%
    standardize_projection_rows()
}

regional_overweight <- read_regional_projection_input(
  regional_overweight_path,
  "NT_ANT_WHZ_PO2_MOD",
  "Regional aggregate (overweight)"
)
regional_anemia <- read_regional_projection_input(
  regional_anemia_path,
  "NT_ANE_WOM_15_49_MOD",
  "Regional aggregate (anemia)"
)
regional_stunting <- read_regional_projection_input(
  regional_stunting_path,
  "NT_ANT_HAZ_NE2_MOD",
  "Regional aggregate (stunting)"
)
regional_lbw <- read_regional_projection_input(
  regional_lbw_path,
  "NT_BW_LBW",
  "Regional aggregate (lbw)"
)
regional_wasting <- read_regional_projection_input(
  regional_wasting_path,
  "NT_ANT_WHZ_NE2",
  "Regional aggregate (wasting)"
)

projection_outputs <- list(
  ant = bind_rows(
    country_series %>% filter(IndicatorCode %in% c("NT_ANT_WHZ_PO2_MOD", "NT_ANT_HAZ_NE2_MOD")),
    country_non_series %>% filter(IndicatorCode == "NT_ANT_WHZ_NE2"),
    regional_overweight,
    regional_stunting,
    regional_wasting
  ),
  ane = bind_rows(
    country_series %>% filter(IndicatorCode == "NT_ANE_WOM_15_49_MOD"),
    regional_anemia
  ),
  bw = bind_rows(
    country_series %>% filter(IndicatorCode == "NT_BW_LBW"),
    regional_lbw
  ),
  iycf = country_non_series %>%
    filter(IndicatorCode == "NT_BF_EXBF")
)

output_files <- c(
  ant = "dw_nut_ant.csv",
  ane = "dw_nut_ane.csv",
  bw = "dw_nut_bw.csv",
  iycf = "dw_nut_iycf.csv"
)

source_map <- c(
  ant = "2a country series/non-series + regional overweight/stunting/wasting aggregates",
  ane = "2a country series + regional anemia aggregate",
  bw = "2a country series + regional LBW aggregate",
  iycf = "2a country non-series"
)

for (group_name in names(projection_outputs)) {
  projection_path <- file.path(projection_input_dir, paste0("nt_projection_", group_name, ".csv"))
  staged_path <- file.path(outputdir_projections_input, output_files[[group_name]])
  readr::write_csv(projection_outputs[[group_name]], projection_path, na = "")
  readr::write_csv(projection_outputs[[group_name]], staged_path, na = "")
  message("Staged NT projection input for ", group_name, ": ", basename(staged_path))
}

projection_all <- bind_rows(projection_outputs, .id = "projection_group")
readr::write_csv(projection_all, file.path(projection_input_dir, "nt_projection_all.csv"), na = "")

dw_country_universe <- projection_all %>%
  filter(REPORTING_LVL == "C") %>%
  distinct(REF_AREA, `Geographic area`) %>%
  arrange(REF_AREA)

readr::write_csv(dw_country_universe, file.path(outputdir_projections_input, "dw_country_universe.csv"), na = "")
readr::write_csv(dw_country_universe, file.path(projection_input_dir, "nt_projection_country_universe.csv"), na = "")

manifest <- bind_rows(lapply(names(projection_outputs), function(group_name) {
  tibble(
    dataset = output_files[[group_name]],
    row_count = nrow(projection_outputs[[group_name]]),
    source = source_map[[group_name]]
  )
})) %>%
  bind_rows(
    tibble(
      dataset = "dw_country_universe.csv",
      row_count = nrow(dw_country_universe),
      source = "derived from staged country projection inputs"
    )
  ) %>%
  mutate(pulled_utc = format(Sys.time(), tz = "UTC", usetz = TRUE))

readr::write_csv(manifest, file.path(outputdir_projections_input, "projection_input_manifest.csv"), na = "")
readr::write_csv(manifest, file.path(projection_input_dir, "nt_projection_manifest.csv"), na = "")

message(
  "NT projection inputs staged from the main pipeline outputs: ",
  nrow(projection_all), " rows across ",
  length(projection_outputs), " staged files."
)
