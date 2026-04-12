# Analysis Datasets — Build Scripts

This folder contains the production scripts that transform upstream CMRS Stata
files into standardised Parquet analysis datasets.

## Quick Start

Set your working directory to the repository root and run the conductor:

```r
source("analysis_datasets/02_codes/0_execute_conductor.r")
```

Or build a single domain:

```r
source("analysis_datasets/02_codes/2_build_cmrs2_bw.r")
```

## File Inventory

| File | Purpose |
|------|---------|
| `0_execute_conductor.r` | Orchestrator — runs all five domain builders in sequence. |
| `1_layer2_utils.r` | Shared utility module (mapping loader, build function, dimension derivation). |
| `2_build_cmrs2_series.r` | Builds the combined series dataset (ANE + ANT + DANT + SANT + VAS). |
| `2_build_cmrs2_bw.r` | Builds the birth-weight (BW) dataset. |
| `2_build_cmrs2_iod.r` | Builds the iodine-deficiency (IOD) dataset. |
| `2_build_cmrs2_ant.r` | Builds the anthropometry (ANT) dataset. |
| `2_build_cmrs2_iycf.r` | Builds the infant & young child feeding (IYCF) dataset. |
| `3_verify_all_outputs.r` | Post-build QA — checks file existence, schema, row counts, and value distributions. |

## Execution Order

The conductor sources files in this order:

1. `2_build_cmrs2_series.r`
2. `2_build_cmrs2_bw.r`
3. `2_build_cmrs2_iod.r`
4. `2_build_cmrs2_ant.r`
5. `2_build_cmrs2_iycf.r`

Each `2_build_*` script sources `1_layer2_utils.r`, which loads
`profile_OSE-DA-NT.R` for path configuration if it is not already loaded.

After a full conductor run, execute `3_verify_all_outputs.r` to validate
outputs.

## Outputs

All output files are written to the directory configured by
`analysisDatasetsOutputDir` in `profile_OSE-DA-NT.R`:

| Output file | Source DTA(s) | Compression |
|-------------|---------------|-------------|
| `cmrs2_series.parquet` | `CMRS_SERIES_ANE/ANT/DANT/SANT/VAS.dta` | zstd |
| `cmrs2_bw.parquet` | `CMRS_BW.dta` | zstd |
| `cmrs2_iod.parquet` | `CMRS_IOD.dta` | zstd |
| `cmrs2_ant.parquet` | `CMRS_ANT.dta` | zstd |
| `cmrs2_iycf.parquet` | `CMRS_IYCF.dta` | zstd |

## Analytical Dimensions

Each output dataset includes 12 analytical dimension columns, populated by a
two-layer strategy:

- **Layer 1 (reference lookup):** The `standard_disagg` ID from each source row
  is joined to `reference_data_manager/indicators/reference_disaggregations.csv`.
  HELIX_* columns provide the standard DW dimensions; OSE_* columns provide
  nutrition-specific dimensions.

- **Layer 2 (fallback derivation):** For rows where the reference does not
  resolve a dimension, hardcoded parsing functions in `1_layer2_utils.r` derive
  codes from `BackgroundCharacteristics` and `ContextualDisaggregationsLabel`.

| Dimension | Source (Layer 1) | Fallback (Layer 2) |
|-----------|------------------|--------------------|
| SEX | HELIX_SEX | — |
| AGE | HELIX_AGE → OSE_AGE | IYCF age-in-months parser |
| RESIDENCE | HELIX_RESIDENCE | IOD area-wealth suffix |
| WEALTH | HELIX_WEALTH_QUINTILE | BW/IOD share/decile/tercile mappers |
| EDUCATION | HELIX_MATERNAL_EDU_LVL → OSE_EDUCATION | BW/IYCF education parser |
| HEAD_OF_HOUSEHOLD | HELIX_HEAD_OF_HOUSE | BW/IOD HH-head sex parser |
| MOTHER_AGE | OSE_MOTHER_AGE | BW mother-age parser |
| DELIVERY_ASSISTANCE | OSE_DELIVERY_ASSISTANCE | BW/IYCF delivery-assistance parser |
| PLACE_OF_DELIVERY | OSE_PLACE_OF_DELIVERY | BW/IYCF place-of-delivery parser |
| DELIVERY_MODE | OSE_DELIVERY_MODE | BW c-section/vaginal parser |
| MULTIPLE_BIRTH | OSE_MULTIPLE_BIRTH | BW singleton/multiple parser |
| REGION | — | Subnational region / ethnicity / religion / caste parser |

## Dependencies

- **R packages:** dplyr, stringr, readr, arrow, haven, tibble
- **Config:** `profile_OSE-DA-NT.R` (reads `~/.config/user_config.yml`)
- **Reference data:** `reference_data_manager/indicators/reference_disaggregations.csv`
- **Upstream inputs:** CMRS Stata files (path set by `cmrsInputDir` in profile)
