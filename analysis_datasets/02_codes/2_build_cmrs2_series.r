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
