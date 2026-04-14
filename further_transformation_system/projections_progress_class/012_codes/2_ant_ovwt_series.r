

if (!exists("interdir")) {
  interdir <- file.path(outputdir, "inter")
}

if (!exists("outputdir_projections_temp")) {
  outputdir_projections_temp <- file.path(outputdir_projections, "temp", "split_progress")
}
if (!exists("outputdir_projections_inter")) {
  outputdir_projections_inter <- file.path(outputdir_projections, "inter")
}
if (!exists("outputdir_projections_final")) {
  outputdir_projections_final <- file.path(outputdir_projections, "final")
}
if (!exists("outputdir_projections_exports")) {
  outputdir_projections_exports <- file.path(outputdir_projections_final, "estimates_projections_targets")
}
if (!exists("outputdir_projections_input")) {
  outputdir_projections_input <- file.path(outputdir_projections, "input")
}
dir.create(outputdir_projections_temp, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_inter, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_final, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_exports, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_input, recursive = TRUE, showWarnings = FALSE)

round_digits_prev <- 1
round_digits_aarr <- 2

stata_round <- function(x, digits = 0) {
  factor <- 10 ^ digits
  ifelse(is.na(x), NA_real_, sign(x) * floor(abs(x) * factor + 0.5) / factor)
}

# === Load staged regional + country projection input ===
dw_ant_path <- file.path(outputdir_projections_input, "dw_nut_ant.csv")
if (!file.exists(dw_ant_path)) {
  stop("Projection input file missing: ", dw_ant_path, " - run 1a_import_inputs.r first")
}
message("Using staged NT projection ant input: ", basename(dw_ant_path))

dw_ant_raw <- read_csv(dw_ant_path, show_col_types = FALSE) %>%
  filter(
    INDICATOR == "NT_ANT_WHZ_PO2_MOD",
    AGE == "_T",
    SEX == "_T"
  ) %>%
  mutate(
    TIME_PERIOD = suppressWarnings(as.integer(TIME_PERIOD)),
    OBS_VALUE = suppressWarnings(as.numeric(OBS_VALUE))
  ) %>%
  filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(OBS_VALUE), OBS_VALUE > 0)

api_label_lookup <- get_nt_projection_label_lookup(
  dw_ant_raw,
  default_indicator_label = "Overweight prevalence (weight-for-height > +2 SD)"
)

regional_df <- dw_ant_raw %>%
  filter(REPORTING_LVL == "R") %>%
  mutate(data_level = "Regional")

country_df <- dw_ant_raw %>%
  filter(REPORTING_LVL == "C") %>%
  mutate(data_level = "Country")

ow_analysis_df <- bind_rows(
  regional_df %>% transmute(data_level, REF_AREA, TIME_PERIOD, OBS_VALUE),
  country_df %>% transmute(data_level, REF_AREA, TIME_PERIOD, OBS_VALUE)
)

# Guardrail: each key should be unique; fail fast if upstream data unexpectedly duplicates keys.
dup_keys <- ow_analysis_df %>%
  count(data_level, REF_AREA, TIME_PERIOD, name = "n") %>%
  filter(n > 1)

if (nrow(dup_keys) > 0) {
  stop(
    "Duplicate overweight keys found after filtering (data_level + REF_AREA + TIME_PERIOD). Example: ",
    paste(
      head(
        paste0(dup_keys$data_level, "/", dup_keys$REF_AREA, "/", dup_keys$TIME_PERIOD, " (n=", dup_keys$n, ")"),
        10
      ),
      collapse = "; "
    )
  )
}

# === 2012 baseline prevalence ===
baseline_df <- ow_analysis_df %>%
  filter(TIME_PERIOD == 2012) %>%
  transmute(data_level, REF_AREA, r_2012 = OBS_VALUE)

# === 2024 prevalence ===
ow_2024_df <- ow_analysis_df %>%
  filter(TIME_PERIOD == 2024) %>%
  transmute(data_level, REF_AREA, r_2024 = OBS_VALUE)

# === AARR using modeled data from 2012 to 2024 ===
aarr_df <- ow_analysis_df %>%
  filter(TIME_PERIOD >= 2012, TIME_PERIOD <= 2024) %>%
  mutate(prev_for_aarr = stata_round(OBS_VALUE, round_digits_prev)) %>%
  filter(prev_for_aarr > 0) %>%
  mutate(log_prev = log(prev_for_aarr)) %>%
  group_by(data_level, REF_AREA) %>%
  filter(n() >= 2) %>%
  summarise(
    slope = coef(lm(log_prev ~ TIME_PERIOD))[2],
    current_AARR = stata_round(100 * (1 - exp(slope)), round_digits_aarr),
    .groups = "drop"
  )

# === Combine and classify ===
final_df <- baseline_df %>%
  left_join(ow_2024_df, by = c("data_level", "REF_AREA")) %>%
  left_join(aarr_df, by = c("data_level", "REF_AREA")) %>%
  mutate(
    r_2012_aarr = stata_round(r_2012, round_digits_prev),

    # Required AARRs
    required_AARR_2030 = stata_round(100 * (1 - exp((log(5) - log(r_2012_aarr)) / (2030 - 2012))), round_digits_aarr),
    current_AARR_assess = stata_round(current_AARR, round_digits_aarr),
    required_AARR_2030_assess = stata_round(required_AARR_2030, round_digits_aarr),

    # Threshold: 2024 already <= 5%
    crossthreshold = if_else(r_2024 <= 5, 1, 0),
    thresholdbasis = "r",
    INDICATOR = "overweight",

    # === Full + UNICEF Classification for 2030 target (reduce to <5%) ===
    FullClassification_2030 = case_when(
      is.na(r_2012) | is.na(r_2024) | is.na(current_AARR_assess) ~ "Assessment not Possible",
      crossthreshold == 1 ~ "On track",
      current_AARR_assess >= required_AARR_2030_assess ~ "On track",
      current_AARR_assess > 1.5 ~ "Some progress",
      current_AARR_assess >= -1.5 ~ "No progress",
      current_AARR_assess < -1.5 ~ "Worsening",
      TRUE ~ "Assessment not Possible"
    ),
    UNICEF_Classification_2030 = case_when(
      is.na(r_2012) | is.na(r_2024) | is.na(current_AARR_assess) ~ "Assessment not Possible",
      (crossthreshold == 1 | r_2024 <= 5) ~ "Target met",
      TRUE ~ FullClassification_2030
    ),

    # --- Simple classification for 2030 target (no threshold logic) ---
    SimpleClassification = case_when(
      is.na(current_AARR_assess) ~ "Assessment not Possible",
      current_AARR_assess > 1.5 ~ "improving",
      current_AARR_assess >= -1.5 ~ "no change",
      current_AARR_assess < -1.5 ~ "worsening",
      TRUE ~ "Assessment not Possible"
    )
  )

# === Export classification-only dataset ===
progress_ow <- final_df %>%
  transmute(
    INDICATOR = "NT_ANT_WHZ_PO2_MOD",
    reporting_level = data_level,
    REF_AREA,
    baseline_year = 2012L,
    baseline_value = r_2012,
    latest_year = 2024L,
    latest_value = r_2024,
    projected_value_2030 = if_else(
      !is.na(r_2012) & !is.na(current_AARR),
      stata_round(r_2012 * (1 - (current_AARR / 100))^(2030 - 2012), round_digits_prev),
      NA_real_
    ),
    target_value_2030 = 5,
    target_threshhold = 5,
    target_percent_change = NA_real_,
    no_progress_aarr_lower_buffer = -1.5,
    no_progress_aarr_upper_buffer = 1.5,
    current_aarr = current_AARR,
    required_aarr_2030 = required_AARR_2030,
    crossthreshold,
    assessment_not_possible_flag = NA_integer_,
    fullclassification_2030 = FullClassification_2030,
    unicef_classification_2030 = UNICEF_Classification_2030,
    simpleclassification = SimpleClassification
  ) %>%
  add_nt_projection_progress_metadata(api_label_lookup)

write_csv(progress_ow, file.path(outputdir_projections_inter, "ow_progress_2030.csv"))

progress_append_path <- file.path(outputdir_projections_final, "progress_2030_appended.csv")
if (file.exists(progress_append_path)) {
  progress_appended <- read_nt_projection_progress_file(progress_append_path)
  if (!("INDICATOR" %in% names(progress_appended))) {
    progress_appended <- progress_appended %>%
      mutate(INDICATOR = if ("indicator_code" %in% names(progress_appended)) as.character(indicator_code) else NA_character_)
  }
  progress_appended <- progress_appended %>%
    filter(INDICATOR != "NT_ANT_WHZ_PO2_MOD") %>%
    bind_rows(progress_ow)
} else {
  progress_appended <- progress_ow
}
tryCatch(
  write_csv(progress_appended, progress_append_path),
  error = function(e) {
    warning("Could not write appended progress file: ", progress_append_path, " (", conditionMessage(e), ")")
  }
)

# =============================================================================
# Projections + Targets (LONG FORMAT) — ANCHORED AT 2012
# =============================================================================
years <- 2013:2030

# Projected values (based on r_2012 and current_AARR)
projected_2013_2030 <- final_df %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = stata_round(r_2012 * (1 - (current_AARR / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Projected"
  ) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

# Target values (based on r_2012 and required_AARR_2030)
target_2013_2030 <- final_df %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = stata_round(r_2012 * (1 - (required_AARR_2030 / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Target"
  ) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

# =============================================================================
# Combine with original modelled data
# =============================================================================
agg_df_with_type <- ow_analysis_df %>%
  mutate(TYPE = "Modelled")

combined_df <- bind_rows(
  agg_df_with_type,
  projected_2013_2030,
  target_2013_2030
) %>%
  mutate(
    current_AARR = stata_round(current_AARR, round_digits_aarr),
    required_AARR_2030 = stata_round(required_AARR_2030, round_digits_aarr)
  ) %>%
  arrange(data_level, REF_AREA, TIME_PERIOD, current_AARR, required_AARR_2030) %>%
  # Keep the analysis window from 2000 onward; ANT 2025 is excluded upstream.
  filter(TIME_PERIOD >= 2000) %>%
  select(-any_of(c("time", "regional_r", "regional_n")))

# =============================================================================
# Export estimates/projections/targets workbook
# =============================================================================
export_df <- combined_df %>%
  mutate(
    INDICATOR = "NT_ANT_WHZ_PO2_MOD"
  )
if ("SEX" %in% names(export_df)) {
  export_df <- export_df %>%
    filter(is.na(SEX) | SEX == "_T")
}
export_df <- add_nt_population_columns(export_df, "NT_ANT_WHZ_PO2_MOD") %>%
  select(any_of(c("INDICATOR", "data_level", "REF_AREA", "TIME_PERIOD", "population", "OBS_VALUE", "number_affected", "TYPE")))

codebook <- tribble(
  ~Column, ~Description,
  "INDICATOR", "Indicator code",
  "data_level", "Country or Regional reporting level included in the output",
  "REF_AREA", "Country/Region code",
  "TIME_PERIOD", "Year",
  "population", "Year-specific denominator population for the target group and geography",
  "OBS_VALUE", "Estimate, projection, or target value (%), rounded to 1 decimal place",
  "number_affected", "Calculated count in the same units as population: population * OBS_VALUE / 100",
  "TYPE", "Series type: Modelled/observed estimate, Projected, or Target"
)

wb <- createWorkbook()
addWorksheet(wb, "Data")
addWorksheet(wb, "Codebook")
writeData(wb, "Data", export_df)
writeData(wb, "Codebook", codebook)
saveWorkbook(
  wb,
  file.path(outputdir_projections_exports, "ow_estimates_targets_projections.xlsx"),
  overwrite = TRUE
)

