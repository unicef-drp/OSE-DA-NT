# ---------------------------------------------------------------------------
# Script:  3_stunting_rankings.r
# Purpose: Compute three top-20 country rankings for stunting:
#            1. Highest current prevalence
#            2. Biggest improvers over 10 years
#            3. Biggest improvers over 20 years
# Input:   01_inputs/stunting_modeled.parquet
# Output:  03_outputs/stunting_rankings.rds  (list of three data frames)
#          03_outputs/stunting_rankings.csv   (combined, human-readable)
# ---------------------------------------------------------------------------

# --- Paths ----------------------------------------------------------------
if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
# Output to external location (outside git) to avoid large files in repo
adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis", "stunting_top20_briefing")
input_dir  <- file.path(adhoc_output_root, "01_inputs")
output_dir <- file.path(adhoc_output_root, "03_outputs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# --- Load data ------------------------------------------------------------
parquet_path <- file.path(input_dir, "stunting_modeled.parquet")
if (!file.exists(parquet_path)) {
  stop("Input not found: ", parquet_path, ". Run 2_prepare_inputs.r first.")
}

stnt <- read_parquet(parquet_path) %>%
  mutate(
    TIME_PERIOD = as.integer(TIME_PERIOD),
    r       = as.numeric(r)
  ) %>%
  filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(r))

# Detect scale: if max > 1, values are percentages; otherwise proportions
if (max(stnt$r, na.rm = TRUE) <= 1) {
  stnt <- stnt %>% mutate(r = r * 100)
  message("Converted r from proportion to percentage scale.")
}

# --- Determine reference years --------------------------------------------
latest_year <- max(stnt$TIME_PERIOD, na.rm = TRUE)
yr_10_ago   <- latest_year - 10
yr_20_ago   <- latest_year - 20

message("Latest year in data: ", latest_year)
message("10-year baseline:    ", yr_10_ago)
message("20-year baseline:    ", yr_20_ago)

# --- Country name lookup --------------------------------------------------
add_country_name <- function(df) {
  df %>% mutate(
    country_name = countrycode(REF_AREA, origin = "iso3c", destination = "country.name",
                               warn = FALSE)
  )
}

# --- 1. Top 20 highest current prevalence ---------------------------------
top20_highest <- stnt %>%
  filter(TIME_PERIOD == latest_year) %>%
  arrange(desc(r)) %>%
  head(20) %>%
  add_country_name() %>%
  mutate(rank = row_number()) %>%
  select(rank, REF_AREA, country_name, year = TIME_PERIOD, prevalence = r)

message("\n=== Top 20 highest stunting prevalence (", latest_year, ") ===")
print(top20_highest, n = 20)

# --- Helper: compute improvement ------------------------------------------
compute_improvement <- function(data, baseline_year, latest_yr) {
  baseline <- data %>%
    filter(TIME_PERIOD == baseline_year) %>%
    select(REF_AREA, baseline_value = r)

  current <- data %>%
    filter(TIME_PERIOD == latest_yr) %>%
    select(REF_AREA, current_value = r)

  inner_join(baseline, current, by = "REF_AREA") %>%
    mutate(
      change_pp = current_value - baseline_value,
      pct_change = (current_value - baseline_value) / baseline_value * 100
    ) %>%
    filter(change_pp < 0) %>%
    arrange(change_pp) %>%
    head(20) %>%
    add_country_name() %>%
    mutate(rank = row_number()) %>%
    select(rank, REF_AREA, country_name,
           baseline_value, current_value,
           change_pp, pct_change)
}

# --- 2. Top 20 biggest improvers in 10 years ------------------------------
top20_improve_10 <- compute_improvement(stnt, yr_10_ago, latest_year)
message("\n=== Top 20 biggest improvers (", yr_10_ago, "-", latest_year, ") ===")
print(top20_improve_10, n = 20)

# --- 3. Top 20 biggest improvers in 20 years ------------------------------
top20_improve_20 <- compute_improvement(stnt, yr_20_ago, latest_year)
message("\n=== Top 20 biggest improvers (", yr_20_ago, "-", latest_year, ") ===")
print(top20_improve_20, n = 20)

# --- Number-based rankings ------------------------------------------------
num_parquet_path <- file.path(input_dir, "stunting_numbers.parquet")
has_numbers <- file.exists(num_parquet_path)

top20_highest_num    <- NULL
top20_improve_10_num <- NULL
top20_improve_20_num <- NULL

if (has_numbers) {
  stnt_num <- read_parquet(num_parquet_path) %>%
    mutate(
      TIME_PERIOD = as.integer(TIME_PERIOD),
      r       = as.numeric(r)
    ) %>%
    filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(r))
  message("\nNumber data: ", nrow(stnt_num), " rows")

  # Top 20 highest number of stunted children (r in thousands)
  top20_highest_num <- stnt_num %>%
    filter(TIME_PERIOD == latest_year) %>%
    arrange(desc(r)) %>%
    head(20) %>%
    add_country_name() %>%
    mutate(rank = row_number()) %>%
    select(rank, REF_AREA, country_name, year = TIME_PERIOD, number_thousands = r)

  message("\n=== Top 20 highest number of stunted children (", latest_year, ") ===")
  print(top20_highest_num, n = 20)

  # Improvement in numbers
  compute_improvement_num <- function(data, baseline_year, latest_yr) {
    baseline <- data %>%
      filter(TIME_PERIOD == baseline_year) %>%
      select(REF_AREA, baseline_value = r)
    current <- data %>%
      filter(TIME_PERIOD == latest_yr) %>%
      select(REF_AREA, current_value = r)
    inner_join(baseline, current, by = "REF_AREA") %>%
      mutate(
        change_th  = current_value - baseline_value,
        pct_change = (current_value - baseline_value) / baseline_value * 100
      ) %>%
      filter(change_th < 0) %>%
      arrange(change_th) %>%
      head(20) %>%
      add_country_name() %>%
      mutate(rank = row_number()) %>%
      select(rank, REF_AREA, country_name,
             baseline_value, current_value,
             change_th, pct_change)
  }

  top20_improve_10_num <- compute_improvement_num(stnt_num, yr_10_ago, latest_year)
  message("\n=== Top 20 biggest reduction in stunted numbers (", yr_10_ago, "-", latest_year, ") ===")
  print(top20_improve_10_num, n = 20)

  top20_improve_20_num <- compute_improvement_num(stnt_num, yr_20_ago, latest_year)
  message("\n=== Top 20 biggest reduction in stunted numbers (", yr_20_ago, "-", latest_year, ") ===")
  print(top20_improve_20_num, n = 20)
} else {
  message("\nNo stunting number data found. Burden rankings skipped.")
}

# --- Save results ---------------------------------------------------------
results <- list(
  highest              = top20_highest,
  improve_10yr         = top20_improve_10,
  improve_20yr         = top20_improve_20,
  highest_number       = top20_highest_num,
  improve_10yr_number  = top20_improve_10_num,
  improve_20yr_number  = top20_improve_20_num,
  metadata = list(
    latest_year = latest_year,
    yr_10_ago   = yr_10_ago,
    yr_20_ago   = yr_20_ago,
    has_numbers = has_numbers,
    generated   = Sys.time()
  )
)

saveRDS(results, file.path(output_dir, "stunting_rankings.rds"))
message("\nSaved: ", file.path(output_dir, "stunting_rankings.rds"))

# Combined CSV for easy review
combined_csv <- bind_rows(
  top20_highest %>% mutate(ranking = "highest_prevalence",
                           baseline_value = NA_real_, current_value = prevalence,
                           change_pp = NA_real_, pct_change = NA_real_) %>%
    select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
  top20_improve_10 %>% mutate(ranking = paste0("improve_10yr_", yr_10_ago, "_", latest_year)) %>%
    select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
  top20_improve_20 %>% mutate(ranking = paste0("improve_20yr_", yr_20_ago, "_", latest_year)) %>%
    select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
)

if (has_numbers && !is.null(top20_highest_num)) {
  num_csv <- bind_rows(
    top20_highest_num %>% mutate(ranking = "highest_number",
                                 baseline_value = NA_real_, current_value = number_thousands,
                                 change_pp = NA_real_, pct_change = NA_real_) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
    top20_improve_10_num %>% mutate(ranking = paste0("improve_10yr_number_", yr_10_ago, "_", latest_year)) %>%
      rename(change_pp = change_th) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
    top20_improve_20_num %>% mutate(ranking = paste0("improve_20yr_number_", yr_20_ago, "_", latest_year)) %>%
      rename(change_pp = change_th) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
  )
  combined_csv <- bind_rows(combined_csv, num_csv)
}

write_csv(combined_csv, file.path(output_dir, "stunting_rankings.csv"))
message("Saved: ", file.path(output_dir, "stunting_rankings.csv"))
