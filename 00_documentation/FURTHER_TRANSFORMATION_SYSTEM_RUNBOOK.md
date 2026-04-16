# Further Transformation System Runbook

Last updated: 2026-04-15

## Scope

This runbook covers the active workflow under:
- further_transformation_system/projections_progress_class/

Main code folder:
- further_transformation_system/projections_progress_class/012_codes/

## Pipeline Goal

Generate nutrition projections and progress classifications for key indicator groups and produce consolidated final outputs for downstream use.

Legacy manuals, especially the overall CND manual and IYCF/birthweight/vitamin A instructions, frame this layer as downstream of standardized warehouse/CMRS outputs. The current repo structure keeps that same intent, but narrows it to nutrition-owned transformation logic.

## Main Entrypoint

- 1_execute.r

This script:
- Loads required libraries.
- Resolves project and teams paths (including fallback through user config).
- Creates required output folders.
- Sources scripts in execution order.

## Execution Order

1. 1a_import_inputs.r
2. 1b_population_lookup.r
3. 2_ant_ovwt_series.r
4. 3_ane_wra_series.r
5. 4_ant_wst_survey.r
6. 5_ant_stnt_series.r
7. 6_bw_lbw_series.r
8. 7_iycf_exbf_survey.r
9. 8_format_output.r

## Input And Output Path Pattern

Path roots are typically resolved from:
- %USERPROFILE%/.config/user_config.yml

Key root variables built in execution:

**DW-Production paths (retained for regional estimates, population, crosswalks):**
- inputdir — population files from DW-Production
- outputdir — DW-Production NT output root
- interdir — DW-Production intermediate files (regional aggregates, groups_for_agg.csv)

**Analysis Space paths (country inputs and projection outputs):**
- analysisDatasetsInputDir — `{nutritionRoot}/github/analysis_datasets` (parquet files)
- outputdir_projections — `{nutritionRoot}/github/projections_progress_class`
- outputdir_projections_input
- outputdir_projections_inter
- outputdir_projections_final

Country-level inputs (series and non-series) are read from analysis_datasets accepted
parquet files (`cmrs2_series_accepted.parquet`, `cmrs2_ant_accepted.parquet`,
`cmrs2_iycf_accepted.parquet`). Regional estimates still come from DW-Production
regional aggregation outputs in interdir.

## Column Conventions

All projection scripts use `IndicatorCode` as the indicator column name
(not `INDICATOR`). The `NT_` prefix is prepended during parquet import in
`1a_import_inputs.r`. Estimate values flow through as `OBS_VALUE` after being
converted from the parquet's 0–1 proportion scale to 0–100 percent scale during
import (the source `r` column is renamed to `OBS_VALUE`).

## Final Output Stage

Script:
- 8_format_output.r

Behavior:
- Reads progress split files from projections inter folder.
- Applies business-rule overrides for specific IndicatorCode/country combinations (e.g. NIC).
- Writes final appended files to projections final folder:
  - progress_2030_appended.csv
  - progress_2030_appended.xlsx

## Operational Notes

- Current scripts include fallback logic for path resolution if profile objects are missing.
- Some business rules are intentionally hardcoded for nutrition-team requested classifications.
- Any change to output filenames should be treated as a breaking interface change and documented before merge.
- The legacy documentation set consistently treats projections/reporting outputs as dependent on curated upstream indicator inputs, so upstream interface assumptions should remain explicit whenever this workflow changes.

## Dependencies

The execute pipeline uses R packages including:
- readxl
- dplyr
- tidyr
- stringr
- readr
- openxlsx
- yaml
- arrow (for reading analysis_datasets parquet files)

Ensure these are installed in the runtime environment before execution.

## Next Documentation Tasks

- Add indicator-level method notes for each of scripts 2 through 7.
- Add QA checklist for validating final appended output consistency.
- Add example dry-run command patterns for local and CI execution.