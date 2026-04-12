suppressPackageStartupMessages({
  library(readr)
  library(haven)
  library(dplyr)
  library(tidyr)
  library(tibble)
})

script_path <- "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/analytical_database/build_layer2_datasets.r"
script_lines <- readLines(script_path)
cut_line <- grep("^input_cmrs_dir <-", script_lines)[1] - 1

eval(parse(text = paste(script_lines[1:cut_line], collapse = "\n")))

input_cmrs_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard"
disagg_map_path <- "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/reference_data_manager/indicators/reference_disaggregations.csv"
layer2_output_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_database"

disagg_map <- read_csv(disagg_map_path, show_col_types = FALSE)

for (dataset_name in c("bw", "iod")) {
  input_file <- if (dataset_name == "bw") "CMRS_BW.dta" else "CMRS_IOD.dta"
  source_data <- read_dta(file.path(input_cmrs_dir, input_file))
  layer2_data <- build_layer2_dataset(source_data, disagg_map)
  output_csv <- file.path(layer2_output_dir, paste0("layer2_", dataset_name, ".csv"))
  write_csv(layer2_data, output_csv)
  cat("Wrote:", output_csv, "\n")
  cat(dataset_name, "rows=", nrow(layer2_data), "na_sex=", sum(is.na(layer2_data$SEX)), "na_age=", sum(is.na(layer2_data$AGE)), "\n", sep = "")
}
