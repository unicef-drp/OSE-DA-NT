# Further Transformation System Runbook

Last updated: 2026-04-12

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
- inputdir
- outputdir
- interdir
- outputdir_projections
- outputdir_projections_input
- outputdir_projections_inter
- outputdir_projections_final

## Final Output Stage

Script:
- 8_format_output.r

Behavior:
- Reads progress split files from projections inter folder.
- Applies business-rule overrides for specific indicator/country combinations.
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

Ensure these are installed in the runtime environment before execution.

## Next Documentation Tasks

- Add indicator-level method notes for each of scripts 2 through 7.
- Add QA checklist for validating final appended output consistency.
- Add example dry-run command patterns for local and CI execution.