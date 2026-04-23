# Reference Data Manager — Runbook

## Overview

The `reference_data_manager/` folder is the canonical store for all UNICEF
nutrition reference tables. It replaces the legacy Access database
(`Indicator Manager.accdb`, `RDM Export Package.accdb`) and the SharePoint
xlsx editing workflow that lived under
`Combined Nutrition Databases/Post-Processing System/2 - Reference Data Manager`.

## Pipeline

```mermaid
flowchart LR
  E1[reference_tables/*.csv\nDATA ENTRY] --> X[3_export_legacy_xlsx.r]
  E2[crosswalk/directory_crosswalk_base.csv\nDATA ENTRY] --> X
  E2 --> B[2_build_directory_crosswalk.r]
  E1 --> B
  EXT[unicef-drp/Country-and-Region-Metadata\nall_regions_long_format.csv] --> B
  B --> O1[githubOutputRoot/reference_data_manager/directory_crosswalk.csv\nDERIVED]
  X --> O2[githubOutputRoot/reference_data_manager/*.xlsx\nDERIVED]
  E1 --> D[3b_export_legacy_dta.r]
  B --> D
  D --> O5[githubOutputRoot/reference_data_manager/*.dta\nDERIVED]
  O1 --> C[4_crosswalk_check.r (optional)]
  ARCH[SharePoint Archive snapshot] --> C
  C --> O3[githubOutputRoot/reference_data_manager/crosswalk_check.csv\nDERIVED]
```

The pipeline never writes to the legacy SharePoint Export folder. To update
SharePoint, copy from the repo output mirror manually after review.

## Editing

| To change                                               | Edit                                                          |
|---------------------------------------------------------|---------------------------------------------------------------|
| Country list / metadata                                  | `reference_tables/directory_country.csv`                      |
| Region definitions                                       | `reference_tables/directory_region.csv`                       |
| Disaggregation mappings                                  | `reference_tables/reference_disaggregations.csv`              |
| Indicator metadata                                       | `reference_tables/directory_indicator.csv`                    |
| UNICEF-curated country classifications (LDC, Programme regions, SOWC, etc.) | `crosswalk/directory_crosswalk_base.csv` |
| Anything else (decision categories, survey types, etc.) | `reference_tables/reference_*.csv`                            |

After editing any CSV, rerun the conductor to refresh the computed wide
crosswalk and the legacy xlsx exports.

## Build

```r
source("profile_OSE-DA-NT.R")
source("reference_data_manager/02_codes/1_execute_conductor.r")
```

## Crosswalk diff vs archive

```r
run_crosswalk_check <- TRUE
crosswalk_check_archive <- "DIRECTORY_CROSSWALK (Beta)_20241212"  # optional
source("reference_data_manager/02_codes/1_execute_conductor.r")
```

The diff is written to `{githubOutputRoot}/reference_data_manager/crosswalk_check.csv`
in long format (`Country, Classification, Class_New, Class_Old, Changed`).

## Outputs

| Output                                     | Built by                          | Path                                                                       |
|--------------------------------------------|-----------------------------------|----------------------------------------------------------------------------|
| Computed wide crosswalk                    | `2_build_directory_crosswalk.r`   | `{githubOutputRoot}/reference_data_manager/directory_crosswalk.csv` (and `.xlsx`, `.dta`) |
| Legacy-named xlsx mirrors                  | `3_export_legacy_xlsx.r`          | `{githubOutputRoot}/reference_data_manager/*.xlsx`                         |
| Legacy-named Stata `.dta` mirrors          | `3b_export_legacy_dta.r`          | `{githubOutputRoot}/reference_data_manager/*.dta`                          |
| Optional crosswalk diff                    | `4_crosswalk_check.r` (opt-in)    | `{githubOutputRoot}/reference_data_manager/crosswalk_check.csv`            |

All outputs are derived. None of them is ever edited by hand. The pipeline
does not write to the legacy SharePoint Export folder.

## Cross-repo dependencies

- `analysis_datasets/02_codes/0_layer2_utils.r` reads
  `reference_data_manager/reference_tables/reference_disaggregations.csv` and
  `reference_data_manager/reference_tables/directory_indicator.csv` directly. No
  changes required when the repo CSVs are updated.
- DW-Production consumers that read the legacy SharePoint xlsx files: copy
  the rebuilt files from `{githubOutputRoot}/reference_data_manager/` to
  SharePoint manually after review. The pipeline does not write to SharePoint.

## Migration provenance

- Source: `C:/Users/<user>/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Post-Processing System/2 - Reference Data Manager`
- Migrated by: `02_codes/_migrate_xlsx_to_csv.py` (one-time helper)
- Date: 2026-04-23

The original folder is the read-only source of truth for the initial
migration. Going forward the repo CSVs are the source of truth and the
SharePoint folder is a generated mirror.
