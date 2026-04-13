# Analysis Datasets Runbook

Last updated: 2026-04-13

## Scope

This runbook covers the active scripts under:
- analysis_datasets/02_codes/

See also: [analysis_datasets/02_codes/README.md](../analysis_datasets/02_codes/README.md)

## Purpose

These scripts build standardized CMRS2 analysis datasets from upstream CMRS
Stata files. Each source DTA is joined to the disaggregation reference mapping,
has 12 analytical dimension columns assigned, and is written to Parquet format.

## Entry Points

### Full build

```r
source("analysis_datasets/02_codes/1_execute_conductor.r")
```

Builds all five domain outputs in sequence. Each `2_build_*` script produces
both the all-estimates and accepted-only outputs.

### Single domain

Any `2_build_cmrs2_*.r` script can be run standalone to rebuild one domain
(both variants):

```r
source("analysis_datasets/02_codes/2_build_cmrs2_bw.r")
```

### Post-build validation

```r
# Verify all datasets
source("analysis_datasets/02_codes/0_verify_all_outputs.r")

# Verify a single dataset (from command line)
# Rscript analysis_datasets/02_codes/0_verify_all_outputs.r bw
```

## File Inventory

| # | Script | Purpose |
|---|--------|---------|
| 0 | `0_layer2_utils.r` | Shared module: reference loader, build function, dimension derivation. |
| 0 | `0_verify_all_outputs.r` | Post-build QA: schema, row counts, distributions. Supports per-dataset targets. |
| 1 | `1_execute_conductor.r` | Orchestrator — sources all five build scripts. |
| 2a | `2_build_cmrs2_series.r` | Series builder (ANE + ANT + DANT + SANT + VAS) — all-estimates + accepted. |
| 2b | `2_build_cmrs2_bw.r` | Birth weight builder — all-estimates + accepted. |
| 2c | `2_build_cmrs2_iod.r` | Iodine deficiency builder — all-estimates + accepted. |
| 2d | `2_build_cmrs2_ant.r` | Anthropometry builder — all-estimates + accepted. |
| 2e | `2_build_cmrs2_iycf.r` | Infant & young child feeding builder — all-estimates + accepted. |

## Outputs

| File | Source | Filter | Compression |
|------|--------|--------|-------------|
| `cmrs2_series.parquet` | 5 series DTAs combined | all estimates | zstd |
| `cmrs2_bw.parquet` | `CMRS_BW.dta` | all estimates | zstd |
| `cmrs2_iod.parquet` | `CMRS_IOD.dta` | all estimates | zstd |
| `cmrs2_ant.parquet` | `CMRS_ANT.dta` | all estimates | zstd |
| `cmrs2_iycf.parquet` | `CMRS_IYCF.dta` | all estimates | zstd |
| `cmrs2_series_accepted.parquet` | 5 series DTAs combined | `DataSourceDecisionCategory == "Accepted"` | zstd |
| `cmrs2_bw_accepted.parquet` | `CMRS_BW.dta` | `DataSourceDecisionCategory == "Accepted"` | zstd |
| `cmrs2_iod_accepted.parquet` | `CMRS_IOD.dta` | `DataSourceDecisionCategory == "Accepted"` | zstd |
| `cmrs2_ant_accepted.parquet` | `CMRS_ANT.dta` | `DataSourceDecisionCategory == "Accepted"` | zstd |
| `cmrs2_iycf_accepted.parquet` | `CMRS_IYCF.dta` | `DataSourceDecisionCategory == "Accepted"` | zstd |

Output directory is configured by `analysisDatasetsOutputDir` in
`profile_OSE-DA-NT.R`.

## Output Schema — Analytical Dimensions

Each output carries 12 dimension columns:

| Column | Layer 1 Reference Source | Layer 2 Fallback |
|--------|--------------------------|------------------|
| SEX | HELIX_SEX | — |
| AGE | HELIX_AGE / OSE_AGE | IYCF age-in-months |
| RESIDENCE | HELIX_RESIDENCE | IOD area-wealth suffix |
| WEALTH | HELIX_WEALTH_QUINTILE | BW/IOD share/decile/tercile |
| EDUCATION | HELIX_MATERNAL_EDU_LVL / OSE_EDUCATION | BW/IYCF education |
| HEAD_OF_HOUSEHOLD | HELIX_HEAD_OF_HOUSE | BW/IOD HH-head sex |
| MOTHER_AGE | OSE_MOTHER_AGE | BW mother-age |
| DELIVERY_ASSISTANCE | OSE_DELIVERY_ASSISTANCE | BW/IYCF delivery-assistance |
| PLACE_OF_DELIVERY | OSE_PLACE_OF_DELIVERY | BW/IYCF place-of-delivery |
| DELIVERY_MODE | OSE_DELIVERY_MODE | BW c-section/vaginal |
| MULTIPLE_BIRTH | OSE_MULTIPLE_BIRTH | BW singleton/multiple |
| REGION | — | Subnational / ethnicity / religion / caste |

## Reference Dependencies

| Asset | Path |
|-------|------|
| Disaggregation mapping | `reference_data_manager/indicators/reference_disaggregations.csv` |
| Indicator directory | `reference_data_manager/indicators/directory_indicator.csv` |
| User config | `~/.config/user_config.yml` |
| Path profile | `profile_OSE-DA-NT.R` |

The disaggregation mapping is also consumed by DW-Production via the GitHub main
branch raw URL. Adding new columns (e.g. OSE_*) is safe — DW-Production selects
only its known HELIX columns and ignores anything else.

## Environment

All paths are resolved through `profile_OSE-DA-NT.R`, which reads
`~/.config/user_config.yml`. Required config keys: `githubFolder`, `teamsRoot`,
`nutritionRoot`.

R package dependencies: dplyr, stringr, readr, arrow, haven, tibble.