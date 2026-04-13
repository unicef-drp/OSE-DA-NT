# ---------------------------------------------------------------------------
# Script:  1_execute_conductor.r
# Purpose: Run the stunting top-20 briefing pipeline in order.
# Usage:   source() from the repo root after profile_OSE-DA-NT.R is loaded.
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

# Use getwd() for within-repo paths (supports alternate clone folder names)
codes_dir <- file.path(getwd(), "adhoc_analysis", "stunting_top20_briefing", "02_codes")

message("=== Stunting Top 20 Briefing ===")
message("Codes directory: ", codes_dir)

message("\n--- Step 1: Prepare inputs ---")
source(file.path(codes_dir, "2_prepare_inputs.r"))

message("\n--- Step 2: Compute rankings ---")
source(file.path(codes_dir, "3_stunting_rankings.r"))

message("\n--- Step 3: Create PowerPoint ---")
source(file.path(codes_dir, "4_create_ppt.r"))

message("\n=== Briefing complete. Output in 03_outputs/ ===")
