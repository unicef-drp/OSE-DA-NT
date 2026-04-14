# =============================================================================
# Stunting (HAZ<-2) — AGGREGATE/NUMBER-BASED target logic
# - Target is defined on NUMBER affected, using 2030 regional population to convert to a % trajectory
# - required_AARR_2030 is computed on the % scale (because current_AARR is computed from % OBS_VALUE)
# =============================================================================

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
# Load staged regional + country modelled projection input
# =============================================================================
dw_ant_path <- file.path(outputdir_projections_input, "dw_nut_ant.csv")
if (!file.exists(dw_ant_path)) {
  stop("Projection input file missing: ", dw_ant_path, " - run 1a_import_inputs.r first")
}

# Crosswalk for regional metadata and population aggregation
crosswalk <- read_csv(file.path(interdir, "groups_for_agg.csv"), show_col_types = FALSE) %>%
  filter(!is.na(ISO3Code)) %>%
  transmute(
    iso3           = ISO3Code,
    Classification = Regional_Grouping,
    Region_Code    = Region_Code,
    Region
  ) %>%
  distinct()

# Region-level metadata: one row per Region_Code
region_meta <- crosswalk %>%
  distinct(Classification, REF_AREA = Region_Code, Region) %>%
  mutate(Class = REF_AREA)

# Population data (reused in crosswalk/pop block below for 2030 regional and country pops)
population_data <- read_csv(pop_path, show_col_types = FALSE) %>%
  mutate(time = as.integer(time))

# 2012 regional population (for number-affected baseline used in target calculation)
pop_2012_regional <- population_data %>%
  filter(time == 2012) %>%
  transmute(iso3 = iso3_code, pop_2012 = as.numeric(pop_month_0_59_value)) %>%
  left_join(crosswalk %>% select(iso3, REF_AREA = Region_Code), by = "iso3") %>%
  filter(!is.na(REF_AREA)) %>%
  group_by(REF_AREA) %>%
  summarise(basepop_2012 = sum(pop_2012, na.rm = TRUE), .groups = "drop")

# Single staged dw_split file for ANT indicators
message("Using dw_split ant input: ", basename(dw_ant_path))

dw_ant_raw <- read_csv(dw_ant_path, show_col_types = FALSE) %>%
  filter(
    INDICATOR == "NT_ANT_HAZ_NE2_MOD",
    AGE       == "_T",
    SEX       == "_T"
  ) %>%
  mutate(
    TIME_PERIOD = suppressWarnings(as.integer(TIME_PERIOD)),
    OBS_VALUE   = suppressWarnings(as.numeric(OBS_VALUE))
  ) %>%
  filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(OBS_VALUE), OBS_VALUE > 0)

api_label_lookup <- get_nt_projection_label_lookup(
  dw_ant_raw,
  default_indicator_label = "Stunting prevalence (height-for-age <-2 SD)"
)

# Regional rows — enrich with classification metadata and 2012 number affected
regional_df <- dw_ant_raw %>%
  filter(REPORTING_LVL == "R") %>%
  left_join(region_meta, by = "REF_AREA") %>%
  left_join(pop_2012_regional, by = "REF_AREA") %>%
  mutate(
    data_level = "Regional",
    regional_n = OBS_VALUE / 100 * coalesce(basepop_2012, 0)
  )

# Country rows — OBS_VALUE is already rounded % (no conversion needed)
country_df <- dw_ant_raw %>%
  filter(REPORTING_LVL == "C") %>%
  mutate(data_level = "Country")

stnt_analysis_df <- bind_rows(
  regional_df %>% transmute(data_level, REF_AREA, TIME_PERIOD, OBS_VALUE),
  country_df  %>% transmute(data_level, REF_AREA, TIME_PERIOD, OBS_VALUE)
)

# Guardrail: each key should be unique; fail fast if upstream data unexpectedly duplicates keys.
dup_keys <- stnt_analysis_df %>%
  count(data_level, REF_AREA, TIME_PERIOD, name = "n") %>%
  filter(n > 1)

if (nrow(dup_keys) > 0) {
  stop(
    "Duplicate stunting keys found after filtering (data_level + REF_AREA + TIME_PERIOD). Example: ",
    paste(
      head(
        paste0(dup_keys$data_level, "/", dup_keys$REF_AREA, "/", dup_keys$TIME_PERIOD, " (n=", dup_keys$n, ")"),
        10
      ),
      collapse = "; "
    )
  )
}

# =============================================================================
# Crosswalk + population (to compute 2030 regional pop)
# =============================================================================
# crosswalk and population_data loaded above in the data loading block

pop_2030_regional <- population_data %>%
  filter(time == 2030) %>%
  transmute(
    iso3 = iso3_code,
    basepop_value_2030 = pop_month_0_59_value
  ) %>%
  left_join(crosswalk, by = "iso3") %>%
  filter(!is.na(Region_Code)) %>%
  group_by(Classification, REF_AREA = Region_Code, Region) %>%
  summarise(
    basepop_value_2030 = sum(basepop_value_2030, na.rm = TRUE),
    .groups = "drop"
  )

# =============================================================================
# Baseline (2012) and endline (2024)
# IMPORTANT: regional_n is assumed to be NUMBER affected in that region-year.
# =============================================================================
baseline_df <- regional_df %>%
  filter(TIME_PERIOD == 2012) %>%
  select(
    Classification,
    Region,
    Class,
    REF_AREA,
    regional_n,
    r_2012 = OBS_VALUE
  ) %>%
  left_join(
    pop_2030_regional %>% select(REF_AREA, basepop_value_2030),
    by = "REF_AREA"
  ) %>%
  mutate(
    data_level = "Regional",
    baseline_numb = regional_n,
    drop_cov_30 = 0.6,                         # 40% reduction -> remaining fraction = 0.6
    target_numb_30 = drop_cov_30 * baseline_numb,
      target_prop_30 = stata_round(100 * target_numb_30 / basepop_value_2030, round_digits_prev)
  )

pop_2012_country <- population_data %>%
  filter(time == 2012) %>%
  transmute(
    REF_AREA = iso3_code,
    basepop_value_2012 = as.numeric(pop_month_0_59_value)
  )

pop_2030_country <- population_data %>%
  filter(time == 2030) %>%
  transmute(
    REF_AREA = iso3_code,
    basepop_value_2030 = as.numeric(pop_month_0_59_value)
  )

country_baseline_df <- country_df %>%
  filter(TIME_PERIOD == 2012) %>%
  transmute(REF_AREA, r_2012_prop = OBS_VALUE / 100) %>%
  left_join(pop_2012_country, by = "REF_AREA") %>%
  left_join(pop_2030_country, by = "REF_AREA") %>%
  mutate(
    data_level = "Country",
    baseline_numb = r_2012_prop * basepop_value_2012,
    drop_cov_30 = 0.6,
    target_numb_30 = drop_cov_30 * baseline_numb,
    target_prop_30 = stata_round(100 * target_numb_30 / basepop_value_2030, round_digits_prev),
    r_2012 = r_2012_prop * 100,
    Classification = NA_character_,
    Region = NA_character_,
    Class = REF_AREA,
    regional_n = baseline_numb
  ) %>%
  select(
    Classification,
    Region,
    Class,
    REF_AREA,
    regional_n,
    r_2012,
    basepop_value_2030,
    data_level,
    baseline_numb,
    drop_cov_30,
    target_numb_30,
    target_prop_30
  )

baseline_df <- bind_rows(baseline_df, country_baseline_df)

endline_df <- stnt_analysis_df %>%
  filter(TIME_PERIOD == 2024) %>%
  transmute(data_level, REF_AREA, r_2024 = OBS_VALUE)

# =============================================================================
# Current AARR (computed on prevalence % because OBS_VALUE is %)
# =============================================================================
aarr_df <- stnt_analysis_df %>%
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

# =============================================================================
# Combine and classify
# =============================================================================
final_df <- baseline_df %>%
  left_join(endline_df, by = c("data_level", "REF_AREA"), suffix = c("_2012", "_2024")) %>%
  left_join(aarr_df, by = c("data_level", "REF_AREA")) %>%
  mutate(
    r_2012 = r_2012,
    r_2024 = r_2024,
    region = REF_AREA,
    indicator = "stunting",
    thresholdbasis = "r",
    r_2012_aarr = stata_round(r_2012, round_digits_prev),
    target_prop_30_aarr = stata_round(target_prop_30, round_digits_prev),
    target_prop_30_for_aarr = if_else(!is.na(target_prop_30_aarr), pmax(target_prop_30_aarr, 3), NA_real_),

    # Required AARR uses the easier target when percent-change target is below threshold.
    required_AARR_2030 = if_else(
      !is.na(target_prop_30_for_aarr) & !is.na(r_2012_aarr) & r_2012_aarr > 0 & target_prop_30_for_aarr > 0,
      stata_round(100 * (1 - exp((log(target_prop_30_for_aarr) - log(r_2012_aarr)) / (2030 - 2012))), round_digits_aarr),
      NA_real_
    ),
    current_AARR_assess = stata_round(current_AARR, round_digits_aarr),
    required_AARR_2030_assess = stata_round(required_AARR_2030, round_digits_aarr),

    # Threshold: already under 3% prevalence (your rule)
    crossthreshold_2030 = if_else(!is.na(r_2024) & r_2024 <= 3, 1, 0),

    FullClassification_2030 = case_when(
      is.na(current_AARR_assess) | is.na(required_AARR_2030_assess) ~ "Assessment not Possible",
      crossthreshold_2030 == 1 ~ "On track",
      current_AARR_assess >= required_AARR_2030_assess ~ "On track",
      current_AARR_assess > 0.5 ~ "Some progress",
      current_AARR_assess >= -0.5 ~ "No progress",
      current_AARR_assess < -0.5 ~ "Worsening",
      TRUE ~ "Assessment not Possible"
    ),

    UNICEF_Classification_2030 = case_when(
      is.na(current_AARR_assess) | is.na(required_AARR_2030_assess) ~ "Assessment not Possible",
      (crossthreshold_2030 == 1 | (!is.na(r_2024) & r_2024 <= 3)) ~ "Target met",
      TRUE ~ FullClassification_2030
    ),

    SimpleClassification = case_when(
      is.na(current_AARR_assess) ~ "Assessment not Possible",
      current_AARR_assess > 0.5 ~ "improving",
      current_AARR_assess >= -0.5 ~ "no change",
      current_AARR_assess < -0.5 ~ "worsening",
      TRUE ~ "Assessment not Possible"
    )
  )

# === Export summary (classification + target_prop_30 etc.) ===
progress_st <- final_df %>%
  transmute(
    INDICATOR = "NT_ANT_HAZ_NE2_MOD",
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
    target_value_2030 = target_prop_30_for_aarr,
    target_threshhold = 3,
    target_percent_change = 40,
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

write_csv(progress_st, file.path(outputdir_projections_inter, "st_progress_2030.csv"))

progress_append_path <- file.path(outputdir_projections_final, "progress_2030_appended.csv")
if (file.exists(progress_append_path)) {
  progress_appended <- read_nt_projection_progress_file(progress_append_path)
  if (!("INDICATOR" %in% names(progress_appended))) {
    progress_appended <- progress_appended %>%
      mutate(INDICATOR = if ("indicator_code" %in% names(progress_appended)) as.character(indicator_code) else NA_character_)
  }
  progress_appended <- progress_appended %>%
    filter(INDICATOR != "NT_ANT_HAZ_NE2_MOD") %>%
    bind_rows(progress_st)
} else {
  progress_appended <- progress_st
}
tryCatch(
  write_csv(progress_appended, progress_append_path),
  error = function(e) {
    warning("Could not write appended progress file: ", progress_append_path, " (", conditionMessage(e), ")")
  }
)

# =============================================================================
# Projections + target trajectories (LONG FORMAT)
# CAREFUL: We keep projections/targets on % scale, because combined_df expects OBS_VALUE (%).
# - Projection: anchored at 2012 using current_AARR
# - Target:     anchored at 2012 using required_AARR_2030 (constructed from number-based target_prop_30)
# =============================================================================
years <- 2013:2030

projected_2013_2030 <- final_df %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = stata_round(r_2012 * (1 - (current_AARR / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Projected"
  ) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

target_2013_2030 <- final_df %>%
  select(data_level, REF_AREA, r_2012, current_AARR, required_AARR_2030) %>%
  crossing(TIME_PERIOD = years) %>%
  mutate(
    SEX = "_T",
    OBS_VALUE = stata_round(r_2012 * (1 - (required_AARR_2030 / 100))^(TIME_PERIOD - 2012), round_digits_prev),
    TYPE = "Target"
  ) %>%
  select(data_level, REF_AREA, SEX, TIME_PERIOD, OBS_VALUE, current_AARR, required_AARR_2030, TYPE)

# Export DW-ready 2030 target indicator for stunting (after conversion to prevalence)
dir.create(file.path(outputdir, "Targets"), recursive = TRUE, showWarnings = FALSE)

trgt_2030_nt_ant_haz_ne2_mod <- bind_rows(
  final_df %>%
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
    INDICATOR = "TRGT_2030_NT_ANT_HAZ_NE2_MOD",
    SEX = SEX,
    AGE = "_T",
    TIME_PERIOD = TIME_PERIOD,
    OBS_VALUE = OBS_VALUE,
    OBS_FOOTNOTE = "2030 target trajectory for stunting prevalence, derived from number-based target then converted to prevalence and anchored at 2012 baseline."
  )



# =============================================================================
# Combine with original modelled data
# =============================================================================
agg_df_with_type <- stnt_analysis_df %>%
  mutate(TYPE = "Modelled")

combined_df <- bind_rows(
  agg_df_with_type,
  projected_2013_2030,
  target_2013_2030
) %>%
  mutate(
    current_AARR      = stata_round(current_AARR,      round_digits_aarr),
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
    INDICATOR = "NT_ANT_HAZ_NE2_MOD"
  )
if ("SEX" %in% names(export_df)) {
  export_df <- export_df %>%
    filter(is.na(SEX) | SEX == "_T")
}
export_df <- add_nt_population_columns(export_df, "NT_ANT_HAZ_NE2_MOD") %>%
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
  file.path(outputdir_projections_exports, "st_estimates_targets_projections.xlsx"),
  overwrite = TRUE
)


