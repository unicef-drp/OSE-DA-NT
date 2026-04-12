source("C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/analytical_database/per_dataset/layer2_utils.r")

disagg_map <- read_disagg_map()
source_data <- haven::read_dta(file.path(cmrs_input_dir, "CMRS_IYCF.dta"))
layer2_iycf <- build_layer2_dataset(source_data, disagg_map, dataset_name = "CMRS_IYCF.dta")

bf_indicator_pattern <- "BF|EXBF|BREAST"

bf_indicators <- layer2_iycf %>%
  dplyr::distinct(.data$INDICATOR) %>%
  dplyr::filter(grepl(bf_indicator_pattern, .data$INDICATOR, ignore.case = TRUE)) %>%
  dplyr::pull(.data$INDICATOR)

layer2_iycf_bf <- layer2_iycf %>%
  dplyr::filter(.data$INDICATOR %in% bf_indicators)

layer2_iycf_cf <- layer2_iycf %>%
  dplyr::filter(!.data$INDICATOR %in% bf_indicators)

arrow::write_parquet(
  layer2_iycf_bf,
  file.path(layer2_output_dir, "cmrs2_iycf_bf.parquet"),
  compression = "zstd"
)

arrow::write_parquet(
  layer2_iycf_cf,
  file.path(layer2_output_dir, "cmrs2_iycf_cf.parquet"),
  compression = "zstd"
)

message("Wrote: ", file.path(layer2_output_dir, "cmrs2_iycf_bf.parquet"))
message("Wrote: ", file.path(layer2_output_dir, "cmrs2_iycf_cf.parquet"))
