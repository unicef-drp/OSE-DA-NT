# ---------------------------------------------------------------------------
# Script:  1_execute_conductor.r
# Purpose: Orchestrator for the reference_data_manager pipeline.
#          1. Build the wide directory_crosswalk.csv from the editable
#             base csv + external classifications + SOFI progress.
#          2. Re-export every editable repo csv as a legacy-named xlsx so
#             the SharePoint Export folder stays a complete drop-in copy.
#          3. (Optional) Run a crosswalk check vs the latest archive snapshot.
#
# Configuration:
#   run_crosswalk_check  <- TRUE                          # default FALSE
#   crosswalk_check_archive <- "DIRECTORY_CROSSWALK (Beta)_20241212"  # optional
#
# Run from repo root:
#   source("reference_data_manager/02_codes/1_execute_conductor.r")
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv) ||
    !exists("rdmInputDir",   envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

# --- Libraries (centralised for all child scripts) ------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(readxl)
  library(writexl)
  library(haven)
  library(tibble)
  library(data.table)
})

rdmCodes <- file.path(projectFolder, "reference_data_manager", "02_codes")

source(file.path(rdmCodes, "2_build_directory_crosswalk.r"))
source(file.path(rdmCodes, "3_export_legacy_xlsx.r"))
source(file.path(rdmCodes, "3b_export_legacy_dta.r"))

if (exists("run_crosswalk_check", envir = .GlobalEnv) &&
    isTRUE(get("run_crosswalk_check", envir = .GlobalEnv))) {
  source(file.path(rdmCodes, "4_crosswalk_check.r"))
}

message("reference_data_manager: pipeline complete.")
