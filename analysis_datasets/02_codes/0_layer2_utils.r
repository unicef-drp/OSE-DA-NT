# ---------------------------------------------------------------------------
# Script:  0_layer2_utils.r
# Purpose: Shared utility functions for building CMRS2 analysis datasets.
#
# This module provides the core data-processing pipeline:
#   1. read_disagg_map()        â€” loads the reference disaggregation mapping
#   2. build_layer2_dataset()   â€” joins source CMRS data to the mapping,
#                                 assigns analytical dimensions, applies
#                                 dataset-specific fallback derivations
#   3. run_single_dataset()     â€” convenience wrapper: read â†’ build â†’ write
#   4. run_combined_datasets()  â€” same, but binds multiple source DTAs first
#
# Dimension assignment uses a two-layer strategy:
#   Layer 1: Reference-based lookup via standard_disagg ID from
#            reference_disaggregations.csv (HELIX_* and OSE_* columns).
#   Layer 2: Hardcoded fallback derivation functions that parse
#            BackgroundCharacteristics / ContextualDisaggregationsLabel
#            for values not yet covered by the reference mapping.
#
# Output columns (analytical dimensions):
#   SEX, AGE, RESIDENCE, WEALTH, EDUCATION, HEAD_OF_HOUSEHOLD,
#   MOTHER_AGE, DELIVERY_ASSISTANCE, PLACE_OF_DELIVERY,
#   DELIVERY_MODE, MULTIPLE_BIRTH, REGION
#
# Dependencies:
#   - profile_OSE-DA-NT.R  (provides path variables)
#   - reference_data_manager/indicators/reference_disaggregations.csv
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Column helpers
# ---------------------------------------------------------------------------

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
# Fallback dimension derivation functions
#
# These parse BackgroundCharacteristics / ContextualDisaggregationsLabel /
# StandardDisaggregations text fields to derive dimension codes for rows
# that were not resolved by the reference mapping (Layer 2).
# ---------------------------------------------------------------------------

derive_region_dim <- function(df) {
  bg <- get_chr_col(df, "BackgroundCharacteristics")
  std <- get_chr_col(df, "StandardDisaggregations")

  has_subnational_region <- stringr::str_detect(coalesce(bg, ""), regex("Subnational Region", ignore_case = TRUE))

  # Extract the region number from StandardDisaggregations ("Region 1",
  # "Region 2 Q3", "Region 5 urban", etc.).  Anchored at start so it
  # also matches cross-disagg patterns.
  region_id <- str_match(str_squish(coalesce(std, "")),
                         regex("^Region\\s+([0-9]+)\\b", ignore_case = TRUE))[, 2]

  out <- rep("_T", nrow(df))
  idx <- has_subnational_region & !is.na(region_id)
  out[idx] <- paste0("REGION_", region_id[idx])

  out
}

derive_residence_from_region_context <- function(df) {
  bg  <- get_chr_col(df, "BackgroundCharacteristics")
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  has_subnational_region <- str_detect(coalesce(bg, ""),
                                       regex("Subnational Region", ignore_case = TRUE))

  # Use StandardDisaggregations (structured field) instead of

  # ContextualDisaggregationsLabel (free-text) to detect urban/rural.
  # This avoids false positives when region names contain "rural"/"urban"
  # (e.g. "..Lower Egypt - Rural", "Milieu rural").
  std_lower <- str_to_lower(coalesce(std, ""))
  is_urban  <- str_detect(std_lower, "\\b(urban|urbaine|urbain)\\b")
  is_rural  <- str_detect(std_lower, "\\b(rural|rurale)\\b")

  out <- rep("_T", nrow(df))
  out[has_subnational_region & is_urban & !is_rural] <- "URBAN"
  out[has_subnational_region & is_rural & !is_urban] <- "RURAL"
  out
}

derive_sex_from_region_context <- function(df) {
  bg  <- str_squish(get_chr_col(df, "BackgroundCharacteristics"))
  std <- str_squish(get_chr_col(df, "StandardDisaggregations"))

  out <- rep("_T", nrow(df))
  # Cross-disagg: Subnational Region x Sex ("Region 1 Female", "Region 2 Male")
  sex_region_idx <- bg == "Subnational Region Sex"
  is_female <- str_detect(coalesce(std, ""), regex("\\bFemale\\b", ignore_case = TRUE))
  is_male   <- str_detect(coalesce(std, ""), regex("\\bMale\\b", ignore_case = TRUE)) & !is_female
  out[sex_region_idx & is_female] <- "F"
  out[sex_region_idx & is_male]   <- "M"

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
  out[wealth_decile_idx & lbl == "D1"]  <- "D01"
  out[wealth_decile_idx & lbl == "D2"]  <- "D02"
  out[wealth_decile_idx & lbl == "D3"]  <- "D03"
  out[wealth_decile_idx & lbl == "D4"]  <- "D04"
  out[wealth_decile_idx & lbl == "D5"]  <- "D05"
  out[wealth_decile_idx & lbl == "D6"]  <- "D06"
  out[wealth_decile_idx & lbl == "D7"]  <- "D07"
  out[wealth_decile_idx & lbl == "D8"]  <- "D08"
  out[wealth_decile_idx & lbl == "D9"]  <- "D09"
  out[wealth_decile_idx & lbl == "D10"] <- "D10"

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
  out[decile_idx & !is.na(d_num)] <- sprintf("D%02d", d_num[decile_idx & !is.na(d_num)])

  tercile_idx <- bg %in% c("Household Wealth Tercile", "Area Household Wealth Tercile")
  t <- str_match(std, regex("^T\\s*([123])(?:\\s+(urban|rural))?$", ignore_case = TRUE))[, 2]
  t_idx <- tercile_idx & !is.na(t)
  out[t_idx] <- paste0("T", t[t_idx])

  # --- Cross-disagg: Wealth Share x Subnational Region ---
  # StandardDisaggregations like "Region 1 Bottom 40%", "Region 2 Top 20%"
  share_region_idx <- bg == "Household Wealth Share Subnational Region"
  share_match <- str_match(std, regex("(Bottom|Top)\\s+(\\d+)%", ignore_case = TRUE))
  share_dir <- str_to_lower(coalesce(share_match[, 2], ""))
  share_pct <- coalesce(share_match[, 3], "")
  share_code <- rep("_T", nrow(df))
  share_code[share_dir == "bottom" & share_pct == "20"] <- "B20"
  share_code[share_dir == "bottom" & share_pct == "40"] <- "B40"
  share_code[share_dir == "bottom" & share_pct == "60"] <- "B60"
  share_code[share_dir == "bottom" & share_pct == "80"] <- "B80"
  share_code[share_dir == "top" & share_pct == "20"] <- "R20"
  share_code[share_dir == "top" & share_pct == "40"] <- "R40"
  share_code[share_dir == "top" & share_pct == "60"] <- "R60"
  share_code[share_dir == "top" & share_pct == "80"] <- "R80"
  out[share_region_idx & share_code != "_T"] <- share_code[share_region_idx & share_code != "_T"]

  # --- Cross-disagg: Wealth Quintile x Subnational Region ---
  # StandardDisaggregations like "Region 1 Q3"
  quintile_region_idx <- bg == "Household Wealth Quintile Subnational Region"
  q <- str_match(std, regex("\\bQ([1-5])\\b", ignore_case = TRUE))[, 2]
  out[quintile_region_idx & !is.na(q)] <- paste0("Q", q[quintile_region_idx & !is.na(q)])

  # --- Cross-disagg: Wealth Decile x Subnational Region ---
  # StandardDisaggregations like "Region 1 D5"
  decile_region_idx <- bg == "Household Wealth Decile Subnational Region"
  d_cross <- str_match(std, regex("\\bD\\s*([0-9]{1,2})\\b", ignore_case = TRUE))[, 2]
  d_cross_num <- suppressWarnings(as.integer(d_cross))
  out[decile_region_idx & !is.na(d_cross_num)] <- sprintf("D%02d", d_cross_num[decile_region_idx & !is.na(d_cross_num)])

  # --- Cross-disagg: Wealth Tercile x Subnational Region ---
  # StandardDisaggregations like "Region 1 T2"
  tercile_region_idx <- bg == "Household Wealth Tercile Subnational Region"
  t_cross <- str_match(std, regex("\\bT([123])\\b", ignore_case = TRUE))[, 2]
  out[tercile_region_idx & !is.na(t_cross)] <- paste0("T", t_cross[tercile_region_idx & !is.na(t_cross)])

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

  # Cross-disagg: Area x Subnational Region ("Region 1 urban", "Region 2 rural")
  area_region_idx <- bg == "Area Subnational Region"
  out[area_region_idx & str_to_lower(suffix) == "urban"] <- "URBAN"
  out[area_region_idx & str_to_lower(suffix) == "rural"] <- "RURAL"

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
          MOTHER_AGE = if_else(.data$MOTHER_AGE == "_T", derive_bw_mother_age_dim(.), .data$MOTHER_AGE),
          DELIVERY_ASSISTANCE = if_else(.data$DELIVERY_ASSISTANCE == "_T", derive_bw_delivery_assistance_dim(.), .data$DELIVERY_ASSISTANCE),
          PLACE_OF_DELIVERY = if_else(.data$PLACE_OF_DELIVERY == "_T", derive_bw_place_of_delivery_dim(.), .data$PLACE_OF_DELIVERY),
          DELIVERY_MODE = if_else(.data$DELIVERY_MODE == "_T", derive_bw_delivery_mode_dim(.), .data$DELIVERY_MODE),
          MULTIPLE_BIRTH = if_else(.data$MULTIPLE_BIRTH == "_T", derive_bw_multiple_birth_dim(.), .data$MULTIPLE_BIRTH),
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
# Reference mapping loader
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
      OSE_MOTHER_AGE         = if ("OSE_MOTHER_AGE" %in% names(.)) coalesce(.data$OSE_MOTHER_AGE, "") else "",
      OSE_DELIVERY_ASSISTANCE = if ("OSE_DELIVERY_ASSISTANCE" %in% names(.)) coalesce(.data$OSE_DELIVERY_ASSISTANCE, "") else "",
      OSE_PLACE_OF_DELIVERY  = if ("OSE_PLACE_OF_DELIVERY" %in% names(.)) coalesce(.data$OSE_PLACE_OF_DELIVERY, "") else "",
      OSE_DELIVERY_MODE      = if ("OSE_DELIVERY_MODE" %in% names(.)) coalesce(.data$OSE_DELIVERY_MODE, "") else "",
      OSE_MULTIPLE_BIRTH     = if ("OSE_MULTIPLE_BIRTH" %in% names(.)) coalesce(.data$OSE_MULTIPLE_BIRTH, "") else "",
      OSE_AGE                = if ("OSE_AGE" %in% names(.)) coalesce(.data$OSE_AGE, "") else "",
      OSE_EDUCATION          = if ("OSE_EDUCATION" %in% names(.)) coalesce(.data$OSE_EDUCATION, "") else "",
      HELIX_CODE = paste0(
        .data$HELIX_SEX, "|", .data$HELIX_AGE, "|", .data$HELIX_WEALTH_QUINTILE, "|",
        .data$HELIX_RESIDENCE, "|", .data$HELIX_MATERNAL_EDU_LVL, "|", .data$HELIX_HEAD_OF_HOUSE
      ),
      OSE_CODE = paste0(
        .data$OSE_MOTHER_AGE, "|", .data$OSE_DELIVERY_ASSISTANCE, "|", .data$OSE_PLACE_OF_DELIVERY, "|",
        .data$OSE_DELIVERY_MODE, "|", .data$OSE_MULTIPLE_BIRTH, "|", .data$OSE_AGE, "|", .data$OSE_EDUCATION
      ),
      standard_disagg_key = str_trim(coalesce(.data$ID, ""))
    ) %>%
    filter(.data$HELIX_CODE != "|||||" | .data$OSE_CODE != "||||||") %>%
    filter(!is.na(.data$standard_disagg_key), .data$standard_disagg_key != "") %>%
    distinct()
}

# ---------------------------------------------------------------------------
# Core build function
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
      HELIX_HEAD_OF_HOUSE    = .data$HELIX_HEAD_OF_HOUSE,
      OSE_MOTHER_AGE         = .data$OSE_MOTHER_AGE,
      OSE_DELIVERY_ASSISTANCE = .data$OSE_DELIVERY_ASSISTANCE,
      OSE_PLACE_OF_DELIVERY  = .data$OSE_PLACE_OF_DELIVERY,
      OSE_DELIVERY_MODE      = .data$OSE_DELIVERY_MODE,
      OSE_MULTIPLE_BIRTH     = .data$OSE_MULTIPLE_BIRTH,
      OSE_AGE                = .data$OSE_AGE,
      OSE_EDUCATION          = .data$OSE_EDUCATION
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
      OSE_MOTHER_AGE         = coalesce(.data$OSE_MOTHER_AGE, ""),
      OSE_DELIVERY_ASSISTANCE = coalesce(.data$OSE_DELIVERY_ASSISTANCE, ""),
      OSE_PLACE_OF_DELIVERY  = coalesce(.data$OSE_PLACE_OF_DELIVERY, ""),
      OSE_DELIVERY_MODE      = coalesce(.data$OSE_DELIVERY_MODE, ""),
      OSE_MULTIPLE_BIRTH     = coalesce(.data$OSE_MULTIPLE_BIRTH, ""),
      OSE_AGE                = coalesce(.data$OSE_AGE, ""),
      OSE_EDUCATION          = coalesce(.data$OSE_EDUCATION, ""),
      disagg_ref_match = (
        .data$HELIX_SEX != "" | .data$HELIX_AGE != "" |
        .data$HELIX_WEALTH_QUINTILE != "" | .data$HELIX_RESIDENCE != "" |
        .data$HELIX_MATERNAL_EDU_LVL != "" | .data$HELIX_HEAD_OF_HOUSE != "" |
        .data$OSE_MOTHER_AGE != "" | .data$OSE_DELIVERY_ASSISTANCE != "" |
        .data$OSE_PLACE_OF_DELIVERY != "" | .data$OSE_DELIVERY_MODE != "" |
        .data$OSE_MULTIPLE_BIRTH != "" | .data$OSE_AGE != "" |
        .data$OSE_EDUCATION != ""
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
      AGE       = if_else(.data$HELIX_AGE != "", .data$HELIX_AGE, if_else(.data$OSE_AGE != "", .data$OSE_AGE, "_T")),
      RESIDENCE = if_else(.data$HELIX_RESIDENCE != "",        .data$HELIX_RESIDENCE, "_T"),
      WEALTH    = if_else(.data$HELIX_WEALTH_QUINTILE != "",  .data$HELIX_WEALTH_QUINTILE, "_T"),
      EDUCATION = if_else(.data$HELIX_MATERNAL_EDU_LVL != "", .data$HELIX_MATERNAL_EDU_LVL, if_else(.data$OSE_EDUCATION != "", .data$OSE_EDUCATION, "_T")),
      HEAD_OF_HOUSEHOLD = if_else(.data$HELIX_HEAD_OF_HOUSE != "", .data$HELIX_HEAD_OF_HOUSE, "_T"),
      MOTHER_AGE = if_else(.data$OSE_MOTHER_AGE != "", .data$OSE_MOTHER_AGE, "_T"),
      DELIVERY_ASSISTANCE = if_else(.data$OSE_DELIVERY_ASSISTANCE != "", .data$OSE_DELIVERY_ASSISTANCE, "_T"),
      PLACE_OF_DELIVERY = if_else(.data$OSE_PLACE_OF_DELIVERY != "", .data$OSE_PLACE_OF_DELIVERY, "_T"),
      DELIVERY_MODE = if_else(.data$OSE_DELIVERY_MODE != "", .data$OSE_DELIVERY_MODE, "_T"),
      MULTIPLE_BIRTH = if_else(.data$OSE_MULTIPLE_BIRTH != "", .data$OSE_MULTIPLE_BIRTH, "_T"),
      REGION    = derive_region_dim(.),
      RESIDENCE = if_else(.data$RESIDENCE == "_T",
                          derive_residence_from_region_context(.),
                          .data$RESIDENCE),
      SEX       = if_else(.data$SEX == "_T",
                          derive_sex_from_region_context(.),
                          .data$SEX),
      REF_AREA    = coalesce(get_chr_col(., "REF_AREA"), get_chr_col(., "ISO3Code"), get_chr_col(., "CND_Country_Code")),
      TIME_PERIOD = coalesce(get_chr_col(., "TIME_PERIOD"), get_chr_col(., "CMRS_year"), get_chr_col(., "warehouse_year"), get_chr_col(., "middle_year")),
      INDICATOR   = coalesce(get_chr_col(., "INDICATOR"), get_chr_col(., "IndicatorCode"), get_chr_col(., "Indicator")),
      VALUE       = coalesce(get_num_col(., "VALUE"), get_num_col(., "r"), get_num_col(., "r_raw"))
    ) %>%
    # --- ZWE Survey 2879 TIME_PERIOD correction ---
    # TODO(upstream): CMRS source has TIME_PERIOD=2013 and CMRS_year_exact=2013.024
    # for this survey, but the correct fieldwork midpoint maps to 2012 (decimal
    # 2012.92213114754).  DW-Production hardcodes this in 1g_country_preferred.R.
    # Fix the source data in CMRS so this hardcode can be removed.
    {
      sid_col <- get_chr_col(., "UNICEF_Survey_ID")
      ra_col  <- get_chr_col(., "REF_AREA")
      is_2879 <- !is.na(sid_col) & sid_col == "2879" &
                 !is.na(ra_col)  & ra_col  == "ZWE"
      if (any(is_2879)) {
        message("ZWE Survey 2879: correcting TIME_PERIOD 2013 -> 2012 and ",
                "CMRS_year_exact -> 2012.92213114754 (", sum(is_2879), " rows)")
        out <- .
        out$TIME_PERIOD[is_2879] <- "2012"
        if ("CMRS_year_exact" %in% names(out)) {
          out$CMRS_year_exact[is_2879] <- "2012.92213114754"
        }
        out
      } else {
        .
      }
    } %>%
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
      "HELIX_CODE",
      "OSE_MOTHER_AGE", "OSE_DELIVERY_ASSISTANCE", "OSE_PLACE_OF_DELIVERY",
      "OSE_DELIVERY_MODE", "OSE_MULTIPLE_BIRTH", "OSE_AGE", "OSE_EDUCATION",
      "OSE_CODE"
    ))) %>%
    relocate(any_of(c("REF_AREA", "TIME_PERIOD", "INDICATOR",
                      "SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION",
                      "HEAD_OF_HOUSEHOLD", "MOTHER_AGE", "DELIVERY_ASSISTANCE",
                      "PLACE_OF_DELIVERY", "DELIVERY_MODE", "MULTIPLE_BIRTH",
                      "REGION", "VALUE")),
             .before = everything()) %>%
    as_tibble()
}

# ---------------------------------------------------------------------------
# Post-build deduplication
#
# Removes exact duplicate analytical-key rows when the value columns are
# also identical. This handles source-data cataloguing errors where the
# same observation is entered under multiple standard_disagg IDs that
# resolve to the same analytical key. A message is emitted for every
# group of duplicates removed, and the duplicates are returned invisibly
# for logging/reporting.
# ---------------------------------------------------------------------------

dedup_analytical_key <- function(df) {
  dim_cols <- c("SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION",
                "HEAD_OF_HOUSEHOLD", "MOTHER_AGE", "DELIVERY_ASSISTANCE",
                "PLACE_OF_DELIVERY", "DELIVERY_MODE", "MULTIPLE_BIRTH", "REGION")

  key_cols <- intersect(
    c("UNICEF_Survey_ID", "REF_AREA", "TIME_PERIOD", "INDICATOR", dim_cols),
    names(df)
  )

  value_cols <- intersect(
    c("VALUE", "r", "se", "ll", "ul", "weighted_N", "unweighted_N"),
    names(df)
  )

  compare_cols <- c(key_cols, value_cols)
  before_n <- nrow(df)

  # Build a composite key string for fast duplicate detection (base R)
  composite <- do.call(paste, c(df[compare_cols], sep = "\x1F"))
  is_dup <- duplicated(composite)
  removed_n <- sum(is_dup)

  if (removed_n == 0L) {
    message("Dedup: no duplicate analytical-key rows with identical values found.")
    return(df)
  }

  # Log sample of removed rows (cap at 20 to avoid flooding output)
  removed_idx <- which(is_dup)
  if (all(c("entryid", "standard_disagg", "REF_AREA", "TIME_PERIOD", "INDICATOR") %in% names(df))) {
    show_n <- min(length(removed_idx), 20L)
    for (idx in removed_idx[seq_len(show_n)]) {
      message(
        "Dedup: removing duplicate row for ",
        df$REF_AREA[idx], " ", df$TIME_PERIOD[idx], " ", df$INDICATOR[idx],
        " [entryid: ", df$entryid[idx],
        ", standard_disagg: ", df$standard_disagg[idx], "]"
      )
    }
    if (removed_n > show_n) {
      message("Dedup: ... and ", removed_n - show_n, " more duplicate rows (logging capped)")
    }
  }

  deduped <- df[!is_dup, ]
  message("Dedup: removed ", removed_n, " duplicate row(s), ", nrow(deduped), " rows remain.")
  deduped
}

# ---------------------------------------------------------------------------
# Preferred source selection (ported from DW-Production 1g_country_preferred.R)
# ---------------------------------------------------------------------------

time_period_to_decimal <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x[x %in% c("", ".", "NA", "N/A", "NULL")] <- NA_character_
  x_num <- suppressWarnings(as.numeric(x))
  out <- rep(NA_real_, length(x))
  is_year <- !is.na(x) & grepl("^\\d{4}$", x)
  out[is_year] <- suppressWarnings(as.numeric(x[is_year]))
  is_ym <- !is.na(x) & grepl("^\\d{4}-\\d{2}$", x)
  if (any(is_ym)) {
    yr <- suppressWarnings(as.numeric(substr(x[is_ym], 1, 4)))
    mo <- suppressWarnings(as.numeric(substr(x[is_ym], 6, 7)))
    out[is_ym] <- yr + (mo - 1) / 12
  }
  is_dec <- !is.na(x_num)
  out[is_dec] <- x_num[is_dec]
  out
}

time_period_to_year <- function(x) {
  tpd <- time_period_to_decimal(x)
  out <- rep(NA_integer_, length(tpd))
  has <- !is.na(tpd)
  out[has] <- as.integer(floor(tpd[has]))
  out
}

assign_data_source_priority <- function(df) {
  # Preferred-source selection for non-series indicators.
  # Adds DATA_SOURCE_PRIORITY (1 = preferred, 0 = not) and
  # LATEST_PRIORITY_SOURCE (1 = most recent preferred source across years).
  #
  # Steps (matching DW-Production 1g_country_preferred.R):
  #   1. Deprioritize adjusted estimates when non-adjusted exist

  #   2. Deprioritize non-preferred source types (prefer DHS/MICS/SMART)
  #   3. Deprioritize surveillance when surveys exist
  #   4. Keep latest survey by fieldwork midpoint
  #   5. Tiebreak â€” keep first preferred row within group
  #   6. Flag latest preferred source across all years
  #
  # Grouping: REF_AREA x YEAR x INDICATOR x all 12 analytical dimensions.
  # This ensures preferred selection operates at the same granularity as
  # the analytical key â€” rows in different disaggregation cells never compete.

  has_estimate_type  <- "Estimate_Type" %in% names(df)
  has_source_type    <- "DataSourceTypeGlobal" %in% names(df)
  has_indicator_code <- "IndicatorCode" %in% names(df)
  has_cmrs_exact     <- "CMRS_year_exact" %in% names(df)

  if (!"INDICATOR" %in% names(df))
    stop("INDICATOR column required for assign_data_source_priority()")

  iycf_seeds <- c(
    "BF_EBF", "BF_EIBF", "BF_EXBF_2D", "BF_EXBF", "BF_CBF_12_23", "BF_MIXMF",
    "CF_ASF", "CF_FG_0_T_2", "CF_FG_3_T_4", "CF_ISSSF_FL", "CF_MAD", "CF_MDD",
    "CF_MMF", "CF_ZEROFV"
  )
  preferred_sources <- c("CDHS", "DHS", "SDHS", "IDHS", "DHS-Style",
                          "MICS", "MICS-DHS", "SMART")

  # --- Derive working columns (prefixed with .pref_ to avoid collisions) ---
  # ZWE Survey 2879 hardcoded TIME_PERIOD correction (uses working copy only)
  has_zwe_cols <- all(c("REF_AREA", "UNICEF_Survey_ID") %in% names(df))
  df <- df %>%
    mutate(
      .pref_tp = if (has_zwe_cols) {
        if_else(
          REF_AREA == "ZWE" & as.character(UNICEF_Survey_ID) == "2879",
          "2012.92213114754", as.character(TIME_PERIOD)
        )
      } else {
        as.character(TIME_PERIOD)
      },
      # Use CMRS_year_exact for sub-year precision when available so that
      # surveys sharing the same calendar year are ranked by fieldwork
      # midpoint (matching DW-Production behaviour).  Fall back to
      # TIME_PERIOD when the column is absent or NA.
      .pref_td = if (has_cmrs_exact) {
        td_exact <- suppressWarnings(as.numeric(CMRS_year_exact))
        td_fallback <- time_period_to_decimal(.pref_tp)
        td <- coalesce(td_exact, td_fallback)
        if (has_zwe_cols) {
          if_else(
            REF_AREA == "ZWE" & as.character(UNICEF_Survey_ID) == "2879",
            2012.92213114754, td
          )
        } else {
          td
        }
      } else {
        time_period_to_decimal(.pref_tp)
      },
      .pref_year = as.character(time_period_to_year(.pref_tp)),
      .pref_row_id = row_number(),
      .pref_seed = toupper(trimws(sub("^NT_", "", INDICATOR))),
      .pref_is_iycf = .pref_seed %in% iycf_seeds,
      .pref_adj = if (has_estimate_type) coalesce(Estimate_Type == "Adjusted", FALSE) else FALSE,
      .pref_stype = if (has_source_type) coalesce(DataSourceTypeGlobal, "") else "",
      .pref_ptype = .pref_stype %in% preferred_sources,
      .pref_surv  = .pref_stype != "Surveillance"
    )

  grp <- intersect(
    c("REF_AREA", ".pref_year", "INDICATOR", "SEX", "AGE",
      "WEALTH", "RESIDENCE", "EDUCATION", "HEAD_OF_HOUSEHOLD",
      "MOTHER_AGE", "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY",
      "DELIVERY_MODE", "MULTIPLE_BIRTH", "REGION"),
    names(df)
  )

  # Only-survey flag
  df <- df %>%
    group_by(across(all_of(grp))) %>%
    mutate(.pref_only = n() == 1L) %>%
    ungroup()

  df$DATA_SOURCE_PRIORITY <- 1L

  # STEP 1 â€” adjusted vs non-adjusted
  if (has_estimate_type) {
    df <- df %>%
      group_by(across(all_of(grp))) %>%
      mutate(.pref_nadj = sum(!.pref_adj, na.rm = TRUE)) %>%
      ungroup() %>%
      mutate(DATA_SOURCE_PRIORITY = if_else(
        coalesce(DATA_SOURCE_PRIORITY == 1L & .pref_adj &
                   !.pref_only & .pref_nadj > 0L & !.pref_is_iycf, FALSE),
        0L, DATA_SOURCE_PRIORITY
      )) %>%
      select(-.pref_nadj)
  }

  # STEP 2 â€” preferred source types
  if (has_source_type) {
    pc <- df %>%
      filter(DATA_SOURCE_PRIORITY == 1L) %>%
      group_by(across(all_of(grp))) %>%
      summarise(.pref_pn = sum(.pref_ptype, na.rm = TRUE), .groups = "drop")
    df <- df %>%
      left_join(pc, by = grp) %>%
      mutate(
        .pref_pn = coalesce(.pref_pn, 0L),
        DATA_SOURCE_PRIORITY = if_else(
          coalesce(DATA_SOURCE_PRIORITY == 1L & !.pref_ptype &
                     .pref_pn > 0L & !.pref_is_iycf, FALSE),
          0L, DATA_SOURCE_PRIORITY
        )
      ) %>%
      select(-.pref_pn)
  }

  # STEP 3 â€” survey vs surveillance
  if (has_source_type) {
    sc <- df %>%
      filter(DATA_SOURCE_PRIORITY == 1L) %>%
      group_by(across(all_of(grp))) %>%
      summarise(.pref_sn = sum(.pref_surv, na.rm = TRUE), .groups = "drop")
    df <- df %>%
      left_join(sc, by = grp) %>%
      mutate(
        .pref_sn = coalesce(.pref_sn, 0L),
        DATA_SOURCE_PRIORITY = if_else(
          coalesce(DATA_SOURCE_PRIORITY == 1L &
                     .pref_stype == "Surveillance" & !.pref_only &
                     .pref_sn > 0L & !.pref_is_iycf, FALSE),
          0L, DATA_SOURCE_PRIORITY
        )
      ) %>%
      select(-.pref_sn)
  }

  # STEP 4 â€” latest fieldwork midpoint
  lm <- df %>%
    filter(DATA_SOURCE_PRIORITY == 1L) %>%
    group_by(across(all_of(grp))) %>%
    summarise(.pref_mx = max(.pref_td, na.rm = TRUE), .groups = "drop") %>%
    mutate(.pref_mx = if_else(is.infinite(.pref_mx), NA_real_, .pref_mx))
  df <- df %>%
    left_join(lm, by = grp) %>%
    mutate(DATA_SOURCE_PRIORITY = if_else(
      coalesce(DATA_SOURCE_PRIORITY == 1L & (.pref_td < .pref_mx), FALSE),
      0L, DATA_SOURCE_PRIORITY
    )) %>%
    select(-.pref_mx)

  # STEP 5 â€” tiebreak: keep first preferred per group
  df <- df %>%
    group_by(across(all_of(grp))) %>%
    arrange(
      desc(DATA_SOURCE_PRIORITY), desc(.pref_td),
      desc(suppressWarnings(as.numeric(TIME_PERIOD))),
      .pref_row_id,
      .by_group = TRUE
    ) %>%
    mutate(
      .pref_cnt5 = sum(DATA_SOURCE_PRIORITY == 1L, na.rm = TRUE),
      .pref_rnk5 = cumsum(DATA_SOURCE_PRIORITY == 1L),
      DATA_SOURCE_PRIORITY = if_else(
        .pref_cnt5 > 1L & DATA_SOURCE_PRIORITY == 1L & .pref_rnk5 > 1L,
        0L, DATA_SOURCE_PRIORITY
      )
    ) %>%
    ungroup() %>%
    select(-.pref_cnt5, -.pref_rnk5)

  # STEP 6 â€” flag latest preferred source across years
  cy_grp <- setdiff(grp, ".pref_year")
  df <- df %>%
    group_by(across(all_of(cy_grp))) %>%
    mutate(
      .pref_lt = {
        pt <- .pref_td[DATA_SOURCE_PRIORITY == 1L & !is.na(.pref_td)]
        if (length(pt) > 0) max(pt) else NA_real_
      },
      LATEST_PRIORITY_SOURCE = if_else(
        DATA_SOURCE_PRIORITY == 1L &
          !is.na(.pref_td) & !is.na(.pref_lt) & .pref_td == .pref_lt,
        1L, 0L
      )
    ) %>%
    ungroup() %>%
    select(-.pref_lt)

  # --- Clean working columns ---
  df <- df %>% select(-starts_with(".pref_"))

  n_total  <- nrow(df)
  n_pref   <- sum(df$DATA_SOURCE_PRIORITY == 1L, na.rm = TRUE)
  n_latest <- sum(df$LATEST_PRIORITY_SOURCE == 1L, na.rm = TRUE)
  message(
    "Preferred source: ", n_pref, " of ", n_total,
    " rows preferred (", round(100 * n_pref / n_total, 1), "%)",
    "; ", n_latest, " latest-priority rows"
  )
  df
}

# ---------------------------------------------------------------------------
# Slim-column priority assignment (memory-efficient)
# ---------------------------------------------------------------------------
# Reads only the columns needed by assign_data_source_priority(), computes
# priorities on the small frame, then splices the two result columns back
# into the full parquet via Arrow Table operations — avoiding loading all
# columns into R memory.

.priority_input_col_names <- c(
  "INDICATOR", "REF_AREA", "TIME_PERIOD", "UNICEF_Survey_ID",
  "CMRS_year_exact", "Estimate_Type", "DataSourceTypeGlobal", "IndicatorCode",
  "SEX", "AGE", "WEALTH", "RESIDENCE", "EDUCATION", "HEAD_OF_HOUSEHOLD",
  "MOTHER_AGE", "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY",
  "DELIVERY_MODE", "MULTIPLE_BIRTH", "REGION"
)

assign_priority_to_parquet <- function(parquet_path) {
  schema    <- arrow::open_dataset(parquet_path)$schema
  all_names <- schema$names
  slim_cols <- intersect(.priority_input_col_names, all_names)

  message(
    "Reading ", length(slim_cols), " of ", length(all_names),
    " columns for priority computation: ", parquet_path
  )
  slim <- arrow::read_parquet(parquet_path, col_select = dplyr::all_of(slim_cols))
  slim$.orig_row_idx <- seq_len(nrow(slim))

  slim <- assign_data_source_priority(slim)

  # Restore original row order and extract only the result columns
  slim <- slim[order(slim$.orig_row_idx), ]
  dsp_vec <- slim$DATA_SOURCE_PRIORITY
  lps_vec <- slim$LATEST_PRIORITY_SOURCE
  rm(slim); gc()


  # Read full file as Arrow Table (columnar, no R data-frame expansion)
  tbl <- arrow::read_parquet(parquet_path, as_data_frame = FALSE)

  # Drop old priority columns if present
  drop_names <- intersect(
    c("DATA_SOURCE_PRIORITY", "LATEST_PRIORITY_SOURCE"), tbl$schema$names
  )
  if (length(drop_names) > 0) {
    keep_idx <- which(!tbl$schema$names %in% drop_names) - 1L
    tbl <- tbl$SelectColumns(keep_idx)
  }

  # Append new priority columns
  tbl <- tbl$AddColumn(
    tbl$num_columns,
    arrow::field("DATA_SOURCE_PRIORITY", arrow::int32()),
    arrow::chunked_array(arrow::Array$create(dsp_vec, type = arrow::int32()))
  )
  tbl <- tbl$AddColumn(
    tbl$num_columns,
    arrow::field("LATEST_PRIORITY_SOURCE", arrow::int32()),
    arrow::chunked_array(arrow::Array$create(lps_vec, type = arrow::int32()))
  )
  rm(dsp_vec, lps_vec); gc()

  arrow::write_parquet(tbl, parquet_path, compression = "zstd")
  message("Wrote: ", parquet_path)
  invisible(parquet_path)
}

# ---------------------------------------------------------------------------
# Convenience runners
# ---------------------------------------------------------------------------

write_accepted_subset <- function(all_data, output_file,
                                  include_categories = "Accepted") {
  if (!("DataSourceDecisionCategory" %in% names(all_data))) {
    stop("DataSourceDecisionCategory column not found for accepted-subset filtering.")
  }
  accepted <- all_data[
    !is.na(all_data$DataSourceDecisionCategory) &
      as.character(all_data$DataSourceDecisionCategory) %in% include_categories, ]
  accepted_path <- file.path(layer2_output_dir, output_file)
  arrow::write_parquet(accepted, accepted_path, compression = "zstd")
  message(
    "Wrote accepted subset: ", accepted_path,
    " (", nrow(accepted), " of ", nrow(all_data), " rows)"
  )
  invisible(accepted)
}

run_single_dataset <- function(dataset_file, output_file, decision_categories = NULL) {
  disagg_map <- read_disagg_map()
  input_path <- file.path(cmrs_input_dir, dataset_file)
  source_data <- if (grepl("\\.csv$", dataset_file, ignore.case = TRUE)) {
    readr::read_csv(input_path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character()))
  } else {
    haven::read_dta(input_path)
  }

  if (!is.null(decision_categories)) {
    if (!("DataSourceDecisionCategory" %in% names(source_data))) {
      stop(
        "Requested decision-category filter, but DataSourceDecisionCategory is missing in ",
        dataset_file,
        "."
      )
    }

    allowed <- as.character(decision_categories)
    before_n <- nrow(source_data)
    source_data <- source_data %>%
      mutate(DataSourceDecisionCategory = as.character(.data$DataSourceDecisionCategory)) %>%
      filter(coalesce(.data$DataSourceDecisionCategory, "") %in% allowed)

    message(
      "Applied decision-category filter [",
      paste(allowed, collapse = ", "),
      "] on ", dataset_file, ": kept ", nrow(source_data), " of ", before_n, " rows"
    )
  }

  layer2 <- build_layer2_dataset(source_data, disagg_map, dataset_name = dataset_file)
  output_path <- file.path(layer2_output_dir, output_file)
  arrow::write_parquet(layer2, output_path, compression = "zstd")
  message("Wrote: ", output_path)
  invisible(layer2)
}

run_combined_datasets <- function(dataset_files, output_file, decision_categories = NULL) {
  disagg_map <- read_disagg_map()

  layer2_list <- lapply(dataset_files, function(dataset_file) {
    input_path <- file.path(cmrs_input_dir, dataset_file)
    source_data <- if (grepl("\\.csv$", dataset_file, ignore.case = TRUE)) {
      readr::read_csv(input_path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character()))
    } else {
      haven::read_dta(input_path)
    }

    if (!is.null(decision_categories)) {
      if (!("DataSourceDecisionCategory" %in% names(source_data))) {
        stop(
          "Requested decision-category filter, but DataSourceDecisionCategory is missing in ",
          dataset_file,
          "."
        )
      }

      allowed <- as.character(decision_categories)
      before_n <- nrow(source_data)
      source_data <- source_data %>%
        mutate(DataSourceDecisionCategory = as.character(.data$DataSourceDecisionCategory)) %>%
        filter(coalesce(.data$DataSourceDecisionCategory, "") %in% allowed)

      message(
        "Applied decision-category filter [",
        paste(allowed, collapse = ", "),
        "] on ", dataset_file, ": kept ", nrow(source_data), " of ", before_n, " rows"
      )
    }

    build_layer2_dataset(source_data, disagg_map, dataset_name = dataset_file)
  })

  layer2 <- dplyr::bind_rows(layer2_list)
  output_path <- file.path(layer2_output_dir, output_file)
  arrow::write_parquet(layer2, output_path, compression = "zstd")

  message("Wrote: ", output_path)
  invisible(layer2)
}
