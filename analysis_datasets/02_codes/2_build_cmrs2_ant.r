# ---------------------------------------------------------------------------
# Script:  2_build_cmrs2_ant.r
# Purpose: Build the CMRS2 anthropometry (ANT) analysis dataset.
# Input:   CMRS_ANT.dta
# Output:  cmrs2_ant.parquet
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "1_layer2_utils.r"))

run_single_dataset("CMRS_ANT.dta", "cmrs2_ant.parquet")
