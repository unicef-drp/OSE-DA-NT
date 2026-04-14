# Nutrition Projections Pipeline (NT)

This folder contains the active nutrition projections workflow for five indicator groups.

Scope of this README:
- Included: scripts 1 through 7 in this folder.
- Excluded on purpose: 101 and 201 scripts (planned to move elsewhere).
- Excluded for now: DANT projection scripts (pending fixes).

## What This Pipeline Does

The pipeline builds progress assessments and projected/target trajectories for:
- Child overweight
- Anemia in women 15-49
- Child wasting
- Child stunting
- Low birth weight

For each indicator group, the pipeline generally:
1. Loads regional modeled series and country modeled series.
2. Harmonizes both to a common percent scale.
3. Computes baseline and latest reference values.
4. Estimates current AARR from historical modeled data.
5. Computes required AARR for global nutrition target logic.
6. Produces classification summaries.
7. Produces long-format modeled/projected/target trajectories.
8. Writes CSV and Excel outputs.

General calculation pattern used in the active scripts:
- Baseline prevalence is taken from a fixed reference year, usually 2012, and rounded to 1 decimal place using Stata-aligned rounding at the point of assignment.
- Latest/endline prevalence is similarly rounded to 1 decimal place at assignment.
- Current AARR is estimated with a log-linear model over the modeled series history used by that script: `current_AARR = 100 * (1 - exp(slope))`, where `slope` comes from `lm(log(prev_for_aarr) ~ TIME_PERIOD)`.
- `prev_for_aarr` is computed from prevalence rounded to 1 decimal place before taking logs.
- All AARR values are rounded to 2 decimal places.
- Required AARR is then computed from the rounded baseline prevalence and the indicator-specific 2030 target prevalence.
- Threshold comparisons (e.g., `r_2024 <= 5`) use the rounded prevalence.
- Projected series are anchored at the rounded baseline and apply rounded current AARR forward each year.
- Target series are anchored at the rounded baseline and apply rounded required AARR forward each year.
- The projection/target trajectory formula used in the scripts is `OBS_VALUE = r_2012 * (1 - (AARR / 100))^(TIME_PERIOD - 2012)`.

## AARR and Classification Rules

The active projection scripts use a common classification framework, but each indicator family has its own target definition, threshold rule, and reliability rule.

### Core formulas

Current AARR:
- Round prevalence to 1 decimal place using the Stata-aligned helper before fitting the log-linear model.
- Define `prev_for_aarr = stata_round(OBS_VALUE, 1)`.
- Fit `lm(log(prev_for_aarr) ~ TIME_PERIOD)` over the script-specific historical window.
- Convert the fitted slope to AARR as `current_AARR = 100 * (1 - exp(slope))`.
- Round final `current_AARR` to 2 decimals using the same Stata-aligned rounding helper.

Required AARR:
- Compute an indicator-specific target prevalence for 2030.
- Use the same log-linear decay formula:
  `required_AARR_2030 = 100 * (1 - exp((log(target_prop) - log(baseline_prop)) / years_to_target))`
- Round final `required_AARR_2030` to 2 decimals using the Stata-aligned rounding helper.

Classification ladder used in the active scripts:
- `On track`: already below the indicator threshold at the latest assessment year, or `current_AARR >= required_AARR_2030`.
- `Some progress`: not yet on track, but `current_AARR >= 0.5`.
- `No progress`: not yet on track, and `-0.5 <= current_AARR < 0.5`.
- `Worsening`: `current_AARR < -0.5`.
- `Assessment not Possible`: insufficient data for the calculation, or script-specific reliability criteria not met.

Simple classification used in outputs:
- `improving`: `current_AARR >= 0.5`
- `no change`: `-0.5 <= current_AARR < 0.5`
- `worsening`: `current_AARR < -0.5`
- `Assessment not Possible`: AARR not available or not reliable for assessment

## Current Folder and Path Conventions

The execute script uses these main paths:

**Analysis Space paths (primary — country inputs and projection outputs):**
- analysisDatasetsInputDir: `{nutritionRoot}/github/analysis_datasets` (parquet files)
- Projection output root: `{nutritionRoot}/github/projections_progress_class`

**DW-Production paths (retained for regional estimates, population, crosswalks):**
- Input root: teamsFolder/01_dw_prep/011_rawdata/nt/input (population files)
- NT reusable intermediates: teamsFolder/01_dw_prep/011_rawdata/nt/output/inter (regional aggregates, groups_for_agg.csv)

Important:
- Country-level inputs (series and non-series) are read from analysis_datasets accepted parquets via `read_analysis_parquet_as_char()` in `1a_import_inputs.r`. Parquet values are proportions (0–1) and are converted to percent (0–100) during import. Indicator codes in parquets omit the `NT_` prefix, which is prepended during import.
- Regional estimates and crosswalk files are still read from DW-Production `output/inter/`.
- Projection products are written under the Analysis Space projection output root.

### Key data conventions during import
- Series parquets have `Subnational_Status = NA` (all national); non-series parquets use `"0"` for national. The filter handles both: `is.na(Subnational_Status) | Subnational_Status == "0"`.
- Accepted parquets contain both preferred (`DATA_SOURCE_PRIORITY = 1`) and non-preferred (`= 0`) surveys. All surveys are passed to downstream scripts; the AARR regression uses all surveys for non-baseline years.
- Confidential rows (`DataSourceDecision == "Accepted and Confidential"`) are excluded before projections.
- Anemia `SEX = "F"` is remapped to `"_T"` during import.

## Execution Order (Scripts 1-7)

1) 1_execute.r
- Entrypoint for projections in this folder.
- Sets input/output/inter paths and projection output folder.
- Sources scripts 2 through 6 in order.

2) 2_ant_ovwt_series.r
- Indicator: NT_ANT_WHZ_PO2_MOD (overweight).
- Inputs:
  - inter/agg_indicator/Regional_Output_NT_ANT_WHZ_PO2_MOD.xlsx
  - inter/cmrs_import/all_cmrs_series_public.csv
- Calculation details:
  - Baseline prevalence is `r_2012` from 2012.
  - Latest observed value used for threshold logic is `r_2024`.
  - Current AARR is estimated from modeled prevalence over 2012-2024 using the rounded prevalence series.
  - The 2030 target is prevalence below 5%.
  - Required AARR for 2030 is calculated as the rate needed to move from `r_2012` to 5% by 2030.
  - A separate 2025 maintenance target is also represented, with `required_AARR_2025 = 0`, meaning prevalence should not increase above the 2012 level.
  - A region/country is treated as already across the threshold when `r_2024 < 5`.
  - Projected values are generated for 2013-2030 from the 2012 baseline using current AARR.
  - Target values are generated for 2013-2030 from the 2012 baseline using required AARR for the 5% threshold.
- Assessment and classification rules:
  - Assessment window for `current_AARR`: 2012-2024.
  - Threshold rule: `r_2024 < 5` means the country/region is already on track.
  - Full/UNICEF classification:
    - `Target met` in the UNICEF field if already below 5% in 2024.
    - Otherwise `On track`, `Some progress`, `No progress`, or `Worsening` using the common AARR ladder.
    - `Assessment not Possible` if `current_AARR` or `required_AARR_2030` is unavailable.
- Outputs:
  - output_projections/aggregate_ow_progress_2025_2030.csv
  - output_projections/aggregate_ow_modelled_projected.xlsx
  - output_projections/aggregate_ow_modelled_projected.csv

3) 3_ane_wra_series.r
- Indicator: NT_ANE_WOM_15_49_MOD (anemia, women 15-49).
- Inputs:
  - inter/agg_indicator/Regional_Output_NT_ANE_WOM_15_49_MOD.xlsx
  - inter/cmrs_import/all_cmrs_series_public.csv
- Calculation details:
  - Baseline prevalence is `r_2012` from 2012.
  - Latest observed value used for assessment is `r_2023`.
  - Current AARR is estimated from modeled prevalence over 2012-2023 using the rounded prevalence series.
  - The 2030 target is a 50% reduction from the 2012 baseline, so `target_prop = r_2012 * 0.5`.
  - Required AARR for 2030 is calculated as the rate needed to move from `r_2012` to that reduced target by 2030.
  - A region/country is treated as already across the threshold when `r_2023 < target_prop`.
  - Projected values are generated for 2013-2030 from the 2012 baseline using current AARR.
  - Target values are generated for 2013-2030 from the 2012 baseline using required AARR for the 50% reduction target.
- Assessment and classification rules:
  - Assessment window for `current_AARR`: 2012-2023.
  - Target rule: the threshold is the indicator-specific 50% reduction target derived from the rounded baseline prevalence used by the script.
  - Threshold rule: `r_2023 < target_prop` means already on track.
  - Full/UNICEF classification:
    - `Target met` in the UNICEF field if already below the indicator-specific target in 2023.
    - Otherwise `On track`, `Some progress`, `No progress`, or `Worsening` using the common AARR ladder.
    - `Assessment not Possible` if `current_AARR` or `required_AARR_2030` is unavailable.
- Outputs:
  - output_projections/aggregate_ane_progress_2025_2030.csv
  - output_projections/aggregate_ane_modelled_projected.xlsx
  - output_projections/aggregate_ane_modelled_projected.csv

4) 4_ant_wst_survey.r
- Indicator: NT_ANT_WHZ_NE2 (wasting).
- Inputs:
  - inter/agg_domain/agg_ant_wasting.csv
- Calculation details:
  - Regional branch is series-like and uses 2012 as the fixed baseline year.
  - Country branch is non-series and survey-based.
  - Country baseline year selection rule:
    - choose the latest survey in 2005-2012 if one exists;
    - otherwise choose the earliest survey in 2013 or later.
  - Baseline prevalence comes from the highest-priority source in the selected baseline year.
  - Latest observed value used for assessment is the most recent survey available for the country and 2024 for the regional series branch.
  - Current AARR is estimated from rounded prevalence values.
  - For countries, the AARR regression uses all eligible post-baseline survey rows, except that duplicate rows in the baseline year are reduced to the highest-priority row only.
  - For countries with a 2005-2012 baseline, at least one post-2012 survey is required to estimate current AARR.
  - The 2030 target is a fixed prevalence of 5%.
  - Required AARR for 2030 is calculated as the rate needed to move from the baseline prevalence to 5% by 2030.
  - A country/region is treated as already across the threshold when the latest observed prevalence is below 5%.
  - Projected values are generated for 2013-2030 from the baseline year using current AARR.
  - Target values are generated for 2013-2030 from the baseline year using required AARR for the 5% target.
- Assessment and classification rules:
  - Threshold rule: latest observed prevalence below 5% means already on track.
  - Reliability rule for country rows: assessment is not possible if the latest survey is before 2005, or if fewer than 2 eligible surveys remain after applying the baseline rule.
  - If the latest observed prevalence is already below 5% and the latest survey year is after 2012, the script marks the row reliable for threshold-based assessment even if the AARR conditions are otherwise weak.
  - Full/UNICEF classification:
    - `Target met` in the UNICEF field if latest prevalence is already below 5%.
    - Otherwise `On track`, `Some progress`, `No progress`, or `Worsening` using the common AARR ladder.
    - `Assessment not Possible` if reliability conditions are not met.
- Outputs:
  - output_projections/aggregate_wst_progress_2025_2030.csv
  - output_projections/aggregate_wst_modelled_projected.xlsx
  - output_projections/aggregate_wst_modelled_projected.csv

5) 5_ant_stnt_series.r
- Indicator: NT_ANT_HAZ_NE2_MOD (stunting).
- Inputs:
  - inter/agg_indicator/Regional_Output_NT_ANT_HAZ_NE2_MOD.xlsx
  - inter/cmrs_import/all_cmrs_series_public.csv
  - inter/groups_for_agg.csv
  - input/base_population_1990_2030.csv
- Calculation details:
  - Baseline prevalence is `r_2012` from 2012 and latest observed value used for assessment is `r_2024`.
  - Current AARR is estimated from modeled prevalence over 2012-2024 using the rounded prevalence series.
  - Stunting uses number-based target logic before converting back to prevalence.
  - For regional rows, baseline numbers affected come from the input field `regional_n` in the 2012 regional file.
  - For country rows, baseline numbers affected are computed as 2012 prevalence times the 2012 under-5 population.
  - The 2030 target assumes a 40% reduction in numbers affected from the 2012 baseline, implemented as `target_numb_30 = 0.6 * baseline_numb`.
  - That 2030 target number is converted back to a 2030 target prevalence using 2030 population: `target_prop_30 = 100 * target_numb_30 / basepop_value_2030`.
  - Required AARR for 2030 is then calculated on the prevalence scale as the rate needed to move from `r_2012` to `target_prop_30` by 2030.
  - A region/country is treated as already across the threshold when `r_2024 < 3`.
  - Projected values are generated for 2013-2030 from the 2012 baseline using current AARR.
  - Target values are generated for 2013-2030 from the 2012 baseline using required AARR after the number-based target has been converted back to prevalence.
- Assessment and classification rules:
  - Assessment window for `current_AARR`: 2012-2024.
  - Threshold rule: `r_2024 < 3` means already on track.
  - The script rounds the converted target prevalence to 1 decimal place before using it in the required AARR calculation, because prevalences in this workflow are intentionally rounded before downstream use.
  - Because of that design choice, required AARR can differ slightly from WHO values for some countries. WHO computes required AARR for stunting from the unrounded converted target prevalence, while this script computes it from the rounded converted target prevalence.
  - Full/UNICEF classification:
    - `Target met` in the UNICEF field if already below 3% in 2024.
    - Otherwise `On track`, `Some progress`, `No progress`, or `Worsening` using the common AARR ladder.
    - `Assessment not Possible` if `current_AARR` or `required_AARR_2030` is unavailable.
- Outputs:
  - output_projections/aggregate_st_progress_2025_2030.csv
  - output_projections/aggregate_st_modelled_projected.xlsx
  - output_projections/aggregate_st_modelled_projected.csv

6) 6_bw_lbw_series.r
- Indicator: NT_BW_LBW (low birth weight).
- Inputs:
  - inter/agg_indicator/Regional_Output_NT_BW_LBW.xlsx
  - inter/cmrs_import/all_cmrs_series_public.csv
- Calculation details:
  - Baseline prevalence is `r_2012` from 2012.
  - Latest observed value used for assessment is `r_2020`.
  - Current AARR is estimated from modeled prevalence over 2012-2020 using the rounded prevalence series.
  - The 2030 target is a 30% reduction from the 2012 baseline, so `target_prop = r_2012 * 0.7`.
  - Required AARR for 2030 is calculated as the rate needed to move from `r_2012` to that reduced target by 2030.
  - The script also applies a threshold rule where values below 5% are treated as already on track.
  - Projected values are generated for 2013-2030 from the 2012 baseline using current AARR.
  - Target values are generated for 2013-2030 from the 2012 baseline using required AARR for the 30% reduction target.
- Assessment and classification rules:
  - Assessment window for `current_AARR`: 2012-2020.
  - Target rule: 30% reduction from the rounded 2012 baseline prevalence.
  - Threshold rule: prevalence below 5% in the latest assessment year is treated as already on track.
  - Full/UNICEF classification:
    - `Target met` in the UNICEF field if already below 5%.
    - Otherwise `On track`, `Some progress`, `No progress`, or `Worsening` using the common AARR ladder.
    - `Assessment not Possible` if `current_AARR` or `required_AARR_2030` is unavailable.
- Outputs:
  - output_projections/aggregate_lbw_progress_2025_2030.csv
  - output_projections/aggregate_lbw_modelled_projected.xlsx
  - output_projections/aggregate_lbw_modelled_projected.csv

## Notes and Current Boundaries

- IYCF and DANT scripts are intentionally not included yet.
- Some scripts include a small fallback that sets interdir from outputdir/inter if interdir is not pre-defined, so script-level execution remains possible.

## Run Guidance

Recommended:
1. Run the NT production pipeline first so output/inter is refreshed.
2. Run this projection execute script:
   - 05_projections/012_codes/nt/1_execute.r
3. Check output files under output_projections.

If inputs are missing, verify expected files exist under output/inter as listed above.
