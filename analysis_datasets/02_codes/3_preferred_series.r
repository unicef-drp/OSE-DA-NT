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

# --- Slim-column read: only need grouping cols + TIME_PERIOD ---------------
grp <- c("REF_AREA", "IndicatorCode", "SEX", "AGE", "RESIDENCE", "WEALTH",
         "EDUCATION", "HEAD_OF_HOUSEHOLD", "MOTHER_AGE",
         "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY", "DELIVERY_MODE",
         "MULTIPLE_BIRTH", "REGION")

schema    <- arrow::open_dataset(accepted_path)$schema
all_names <- schema$names
slim_cols <- intersect(c("TIME_PERIOD", grp), all_names)

message(
  "Reading ", length(slim_cols), " of ", length(all_names),
  " columns for series priority: ", accepted_path
)
slim <- arrow::read_parquet(accepted_path, col_select = dplyr::all_of(slim_cols))

# --- All series rows are preferred ----------------------------------------
dsp_vec <- rep(1L, nrow(slim))

# --- Flag latest year per country × indicator × disaggregation cell -------
yr     <- as.integer(slim$TIME_PERIOD)
max_yr <- ave(yr, interaction(slim[intersect(grp, names(slim))], drop = TRUE),
              FUN = max)
lps_vec <- as.integer(yr == max_yr)
n_total <- nrow(slim)
n_latest <- sum(lps_vec == 1L)
rm(slim, yr, max_yr); gc()

message("Series preferred: all ", n_total, " rows preferred; ",
        n_latest, " latest-priority rows")

# --- Splice columns back via Arrow Table ----------------------------------
tbl <- arrow::read_parquet(accepted_path, as_data_frame = FALSE)

drop_names <- intersect(
  c("DATA_SOURCE_PRIORITY", "LATEST_PRIORITY_SOURCE"), tbl$schema$names
)
if (length(drop_names) > 0) {
  keep_idx <- which(!tbl$schema$names %in% drop_names) - 1L
  tbl <- tbl$SelectColumns(keep_idx)
}

tbl <- tbl$AddColumn(
  tbl$num_columns,
  arrow::field("DATA_SOURCE_PRIORITY", arrow::int32()),
  arrow::chunked_array(arrow::Array$create(dsp_vec, type = arrow::int32()))
)
tbl <- tbl$AddColumn(
  tbl$num_columns,
  arrow::field("LATEST_PRIORITY_SOURCE", arrow::int32()),
  arrow::chunked_array(arrow::Array$create(lps_vec, type = arrow::int32()))
)
rm(dsp_vec, lps_vec); gc()

arrow::write_parquet(tbl, accepted_path, compression = "zstd")
message("Wrote: ", accepted_path)
