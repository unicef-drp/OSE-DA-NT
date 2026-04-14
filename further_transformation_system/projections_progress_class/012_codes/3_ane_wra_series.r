# projections and targets for anemia prevalence (women 15-49)

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

# =============================================================================
# Load staged regional + country projection input
# =============================================================================
dw_ane_path <- file.path(outputdir_projections_input, "dw_nut_ane.csv")
if (!file.exists(dw_ane_path)) {
  stop("Projection input file missing: ", dw_ane_path, " - run 1a_import_inputs.r first")
}
message("Using staged NT projection ane input: ", basename(dw_ane_path))

dw_ane_raw <- read_csv(dw_ane_path, show_col_types = FALSE) %>%
  filter(
    INDICATOR == "NT_ANE_WOM_15_49_MOD",
    SEX == "_T"
  ) %>%
  mutate(
    TIME_PERIOD = suppressWarnings(as.integer(TIME_PERIOD)),
    OBS_VALUE = suppressWarnings(as.numeric(OBS_VALUE))
  ) %>%
  filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(OBS_VALUE), OBS_VALUE > 0)

api_label_lookup <- get_nt_projection_label_lookup(
  dw_ane_raw,
  default_indicator_label = "Anemia prevalence in women aged 15-49 years"
)

regional_df <- dw_ane_raw %>%
  filter(REPORTING_LVL == "R", AGE == "_T") %>%
  mutate(data_level = "Regional")

country_df <- dw_ane_raw %>%
  filter(REPORTING_LVL == "C", AGE == "_T") %>%
  mutate(data_level = "Country")

ane_analysis_df <- bind_rows(
  regional_df %>% transmute(data_level, REF_AREA, INDICATOR, SEX, TIME_PERIOD, OBS_VALUE),
  country_df %>% transmute(data_level, REF_AREA, INDICATOR, SEX, TIME_PERIOD, OBS_VALUE)
)

# =============================================================================
# Baseline + endline
# =============================================================================
baseline_df <- ane_analysis_df %>%
  filter(TIME_PERIOD == 2012) %>%
  transmute(data_level, REF_AREA, r_2012 = stata_round(OBS_VALUE, round_digits_prev))

end_2023_df <- ane_analysis_df %>%
  filter(TIME_PERIOD == 2023) %>%
  transmute(data_level, REF_AREA, r_2023 = stata_round(OBS_VALUE, round_digits_prev))

# =============================================================================
# AARR (log-linear) using modeled data from 2012 to 2023
# =============================================================================
aarr_df <- ane_analysis_df %>%
  filter(TIME_PERIOD >= 2012, TIME_PERIOD <= 2023) %>%
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

# =============================================================================
# Combine + classify
# =============================================================================
final_ane <- baseline_df %>%
  left_join(end_2023_df, by = c("data_level", "REF_AREA")) %>%
  left_join(aarr_df, by = c("data_level", "REF_AREA")) %>%
  mutate(
    indicator = "anemia",
    # 2030 target = 50% reduction from 2012
    target_prop = r_2012 * 0.5,
    r_2012_aarr = stata_round(r_2012, round_digits_prev),
    target_prop_aarr = stata_round(target_prop, round_digits_prev),
    target_value_2030 = case_when(
      !is.na(target_prop_aarr) & target_prop_aarr >= 5 ~ target_prop_aarr,
      !is.na(target_prop_aarr) ~ 5,
      TRUE ~ NA_real_
    ),

    # Required AARR for 2030:
    # - If using 50% reduction target, use fixed 3.78
    # - If threshold (5%) is easier, calculate AARR to 5%
    required_AARR_2030 = case_when(
      !is.na(target_prop_aarr) & target_prop_aarr >= 5 ~ 3.78,
      !is.na(target_prop_aarr) & !is.na(r_2012_aarr) & r_2012_aarr > 0 & target_prop_aarr > 0 ~
        stata_round(100 * (1 - exp((log(5) - log(r_2012_aarr)) / (2030 - 2012))), round_digits_aarr),
      TRUE ~ NA_real_
    ),
    current_AARR_assess = stata_round(current_AARR, round_digits_aarr),
    required_AARR_2030_assess = stata_round(required_AARR_2030, round_digits_aarr),

    # Target met if either criterion is achieved: 50% reduction OR <5% threshold.
    crossthreshold_2030 = if_else(r_2023 <= target_prop | r_2023 <= 5, 1, 0),
    thresholdbasis = "r",

    # === Full + UNICEF Classification for 2030 target ===
    FullClassification_2030 = case_when(
      is.na(r_2012) | is.na(r_2023) | is.na(current_AARR_assess) ~ "Assessment not Possible",
      crossthreshold_2030 == 1 ~ "On track",
      current_AARR_assess >= required_AARR_2030_assess ~ "On track",
      current_AARR_assess > 0.5 ~ "Some progress",
      current_AARR_assess >= -0.5 ~ "No progress",
      current_AARR_assess < -0.5 ~ "Worsening",
      TRUE ~ "Assessment not Possible"
    ),
    UNICEF_Classification_2030 = case_when(
      is.na(r_2012) | is.na(r_2023) | is.na(current_AARR_assess) ~ "Assessment not Possible",
      (crossthreshold_2030 == 1 | r_2023 <= target_prop | r_2023 <= 5) ~ "Target met",
      TRUE ~ FullClassification_2030
    ),

    # --- Simple classification for 2030 target (no threshold logic) ---
    SimpleClassification = case_when(
      is.na(current_AARR_assess) ~ "Assessment not Possible",
      current_AARR_assess > 0.5 ~ "improving",
      current_AARR_assess >= -0.5 ~ "no change",
      current_AARR_assess < -0.5 ~ "worsening",
      TRUE ~ "Assessment not Possible"
    )
  )

# === Export summary (classification table) ===
progress_ane <- final_ane %>%
  transmute(
    INDICATOR = "NT_ANE_WOM_15_49_MOD",
    reporting_level = data_level,
    REF_AREA,
    baseline_year = 2012L,
    baseline_value = r_2012,
    latest_year = 2023L,
    latest_value = r_2023,
    projected_value_2030 = if_else(
      !is.na(r_2012) & !is.na(current_AARR),
      stata_round(r_2012 * (1 - (current_AARR / 100))^(2030 - 2012), round_digits_prev),
      NA_real_
    ),
    target_value_2030 = target_value_2030,
    target_threshhold = 5,
    target_percent_change = 50,
    no_progress_aarr_lower_buffer = -0.5,
    no_progress_aarr_upper_buffer = 0.5,
    current_aarr = current_AARR,
    required_aarr_2030 = required_AARR_2030,
    crossthreshold = crossthreshold_2030,
    assessment_not_possible_flag = NA_integer_,
    fullclassification_2030 = FullClassification_2030,
    unicef_classification_2030 = UNICEF_Classification_2030,
    simpleclassification = SimpleClassification
  ) %>%
  add_nt_projection_progress_metadata(api_label_lookup)

write_csv(progress_ane, file.path(outputdir_projections_inter, "ane_progress_2030.csv"))

progress_append_path <- file.path(outputdir_projections_final, "progress_2030_appended.csv")
if (file.exists(progress_append_path)) {
  progress_appended <- read_nt_projection_progress_file(progress_append_path)
  if (!("INDICATOR" %in% names(progress_appended))) {
    progress_appended <- progress_appended %>%
      mutate(INDICATOR = if ("indicator_code" %in% names(progress_appended)) as.character(indicator_code) else NA_character_)
  }
  progress_appended <- progress_appended %>%
    filter(INDICATOR != "NT_ANE_WOM_15_49_MOD") %>%
    bind_rows(progress_ane)
} else {
  progress_appended <- progress_ane
}
tryCatch(
  write_csv(progress_appended, progress_append_path),
  error = function(e) {
    warning("Could not write appended progress file: ", progress_append_path, " (", conditionMessage(e), ")")
  }
)

# =============================================================================
# Projections + targets (LONG FORMAT)
# - Projections: anchored at 2012, applying current_AARR
# - Targets:     anchored at 2012, applying required_AARR_2030 to hit 50% reduction by 2030
# =============================================================================
years <- 2013:2030

projected_2013_2030 <- final_ane %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    INDICATOR = "NT_ANE_WOM_15_49_MOD",
    OBS_VALUE = stata_round(r_2012 * (1 - (current_AARR / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Projected"
  ) %>%
  select(data_level, REF_AREA, INDICATOR, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

target_2013_2030 <- final_ane %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030, target_value_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    INDICATOR = "NT_ANE_WOM_15_49_MOD",
    OBS_VALUE = stata_round(r_2012 * (1 - (required_AARR_2030 / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    OBS_VALUE = if_else(TIME_PERIOD == 2030, target_value_2030, OBS_VALUE),
    TYPE = "Target"
  ) %>%
  select(data_level, REF_AREA, INDICATOR, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

# Export DW-ready 2030 target indicator for anemia (women 15-49)
dir.create(file.path(outputdir, "Targets"), recursive = TRUE, showWarnings = FALSE)

trgt_2030_nt_ane_wra <- bind_rows(
  final_ane %>%
    transmute(
      REF_AREA = REF_AREA,
      SEX = "_T",
      TIME_PERIOD = 2012,
      OBS_VALUE = r_2012
    ),
  target_2013_2030 %>%
    select(REF_AREA, SEX, TIME_PERIOD, OBS_VALUE)
) %>%
  transmute(
    REF_AREA = REF_AREA,
    INDICATOR = "TRGT_2030_NT_ANE_WOM_15_49_MOD",
    SEX = SEX,
    AGE = "_T",
    TIME_PERIOD = TIME_PERIOD,
    OBS_VALUE = OBS_VALUE,
    OBS_FOOTNOTE = "2030 target trajectory for anemia prevalence in women (15-49), anchored at 2012 baseline."
  )



# =============================================================================
# Combine with original modelled data
# =============================================================================
agg_df_with_type <- ane_analysis_df %>%
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
  arrange(data_level, REF_AREA, TIME_PERIOD) %>%
  # Drop modelled 2024 estimates (your original intention) + rows before 2000
  # NOTE: This anemia script ends at 2023, but keeping your filter is harmless.
  filter(!(TYPE == "Modelled" & TIME_PERIOD == 2024) & TIME_PERIOD >= 2000) %>%
  select(-any_of(c("time", "regional_r", "regional_n")))

# =============================================================================
# Export estimates/projections/targets workbook
# =============================================================================
export_df <- combined_df %>%
  mutate(
    INDICATOR = "NT_ANE_WOM_15_49_MOD"
  )
if ("SEX" %in% names(export_df)) {
  export_df <- export_df %>%
    filter(is.na(SEX) | SEX == "_T")
}
export_df <- add_nt_population_columns(export_df, "NT_ANE_WOM_15_49_MOD") %>%
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
  file.path(outputdir_projections_exports, "ane_estimates_targets_projections.xlsx"),
  overwrite = TRUE
)

