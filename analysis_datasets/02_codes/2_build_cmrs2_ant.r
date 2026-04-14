# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_ant.r
# Purpose: Build the CMRS2 anthropometry (ANT) analysis dataset.
# Input:   CMRS_ANT.dta
# Output:  cmrs2_ant.parquet, cmrs2_ant_accepted.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

all_data <- run_single_dataset("CMRS_ANT.dta", "cmrs2_ant.parquet")
write_accepted_subset(all_data, "cmrs2_ant_accepted.parquet")

verify_targets <- c("ant")
source(file.path(analysisCodes, "0_verify_all_outputs.r"))
