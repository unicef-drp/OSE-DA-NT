# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_bw.r
# Purpose: Build the CMRS2 birth weight (BW) analysis dataset.
# Input:   CMRS_BW.dta
# Output:  cmrs2_bw.parquet, cmrs2_bw_accepted.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

all_data <- run_single_dataset("CMRS_BW.dta", "cmrs2_bw.parquet")
write_accepted_subset(all_data, "cmrs2_bw_accepted.parquet")

verify_targets <- c("bw")
source(file.path(analysisCodes, "0_verify_all_outputs.r"))
