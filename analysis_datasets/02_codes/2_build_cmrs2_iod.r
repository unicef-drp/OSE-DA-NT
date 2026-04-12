# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_iod.r
# Purpose: Build the CMRS2 iodine deficiency (IOD) analysis dataset.
# Input:   CMRS_IOD.dta
# Output:  cmrs2_iod.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "1_layer2_utils.r"))

run_single_dataset("CMRS_IOD.dta", "cmrs2_iod.parquet")
