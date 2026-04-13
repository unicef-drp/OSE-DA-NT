# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_iycf.r
# Purpose: Build the CMRS2 infant & young child feeding (IYCF) analysis dataset.
# Input:   CMRS_IYCF.dta
# Output:  cmrs2_iycf.parquet, cmrs2_iycf_accepted.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

run_single_dataset("CMRS_IYCF.dta", "cmrs2_iycf.parquet")
run_single_dataset("CMRS_IYCF.dta", "cmrs2_iycf_accepted.parquet", decision_categories = c("Accepted"))

verify_targets <- c("iycf")
source(file.path(analysisCodes, "0_verify_all_outputs.r"))
