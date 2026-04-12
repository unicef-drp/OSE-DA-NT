if (!exists("analysisCodes", envir = .GlobalEnv)) {
	source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "1_layer2_utils.r"))

disagg_map <- read_disagg_map()
source_data <- haven::read_dta(file.path(cmrs_input_dir, "CMRS_IYCF.dta"))
layer2_iycf <- build_layer2_dataset(source_data, disagg_map, dataset_name = "CMRS_IYCF.dta")

output_path <- file.path(layer2_output_dir, "cmrs2_iycf.parquet")
arrow::write_parquet(layer2_iycf, output_path, compression = "snappy")
message("Wrote: ", output_path)
