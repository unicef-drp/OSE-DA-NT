# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_series.r
# Purpose: Build the CMRS2 combined series analysis dataset.
#          Merges 5 series domains: ANE, ANT, DANT, SANT, VAS.
# Input:   CMRS_SERIES_ANE.dta, CMRS_SERIES_ANT.dta, CMRS_SERIES_DANT.dta,
#          CMRS_SERIES_SANT.dta, CMRS_SERIES_VAS.dta,
#          cmrs_series_lbw.csv
# Output:  cmrs2_series.parquet, cmrs2_series_accepted.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

series_files <- c(
  "CMRS_SERIES_ANE.dta",
  "CMRS_SERIES_ANT.dta",
  "CMRS_SERIES_DANT.dta",
  "CMRS_SERIES_SANT.dta",
  "CMRS_SERIES_VAS.dta",
  "cmrs_series_lbw.csv"
)

all_data <- run_combined_datasets(series_files, output_file = "cmrs2_series.parquet")

# ---------------------------------------------------------------------------
# Confidential overrides — mark specific country × indicator rows as
# confidential following CMRS convention: DataSourceDecisionCategory stays
# "Accepted" (so the rows remain in the accepted subset) but
# DataSourceDecision is set to "Accepted and Confidential".
# These compensate for upstream data issues that should eventually be fixed
# in CMRS production (see analysis_datasets/00_documentation/UPSTREAM_SOURCE_DATA_FLAGS.md).
# ---------------------------------------------------------------------------
conf_idx <- rep(FALSE, nrow(all_data))

# NIC: all series estimates are unreliable — flag entire country
conf_idx <- conf_idx | (!is.na(all_data$REF_AREA) & all_data$REF_AREA == "NIC")

# BHR: overweight series estimates are unreliable
conf_idx <- conf_idx | (
  !is.na(all_data$REF_AREA) & all_data$REF_AREA == "BHR" &
  !is.na(all_data$IndicatorCode) & grepl("WHZ.*PO2", all_data$IndicatorCode, ignore.case = TRUE)
)

if (sum(conf_idx) > 0L) {
  all_data$DataSourceDecision[conf_idx] <- "Accepted and Confidential"
  message(
    "Confidential override: flagged ", sum(conf_idx),
    " series rows (NIC all indicators; BHR overweight)"
  )
}

write_accepted_subset(all_data, "cmrs2_series_accepted.parquet")

verify_targets <- c("series")
source(file.path(analysisCodes, "0_verify_all_outputs.r"))
