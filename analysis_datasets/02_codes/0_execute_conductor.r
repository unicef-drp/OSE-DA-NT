# ---------------------------------------------------------------------------
# Script:  0_execute_conductor.r
# Purpose: Orchestrator — builds all CMRS2 analysis datasets in sequence.
#
# Usage:   Source this script from the repo root with working directory set
#          to the OSE-DA-NT project folder, or run any 2_build_cmrs2_*.r
#          script individually for a single domain.
#
# Outputs: cmrs2_series.parquet  (5 series domains combined)
#          cmrs2_bw.parquet      (birth weight)
#          cmrs2_iod.parquet     (iodine deficiency)
#          cmrs2_ant.parquet     (anthropometry)
#          cmrs2_iycf.parquet    (infant & young child feeding)
#
# Dependencies:
#   - profile_OSE-DA-NT.R          (path configuration)
#   - 1_layer2_utils.r             (shared build functions)
#   - reference_disaggregations.csv (disaggregation mapping)
#   - CMRS Stata source files      (upstream input)
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv) || !exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

# source(file.path(analysisCodes, "2_build_cmrs2_series.r"))
# source(file.path(analysisCodes, "2_build_cmrs2_bw.r"))
source(file.path(analysisCodes, "2_build_cmrs2_iod.r"))
# source(file.path(analysisCodes, "2_build_cmrs2_ant.r"))
#source(file.path(analysisCodes, "2_build_cmrs2_iycf.r"))
