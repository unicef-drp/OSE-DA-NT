# reference_data_manager

Editable reference data for the UNICEF Combined Nutrition Databases.

This folder replaces the legacy Access-based "Reference Data Manager" tool and
the SharePoint-only edit workflow. Every reference table is a small CSV that
can be edited directly in the repo. Build scripts assemble the wide
`directory_crosswalk.csv` and re-export legacy-named xlsx and Stata `.dta`
files so the SharePoint Export folder and the legacy `CND Import/` Stata
folder remain a complete drop-in copy.

## Folder layout

```
reference_data_manager/
  reference_tables/      # DATA ENTRY  — one CSV per legacy DIRECTORY_*/REFERENCE_*.xlsx
  crosswalk/             # DATA ENTRY  — single editable wide directory_crosswalk_base.csv
  02_codes/              # build + export R scripts (and one-time migration helpers)
  00_documentation/      # runbook
```

**No derived files live in the repo.** Every CSV under `reference_tables/`
and `crosswalk/` is meant to be edited by hand. All computed outputs are
written to `{githubOutputRoot}/reference_data_manager/` and are rebuilt from
the editable inputs each run — do not edit them by hand.

Field-level guarantee: the editable `crosswalk/directory_crosswalk_base.csv`
and the columns added by the build script (external classifications) have
**zero column-name overlap**, so there is no risk of editing the "wrong
copy" of any field.

### `reference_tables/` — DATA ENTRY

Every file is editable by hand. Each CSV maps 1-to-1 to a legacy SharePoint
`DIRECTORY_*` or `REFERENCE_*.xlsx` file. The legacy `indicators/` subfolder
has been consolidated here: `directory_indicator.csv` and
`reference_disaggregations.csv` now live directly in `reference_tables/`.

### `crosswalk/` — DATA ENTRY

Contains the single editable wide base table:

- `directory_crosswalk_base.csv` — UNICEF-curated country classifications
  (Programme Region, SOWC, LDC_2020, hand-tagged groupings, etc.). Maps 1-to-1
  to the legacy `DIRECTORY_CROSSWALK (Beta).xlsx` sheet.

The build script `02_codes/2_build_directory_crosswalk.r` reads this file,
merges in external classifications (UNICEF, WHO, WB, SDGRC, AU, UNSDG,
FAO_LIFDC) from the public `unicef-drp/Country-and-Region-Metadata` repo,
and writes the wide computed `directory_crosswalk.csv` to
`{githubOutputRoot}/reference_data_manager/`.

> **Planned migration.** The section-wide region repository (currently in
> build-out) is intended to become the authoritative source for country and
> region classifications across the section. Once that repo is complete,
> `2_build_directory_crosswalk.r` should be updated so that the section-wide
> repo — not `unicef-drp/Country-and-Region-Metadata` and not the editable
> `directory_crosswalk_base.csv` — is the primary source of the wide
> crosswalk. The repo CSV will then shrink to only the UNICEF-curated
> columns that are not yet in the section-wide repo.

### Column provenance in the wide crosswalk

The wide `directory_crosswalk.csv` is built from two sources:

| Source                                                          | # cols | Examples                                                                                                  |
|-----------------------------------------------------------------|--------|-----------------------------------------------------------------------------------------------------------|
| `crosswalk/directory_crosswalk_base.csv` (editable in repo)     | 218    | `Country`, `M49`, `ISO-3 Code`, `WB_Code`, `CND_Country_Code`, `UNICEF_Programme_Region_*`, `SOWC*`, `LDC_2014`–`LDC_2020`, `WB_1990`–`WB_2022`, `HAC_*`, `SP_*`, `Nutrition_Programme_*`, `Notes` |
| External merge from `unicef-drp/Country-and-Region-Metadata`    | 156    | `ISO3Code`, `WB_2024*`, `WHO.Region_2024`, `LDC_2024`, `AU_*`, `SDGRC_*` (ECA/ECE/ECLAC/ESCAP/ESCWA), `UNICEF_*` regions, `UNSDG_*`, `WB_HI/LI/LMI/UMI`, `WB_EAP/ECA/LAC/MNA/NAR/SAR/SSA`, `WHO_AFRO/AMRO/EMRO/EURO/SEARO/WPRO`, `FAO_LIFDC` |

Within the merged 156, the build script also derives a few consolidated
columns from the per-flag inputs:

- `WB_Latest`, `WB_Latest_3_Group`, `WB_Latest_2_Group` (from `WB_HI`/`WB_LI`/`WB_LMI`/`WB_UMI`)
- `WHO.Region` (from `WHO_AFRO`/`WHO_AMRO`/`WHO_EMRO`/`WHO_EURO`/`WHO_SEARO`/`WHO_WPRO`)
- `World.Bank.Regions` (from `WB_EAP`/`WB_ECA`/`WB_LAC`/`WB_MNA`/`WB_NAR`/`WB_SSA`/`WB_SAR`)
- `LDC_Latest` (from `LDC_2024`, with BTN/STP recoded to "No")

The base 218 and the merged 156 have **zero name overlap** with each
other, so there is no ambiguity inside the wide crosswalk itself.

#### Known duplication with `reference_tables/`

A handful of country-identifier columns also appear in
`reference_tables/directory_country.csv` (legacy migration artifact — the
SharePoint Export had the same identifiers in both tables). The build
script currently passes these through from `directory_crosswalk_base.csv`
verbatim; it does **not** look them up from `directory_country.csv`.

| Column                          | Also in                                  | Notes                                      |
|---------------------------------|------------------------------------------|--------------------------------------------|
| `Country`                       | `reference_country_survey_type.csv`      | Country display name                       |
| `M49`                           | `directory_country.csv`                  | UN M49 numeric code                        |
| `ISO-3 Code`                    | `directory_country.csv`                  | ISO 3166-1 alpha-3                         |
| `WB_Code`                       | `directory_country.csv`                  | World Bank country code                    |
| `CND_Country_Code`              | `directory_country.csv`                  | Internal CND country code                  |
| `ID`, `Compliance Asset Id`     | every legacy SharePoint table            | Per-table SharePoint row IDs (name overlap only — not semantically the same value across tables) |
| `Notes`                         | `directory_indicator.csv`                | Name overlap only (different content)      |

`directory_country.csv` is the editorial source of truth for country
identifiers. If a country identifier ever drifts between the two files,
`directory_country.csv` should win and the crosswalk_base should be
updated to match. A future refactor could have the build script lookup
these identifiers from `directory_country.csv` instead of trusting the
crosswalk_base copy — not done yet to keep the migration minimally
invasive.

## Editing rule — do NOT double-click open these CSVs in Excel

Excel silently mangles CSV content on save:
- Strips leading zeros from numeric ID codes (M49, ISO numeric)
- Coerces long IDs to scientific notation (`1.23E+11`)
- Turns values like `"3-1"`, `"1/2"`, `"MAR"` into dates
- Re-encodes UTF-8 to Windows-1252 (loses accents and smart quotes)
- Adds a UTF-8 BOM at the file head

Safe ways to edit:
1. **VS Code** (preferred). Use the Edit CSV / Rainbow CSV extension if you
   want a grid view.
2. **Excel via `Data → From Text/CSV`**. In the import wizard set every
   column to *Text*, then save back as CSV UTF-8.
3. **R / Python**, writing back with `readr::write_csv()` or
   `pandas.to_csv(encoding="utf-8")`.

The pipeline runs `0_validate_csvs.r` before any build step and will fail
fast on BOMs, non-UTF-8 bytes, scientific-notation IDs, and parse errors.
Heuristic checks (whitespace, suspected stripped leading zeros) are emitted
as non-blocking warnings.

## What gets built (DERIVED — written to `{githubOutputRoot}/reference_data_manager/`, never edited by hand)

| Output                                         | Built by                                      | Source                                                                                                |
|------------------------------------------------|-----------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `directory_crosswalk.csv` (wide computed)      | `2_build_directory_crosswalk.r`               | `crosswalk/directory_crosswalk_base.csv` + external classifications (`unicef-drp/Country-and-Region-Metadata` GitHub) |
| `xlsx/*.xlsx` (one per editable CSV + `directory_crosswalk.xlsx`) | `3_export_legacy_xlsx.r`            | Each editable repo CSV is re-exported as xlsx with the legacy SharePoint sheet name                    |
| `dta/*.dta` (one per editable CSV + `directory_crosswalk.dta`) | `3b_export_legacy_dta.r`              | Each editable repo CSV is re-exported as Stata `.dta` for the legacy Stata Decision Engine and CMRS Preparation pipelines |
| `crosswalk_check.csv` (optional diff vs archive snapshot) | `4_crosswalk_check.r` (opt-in)                | Built crosswalk + archived xlsx snapshot                                                              |

The pipeline **never writes to the legacy SharePoint Export folder or the
legacy `CND Import/` Stata folder**. To update those, copy from the repo
output mirror manually after review.

### Manual copy to legacy folders

After a successful run, the legacy consumers must be refreshed by hand:

- Copy `{githubOutputRoot}/reference_data_manager/xlsx/*.xlsx` →
  legacy SharePoint `Sharepoint Export/` folder.
- Copy `{githubOutputRoot}/reference_data_manager/dta/*.dta` →
  legacy `CND Import/` Stata folder.

This is intentional — the pipeline never touches those legacy locations
directly. Review the rebuilt files in the repo output mirror first, then
copy across.

## Running

```r
source("profile_OSE-DA-NT.R")
source("reference_data_manager/02_codes/1_execute_conductor.r")
```

Optional crosswalk diff vs the latest archive snapshot:

```r
run_crosswalk_check <- TRUE
source("reference_data_manager/02_codes/1_execute_conductor.r")
```

## What was migrated

The original folder
`Combined Nutrition Databases/Post-Processing System/2 - Reference Data Manager`
was the source of every CSV in this folder. The original folder is **never
modified** by this pipeline.

Out of scope (intentionally not migrated):
- `GitHub Imports/` (legacy import staging — superseded by this layout)
- `Sharepoint Export/CROSSWALK_POP/` (large per-year population CSVs — stay on
  SharePoint)
- `Interface/*.accdb` (Access UI — retired)
- `Stata Code/` (re-implemented as `4_crosswalk_check.r`)
- `EXTENSION/CROSSWALK/` R package (re-implemented as `2_build_directory_crosswalk.r`)
