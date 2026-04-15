# projections and targets for low birth weight prevalence (LBW)

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
dw_bw_path <- file.path(outputdir_projections_input, "dw_nut_bw.csv")
if (!file.exists(dw_bw_path)) {
  stop("Projection input file missing: ", dw_bw_path, " - run 1a_import_inputs.r first")
}
message("Using staged NT projection bw input: ", basename(dw_bw_path))

dw_bw_raw <- read_csv(dw_bw_path, show_col_types = FALSE) %>%
  filter(
    IndicatorCode == "NT_BW_LBW",
    SEX == "_T",
    AGE == "_T"
  ) %>%
  mutate(
    TIME_PERIOD = suppressWarnings(as.integer(TIME_PERIOD)),
    OBS_VALUE = suppressWarnings(as.numeric(OBS_VALUE))
  ) %>%
  filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(OBS_VALUE), OBS_VALUE > 0)

api_label_lookup <- get_nt_projection_label_lookup(
  dw_bw_raw,
  default_indicator_label = "Low birth weight prevalence"
)

regional_df <- dw_bw_raw %>%
  filter(REPORTING_LVL == "R") %>%
  mutate(data_level = "Regional")

country_df <- dw_bw_raw %>%
  filter(REPORTING_LVL == "C") %>%
  mutate(data_level = "Country")

lbw_analysis_df <- bind_rows(
  regional_df %>% transmute(data_level, REF_AREA, TIME_PERIOD, OBS_VALUE),
  country_df %>% transmute(data_level, REF_AREA, TIME_PERIOD, OBS_VALUE)
)

# =============================================================================
# Baseline + endline
# =============================================================================
baseline_df <- lbw_analysis_df %>%
  filter(TIME_PERIOD == 2012) %>%
  transmute(data_level, REF_AREA, r_2012 = stata_round(OBS_VALUE, round_digits_prev))

end_2020_df <- lbw_analysis_df %>%
  filter(TIME_PERIOD == 2020) %>%
  transmute(data_level, REF_AREA, r_2020 = stata_round(OBS_VALUE, round_digits_prev))

# =============================================================================
# AARR (log-linear) using modeled data from 2012 to 2020
# =============================================================================
aarr_df <- lbw_analysis_df %>%
  filter(TIME_PERIOD >= 2012, TIME_PERIOD <= 2020) %>%
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
final_lbw <- baseline_df %>%
  left_join(end_2020_df, by = c("data_level", "REF_AREA")) %>%
  left_join(aarr_df, by = c("data_level", "REF_AREA")) %>%
  mutate(
    indicator = "lbw",
    # 2030 target = 30% reduction from 2012
    target_prop = r_2012 * 0.7,
    r_2012_aarr = stata_round(r_2012, round_digits_prev),
    target_prop_aarr = stata_round(target_prop, round_digits_prev),

    # Required AARR for 2030:
    # - If using 30% reduction target, use fixed 1.96
    # - If threshold (5%) is easier, calculate AARR to 5%
    required_AARR_2030 = case_when(
      !is.na(target_prop_aarr) & target_prop_aarr >= 5 ~ 1.96,
      !is.na(target_prop_aarr) & !is.na(r_2012_aarr) & r_2012_aarr > 0 & target_prop_aarr > 0 ~
        stata_round(100 * (1 - exp((log(5) - log(r_2012_aarr)) / (2030 - 2012))), round_digits_aarr),
      TRUE ~ NA_real_
    ),
    current_AARR_assess = stata_round(current_AARR, round_digits_aarr),
    required_AARR_2030_assess = stata_round(required_AARR_2030, round_digits_aarr),

    # Threshold rule: <5% is considered on-track
    crossthreshold_2030 = if_else(r_2020 <= 5, 1, 0),
    thresholdbasis = "r",

    # === Full + UNICEF Classification for 2030 target ===
    FullClassification_2030 = case_when(
      is.na(r_2012) | is.na(r_2020) | is.na(current_AARR_assess) ~ "Assessment not Possible",
      crossthreshold_2030 == 1 ~ "On track",
      current_AARR_assess >= required_AARR_2030_assess ~ "On track",
      current_AARR_assess > 0.5 ~ "Some progress",
      current_AARR_assess >= -0.5 ~ "No progress",
      current_AARR_assess < -0.5 ~ "Worsening",
      TRUE ~ "Assessment not Possible"
    ),
    UNICEF_Classification_2030 = case_when(
      is.na(r_2012) | is.na(r_2020) | is.na(current_AARR_assess) ~ "Assessment not Possible",
      (crossthreshold_2030 == 1 | r_2020 <= target_prop) ~ "Target met",
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

# === Export summary ===
progress_lbw <- final_lbw %>%
  transmute(
    IndicatorCode = "NT_BW_LBW",
    reporting_level = data_level,
    REF_AREA,
    baseline_year = 2012L,
    baseline_value = r_2012,
    latest_year = 2020L,
    latest_value = r_2020,
    projected_value_2030 = if_else(
      !is.na(r_2012) & !is.na(current_AARR),
      stata_round(r_2012 * (1 - (current_AARR / 100))^(2030 - 2012), round_digits_prev),
      NA_real_
    ),
    target_value_2030 = if_else(
      !is.na(target_prop_aarr),
      if_else(target_prop_aarr >= 5, target_prop_aarr, 5),
      NA_real_
    ),
    target_threshhold = 5,
    target_percent_change = 30,
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

write_csv(progress_lbw, file.path(outputdir_projections_inter, "lbw_progress_2030.csv"))

progress_append_path <- file.path(outputdir_projections_final, "progress_2030_appended.csv")
if (file.exists(progress_append_path)) {
  progress_appended <- read_nt_projection_progress_file(progress_append_path)
  if (!("IndicatorCode" %in% names(progress_appended))) {
    progress_appended <- progress_appended %>%
      mutate(IndicatorCode = if ("indicator_code" %in% names(progress_appended)) as.character(indicator_code) else NA_character_)
  }
  progress_appended <- progress_appended %>%
    filter(IndicatorCode != "NT_BW_LBW") %>%
    bind_rows(progress_lbw)
} else {
  progress_appended <- progress_lbw
}
tryCatch(
  write_csv(progress_appended, progress_append_path),
  error = function(e) {
    warning("Could not write appended progress file: ", progress_append_path, " (", conditionMessage(e), ")")
  }
)

# =============================================================================
# Projections + targets (LONG FORMAT) — ANCHORED AT 2012
# - Projections: apply current_AARR from 2012 baseline
# - Targets:     apply required_AARR_2030 from 2012 baseline
# =============================================================================
years <- 2013:2030

projected_2013_2030 <- final_lbw %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = stata_round(r_2012 * (1 - (current_AARR / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Projected"
  ) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

target_2013_2030 <- final_lbw %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = stata_round(r_2012 * (1 - (required_AARR_2030 / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Target"
  ) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

# Export DW-ready target indicator for nutrition merge script
dir.create(file.path(outputdir, "Targets"), recursive = TRUE, showWarnings = FALSE)

trgt_2030_nt_bw_lbw <- bind_rows(
  final_lbw %>%
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
    IndicatorCode = "TRGT_2030_NT_BW_LBW",
    SEX = SEX,
    AGE = "_T",
    TIME_PERIOD = TIME_PERIOD,
    OBS_VALUE = OBS_VALUE,
    OBS_FOOTNOTE = "2030 target trajectory for low birth weight prevalence, anchored at 2012 baseline."
  )



# =============================================================================
# Combine with original modelled data
# =============================================================================
agg_df_with_type <- lbw_analysis_df %>%
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
  # Drop modelled 2024 estimates and rows before 2000
  # NOTE: LBW endline here is 2020; leaving 2024 drop is harmless.
  filter(!(TYPE == "Modelled" & TIME_PERIOD == 2024) & TIME_PERIOD >= 2000) %>%
  select(-any_of(c("time", "regional_r", "regional_n")))

# =============================================================================
# Export estimates/projections/targets workbook
# =============================================================================
export_df <- combined_df %>%
  mutate(
    IndicatorCode = "NT_BW_LBW"
  )
if ("SEX" %in% names(export_df)) {
  export_df <- export_df %>%
    filter(is.na(SEX) | SEX == "_T")
}
export_df <- add_nt_population_columns(export_df, "NT_BW_LBW") %>%
  select(any_of(c("IndicatorCode", "data_level", "REF_AREA", "TIME_PERIOD", "population", "OBS_VALUE", "number_affected", "TYPE")))

codebook <- tribble(
  ~Column, ~Description,
  "IndicatorCode", "Indicator code",
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
  file.path(outputdir_projections_exports, "lbw_estimates_targets_projections.xlsx"),
  overwrite = TRUE
)


# # === Load aggregate Excel data ===
# agg_df <- read_excel(file.path(outputdir, "agg_indicator", "Regional_Output_NT_BW_LBW.xlsx")) %>%
#   filter(!is.na(REF_AREA), !is.na(OBS_VALUE))


# # === 2012 baseline prevalence ===
# baseline_df <- agg_df %>%
#   filter(TIME_PERIOD == 2012) %>%
#   select(
#     Classification,
#     Region,
#     REF_AREA,
#     r_2012 = OBS_VALUE
#   )

# # === 2020 prevalence ===
# end_2020_df <- agg_df %>%
#   filter(TIME_PERIOD == 2020) %>%
#   select(
#     Classification,
#     Region,
#     REF_AREA,
#     r_2020 = OBS_VALUE
#   )

# # === AARR using modeled data from 2012 to 2020 ===
# aarr_df <- agg_df %>%
#   filter(
#     SEX == "_T",
#     TIME_PERIOD >= 2012,
#     TIME_PERIOD <= 2020
#   ) %>%
#   mutate(log_prev = log(OBS_VALUE)) %>%
#   group_by(
#     REF_AREA
#   ) %>%
#   filter(n() >= 2) %>%
#   summarise(
#     slope = coef(lm(log_prev ~ TIME_PERIOD))[2],
#     current_AARR = 100 * (1 - exp(slope)),
#     .groups = "drop"
#   )


# # === Combine and classify ===
# final_lbw <- baseline_df %>%
#   left_join(end_2020_df, by = c("REF_AREA")) %>%
#   left_join(aarr_df, by = c("REF_AREA")) %>%
#   mutate(
#     target_prop = r_2012 * 0.7,
    
#     # Required AARR for 2030 (target 30% reduction from 2012)
#     required_AARR_2030 = 100 * (1 - exp((log(target_prop) - log(r_2012)) / (2030 - 2012))),

#     crossthreshold_2030 = if_else(r_2020 < 5, 1, 0), #<5% is considered on-track
#     thresholdbasis = "r",
#     indicator = "lbw",
    
#     # === Full + UNICEF Classification for 2030 target ===
#     FullClassification_2030 = case_when(
#       crossthreshold_2030 == 1 ~ "On track",
#       current_AARR >= required_AARR_2030 ~ "On track",
#       current_AARR >= 0.5 ~ "Some progress",
#       current_AARR >= -0.5 ~ "No progress",
#       current_AARR < -0.5 ~ "Worsening",
#       TRUE ~ ""
#     ),
#     UNICEF_Classification_2030 = case_when(
#       (crossthreshold_2030 == 1 | r_2020 < target_prop) & FullClassification_2030 != "Assessment not Possible" ~ "Target met",
#       TRUE ~ FullClassification_2030
#     ),
#     FullClassification_2030 = if_else(
#       (is.na(FullClassification_2030) | FullClassification_2030 == "") & is.na(r_2012),
#       "Assessment not Possible",
#       FullClassification_2030
#     ),
#     UNICEF_Classification_2030 = if_else(
#       (is.na(UNICEF_Classification_2030) | UNICEF_Classification_2030 == "") & is.na(r_2012),
#       "Assessment not Possible",
#       UNICEF_Classification_2030
#     ),

#     # --- Simple classification for 2030 target (no threshold logic) ---
#     SimpleClassification = case_when(
#       current_AARR >= 0.5 ~ "improving",
#       current_AARR >= -0.5 ~ "no change",
#       current_AARR < -0.5 ~ "worsening",
#       TRUE ~ "Assessment not Possible"
#     ),

#     # === Estimate annual OBS_VALUE for 2013-2030 based on r_2020 and current_AARR ===
#     # Note: AARR is a reduction rate, so positive AARR means decrease (negate in formula)
#     PROJ_VALUE_2013 = r_2020 * (1 - (current_AARR / 100))^(2013 - 2020),
# PROJ_VALUE_2014 = r_2020 * (1 - (current_AARR / 100))^(2014 - 2020),
# PROJ_VALUE_2015 = r_2020 * (1 - (current_AARR / 100))^(2015 - 2020),
# PROJ_VALUE_2016 = r_2020 * (1 - (current_AARR / 100))^(2016 - 2020),
# PROJ_VALUE_2017 = r_2020 * (1 - (current_AARR / 100))^(2017 - 2020),
# PROJ_VALUE_2018 = r_2020 * (1 - (current_AARR / 100))^(2018 - 2020),
# PROJ_VALUE_2019 = r_2020 * (1 - (current_AARR / 100))^(2019 - 2020),
# PROJ_VALUE_2020 = r_2020 * (1 - (current_AARR / 100))^(2020 - 2020),
# PROJ_VALUE_2021 = r_2020 * (1 - (current_AARR / 100))^(2021 - 2020),
# PROJ_VALUE_2022 = r_2020 * (1 - (current_AARR / 100))^(2022 - 2020),
# PROJ_VALUE_2023 = r_2020 * (1 - (current_AARR / 100))^(2023 - 2020),
# PROJ_VALUE_2024 = r_2020 * (1 - (current_AARR / 100))^(2024 - 2020),
# PROJ_VALUE_2025 = r_2020 * (1 - (current_AARR / 100))^(2025 - 2020),
# PROJ_VALUE_2026 = r_2020 * (1 - (current_AARR / 100))^(2026 - 2020),
# PROJ_VALUE_2027 = r_2020 * (1 - (current_AARR / 100))^(2027 - 2020),
# PROJ_VALUE_2028 = r_2020 * (1 - (current_AARR / 100))^(2028 - 2020),
# PROJ_VALUE_2029 = r_2020 * (1 - (current_AARR / 100))^(2029 - 2020),
# PROJ_VALUE_2030 = r_2020 * (1 - (current_AARR / 100))^(2030 - 2020),

#     # === Estimate annual TARGET_VALUE for 2013-2030 based on r_2012 and required_AARR_2030 ===
#     # Note: Target values show what values should be if required rate of change is achieved
# TARGET_VALUE_2013 = r_2012 * (1 - required_AARR_2030 / 100)^(2013 - 2012),
# TARGET_VALUE_2014 = r_2012 * (1 - required_AARR_2030 / 100)^(2014 - 2012),
# TARGET_VALUE_2015 = r_2012 * (1 - required_AARR_2030 / 100)^(2015 - 2012),
# TARGET_VALUE_2016 = r_2012 * (1 - required_AARR_2030 / 100)^(2016 - 2012),
# TARGET_VALUE_2017 = r_2012 * (1 - required_AARR_2030 / 100)^(2017 - 2012),
# TARGET_VALUE_2018 = r_2012 * (1 - required_AARR_2030 / 100)^(2018 - 2012),
# TARGET_VALUE_2019 = r_2012 * (1 - required_AARR_2030 / 100)^(2019 - 2012),
# TARGET_VALUE_2020 = r_2012 * (1 - required_AARR_2030 / 100)^(2020 - 2012),
# TARGET_VALUE_2021 = r_2012 * (1 - required_AARR_2030 / 100)^(2021 - 2012),
# TARGET_VALUE_2022 = r_2012 * (1 - required_AARR_2030 / 100)^(2022 - 2012),
# TARGET_VALUE_2023 = r_2012 * (1 - required_AARR_2030 / 100)^(2023 - 2012),
# TARGET_VALUE_2024 = r_2012 * (1 - required_AARR_2030 / 100)^(2024 - 2012),
# TARGET_VALUE_2025 = r_2012 * (1 - required_AARR_2030 / 100)^(2025 - 2012),
# TARGET_VALUE_2026 = r_2012 * (1 - required_AARR_2030 / 100)^(2026 - 2012),
# TARGET_VALUE_2027 = r_2012 * (1 - required_AARR_2030 / 100)^(2027 - 2012),
# TARGET_VALUE_2028 = r_2012 * (1 - required_AARR_2030 / 100)^(2028 - 2012),
# TARGET_VALUE_2029 = r_2012 * (1 - required_AARR_2030 / 100)^(2029 - 2012),
# TARGET_VALUE_2030 = r_2012 * (1 - required_AARR_2030 / 100)^(2030 - 2012)
#   )

# # === Export summary ===
# write_csv(final_lbw, file.path(outputdir_projections, "aggregate_lbw_progress_2025_2030.csv"))

# # Convert 2024-2030 projections to long format with all columns from final_lbw
# projected_2024_2030 <- final_lbw %>%
#     select(REF_AREA, current_AARR, required_AARR_2030, starts_with("PROJ_VALUE_")) %>%
#     mutate(SEX = "_T") %>%
#     pivot_longer(
#         cols = starts_with("PROJ_VALUE_"),
#         names_to = "year_col",
#         values_to = "OBS_VALUE"
#     ) %>%
#     mutate(
#         TIME_PERIOD = as.numeric(str_extract(year_col, "\\d{4}"))
#     ) %>%
#     select(REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030) %>%
#     mutate(TYPE = "Projected")

# # Convert 2013-2030 targets to long format with all columns from final_lbw
# target_2013_2030 <- final_lbw %>%
#     select(REF_AREA, current_AARR, required_AARR_2030, starts_with("TARGET_VALUE_")) %>%
#     mutate(SEX = "_T") %>%
#     pivot_longer(
#         cols = starts_with("TARGET_VALUE_"),
#         names_to = "year_col",
#         values_to = "OBS_VALUE"
#     ) %>%
#     mutate(
#         TIME_PERIOD = as.numeric(str_extract(year_col, "\\d{4}"))
#     ) %>%
#     select(REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030) %>%
#     mutate(TYPE = "Target")

# # Add TYPE column to original data (mark as Modelled), keeping all original columns
# agg_df_with_type <- agg_df %>%
#     mutate(TYPE = "Modelled")

# # Append projected and target data
# combined_df <- bind_rows(agg_df_with_type, projected_2024_2030, target_2013_2030) %>%
#     arrange(REF_AREA, TIME_PERIOD) %>%
#     # Drop modelled 2024 estimates and rows before 2000
#     filter(!(TYPE == "Modelled" & TIME_PERIOD == 2024) & TIME_PERIOD >= 2000) %>%
# select(-c(time, regional_r, regional_n))

# # === Export combined data with codebook ===
# # Create codebook with all available columns
# codebook <- tribble(
#     ~Column, ~Description,
#     "INDICATOR", "Indicator code",
#     "INDICATOR_CODE", "Alternative indicator code",
#     "datapop", "Population in target age group in countries with data in region",
#     "popaffectd", "Number affected in region (basepop_value * OBS_VALUE/100)",
#     "popcoverage", "Proportion of population in region covered by data (datapop / basepop_value)",
#     "basepop_value", "Base population for weighting",
#     "REF_AREA", "Country/Region code",
#     "SEX", "Sex disaggregation (_T = Total)",
#     "TIME_PERIOD", "Year",
#     "OBS_VALUE", "Observed, modelled, projected, or target prevalence/coverage",
#     "current_AARR", "Current annual average rate of reduction (linear model of 2012 to 2023)",
#     "required_AARR_2030", "Required annual average rate of reduction to reach 2030 Global Nutrition Target (2012 to 2030)",
#     "TYPE", "Data type: Modelled (estimate from statistical model), Projected (based on current AARR), or Target (based on required AARR for 50% reduction)"
# )

# # Export to Excel with multiple sheets
# library(openxlsx)
# wb <- createWorkbook()
# addWorksheet(wb, "Data")
# addWorksheet(wb, "Codebook")
# writeData(wb, "Data", combined_df)
# writeData(wb, "Codebook", codebook)
# saveWorkbook(wb, file.path(outputdir_projections, "aggregate_lbw_modelled_projected.xlsx"), overwrite = TRUE)

# # Also export as CSV for compatibility
# write_csv(combined_df, file.path(outputdir_projections, "aggregate_lbw_modelled_projected.csv"))
