source("C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/analysis_datasets/02_codes/1_layer2_utils.r")

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
