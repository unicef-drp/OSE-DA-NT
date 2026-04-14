# ---------------------------------------------------------------------------
# Script:  3_preferred_iycf.r
# Purpose: Assign DATA_SOURCE_PRIORITY to the accepted IYCF dataset.
# Input:   cmrs2_iycf_accepted.parquet
# Output:  cmrs2_iycf_accepted.parquet (overwritten with priority columns)
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

accepted_file <- "cmrs2_iycf_accepted.parquet"
accepted_path <- file.path(layer2_output_dir, accepted_file)

assign_priority_to_parquet(accepted_path)
