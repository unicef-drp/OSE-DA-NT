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

## Wide crosswalk column provenance

The wide `directory_crosswalk.csv` is built from two sources:

| Source                                                          | # cols | Examples                                                                                                  |
|-----------------------------------------------------------------|--------|-----------------------------------------------------------------------------------------------------------|
| `crosswalk/directory_crosswalk_base.csv` (editable in repo)     | 218    | `Country`, `M49`, `ISO-3 Code`, `WB_Code`, `CND_Country_Code`, `UNICEF_Programme_Region_*`, `SOWC*`, `LDC_2014`–`LDC_2020`, `WB_1990`–`WB_2022`, `HAC_*`, `SP_*`, `Nutrition_Programme_*`, `Notes` |
| External merge from `unicef-drp/Country-and-Region-Metadata`    | 156    | `ISO3Code`, `WB_2024*`, `WHO.Region_2024`, `LDC_2024`, `AU_*`, `SDGRC_*` (ECA/ECE/ECLAC/ESCAP/ESCWA), `UNICEF_*` regions, `UNSDG_*`, `WB_HI/LI/LMI/UMI`, `WB_EAP/ECA/LAC/MNA/NAR/SAR/SSA`, `WHO_AFRO/AMRO/EMRO/EURO/SEARO/WPRO`, `FAO_LIFDC` |

Within the merged 156, the build script also derives consolidated columns
from the per-flag inputs: `WB_Latest`/`_3_Group`/`_2_Group` (from
`WB_HI/LI/LMI/UMI`), `WHO.Region` (from `WHO_AFRO/AMRO/EMRO/EURO/SEARO/WPRO`),
`World.Bank.Regions` (from `WB_EAP/ECA/LAC/MNA/NAR/SSA/SAR`), and
`LDC_Latest` (from `LDC_2024`, with BTN/STP recoded to "No").

The base 218 and the merged 156 have **zero name overlap** with each
other.

### Planned migration to the section-wide region repository

The section-wide region repository (currently in build-out) is intended to
become the authoritative source for country and region classifications
across the section. When that repo is complete, `2_build_directory_crosswalk.r`
must be updated so the section-wide repo — not
`unicef-drp/Country-and-Region-Metadata` and not the editable
`crosswalk/directory_crosswalk_base.csv` — is the primary source of the
wide crosswalk. At that point:

- The external merge step should be repointed at the section-wide repo.
- The repo CSV should shrink to only the UNICEF-curated columns that are
  not yet covered by the section-wide repo.
- Country identifiers (`M49`, `ISO-3 Code`, `WB_Code`, `CND_Country_Code`)
  should also be sourced from the section-wide repo, retiring the
  duplication noted above.

### Known duplication with `reference_tables/`

A handful of country-identifier columns also appear in
`reference_tables/directory_country.csv` (legacy migration artifact). The
build script currently passes them through from `directory_crosswalk_base.csv`
verbatim and does **not** look them up from `directory_country.csv`.

| Column                       | Also in                                  | Notes                                      |
|------------------------------|------------------------------------------|--------------------------------------------|
| `Country`                    | `reference_country_survey_type.csv`      | Country display name                       |
| `M49`                        | `directory_country.csv`                  | UN M49 numeric code                        |
| `ISO-3 Code`                 | `directory_country.csv`                  | ISO 3166-1 alpha-3                         |
| `WB_Code`                    | `directory_country.csv`                  | World Bank country code                    |
| `CND_Country_Code`           | `directory_country.csv`                  | Internal CND country code                  |
| `ID`, `Compliance Asset Id`  | every legacy SharePoint table            | Per-table SharePoint row IDs (name overlap only) |
| `Notes`                      | `directory_indicator.csv`                | Name overlap only (different content)      |

`directory_country.csv` is the editorial source of truth for country
identifiers; the crosswalk_base copy must be kept consistent with it.
A future refactor could have the build script lookup these identifiers
from `directory_country.csv` rather than trusting the crosswalk_base copy.

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
| Computed wide crosswalk                    | `2_build_directory_crosswalk.r`   | `{githubOutputRoot}/reference_data_manager/directory_crosswalk.csv`        |
| xlsx mirrors (one per editable CSV + wide) | `3_export_legacy_xlsx.r`          | `{githubOutputRoot}/reference_data_manager/xlsx/*.xlsx`                    |
| Stata `.dta` mirrors (one per editable CSV + wide) | `3b_export_legacy_dta.r`  | `{githubOutputRoot}/reference_data_manager/dta/*.dta`                      |
| Optional crosswalk diff                    | `4_crosswalk_check.r` (opt-in)    | `{githubOutputRoot}/reference_data_manager/crosswalk_check.csv`            |

All outputs are derived. None of them is ever edited by hand. The pipeline
does not write to the legacy SharePoint Export folder.

## Manual copy to legacy folders

The pipeline never writes to the legacy locations. After a successful run,
refresh the legacy consumers manually:

- Copy `{githubOutputRoot}/reference_data_manager/xlsx/*.xlsx` →
  legacy SharePoint `Sharepoint Export/` folder.
- Copy `{githubOutputRoot}/reference_data_manager/dta/*.dta` →
  legacy `CND Import/` Stata folder.

Review the rebuilt files in the repo output mirror before copying.

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
