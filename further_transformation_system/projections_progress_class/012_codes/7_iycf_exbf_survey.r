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
# Load staged exclusive breastfeeding projection input
# Values are flipped to "not exclusively breastfeeding" (100 - EBF) immediately
# after loading, so that a declining trend indicates improvement (same direction
# as wasting / anemia).
# Target: not-exbf < 40%  (equivalent to EBF >= 60%)
# =============================================================================
dw_iycf_path <- file.path(outputdir_projections_input, "dw_nut_iycf.csv")
if (!file.exists(dw_iycf_path)) {
  stop("Projection input file missing: ", dw_iycf_path, " - run 1a_import_inputs.r first")
}
message("Using staged NT projection iycf input: ", basename(dw_iycf_path))

exbf_raw <- read_csv(dw_iycf_path, show_col_types = FALSE) %>%
  filter(
    INDICATOR == "NT_BF_EXBF",
    SEX == "_T",
    AGE == "M0T5",
    REPORTING_LVL == "C"
  ) %>%
  {
    data <- .
    for (col_name in c("WEALTH_QUINTILE", "RESIDENCE", "MATERNAL_EDU_LVL", "HEAD_OF_HOUSE")) {
      if (col_name %in% names(data)) {
        data <- data %>% filter(.data[[col_name]] == "_T")
      }
    }
    data
  } %>%
  mutate(
    year_num = suppressWarnings(as.integer(substr(as.character(TIME_PERIOD), 1, 4))),
    OBS_VALUE = suppressWarnings(as.numeric(OBS_VALUE))
  ) %>%
  filter(!is.na(REF_AREA), !is.na(year_num), !is.na(OBS_VALUE)) %>%
  # Flip to "not exclusively breastfeeding"
  mutate(OBS_VALUE = 100 - OBS_VALUE) %>%
  filter(OBS_VALUE > 0)

api_label_lookup <- get_nt_projection_label_lookup(
  exbf_raw,
  default_indicator_label = "Exclusive breastfeeding (0-5 months)"
)

# Country EBF is treated as non-series: keep all eligible survey rows,
# then select a country-specific baseline and estimate AARR from baseline onward.
country_surveys <- exbf_raw %>%
  arrange(REF_AREA, year_num, as.character(TIME_PERIOD)) %>%
  transmute(
    REF_AREA,
    survey_year = year_num,
    OBS_VALUE,
    source_priority = if ("DATA_SOURCE_PRIORITY" %in% names(exbf_raw)) suppressWarnings(as.numeric(DATA_SOURCE_PRIORITY)) else 1,
    time_period_seed = as.character(TIME_PERIOD)
  )

# =============================================================================
# Country branch (non-series)
# =============================================================================
country_baseline <- country_surveys %>%
  group_by(REF_AREA) %>%
  summarise(
    year_baseline = {
      years_0512 <- survey_year[survey_year >= 2005 & survey_year <= 2012]
      years_13p  <- survey_year[survey_year >= 2013]
      if (length(years_0512) > 0) {
        as.integer(max(years_0512, na.rm = TRUE))
      } else if (length(years_13p) > 0) {
        as.integer(min(years_13p, na.rm = TRUE))
      } else {
        NA_integer_
      }
    },
    .groups = "drop"
  ) %>%
  left_join(
    country_surveys %>%
      group_by(REF_AREA, survey_year) %>%
      arrange(desc(source_priority), time_period_seed, .by_group = TRUE) %>%
      summarise(r_baseline = first(OBS_VALUE), .groups = "drop") %>%
      transmute(REF_AREA, year_baseline = survey_year, r_baseline),
    by = c("REF_AREA", "year_baseline")
  )

country_recent <- country_surveys %>%
  group_by(REF_AREA) %>%
  arrange(desc(survey_year)) %>%
  slice_head(n = 1) %>%
  ungroup() %>%
  transmute(
    REF_AREA,
    year_recent = survey_year,
    r_recent = OBS_VALUE,
    r_2024 = if_else(year_recent > 2016, r_recent, NA_real_)
  )

country_aarr <- country_surveys %>%
  left_join(country_baseline %>% select(REF_AREA, year_baseline), by = "REF_AREA") %>%
  arrange(REF_AREA, survey_year, desc(source_priority), time_period_seed) %>%
  group_by(REF_AREA, survey_year) %>%
  mutate(
    keep_for_aarr = if_else(
      survey_year == first(year_baseline),
      row_number() == 1,
      TRUE
    )
  ) %>%
  ungroup() %>%
  filter(keep_for_aarr) %>%
  filter(!is.na(year_baseline), survey_year >= year_baseline) %>%
  mutate(prev_for_aarr = stata_round(OBS_VALUE, round_digits_prev)) %>%
  filter(prev_for_aarr > 0) %>%
  mutate(log_prev = log(prev_for_aarr)) %>%
  group_by(REF_AREA) %>%
  filter(n() >= 2) %>%
  # If baseline is in 2005-2012, require at least one post-2012 survey to estimate current AARR.
  filter(first(year_baseline) >= 2013 | any(survey_year > 2012)) %>%
  summarise(
    slope = coef(lm(log_prev ~ survey_year))[2],
    current_AARR = stata_round(100 * (1 - exp(slope)), round_digits_aarr),
    n_surveys_postbaseline = n(),
    .groups = "drop"
  )

# Include staged country universe so missing countries are explicit in output
country_universe_path <- file.path(outputdir_projections_input, "dw_country_universe.csv")
if (!file.exists(country_universe_path)) {
  stop("Projection country universe missing: ", country_universe_path, " - run 1a_import_inputs.r first")
}
country_universe <- read_csv(country_universe_path, show_col_types = FALSE) %>%
  distinct(REF_AREA)

country_final <- country_universe %>%
  left_join(country_baseline, by = "REF_AREA") %>%
  left_join(country_recent, by = "REF_AREA") %>%
  left_join(country_aarr, by = "REF_AREA") %>%
  mutate(
    data_level = "Country",
    target_prop = 40,
    r_baseline_aarr = stata_round(r_baseline, round_digits_prev),
    required_AARR_2030 = if_else(
      !is.na(r_baseline_aarr) & r_baseline_aarr > 0 & !is.na(year_baseline),
      stata_round(100 * (1 - exp((log(target_prop) - log(r_baseline_aarr)) / (2030 - year_baseline))), round_digits_aarr),
      NA_real_
    ),
    current_AARR_assess = current_AARR,
    required_AARR_2030_assess = required_AARR_2030,
    reliable = if_else(is.na(year_recent) | year_recent < 2005 | is.na(n_surveys_postbaseline) | n_surveys_postbaseline < 2, 1L, 0L),
    crossthreshold_2030 = if_else(!is.na(r_recent) & r_recent <= target_prop, 1L, 0L),
    reliable = if_else(!is.na(r_recent) & r_recent <= target_prop & !is.na(year_recent) & year_recent > 2012, 0L, reliable),
    thresholdbasis = "r",
    indicator = "exbf"
  )

# =============================================================================
# Classify
# =============================================================================
final_exbf <- country_final %>%
  mutate(
    FullClassification_2030 = case_when(
      reliable == 1L ~ "Assessment not Possible",
      crossthreshold_2030 == 1L ~ "On track",
      current_AARR_assess >= required_AARR_2030_assess ~ "On track",
      current_AARR_assess > 0.8 ~ "Some progress",
      current_AARR_assess >= -0.8 ~ "No progress",
      current_AARR_assess < -0.8 ~ "Worsening",
      TRUE ~ "Assessment not Possible"
    ),
    UNICEF_Classification_2030 = case_when(
      reliable == 1L ~ "Assessment not Possible",
      crossthreshold_2030 == 1L ~ "Target met",
      TRUE ~ FullClassification_2030
    ),
    SimpleClassification = case_when(
      reliable == 1L ~ "Assessment not Possible",
      current_AARR_assess > 0.8 ~ "improving",
      current_AARR_assess >= -0.8 ~ "no change",
      current_AARR_assess < -0.8 ~ "worsening",
      TRUE ~ "Assessment not Possible"
    )
  )

# === Export summary ===
progress_exbf <- final_exbf %>%
  transmute(
    INDICATOR = "NOT_NT_BF_EXBF",
    reporting_level = data_level,
    REF_AREA,
    baseline_year = year_baseline,
    baseline_value = r_baseline,
    latest_year = year_recent,
    latest_value = r_recent,
    projected_value_2030 = if_else(
      !is.na(year_baseline) & !is.na(r_baseline) & !is.na(current_AARR),
      stata_round(r_baseline * (1 - (current_AARR / 100))^(2030 - year_baseline), round_digits_prev),
      NA_real_
    ),
    target_value_2030 = if_else(!is.na(year_baseline), 40, NA_real_),
    target_threshhold = if_else(!is.na(year_baseline), 40, NA_real_),
    target_percent_change = NA_real_,
    no_progress_aarr_lower_buffer = -0.8,
    no_progress_aarr_upper_buffer = 0.8,
    current_aarr = current_AARR,
    required_aarr_2030 = required_AARR_2030,
    crossthreshold = crossthreshold_2030,
    assessment_not_possible_flag = reliable,
    fullclassification_2030 = FullClassification_2030,
    unicef_classification_2030 = UNICEF_Classification_2030,
    simpleclassification = SimpleClassification
  ) %>%
  add_nt_projection_progress_metadata(api_label_lookup) %>%
  mutate(indicator_name = "Not exclusively breastfeeding (0-5 months)")

write_csv(progress_exbf, file.path(outputdir_projections_inter, "exbf_progress_2030.csv"))

progress_append_path <- file.path(outputdir_projections_final, "progress_2030_appended.csv")
if (file.exists(progress_append_path)) {
  progress_appended <- read_nt_projection_progress_file(progress_append_path)
  if (!("INDICATOR" %in% names(progress_appended))) {
    progress_appended <- progress_appended %>%
      mutate(INDICATOR = if ("indicator_code" %in% names(progress_appended)) as.character(indicator_code) else NA_character_)
  }
  progress_appended <- progress_appended %>%
    filter(INDICATOR != "NT_BF_EXBF", INDICATOR != "NOT_NT_BF_EXBF") %>%
    bind_rows(progress_exbf)
} else {
  progress_appended <- progress_exbf
}
tryCatch(
  write_csv(progress_appended, progress_append_path),
  error = function(e) {
    warning("Could not write appended progress file: ", progress_append_path, " (", conditionMessage(e), ")")
  }
)

# =============================================================================
# Projections + targets (LONG FORMAT)
# =============================================================================
years <- 2013:2030

projected_2013_2030 <- final_exbf %>%
  select(data_level, REF_AREA, year_baseline, r_baseline, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = if_else(
      !is.na(year_baseline) & !is.na(current_AARR) & TIME_PERIOD >= year_baseline,
      stata_round(r_baseline * (1 - (current_AARR / 100))^(TIME_PERIOD - year_baseline), round_digits_prev),
      NA_real_
    ),
    TYPE = "Projected"
  ) %>%
  filter(!is.na(OBS_VALUE)) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

target_2013_2030 <- final_exbf %>%
  select(data_level, REF_AREA, year_baseline, r_baseline, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = if_else(
      !is.na(year_baseline) & !is.na(required_AARR_2030) & TIME_PERIOD >= year_baseline,
      stata_round(r_baseline * (1 - (required_AARR_2030 / 100))^(TIME_PERIOD - year_baseline), round_digits_prev),
      NA_real_
    ),
    OBS_VALUE = if_else(TIME_PERIOD == 2030 & !is.na(OBS_VALUE), 40, OBS_VALUE),
    TYPE = "Target"
  ) %>%
  filter(!is.na(OBS_VALUE)) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

# =============================================================================
# Combine with original survey data
# =============================================================================
agg_df_with_type <- country_surveys %>%
  transmute(data_level = "Country", REF_AREA, SEX = "_T", TIME_PERIOD = survey_year, OBS_VALUE) %>%
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
  filter(!(TYPE == "Modelled" & TIME_PERIOD == 2024) & TIME_PERIOD >= 2000)

# =============================================================================
# Export estimates/projections/targets workbook
# =============================================================================
export_df <- combined_df %>%
  mutate(
    INDICATOR = "NOT_NT_BF_EXBF"
  )
if ("SEX" %in% names(export_df)) {
  export_df <- export_df %>%
    filter(is.na(SEX) | SEX == "_T")
}
export_df <- add_nt_population_columns(export_df, "NOT_NT_BF_EXBF") %>%
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

## Excel export moved to 8_format_output.r for unified formatting
