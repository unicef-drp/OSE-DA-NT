suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(readr)
  library(arrow)
  library(haven)
  library(tibble)
})

if (!exists("projectFolder", envir = .GlobalEnv) ||
    !exists("cmrsInputDir", envir = .GlobalEnv) ||
    !exists("analysisDatasetsOutputDir", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

cmrs_input_dir <- cmrsInputDir
disagg_map_path <- file.path(projectFolder, "reference_data_manager", "indicators", "reference_disaggregations.csv")
layer2_output_dir <- analysisDatasetsOutputDir

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

derive_region_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- get_chr_col(df, "ContextualDisaggregationsLabel")
  std <- get_chr_col(df, "StandardDisaggregations")

  has_subnational_region <- stringr::str_detect(coalesce(bg, ""), regex("Subnational Region", ignore_case = TRUE))

  region <- str_squish(coalesce(lbl, ""))
  region <- str_replace_all(region, regex("\\bQ[1-5]\\b", ignore_case = TRUE), "")
  region <- str_replace_all(region, regex("\\b(Bottom|Top)\\s+\\d+%", ignore_case = TRUE), "")
  region <- str_replace_all(region, regex("\\b(urban|rural|urbaine|urbain|rurale|rurale)\\b", ignore_case = TRUE), "")
  region <- str_squish(region)

  region[is.na(region) | region == "" | str_to_lower(region) %in% c("national", "urban", "rural", "urbaine", "urbain", "rurale", "rurale")] <- "_T"

  out <- rep("_T", nrow(df))
  out[has_subnational_region] <- region[has_subnational_region]

  # Fallback for rows that only provide "Region N" without a clean contextual label.
  region_id <- str_match(str_squish(coalesce(std, "")), regex("^Region\\s+([0-9]+)$", ignore_case = TRUE))[, 2]
  fallback_idx <- has_subnational_region & out == "_T" & !is.na(region_id)
  out[fallback_idx] <- paste0("REGION_", region_id[fallback_idx])

  out[out == ""] <- "_T"
  out
}

derive_bw_wealth_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))

  wealth_share_idx <- bg == "Household Wealth Share"
  out[wealth_share_idx & lbl == "Bottom 20%"] <- "B20"
  out[wealth_share_idx & lbl == "Bottom 40%"] <- "B40"
  out[wealth_share_idx & lbl == "Bottom 60%"] <- "B60"
  out[wealth_share_idx & lbl == "Bottom 80%"] <- "B80"
  out[wealth_share_idx & lbl == "Top 20%"] <- "R20"
  out[wealth_share_idx & lbl == "Top 40%"] <- "R40"
  out[wealth_share_idx & lbl == "Top 60%"] <- "R60"
  out[wealth_share_idx & lbl == "Top 80%"] <- "R80"

  wealth_decile_idx <- bg == "Household Wealth Decile"
  out[wealth_decile_idx & lbl %in% c("D1", "D2")] <- "Q1"
  out[wealth_decile_idx & lbl %in% c("D3", "D4")] <- "Q2"
  out[wealth_decile_idx & lbl %in% c("D5", "D6")] <- "Q3"
  out[wealth_decile_idx & lbl %in% c("D7", "D8")] <- "Q4"
  out[wealth_decile_idx & lbl %in% c("D9", "D10")] <- "Q5"

  out
}

derive_bw_education_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))
  edu_idx <- bg == "Mother's Education"

  out[edu_idx & lbl == "Mother's Education - No Education"] <- "ISCED11A_01"
  out[edu_idx & lbl == "Mother's Education - Primary Education"] <- "ISCED11_1"
  out[edu_idx & lbl == "Mother's Education - None and Primary Education"] <- "AGG_0_1"
  out[edu_idx & lbl == "Mother's Education - Secondary Education"] <- "AGG_2_3"
  out[edu_idx & lbl == "Mother's Education - Secondary Education and Higher"] <- "AGG_3S_H"
  out[edu_idx & lbl == "Mother's Education - Higher Education"] <- "AGG_5T8"
  out[edu_idx & lbl == "Mother's Education - Missing Education Data"] <- "MISSING_EDU"

  out
}

derive_bw_mother_age_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Mother's Age at Birth"

  out[idx & lbl == "Mother's Age at Birth - Less than 15 years"] <- "Y_LT15"
  out[idx & lbl == "Mother's Age at Birth - 15 to 19 years"] <- "Y15T19"
  out[idx & lbl == "Mother's Age at Birth - 20 to 34 years"] <- "Y20T34"
  out[idx & lbl == "Mother's Age at Birth - 35 years or greater"] <- "Y_GE35"

  out
}

derive_bw_delivery_assistance_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Assistance at Delivery"

  out[idx & lbl == "Attendance at Birth - Skilled Provider"] <- "SKILLED"
  out[idx & lbl == "Attendance at Birth - Other Provider"] <- "OTHER_PROVIDER"
  out[idx & lbl == "Attendance at Birth - Relative or Other"] <- "RELATIVE_OR_OTHER"

  out
}

derive_bw_place_of_delivery_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Place of Delivery"

  out[idx & lbl == "Place of Delivery - Home or Other"] <- "HOME_OR_OTHER"
  out[idx & lbl == "Place of Delivery - Public Sector"] <- "PUBLIC_SECTOR"
  out[idx & lbl == "Place of Delivery - Private Medical Sector"] <- "PRIVATE_MEDICAL_SECTOR"

  out
}

derive_bw_delivery_mode_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Delivery by c-section"

  out[idx & lbl == "C-section Delivery"] <- "C_SECTION"
  out[idx & lbl == "Vaginal Delivery"] <- "VAGINAL"

  out
}

derive_bw_multiple_birth_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  lbl <- str_squish(get_chr_col(df, "ContextualDisaggregationsLabel"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Singleton or Multiple Births"

  out[idx & lbl == "Singleton"] <- "SINGLETON"
  out[idx & lbl == "Multiple Births"] <- "MULTIPLE"

  out
}

derive_bw_head_of_household_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Sex of Household Head"

  out[idx & str_to_lower(std) %in% c("female head", "female headed household")] <- "F"
  out[idx & str_to_lower(std) %in% c("male head", "male headed household")] <- "M"

  out
}

derive_iod_wealth_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))

  share_idx <- bg == "Household Wealth Share"
  out[share_idx & std == "Bottom 20%"] <- "B20"
  out[share_idx & std == "Bottom 40%"] <- "B40"
  out[share_idx & std == "Bottom 60%"] <- "B60"
  out[share_idx & std == "Bottom 80%"] <- "B80"
  out[share_idx & std == "Top 20%"] <- "R20"
  out[share_idx & std == "Top 40%"] <- "R40"
  out[share_idx & std == "Top 60%"] <- "R60"
  out[share_idx & std == "Top 80%"] <- "R80"

  decile_idx <- bg %in% c("Household Wealth Decile", "Area Household Wealth Decile")
  d <- str_match(std, regex("^D\\s*([0-9]{1,2})(?:\\s+(urban|rural))?$", ignore_case = TRUE))[, 2]
  d_num <- suppressWarnings(as.integer(d))
  out[decile_idx & !is.na(d_num) & d_num %in% c(1L, 2L)] <- "Q1"
  out[decile_idx & !is.na(d_num) & d_num %in% c(3L, 4L)] <- "Q2"
  out[decile_idx & !is.na(d_num) & d_num %in% c(5L, 6L)] <- "Q3"
  out[decile_idx & !is.na(d_num) & d_num %in% c(7L, 8L)] <- "Q4"
  out[decile_idx & !is.na(d_num) & d_num %in% c(9L, 10L)] <- "Q5"

  tercile_idx <- bg %in% c("Household Wealth Tercile", "Area Household Wealth Tercile")
  t <- str_match(std, regex("^T\\s*([123])(?:\\s+(urban|rural))?$", ignore_case = TRUE))[, 2]
  t_idx <- tercile_idx & !is.na(t)
  out[t_idx] <- paste0("T", t[t_idx])

  out
}

derive_iod_residence_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  area_wealth_idx <- bg %in% c("Area Household Wealth Decile", "Area Household Wealth Tercile")
  suffix <- str_match(std, regex("\\b(urban|rural)$", ignore_case = TRUE))[, 2]
  out[area_wealth_idx & str_to_lower(suffix) == "urban"] <- "URBAN"
  out[area_wealth_idx & str_to_lower(suffix) == "rural"] <- "RURAL"

  out
}

derive_iod_head_of_household_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Sex of Household Head"
  out[idx & str_to_lower(std) %in% c("female head", "female headed household")] <- "F"
  out[idx & str_to_lower(std) %in% c("male head", "male headed household")] <- "M"

  out
}

derive_iod_region_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std_num <- str_squish(get_chr_col(df, "standard_disagg"))
  std_lbl <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  idx <- (is.na(bg) | bg == "") & (is.na(std_num) | std_num == "") & (is.na(std_lbl) | std_lbl == "")
  out[idx] <- "NATIONAL_TOTAL"

  out
}

derive_iycf_age_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))

  months_idx <- bg == "Age in months"
  months <- str_match(std, regex("^([0-9]{1,2})\\s+months?\\s+old$", ignore_case = TRUE))[, 2]
  out[months_idx & !is.na(months)] <- paste0("M", sprintf("%02d", as.integer(months[months_idx & !is.na(months)])))

  age_group_idx <- bg == "Age Group"
  out[age_group_idx & str_to_lower(std) == "0 to 3 months"] <- "M00T03"

  out
}

derive_iycf_education_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Mother's Education"
  out[idx & std == "Mother's Education - Missing Education Data"] <- "MISSING_EDU"

  out
}

derive_iycf_delivery_assistance_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Assistance at Delivery"
  out[idx & std == "Attendance at Birth - Health Professional"] <- "HEALTH_PROFESSIONAL"
  out[idx & std == "Attendance at Birth - Other"] <- "OTHER"
  out[idx & std == "Attendance at Birth - Traditional Birth Attendant"] <- "TRADITIONAL_BIRTH_ATTENDANT"
  out[idx & std == "Attendance at Birth - No one"] <- "NO_ONE"

  out
}

derive_iycf_place_of_delivery_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  idx <- bg == "Place of Delivery"
  out[idx & std == "Place of Delivery - Health Facility"] <- "HEALTH_FACILITY"
  out[idx & std == "Place of Delivery - Home"] <- "HOME"
  out[idx & std == "Place of Delivery - Other"] <- "OTHER"

  out
}

derive_iycf_misc_region_dim <- function(df) {
  bg <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  misc_idx <- bg %in% c("Ethnicity", "Religion", "Caste")
  token_bg <- str_replace_all(str_to_upper(bg), "[^A-Z0-9]+", "_")
  token_std <- str_replace_all(str_to_upper(std), "[^A-Z0-9]+", "_")
  token <- str_replace_all(str_trim(paste0(token_bg, "_", token_std)), "_+", "_")
  token <- str_replace_all(token, "^_|_$", "")
  out[misc_idx & token != ""] <- paste0("DISAGG_", token[misc_idx & token != ""])

  out
}

apply_dataset_fallback_dims <- function(df, dataset_name) {
  if (identical(dataset_name, "CMRS_BW.dta")) {
    return(
      df %>%
        mutate(
          WEALTH = if_else(.data$WEALTH == "_T", derive_bw_wealth_dim(.), .data$WEALTH),
          EDUCATION = if_else(.data$EDUCATION == "_T", derive_bw_education_dim(.), .data$EDUCATION),
          MOTHER_AGE = derive_bw_mother_age_dim(.),
          DELIVERY_ASSISTANCE = derive_bw_delivery_assistance_dim(.),
          PLACE_OF_DELIVERY = derive_bw_place_of_delivery_dim(.),
          DELIVERY_MODE = derive_bw_delivery_mode_dim(.),
          MULTIPLE_BIRTH = derive_bw_multiple_birth_dim(.),
          HEAD_OF_HOUSEHOLD = if_else(.data$HEAD_OF_HOUSEHOLD == "_T", derive_bw_head_of_household_dim(.), .data$HEAD_OF_HOUSEHOLD)
        )
    )
  }

  if (identical(dataset_name, "CMRS_IOD.dta")) {
    return(
      df %>%
        mutate(
          WEALTH = if_else(.data$WEALTH == "_T", derive_iod_wealth_dim(.), .data$WEALTH),
          RESIDENCE = if_else(.data$RESIDENCE == "_T", derive_iod_residence_dim(.), .data$RESIDENCE),
          HEAD_OF_HOUSEHOLD = if_else(.data$HEAD_OF_HOUSEHOLD == "_T", derive_iod_head_of_household_dim(.), .data$HEAD_OF_HOUSEHOLD),
          REGION = if_else(.data$REGION == "_T", derive_iod_region_dim(.), .data$REGION)
        )
    )
  }

  if (identical(dataset_name, "CMRS_ANT.dta")) {
    return(
      df %>%
        mutate(
          WEALTH = if_else(.data$WEALTH == "_T", derive_iod_wealth_dim(.), .data$WEALTH),
          RESIDENCE = if_else(.data$RESIDENCE == "_T", derive_iod_residence_dim(.), .data$RESIDENCE),
          HEAD_OF_HOUSEHOLD = if_else(.data$HEAD_OF_HOUSEHOLD == "_T", derive_iod_head_of_household_dim(.), .data$HEAD_OF_HOUSEHOLD),
          REGION = if_else(.data$REGION == "_T", derive_iod_region_dim(.), .data$REGION)
        )
    )
  }

  if (identical(dataset_name, "CMRS_IYCF.dta")) {
    return(
      df %>%
        mutate(
          AGE = if_else(.data$AGE == "_T", derive_iycf_age_dim(.), .data$AGE),
          EDUCATION = if_else(.data$EDUCATION == "_T", derive_iycf_education_dim(.), .data$EDUCATION),
          DELIVERY_ASSISTANCE = if_else(.data$DELIVERY_ASSISTANCE == "_T", derive_iycf_delivery_assistance_dim(.), .data$DELIVERY_ASSISTANCE),
          PLACE_OF_DELIVERY = if_else(.data$PLACE_OF_DELIVERY == "_T", derive_iycf_place_of_delivery_dim(.), .data$PLACE_OF_DELIVERY),
          WEALTH = if_else(.data$WEALTH == "_T", derive_iod_wealth_dim(.), .data$WEALTH),
          RESIDENCE = if_else(.data$RESIDENCE == "_T", derive_iod_residence_dim(.), .data$RESIDENCE),
          HEAD_OF_HOUSEHOLD = if_else(.data$HEAD_OF_HOUSEHOLD == "_T", derive_iod_head_of_household_dim(.), .data$HEAD_OF_HOUSEHOLD),
          REGION = if_else(.data$REGION == "_T", derive_iycf_misc_region_dim(.), .data$REGION),
          REGION = if_else(.data$REGION == "_T", derive_iod_region_dim(.), .data$REGION)
        )
    )
  }

  df
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
build_layer2_dataset <- function(data, disagg_map, dataset_name = NA_character_) {

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

  # Join on numeric ID (standard_disagg -> map ID), matching DW-Production
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

  # Assign dimension columns - default to "_T" when field is empty, matching DW-Production
  out <- out %>%
    mutate(
      SEX       = if_else(.data$HELIX_SEX != "",              .data$HELIX_SEX, "_T"),
      AGE       = if_else(.data$HELIX_AGE != "",              .data$HELIX_AGE, "_T"),
      RESIDENCE = if_else(.data$HELIX_RESIDENCE != "",        .data$HELIX_RESIDENCE, "_T"),
      WEALTH    = if_else(.data$HELIX_WEALTH_QUINTILE != "",  .data$HELIX_WEALTH_QUINTILE, "_T"),
      EDUCATION = if_else(.data$HELIX_MATERNAL_EDU_LVL != "", .data$HELIX_MATERNAL_EDU_LVL, "_T"),
      HEAD_OF_HOUSEHOLD = if_else(.data$HELIX_HEAD_OF_HOUSE != "", .data$HELIX_HEAD_OF_HOUSE, "_T"),
      MOTHER_AGE = "_T",
      DELIVERY_ASSISTANCE = "_T",
      PLACE_OF_DELIVERY = "_T",
      DELIVERY_MODE = "_T",
      MULTIPLE_BIRTH = "_T",
      REGION    = derive_region_dim(.),
      REF_AREA    = coalesce(get_chr_col(., "REF_AREA"), get_chr_col(., "ISO3Code"), get_chr_col(., "CND_Country_Code")),
      TIME_PERIOD = coalesce(get_chr_col(., "TIME_PERIOD"), get_chr_col(., "CMRS_year"), get_chr_col(., "warehouse_year"), get_chr_col(., "middle_year")),
      INDICATOR   = coalesce(get_chr_col(., "INDICATOR"), get_chr_col(., "IndicatorCode"), get_chr_col(., "Indicator")),
      VALUE       = coalesce(get_num_col(., "VALUE"), get_num_col(., "r"), get_num_col(., "r_raw"))
    ) %>%
    mutate(
      SEX = if_else(.data$SEX == "_T" & str_detect(.data$INDICATOR, regex("^ANE_WOM", ignore_case = TRUE)), "F", .data$SEX)
    ) %>%
    apply_dataset_fallback_dims(dataset_name = dataset_name)

  analytical_dim_assigned <- with(
    out,
    SEX != "_T" |
      AGE != "_T" |
      RESIDENCE != "_T" |
      WEALTH != "_T" |
      EDUCATION != "_T" |
      HEAD_OF_HOUSEHOLD != "_T" |
      MOTHER_AGE != "_T" |
      DELIVERY_ASSISTANCE != "_T" |
      PLACE_OF_DELIVERY != "_T" |
      DELIVERY_MODE != "_T" |
      MULTIPLE_BIRTH != "_T" |
      REGION != "_T"
  )

  message(
    "Rows assigned to at least one analytical dimension: ",
    sum(analytical_dim_assigned, na.rm = TRUE), " of ", nrow(out)
  )

  out %>%
    select(-any_of(c(
      "standard_disagg_key", "disagg_ref_match",
      "HELIX_SEX", "HELIX_AGE", "HELIX_WEALTH_QUINTILE",
      "HELIX_RESIDENCE", "HELIX_MATERNAL_EDU_LVL", "HELIX_HEAD_OF_HOUSE",
      "HELIX_CODE"
    ))) %>%
    relocate(any_of(c("REF_AREA", "TIME_PERIOD", "INDICATOR", "SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION", "HEAD_OF_HOUSEHOLD", "MOTHER_AGE", "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY", "DELIVERY_MODE", "MULTIPLE_BIRTH", "REGION", "VALUE")), .before = everything()) %>%
    as_tibble()
}

run_single_dataset <- function(dataset_file, output_file) {
  disagg_map <- read_disagg_map()
  source_data <- haven::read_dta(file.path(cmrs_input_dir, dataset_file))
  layer2 <- build_layer2_dataset(source_data, disagg_map, dataset_name = dataset_file)
  output_path <- file.path(layer2_output_dir, output_file)
  arrow::write_parquet(layer2, output_path, compression = "zstd")
  message("Wrote: ", output_path)
  invisible(layer2)
}

run_combined_datasets <- function(dataset_files, output_file) {
  disagg_map <- read_disagg_map()

  layer2_list <- lapply(dataset_files, function(dataset_file) {
    source_data <- haven::read_dta(file.path(cmrs_input_dir, dataset_file))
    build_layer2_dataset(source_data, disagg_map, dataset_name = dataset_file)
  })

  layer2 <- dplyr::bind_rows(layer2_list)
  output_path <- file.path(layer2_output_dir, output_file)
  arrow::write_parquet(layer2, output_path, compression = "zstd")

  message("Wrote: ", output_path)
  invisible(layer2)
}
