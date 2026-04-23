# Dimension Coverage and Reference Disaggregation Extension Skill

Last updated: 2026-04-12

## Purpose

Guide AI agents through the full cycle of:
1. Auditing dimension coverage after a CMRS2 build
2. Diagnosing unmapped rows
3. Deciding whether to fix via hardcoded fallback or by extending `reference_disaggregations.csv`
4. Executing the chosen fix safely without breaking DW-Production

---

## Background: Two-Layer Mapping System

CMRS2 datasets are dimensioned using a two-layer system:

**Layer 1 — Reference join (primary)**
`build_layer2_dataset()` joins each row to `reference_disaggregations.csv` via `standard_disagg` (numeric ID).
This populates HELIX_SEX, HELIX_AGE, HELIX_WEALTH_QUINTILE, HELIX_RESIDENCE, HELIX_MATERNAL_EDU_LVL, HELIX_HEAD_OF_HOUSE.
Rows that don't match a reference ID get all HELIX fields empty → dimensions default to `_T`.

**Layer 2 — Fallback derivation (secondary)**
`apply_dataset_fallback_dims()` in `0_layer2_utils.r` catches rows still at `_T` after the reference join.
Each dataset has its own fallback derive functions that inspect `BackgroundCharacteristics`, `StandardDisaggregations`, and `ContextualDisaggregationsLabel`.
This is the current fix for dimensions not yet in the reference CSV.

---

## Coverage Audit Recipe

Run after every CMRS2 build. The target is: non-National fully_T = 0.

```r
library(arrow); library(dplyr)

df <- read_parquet("<output_path>.parquet") %>% mutate(across(everything(), as.character))

dim_cols <- c("SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION", "HEAD_OF_HOUSEHOLD",
              "MOTHER_AGE", "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY", "DELIVERY_MODE",
              "MULTIPLE_BIRTH", "REGION")

fully_t <- df %>% filter(apply(select(., all_of(dim_cols)), 1, function(r) all(r == "_T")))
cat("Fully _T rows:", nrow(fully_t), "\n")
print(fully_t %>% count(BackgroundCharacteristics, sort = TRUE), n = 30)

non_national <- fully_t %>%
  filter(!(BackgroundCharacteristics %in% c("National", NA_character_) |
           trimws(coalesce(BackgroundCharacteristics, "")) == ""))
cat("Non-National fully_T:", nrow(non_national), "\n")
```

---

## Diagnosing Unmapped Rows

When non-National fully_T > 0, inspect the source DTA to understand what `standard_disagg` IDs and labels these rows carry:

```r
library(haven); library(dplyr)
src <- haven::read_dta(file.path(cmrsInputDir, "CMRS_<DATASET>.dta")) %>%
  mutate(across(everything(), as.character))

# Find standard_disagg IDs present in source but absent from reference_disaggregations.csv
ref <- readr::read_csv(disagg_map_path, col_types = cols(.default = col_character()))
missing_ids <- src %>%
  filter(!standard_disagg %in% ref$ID) %>%
  count(standard_disagg, BackgroundCharacteristics, StandardDisaggregations, sort = TRUE)
print(missing_ids, n = 50)
```

---

## Decision: Reference CSV Extension vs. Hardcoded Fallback

### When to extend `reference_disaggregations.csv`

Extend the CSV when the disaggregation maps cleanly to an existing DW dimension (SEX, AGE, RESIDENCE, WEALTH/HELIX_WEALTH_QUINTILE, EDUCATION/HELIX_MATERNAL_EDU_LVL, HEAD_OF_HOUSE) **using a code DW already accepts**.

### When to use hardcoded fallback

Use fallback functions in `0_layer2_utils.r` when:
- The dimension doesn't exist as a HELIX column (MOTHER_AGE, DELIVERY_ASSISTANCE, PLACE_OF_DELIVERY, DELIVERY_MODE, MULTIPLE_BIRTH, REGION)
- The required value code is OSE-specific and not a valid DW HELIX value
- The mapping logic requires string parsing that can't be expressed as a row-level ID lookup

### CRITICAL: DW-Production Dependency

DW-Production fetches `reference_disaggregations.csv` **directly from the GitHub main branch** via raw URL:
```
https://raw.githubusercontent.com/unicef-drp/OSE-DA-NT/refs/heads/main/reference_data_manager/reference_tables/reference_disaggregations.csv
```

DW uses `transmute()` selecting only these columns:
- `standard_disagg_key` (from `ID`)
- `HELIX_SEX`, `HELIX_AGE`, `HELIX_WEALTH_QUINTILE`, `HELIX_RESIDENCE`, `HELIX_MATERNAL_EDU_LVL`, `HELIX_HEAD_OF_HOUSE`
- `REF_STANDARD_DISAGG` (from `Standard Disaggregations`)
- `REF_BASE_POPULATION` (from `BasePopulation`)

**Adding new columns is safe** — DW ignores them via `transmute()`.
**Adding new rows is safe provided** HELIX_CODE would be `"|||||"` (all 6 fields empty) — DW filters those out.
**Modifying existing rows changes DW output** — requires explicit approval.

---

## Valid HELIX Column Codes

Do NOT use SDMX codebook values — they differ from DW accepted values.
The authoritative source is the existing `HELIX_*` column values already present in `reference_disaggregations.csv`.

Current known DW-accepted values by column (derived from existing CSV):
- `HELIX_SEX`: F, M (female/male); `_T` = total (leave blank in CSV, not written as `_T`)
- `HELIX_RESIDENCE`: U, R
- `HELIX_WEALTH_QUINTILE`: Q1, Q2, Q3, Q4, Q5, B20, B40, B60, B80, R20, R40, R60, R80, T1, T2, T3
- `HELIX_MATERNAL_EDU_LVL`: ISCED11A_01, ISCED11_1, AGG_0_1, AGG_2_3, AGG_3S_H, AGG_5T8, MISSING_EDU
- `HELIX_HEAD_OF_HOUSE`: (check existing values in CSV before assuming)
- `HELIX_AGE`: (check existing values in CSV — SDMX age codes differ from DW practice)

Before adding any new code value to a HELIX column, verify it exists elsewhere in the CSV.
If a value doesn't exist yet, treat it as an OSE-specific extension and use a fallback function instead.

---

## Safe Extension Procedure for `reference_disaggregations.csv`

1. Identify the `standard_disagg` ID(s) that need mapping (from diagnostic step above)
2. Look up what `BackgroundCharacteristics` / `StandardDisaggregations` those IDs represent in the source DTA
3. Determine the correct HELIX column and value — verify the value exists in the CSV already
4. Propose new rows to add (new IDs get new sequential `ID` values; do not reuse or renumber)
5. Confirm with user before writing — this file affects DW-Production on merge to main
6. After adding rows: re-run the build, re-run coverage audit, confirm non-National fully_T = 0
7. Remove the corresponding hardcoded fallback logic from `0_layer2_utils.r` if it is now redundant

---

## OSE-Specific Dimensions (No Reference CSV Column)

These dimensions are OSE-DA-NT only and will always be handled by fallback functions:

| Dimension | Column | Notes |
|---|---|---|
| MOTHER_AGE | Not in CSV | Age at birth: Y_LT15, Y15T19, Y20T34, Y_GE35 |
| DELIVERY_ASSISTANCE | Not in CSV | SKILLED, OTHER_PROVIDER, RELATIVE_OR_OTHER (BW); HEALTH_PROFESSIONAL, OTHER, TRADITIONAL_BIRTH_ATTENDANT, NO_ONE (IYCF) |
| PLACE_OF_DELIVERY | Not in CSV | HOME_OR_OTHER, PUBLIC_SECTOR, PRIVATE_MEDICAL_SECTOR (BW); HEALTH_FACILITY, HOME, OTHER (IYCF) |
| DELIVERY_MODE | Not in CSV | C_SECTION, VAGINAL |
| MULTIPLE_BIRTH | Not in CSV | SINGLETON, MULTIPLE |
| REGION | Not in CSV | For Subnational Region, derive canonical REGION_N from StandardDisaggregations; contextual labels are secondary only |

---

## Duplicate-Key Safety Rule (Subnational Region)

If accepted outputs show duplicate analytical keys and Subnational Region is involved:

1. Derive REGION from `StandardDisaggregations` Region number (for example `Region 3` -> `REGION_3`).
2. Derive Subnational urban/rural residence flags from `StandardDisaggregations` tokens.
3. Do not derive canonical REGION from contextual label text, because labels can contain embedded urban/rural words that collapse distinct regions after normalization.

This pattern was validated on IOD in April 2026 and removed the final accepted-key duplicates.

These should remain as fallback functions unless a new HELIX column is added to the CSV for them — which would require DW-Production coordination.

---

## Files Involved

| File | Role |
|---|---|
| `reference_data_manager/reference_tables/reference_disaggregations.csv` | Primary mapping reference; consumed by DW-Production via GitHub raw URL |
| `analysis_datasets/02_codes/0_layer2_utils.r` | Fallback dimension functions and `apply_dataset_fallback_dims()` |
| `analysis_datasets/02_codes/2_build_cmrs2_*.r` | Per-dataset build scripts |
| `C:/.../nt_sdmx_codebooks.xlsx` | SDMX standard reference — use for context only; does NOT define DW accepted codes |
