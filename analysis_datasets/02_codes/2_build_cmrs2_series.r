# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_series.r
# Purpose: Build the CMRS2 combined series analysis dataset.
#          Merges 5 series domains: ANE, ANT, DANT, SANT, VAS.
# Input:   CMRS_SERIES_ANE.dta, CMRS_SERIES_ANT.dta, CMRS_SERIES_DANT.dta,
#          CMRS_SERIES_SANT.dta, CMRS_SERIES_VAS.dta
# Output:  cmrs2_series.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "1_layer2_utils.r"))

run_combined_datasets(
  dataset_files = c(
    "CMRS_SERIES_ANE.dta",
    "CMRS_SERIES_ANT.dta",
    "CMRS_SERIES_DANT.dta",
    "CMRS_SERIES_SANT.dta",
    "CMRS_SERIES_VAS.dta"
  ),
  output_file = "cmrs2_series.parquet"
)
