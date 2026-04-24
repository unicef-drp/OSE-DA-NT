# ---------------------------------------------------------------------------
# Script:  2_build_directory_crosswalk.r
# Purpose: Build the wide directory_crosswalk.csv from:
#            * crosswalk/directory_crosswalk_base.csv  (editable in repo)
#            * external classifications fetched from
#                unicef-drp/Country-and-Region-Metadata (GitHub)
#          Output is written to the repo output mirror only
#          ({githubOutputRoot}/reference_data_manager/).
#
#          Replaces the legacy R scripts:
#            EXTENSION/CROSSWALK/R/SECTION_WIDE_ADD.R
#            EXTENSION/CROSSWALK/R/LDC_UPDATE.R
#
# Inputs:
#   - reference_data_manager/crosswalk/directory_crosswalk_base.csv
#   - https://raw.githubusercontent.com/unicef-drp/Country-and-Region-Metadata/
#       refs/heads/main/output/all_regions_long_format.csv
#
# Outputs:
#   - {githubOutputRoot}/reference_data_manager/directory_crosswalk.csv
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

stopifnot(exists("rdmInputDir"), exists("rdmOutputDir"))

# Editable inputs (repo)
base_csv <- file.path(rdmInputDir, "crosswalk", "directory_crosswalk_base.csv")

# External classification table (long format)
ext_long_url <- "https://raw.githubusercontent.com/unicef-drp/Country-and-Region-Metadata/refs/heads/main/output/all_regions_long_format.csv"

# --- 1. Load base wide crosswalk -------------------------------------------
crosswalk <- readr::read_csv(base_csv, show_col_types = FALSE,
                             col_types = readr::cols(.default = readr::col_character()))

# rename to ISO3Code for join stability
if ("ISO-3 Code" %in% names(crosswalk)) {
  names(crosswalk)[names(crosswalk) == "ISO-3 Code"] <- "ISO3Code"
}

# Patch ISO3 codes for non-standard rows (Kosovo, Channel Islands)
crosswalk$ISO3Code[crosswalk$Country == "Kosovo"]          <- "XKX"
crosswalk$ISO3Code[crosswalk$Country == "Channel Islands"] <- "CHI"

# --- 2. LDC update logic (legacy LDC_UPDATE.R) -----------------------------
# Recode literal NA strings to 'NA ' so they aren't treated as missing.
crosswalk <- crosswalk %>%
  dplyr::mutate(dplyr::across(where(is.character),
                              ~ ifelse(. == "NA", "NA ", .)))

if ("LDC_2020" %in% names(crosswalk)) {
  crosswalk$LDC_2024 <- crosswalk$LDC_2020
  crosswalk$LDC_2024 <- ifelse(crosswalk$ISO3Code %in% c("BTN", "STP"),
                               "No", crosswalk$LDC_2024)
  crosswalk$LDC_Latest <- crosswalk$LDC_2024
}

# --- 3. Merge external classification table (legacy SECTION_WIDE_ADD.R) ----
ext_long <- tryCatch(
  readr::read_csv(ext_long_url, show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character())),
  error = function(e) {
    warning("Could not fetch external classifications: ", conditionMessage(e),
            "\nProceeding without merge.")
    NULL
  }
)

if (!is.null(ext_long)) {
  ext_long <- ext_long[ext_long$Region_Code != "" & !is.na(ext_long$Region_Code), ]
  # Deduplicate (ISO3Code, Region_Code) — keep first occurrence — before
  # widening, otherwise pivot_wider produces list columns.
  ext_long <- dplyr::distinct(ext_long, ISO3Code, Region_Code, .keep_all = TRUE)
  ext_wide <- tidyr::pivot_wider(
    data       = ext_long,
    id_cols    = ISO3Code,
    names_from = Region_Code,
    values_from = Region,
    values_fn  = dplyr::first
  )
  crosswalk <- merge(crosswalk, ext_wide, by = "ISO3Code", all.x = TRUE)

  # rename and replace WB income groups
  if ("WB_Latest" %in% names(crosswalk)) {
    crosswalk <- dplyr::rename(crosswalk,
      WB_2024         = WB_Latest,
      WB_2024_3_Group = WB_Latest_3_Group,
      WB_2024_2_Group = WB_Latest_2_Group)
  }
  wb_income_cols <- intersect(c("WB_HI", "WB_LI", "WB_LMI", "WB_UMI"), names(crosswalk))
  if (length(wb_income_cols) > 0) {
    crosswalk$WB_Latest <- apply(crosswalk[, wb_income_cols, drop = FALSE], 1,
                                 function(x) x[!is.na(x)][1])
    crosswalk <- crosswalk %>%
      dplyr::mutate(WB_Latest = dplyr::recode(WB_Latest,
        "World Bank (low income)"          = "Low Income",
        "World Bank (lower middle income)" = "Lower Middle Income",
        "World Bank (upper middle income)" = "Upper Middle Income",
        "World Bank (high income)"         = "High Income")) %>%
      dplyr::mutate(WB_Latest_3_Group = dplyr::case_when(
        WB_Latest %in% "High Income"                                 ~ "High Income",
        WB_Latest == "Low Income"                                    ~ "Low Income",
        WB_Latest %in% c("Lower Middle Income", "Upper Middle Income") ~ "Middle Income",
        TRUE ~ NA_character_)) %>%
      dplyr::mutate(WB_Latest_2_Group = dplyr::case_when(
        WB_Latest %in% "High Income"                                 ~ "High Income",
        WB_Latest %in% c("Lower Middle Income", "Upper Middle Income", "Low Income") ~ "Low and Middle Income",
        TRUE ~ NA_character_))
  }

  # rename and replace WHO regions
  if ("WHO Region" %in% names(crosswalk)) {
    names(crosswalk)[names(crosswalk) == "WHO Region"] <- "WHO.Region_2024"
  }
  who_cols <- intersect(c("WHO_AFRO", "WHO_AMRO", "WHO_EMRO", "WHO_EURO", "WHO_SEARO", "WHO_WPRO"),
                        names(crosswalk))
  if (length(who_cols) > 0) {
    crosswalk$WHO.Region <- apply(crosswalk[, who_cols, drop = FALSE], 1,
                                  function(x) x[!is.na(x)][1])
  }

  # rename and replace WB regions
  if ("World Bank Regions" %in% names(crosswalk)) {
    names(crosswalk)[names(crosswalk) == "World Bank Regions"] <- "World.Bank.Regions_2024"
  }
  wb_reg_cols <- intersect(c("WB_EAP", "WB_ECA", "WB_LAC", "WB_MNA", "WB_NAR", "WB_SSA", "WB_SAR"),
                           names(crosswalk))
  if (length(wb_reg_cols) > 0) {
    crosswalk$World.Bank.Regions <- apply(crosswalk[, wb_reg_cols, drop = FALSE], 1,
                                          function(x) x[!is.na(x)][1])
  }
}

# --- 4. Write outputs ------------------------------------------------------
out_repo <- file.path(rdmOutputDir, "directory_crosswalk.csv")
dir.create(dirname(out_repo), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(crosswalk, out_repo)
message("Wrote: ", out_repo, "  (", nrow(crosswalk), " rows x ", ncol(crosswalk), " cols)")

# Note: this script never writes to the legacy SharePoint Export folder.
# To update SharePoint, copy from the repo output mirror manually after review.

invisible(crosswalk)
