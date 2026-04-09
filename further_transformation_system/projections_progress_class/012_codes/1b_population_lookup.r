#------------------------------------------------------------------------------
# Project: DW-Production
# Sector: Nutrition projections
# Objective: Build reusable year-specific population lookups for estimates /
#            targets / projections exports and calculate number affected
#------------------------------------------------------------------------------

.data <- NULL
ISO3Code <- Region_Code <- iso3_code <- time <- REF_AREA <- TIME_PERIOD <- population <- data_level <- OBS_VALUE <- NULL

utils::globalVariables(c(
  "ISO3Code", "Region_Code", "iso3_code", "time", "REF_AREA",
  "TIME_PERIOD", "population", "data_level", "OBS_VALUE"
))

if (!exists("pop_path")) {
  stop("`pop_path` is not defined. Run 1_execute.r setup first.")
}
if (!exists("interdir")) {
  stop("`interdir` is not defined. Run 1_execute.r setup first.")
}

read_nt_projection_population_data <- function(path) {
  if (!file.exists(path)) {
    stop("Population file missing: ", path)
  }

  pop_data <- readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(time = suppressWarnings(as.integer(.data$time)))

  female_cols <- paste0("popfemale_", 15:49)
  if (all(female_cols %in% names(pop_data))) {
    pop_data <- pop_data |>
      dplyr::mutate(
        popfemale_year_15_49 = rowSums(dplyr::across(dplyr::all_of(female_cols)), na.rm = TRUE)
      )
  } else if (!"popfemale_year_15_49" %in% names(pop_data)) {
    pop_data <- pop_data |>
      dplyr::mutate(popfemale_year_15_49 = NA_real_)
  }

  pop_data
}

crosswalk_path <- file.path(interdir, "groups_for_agg.csv")
if (!file.exists(crosswalk_path)) {
  stop("Regional crosswalk file missing: ", crosswalk_path)
}

nt_projection_crosswalk <- readr::read_csv(crosswalk_path, show_col_types = FALSE) |>
  dplyr::filter(!is.na(.data$ISO3Code), !is.na(.data$Region_Code)) |>
  dplyr::transmute(
    iso3 = .data$ISO3Code,
    REF_AREA = .data$Region_Code
  ) |>
  dplyr::distinct()

nt_projection_population_data <- read_nt_projection_population_data(pop_path)

nt_projection_population_columns <- c(
  "NT_ANT_WHZ_PO2_MOD" = "pop_month_0_59_value",
  "NT_ANT_WHZ_NE2" = "pop_month_0_59_value",
  "NT_ANT_HAZ_NE2_MOD" = "pop_month_0_59_value",
  "NT_ANE_WOM_15_49_MOD" = "popfemale_year_15_49",
  "NT_BW_LBW" = "BW_VALIDBW_value",
  "NT_BF_EXBF" = "BF_EXBF_value",
  "NOT_NT_BF_EXBF" = "BF_EXBF_value"
)

nt_projection_current_age_labels <- c(
  "NT_ANT_WHZ_PO2_MOD" = "0 to 4 years",
  "NT_ANT_WHZ_NE2" = "0 to 4 years",
  "NT_ANT_HAZ_NE2_MOD" = "0 to 4 years",
  "NT_ANE_WOM_15_49_MOD" = "15 to 49 years",
  "NT_BW_LBW" = "Total",
  "NT_BF_EXBF" = "0 to 5 months",
  "NOT_NT_BF_EXBF" = "0 to 5 months"
)

get_nt_projection_current_age <- function(indicator_code) {
  label <- unname(nt_projection_current_age_labels[[indicator_code]])
  if (is.null(label) || is.na(label)) NA_character_ else label
}

first_non_missing_value <- function(x, default = NA_character_) {
  x <- as.character(x)
  x <- x[!is.na(x) & trimws(x) != ""]
  if (length(x) == 0) default else x[[1]]
}

coalesce_projection_cols <- function(data, candidates, default = NA_character_) {
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

nt_projection_reporting_level_name <- function(code) {
  dplyr::case_when(
    code %in% c("C", "Country") ~ "Country",
    code %in% c("R", "Regional") ~ "Regional",
    code %in% c("G", "Global") ~ "Global",
    TRUE ~ as.character(code)
  )
}

nt_projection_dimension_name <- function(code, dimension = c("sex", "age", "generic")) {
  dimension <- match.arg(dimension)
  code_chr <- as.character(code)

  dplyr::case_when(
    is.na(code_chr) | trimws(code_chr) == "" ~ NA_character_,
    code_chr == "_T" ~ "Total",
    dimension == "sex" & code_chr %in% c("M", "_M") ~ "Male",
    dimension == "sex" & code_chr %in% c("F", "_F") ~ "Female",
    dimension == "age" & code_chr == "Y0T4" ~ "0 to 4 years",
    dimension == "age" & code_chr == "Y15T49" ~ "15 to 49 years",
    dimension == "age" & code_chr == "M0T5" ~ "0 to 5 months",
    TRUE ~ code_chr
  )
}

get_nt_projection_label_lookup <- function(data, default_indicator_label = NA_character_) {
  if (!("REF_AREA" %in% names(data))) {
    return(tibble::tibble(
      REF_AREA = character(),
      data_level = character(),
      reporting_level_code = character(),
      reporting_level_name = character(),
      indicator_name = character(),
      geographic_area_name = character(),
      sex_code = character(),
      sex_name = character(),
      age_code = character(),
      age_name = character(),
      wealth_quintile_code = character(),
      wealth_quintile_name = character(),
      residence_code = character(),
      residence_name = character(),
      maternal_edu_lvl_code = character(),
      maternal_edu_lvl_name = character(),
      head_of_house_code = character(),
      head_of_house_name = character(),
      latest_data_source = character(),
      latest_data_source_priority = integer(),
      latest_obs_status = character(),
      latest_lower_bound = numeric(),
      latest_upper_bound = numeric(),
      latest_obs_footnote = character()
    ))
  }

  time_seed <- coalesce_projection_cols(data, c("TIME_PERIOD", "warehouse_year"), NA_character_)
  reporting_level_seed <- coalesce_projection_cols(data, c("REPORTING_LVL", "reporting_level"), NA_character_)
  existing_data_level <- if ("data_level" %in% names(data)) as.character(data$data_level) else rep(NA_character_, nrow(data))

  data |>
    dplyr::mutate(
      REF_AREA = as.character(.data$REF_AREA),
      data_level = dplyr::case_when(
        !is.na(existing_data_level) & trimws(existing_data_level) != "" ~ existing_data_level,
        reporting_level_seed %in% c("C", "Country") ~ "Country",
        reporting_level_seed %in% c("R", "Regional") ~ "Regional",
        reporting_level_seed %in% c("G", "Global") ~ "Global",
        TRUE ~ as.character(reporting_level_seed)
      ),
      reporting_level_code = dplyr::case_when(
        reporting_level_seed == "Country" ~ "C",
        reporting_level_seed == "Regional" ~ "R",
        reporting_level_seed == "Global" ~ "G",
        TRUE ~ as.character(reporting_level_seed)
      ),
      indicator_name_seed = coalesce_projection_cols(data, c("indicator_name", "Indicator", "INDICATOR_METADATA"), default_indicator_label),
      geographic_area_name_seed = coalesce_projection_cols(data, c("geographic_area_name", "Geographic area", "Geographic.area", "Region"), .data$REF_AREA),
      sex_code = coalesce_projection_cols(data, c("SEX", "sex_code"), "_T"),
      age_code = coalesce_projection_cols(data, c("AGE", "age_code"), "_T"),
      wealth_quintile_code = coalesce_projection_cols(data, c("WEALTH_QUINTILE", "wealth_quintile_code"), "_T"),
      residence_code = coalesce_projection_cols(data, c("RESIDENCE", "residence_code"), "_T"),
      maternal_edu_lvl_code = coalesce_projection_cols(data, c("MATERNAL_EDU_LVL", "maternal_edu_lvl_code"), "_T"),
      head_of_house_code = coalesce_projection_cols(data, c("HEAD_OF_HOUSE", "head_of_house_code"), "_T"),
      latest_data_source_seed = coalesce_projection_cols(data, c("DATA_SOURCE", "DataSourceTypeGlobal", "latest_data_source"), NA_character_),
      latest_data_source_priority_seed = coalesce_projection_cols(data, c("DATA_SOURCE_PRIORITY", "latest_data_source_priority"), NA_character_),
      latest_obs_status_seed = coalesce_projection_cols(data, c("OBS_STATUS", "latest_obs_status"), NA_character_),
      latest_lower_bound_seed = coalesce_projection_cols(data, c("LOWER_BOUND", "latest_lower_bound"), NA_character_),
      latest_upper_bound_seed = coalesce_projection_cols(data, c("UPPER_BOUND", "latest_upper_bound"), NA_character_),
      latest_obs_footnote_seed = coalesce_projection_cols(data, c("OBS_FOOTNOTE", "SERIES_FOOTNOTE", "latest_obs_footnote"), NA_character_),
      time_order = suppressWarnings(as.numeric(substr(as.character(time_seed), 1, 4)))
    ) |>
    dplyr::arrange(.data$REF_AREA, .data$data_level, dplyr::desc(.data$time_order), dplyr::desc(as.character(time_seed))) |>
    dplyr::group_by(.data$REF_AREA, .data$data_level) |>
    dplyr::summarise(
      reporting_level_code = first_non_missing_value(.data$reporting_level_code, default = ifelse(first_non_missing_value(.data$data_level) == "Country", "C", "R")),
      reporting_level_name = nt_projection_reporting_level_name(.data$reporting_level_code),
      indicator_name = first_non_missing_value(.data$indicator_name_seed, default = default_indicator_label),
      geographic_area_name = first_non_missing_value(.data$geographic_area_name_seed, default = first_non_missing_value(.data$REF_AREA)),
      sex_code = first_non_missing_value(.data$sex_code, default = "_T"),
      sex_name = nt_projection_dimension_name(.data$sex_code, dimension = "sex"),
      age_code = first_non_missing_value(.data$age_code, default = "_T"),
      age_name = nt_projection_dimension_name(.data$age_code, dimension = "age"),
      wealth_quintile_code = first_non_missing_value(.data$wealth_quintile_code, default = "_T"),
      wealth_quintile_name = nt_projection_dimension_name(.data$wealth_quintile_code, dimension = "generic"),
      residence_code = first_non_missing_value(.data$residence_code, default = "_T"),
      residence_name = nt_projection_dimension_name(.data$residence_code, dimension = "generic"),
      maternal_edu_lvl_code = first_non_missing_value(.data$maternal_edu_lvl_code, default = "_T"),
      maternal_edu_lvl_name = nt_projection_dimension_name(.data$maternal_edu_lvl_code, dimension = "generic"),
      head_of_house_code = first_non_missing_value(.data$head_of_house_code, default = "_T"),
      head_of_house_name = nt_projection_dimension_name(.data$head_of_house_code, dimension = "generic"),
      latest_data_source = first_non_missing_value(.data$latest_data_source_seed),
      latest_data_source_priority = suppressWarnings(as.integer(first_non_missing_value(.data$latest_data_source_priority_seed))),
      latest_obs_status = first_non_missing_value(.data$latest_obs_status_seed),
      latest_lower_bound = suppressWarnings(as.numeric(first_non_missing_value(.data$latest_lower_bound_seed))),
      latest_upper_bound = suppressWarnings(as.numeric(first_non_missing_value(.data$latest_upper_bound_seed))),
      latest_obs_footnote = first_non_missing_value(.data$latest_obs_footnote_seed),
      .groups = "drop"
    )
}

add_nt_projection_progress_metadata <- function(progress_data, label_lookup) {
  if (!all(c("REF_AREA", "reporting_level") %in% names(progress_data))) {
    return(progress_data)
  }
  if (nrow(label_lookup) == 0) {
    return(progress_data)
  }

  progress_data |>
    dplyr::mutate(
      data_level = dplyr::case_when(
        .data$reporting_level %in% c("C", "Country") ~ "Country",
        .data$reporting_level %in% c("R", "Regional") ~ "Regional",
        .data$reporting_level %in% c("G", "Global") ~ "Global",
        TRUE ~ as.character(.data$reporting_level)
      )
    ) |>
    dplyr::left_join(label_lookup, by = c("REF_AREA", "data_level")) |>
    dplyr::mutate(
      reporting_level_code = dplyr::coalesce(
        .data$reporting_level_code,
        dplyr::case_when(
          .data$data_level == "Country" ~ "C",
          .data$data_level == "Regional" ~ "R",
          .data$data_level == "Global" ~ "G",
          TRUE ~ as.character(.data$reporting_level)
        )
      ),
      reporting_level_name = dplyr::coalesce(.data$reporting_level_name, .data$data_level),
      indicator_name = dplyr::coalesce(.data$indicator_name, as.character(.data$INDICATOR)),
      geographic_area_name = dplyr::coalesce(.data$geographic_area_name, as.character(.data$REF_AREA))
    ) |>
    dplyr::select(-"data_level")
}

read_nt_projection_progress_file <- function(path) {
  progress_numeric_cols <- c(
    "baseline_year", "baseline_value", "latest_year", "latest_value",
    "latest_lower_bound", "latest_upper_bound", "projected_value_2030",
    "target_value_2030", "target_threshhold", "target_percent_change",
    "no_progress_aarr_lower_buffer", "no_progress_aarr_upper_buffer",
    "current_aarr", "required_aarr_2030"
  )
  progress_integer_cols <- c(
    "latest_data_source_priority", "crossthreshold", "assessment_not_possible_flag"
  )

  readr::read_csv(
    path,
    show_col_types = FALSE,
    col_types = readr::cols(.default = "c")
  ) |>
    dplyr::mutate(
      dplyr::across(dplyr::any_of(progress_integer_cols), ~ suppressWarnings(as.integer(.x))),
      dplyr::across(dplyr::any_of(progress_numeric_cols), ~ suppressWarnings(as.numeric(.x)))
    )
}

nt_projection_population_cache <- new.env(parent = emptyenv())

get_nt_projection_population_lookup <- function(indicator_code) {
  if (exists(indicator_code, envir = nt_projection_population_cache, inherits = FALSE)) {
    return(get(indicator_code, envir = nt_projection_population_cache, inherits = FALSE))
  }

  pop_col <- unname(nt_projection_population_columns[[indicator_code]])
  if (is.null(pop_col) || is.na(pop_col)) {
    warning("No population mapping configured for indicator: ", indicator_code)
    empty_lookup <- tibble::tibble(
      data_level = character(),
      REF_AREA = character(),
      TIME_PERIOD = integer(),
      population = numeric()
    )
    assign(indicator_code, empty_lookup, envir = nt_projection_population_cache)
    return(empty_lookup)
  }

  population_data <- nt_projection_population_data
  if (!(pop_col %in% names(population_data))) {
    warning("Population column `", pop_col, "` not found for indicator: ", indicator_code)
    empty_lookup <- tibble::tibble(
      data_level = character(),
      REF_AREA = character(),
      TIME_PERIOD = integer(),
      population = numeric()
    )
    assign(indicator_code, empty_lookup, envir = nt_projection_population_cache)
    return(empty_lookup)
  }

  country_lookup <- population_data |>
    dplyr::transmute(
      data_level = "Country",
      REF_AREA = as.character(.data$iso3_code),
      TIME_PERIOD = as.integer(.data$time),
      population = suppressWarnings(as.numeric(.data[[pop_col]]))
    ) |>
    dplyr::filter(!is.na(.data$REF_AREA), !is.na(.data$TIME_PERIOD))

  regional_lookup <- country_lookup |>
    dplyr::transmute(
      iso3 = .data$REF_AREA,
      TIME_PERIOD = .data$TIME_PERIOD,
      population = .data$population
    ) |>
    dplyr::left_join(
      nt_projection_crosswalk,
      by = "iso3",
      relationship = "many-to-many"
    ) |>
    dplyr::filter(!is.na(.data$REF_AREA)) |>
    dplyr::group_by(.data$REF_AREA, .data$TIME_PERIOD) |>
    dplyr::summarise(
      population = if (all(is.na(.data$population))) NA_real_ else sum(.data$population, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(data_level = "Regional") |>
    dplyr::select(dplyr::all_of(c("data_level", "REF_AREA", "TIME_PERIOD", "population")))

  lookup <- dplyr::bind_rows(country_lookup, regional_lookup) |>
    dplyr::mutate(population = dplyr::if_else(is.nan(.data$population), NA_real_, .data$population))

  assign(indicator_code, lookup, envir = nt_projection_population_cache)
  lookup
}

add_nt_population_columns <- function(data, indicator_code) {
  if (!all(c("data_level", "REF_AREA", "TIME_PERIOD") %in% names(data))) {
    warning("Population join skipped for ", indicator_code, ": required key columns are missing.")
    return(
      dplyr::mutate(
        data,
        population = NA_real_,
        number_affected = NA_real_
      )
    )
  }

  pop_lookup <- get_nt_projection_population_lookup(indicator_code)

  data |>
    dplyr::select(-dplyr::any_of(c("population", "number_affected"))) |>
    dplyr::left_join(pop_lookup, by = c("data_level", "REF_AREA", "TIME_PERIOD")) |>
    dplyr::mutate(
      number_affected = dplyr::if_else(
        !is.na(.data$population) & !is.na(.data$OBS_VALUE),
        .data$population * .data$OBS_VALUE / 100,
        NA_real_
      )
    )
}
