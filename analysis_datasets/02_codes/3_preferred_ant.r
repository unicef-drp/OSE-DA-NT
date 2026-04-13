# ---------------------------------------------------------------------------
# Script:  3_preferred_ant.r
# Purpose: Assign DATA_SOURCE_PRIORITY to the accepted ANT dataset.
# Input:   cmrs2_ant_accepted.parquet
# Output:  cmrs2_ant_accepted.parquet (overwritten with priority columns)
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

accepted_file <- "cmrs2_ant_accepted.parquet"
accepted_path <- file.path(layer2_output_dir, accepted_file)

message("Reading: ", accepted_path)
df <- arrow::read_parquet(accepted_path)
df <- assign_data_source_priority(df)
arrow::write_parquet(df, accepted_path, compression = "zstd")
message("Wrote: ", accepted_path)
