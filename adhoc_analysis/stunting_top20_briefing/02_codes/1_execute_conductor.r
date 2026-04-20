# ---------------------------------------------------------------------------
# Script:  1_execute_conductor.r
# Purpose: Run the stunting top-20 briefing pipeline in order.
# Usage:   source() from the repo root after profile_OSE-DA-NT.R is loaded.
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

# --- Libraries (centralised for all child scripts) ------------------------
suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(scales)
  library(xml2)
})

for (pkg in c("officer", "rvg", "openxlsx")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
library(officer)
library(rvg)
library(openxlsx)

# Use getwd() for within-repo paths (supports alternate clone folder names)
codes_dir <- file.path(getwd(), "adhoc_analysis", "stunting_top20_briefing", "02_codes")

message("=== Stunting Top 20 Briefing ===")
message("Codes directory: ", codes_dir)

message("\n--- Step 1: Prepare inputs ---")
source(file.path(codes_dir, "2_prepare_inputs.r"))

message("\n--- Step 2: Compute rankings, tables, figures ---")
source(file.path(codes_dir, "3_stunting_rankings.r"))

# Step 3 (product generation) is run manually after the tables/figures
# review cycle is complete. The active on-disk Word generator is:
source(file.path(codes_dir, "4_create_two_pager.r"))

# moved to old pending review
#   5c_create_ppt_combined.r  — PPT combined (content + design)

message("\n=== Data analysis complete. Review outputs in 03_outputs/ ===")
