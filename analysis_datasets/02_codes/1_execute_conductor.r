# ---------------------------------------------------------------------------
# Script:  1_execute_conductor.r
# Purpose: Orchestrator — builds all CMRS2 analysis datasets in sequence,
#          then assigns preferred-source priority to accepted outputs.
#          Each 2_build_* script produces both all-estimates and accepted-only
#          outputs. Each 3_preferred_* script adds DATA_SOURCE_PRIORITY and
#          LATEST_PRIORITY_SOURCE to the accepted output.
#          Run any script individually for a single domain.
#
# Validation (optional):
#   Set run_verify <- TRUE before sourcing to run 0_verify_all_outputs.r
#   after the build.  Optionally set verify_targets to limit scope:
#     run_verify     <- TRUE
#     verify_targets <- c("ant")        # validate only ant
#     source("analysis_datasets/02_codes/1_execute_conductor.r")
#
# Dependencies:
#   - profile_OSE-DA-NT.R          (path configuration)
#   - 0_layer2_utils.r             (shared build functions)
#   - reference_disaggregations.csv (disaggregation mapping)
#   - CMRS Stata source files      (upstream input)
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv) || !exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

source(file.path(analysisCodes, "2_build_cmrs2_series.r"))
source(file.path(analysisCodes, "2_build_cmrs2_bw.r"))
source(file.path(analysisCodes, "2_build_cmrs2_iod.r"))
source(file.path(analysisCodes, "2_build_cmrs2_ant.r"))
source(file.path(analysisCodes, "2_build_cmrs2_iycf.r"))

 source(file.path(analysisCodes, "3_preferred_series.r"))
 source(file.path(analysisCodes, "3_preferred_bw.r"))
 source(file.path(analysisCodes, "3_preferred_iod.r"))
 source(file.path(analysisCodes, "3_preferred_ant.r"))
 source(file.path(analysisCodes, "3_preferred_iycf.r"))

# --- Optional post-build validation ---
# Set run_verify <- TRUE before sourcing conductor to enable.
# verify_targets controls which datasets to check (defaults to all built).
if (exists("run_verify", envir = .GlobalEnv) &&
    isTRUE(get("run_verify", envir = .GlobalEnv))) {
  if (!exists("verify_targets", envir = .GlobalEnv)) {
    verify_targets <- c("series", "ant", "bw", "iod", "iycf")
  }
  source(file.path(analysisCodes, "0_verify_all_outputs.r"))
}
