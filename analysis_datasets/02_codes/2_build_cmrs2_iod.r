# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_iod.r
# Purpose: Build the CMRS2 iodine deficiency (IOD) analysis dataset.
# Input:   CMRS_IOD.dta
# Output:  cmrs2_iod.parquet, cmrs2_iod_accepted.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

all_data <- run_single_dataset("CMRS_IOD.dta", "cmrs2_iod.parquet")
write_accepted_subset(all_data, "cmrs2_iod_accepted.parquet")

verify_targets <- c("iod")
source(file.path(analysisCodes, "0_verify_all_outputs.r"))
