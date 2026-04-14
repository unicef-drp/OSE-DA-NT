# ---------------------------------------------------------------------------
# Script:  2_prepare_inputs.r
# Purpose: Copy the stunting subset of cmrs2_series_accepted.parquet into the
#          external output folder so the analysis is self-contained.
# Input:   {analysisDatasetsOutputDir}/cmrs2_series_accepted.parquet
# Output:  {adhoc_output_root}/01_inputs/stunting_modeled.parquet
# Note:    Excludes rows where DataSourceDecision == "Accepted and Confidential"
# ---------------------------------------------------------------------------

# Load repo profile for path resolution
profile_path <- file.path(getwd(), "profile_OSE-DA-NT.R")
if (!file.exists(profile_path)) {
  # If running from the adhoc folder, walk up to repo root
  repo_root <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), "..", "..", ".."), winslash = "/")
  profile_path <- file.path(repo_root, "profile_OSE-DA-NT.R")
}
if (file.exists(profile_path)) {
  source(profile_path)
} else {
  stop("Cannot find profile_OSE-DA-NT.R. Run from the repo root or set analysisDatasetsOutputDir manually.")
}

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

# --- Paths ----------------------------------------------------------------
source_parquet <- file.path(analysisDatasetsOutputDir, "cmrs2_series_accepted.parquet")
if (!file.exists(source_parquet)) {
  stop("Source file not found: ", source_parquet)
}

# Output to external location (outside git) to avoid large files in repo
adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis", "stunting_top20_briefing")
input_dir         <- file.path(adhoc_output_root, "01_inputs")
dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)

# --- Read source and filter to stunting modeled estimates -----------------
message("Reading: ", source_parquet)
series_all <- read_parquet(source_parquet)

# Identify stunting modeled indicator (with or without NT_ prefix)
stnt_indicators <- unique(series_all$INDICATOR[
  grepl("HAZ_NE2_MOD$", series_all$INDICATOR, ignore.case = TRUE) &
  !grepl("NUMTH|NE3", series_all$INDICATOR, ignore.case = TRUE)
])

if (length(stnt_indicators) == 0) {
  stop(
    "No modeled stunting indicator found in the data. ",
    "Available indicators: ", paste(head(unique(series_all$INDICATOR), 20), collapse = ", ")
  )
}
message("Using stunting indicator(s): ", paste(stnt_indicators, collapse = ", "))

# Exclude confidential data sources
if ("DataSourceDecision" %in% names(series_all)) {
  n_before <- nrow(series_all)
  series_all <- series_all %>%
    filter(is.na(DataSourceDecision) | DataSourceDecision != "Accepted and Confidential")
  message("Confidentiality filter: kept ", nrow(series_all), " of ", n_before, " rows")
}

# Filter: modeled stunting, national total (all dimension columns == "_T")
stunting_df <- series_all %>%
  filter(
    INDICATOR %in% stnt_indicators,
    SEX       == "_T",
    RESIDENCE == "_T",
    WEALTH    == "_T",
    REGION    == "_T"
  )

message("Rows after filter: ", nrow(stunting_df))

if (nrow(stunting_df) == 0) {
  stop("No national-level modeled stunting data found after filtering.")
}

# --- Write local copy -----------------------------------------------------
out_path <- file.path(input_dir, "stunting_modeled.parquet")
write_parquet(stunting_df, out_path, compression = "zstd")
message("Wrote: ", out_path, " (", nrow(stunting_df), " rows)")

# --- Also extract stunting numbers (NUMTH) indicator ----------------------
numth_indicators <- unique(series_all$INDICATOR[
  grepl("HAZ_NE2_MOD_NUMTH$", series_all$INDICATOR, ignore.case = TRUE)
])

if (length(numth_indicators) == 0) {
  warning("No stunting NUMTH indicator found. Number-based burden rankings will be skipped.")
} else {
  message("Using stunting number indicator(s): ", paste(numth_indicators, collapse = ", "))
  numbers_df <- series_all %>%
    filter(
      INDICATOR %in% numth_indicators,
      SEX       == "_T",
      RESIDENCE == "_T",
      WEALTH    == "_T",
      REGION    == "_T"
    )
  message("Number rows after filter: ", nrow(numbers_df))

  if (nrow(numbers_df) > 0) {
    out_num_path <- file.path(input_dir, "stunting_numbers.parquet")
    write_parquet(numbers_df, out_num_path, compression = "zstd")
    message("Wrote: ", out_num_path, " (", nrow(numbers_df), " rows)")
  } else {
    warning("No national-level stunting number data found after filtering.")
  }
}
