# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_series.r
# Purpose: Build the CMRS2 combined series analysis dataset.
#          Merges 5 series domains: ANE, ANT, DANT, SANT, VAS.
# Input:   CMRS_SERIES_ANE.dta, CMRS_SERIES_ANT.dta, CMRS_SERIES_DANT.dta,
#          CMRS_SERIES_SANT.dta, CMRS_SERIES_VAS.dta
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
  "CMRS_SERIES_VAS.dta"
)

run_combined_datasets(series_files, output_file = "cmrs2_series.parquet")
run_combined_datasets(series_files, output_file = "cmrs2_series_accepted.parquet", decision_categories = c("Accepted"))

verify_targets <- c("series")
source(file.path(analysisCodes, "0_verify_all_outputs.r"))
