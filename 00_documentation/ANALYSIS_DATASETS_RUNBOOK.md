# Analysis Datasets Runbook

Last updated: 2026-04-12

## Scope

This runbook covers the active scripts under:
- analysis_datasets/02_codes/

## Purpose

These scripts build standardized CMRS2-friendly datasets and validation outputs from upstream CMRS Stata files.

This area aligns with the legacy CMRS usage manuals and reference workbooks, which describe how nutrition data move from structured warehouse/CMRS assets into reusable analysis datasets.

## Current Entry Points

- analysis_datasets/02_codes/0_execute_conductor.r
  - Sources the CMRS2 build scripts for series and non-series domain families.

- analysis_datasets/02_codes/1_build_layer2_datasets.r
  - Builds standardized layer-2 datasets from CMRS Stata inputs.
  - Joins disaggregation mappings from reference_data_manager/indicators/reference_disaggregations.csv.

- analysis_datasets/02_codes/_verify_all_outputs.r
  - Performs structural and distribution-style verification across generated outputs.

## Current Build Chain

The execute conductor currently sources:
- 2_build_cmrs2_series.r
- 2_build_cmrs2_bw.r
- 2_build_cmrs2_iod.r
- 2_build_cmrs2_ant.r
- 2_build_cmrs2_iycf.r

The series builder currently depends on shared helpers in:
- analysis_datasets/02_codes/1_layer2_utils.r

## Reference Dependencies

Current repository reference assets used in this workflow include:
- reference_data_manager/indicators/directory_indicator.csv
- reference_data_manager/indicators/reference_disaggregations.csv

These mirror the role played by legacy assets such as:
- DIRECTORY_INDICATOR
- REFERENCE_DISAGGREGATIONS
- DIRECTORY_SURVEY
- CMRS field/codebook workbooks

## Data Model Notes

The active layer-2 build script standardizes core analytical fields such as:
- REF_AREA
- TIME_PERIOD
- INDICATOR
- SEX
- AGE
- RESIDENCE
- WEALTH
- EDUCATION
- VALUE

It also preserves row count across joins and warns on unmapped disaggregation codes, which is consistent with the legacy emphasis on controlled disaggregation mapping.

## Environment Notes

Some current scripts still use entrenched absolute paths for:
- upstream CMRS input directories
- local output directories

These should be treated as migration-state behavior, not the long-term target design.

Future refactoring should move this workflow toward profile/config-based path resolution like the further transformation system.

## Recommended Documentation Follow-Up

- Document each `2_build_cmrs2_*` output file and expected schema.
- Document the verification checks in _verify_all_outputs.r as a formal QA checklist.
- Add a reference-data-manager note describing how indicator and disaggregation reference files are versioned and updated.