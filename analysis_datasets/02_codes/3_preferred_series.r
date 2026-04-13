# ---------------------------------------------------------------------------
# Script:  3_preferred_series.r
# Purpose: Add DATA_SOURCE_PRIORITY and LATEST_PRIORITY_SOURCE columns to the
#          accepted series dataset.  Series are authoritative modelled estimates
#          so every row is preferred (DATA_SOURCE_PRIORITY = 1).
#          LATEST_PRIORITY_SOURCE flags the most recent year per country ×
#          indicator × disaggregation cell.
# Input:   cmrs2_series_accepted.parquet
# Output:  cmrs2_series_accepted.parquet (overwritten with priority columns)
# ---------------------------------------------------------------------------

if (!exists("analysisCodes", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "0_layer2_utils.r"))

accepted_file <- "cmrs2_series_accepted.parquet"
accepted_path <- file.path(layer2_output_dir, accepted_file)

message("Reading: ", accepted_path)
df <- arrow::read_parquet(accepted_path)

# --- All series rows are preferred ----------------------------------------
df$DATA_SOURCE_PRIORITY <- 1L

# --- Flag latest year per country × indicator × disaggregation cell -------
grp <- c("REF_AREA", "INDICATOR", "SEX", "AGE", "RESIDENCE", "WEALTH",
         "EDUCATION", "HEAD_OF_HOUSEHOLD", "MOTHER_AGE",
         "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY", "DELIVERY_MODE",
         "MULTIPLE_BIRTH", "REGION")

yr <- as.integer(df$TIME_PERIOD)
max_yr <- ave(yr, interaction(df[grp], drop = TRUE), FUN = max)
df$LATEST_PRIORITY_SOURCE <- as.integer(yr == max_yr)

n_latest <- sum(df$LATEST_PRIORITY_SOURCE == 1L)
message("Series preferred: all ", nrow(df), " rows preferred; ",
        n_latest, " latest-priority rows")

arrow::write_parquet(df, accepted_path, compression = "zstd")
message("Wrote: ", accepted_path)
