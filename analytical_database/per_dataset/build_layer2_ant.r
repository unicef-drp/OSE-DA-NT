source("C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/analytical_database/per_dataset/layer2_utils.r")

core_indicators <- c(
  "ANT_HAZ_NE2",
  "ANT_WAZ_NE2",
  "ANT_WHZ_NE3",
  "ANT_WHZ_NE2",
  "ANT_WHZ_PO2"
)

disagg_map <- read_disagg_map()
source_data <- haven::read_dta(file.path(cmrs_input_dir, "CMRS_ANT.dta"))
layer2_ant <- build_layer2_dataset(source_data, disagg_map)

layer2_ant_core <- layer2_ant %>%
  dplyr::filter(.data$INDICATOR %in% core_indicators)

layer2_ant_not_core <- layer2_ant %>%
  dplyr::filter(!.data$INDICATOR %in% core_indicators)

readr::write_csv(
  layer2_ant_core,
  file.path(layer2_output_dir, "layer2_ant_core.csv")
)

readr::write_csv(
  layer2_ant_not_core,
  file.path(layer2_output_dir, "layer2_ant_not_core.csv")
)

message("Wrote: ", file.path(layer2_output_dir, "layer2_ant_core.csv"))
message("Wrote: ", file.path(layer2_output_dir, "layer2_ant_not_core.csv"))
