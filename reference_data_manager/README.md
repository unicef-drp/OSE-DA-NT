# reference_data_manager

Editable reference data for the UNICEF Combined Nutrition Databases.

This folder replaces the legacy Access-based "Reference Data Manager" tool and
the SharePoint-only edit workflow. Every reference table is a small CSV that
can be edited directly in the repo. Build scripts assemble the wide
`directory_crosswalk.csv` and re-export legacy-named xlsx files so the
SharePoint folder remains a complete drop-in copy.

## Folder layout

```
reference_data_manager/
  reference_tables/      # DATA ENTRY  — small editable CSVs (one per legacy DIRECTORY_*/REFERENCE_*.xlsx)
  crosswalk/             # DATA ENTRY  — editable wide directory_crosswalk_base.csv
  02_codes/              # build + export R scripts (and one-time migration helpers)
  00_documentation/      # runbook
```

**No derived files live in the repo.** Every CSV under `reference_tables/`
and `crosswalk/` is meant to be edited by hand. All computed outputs are
written to `{githubOutputRoot}/reference_data_manager/` and are rebuilt from
the editable inputs each run — do not edit them by hand.

Field-level guarantee: the editable `crosswalk/directory_crosswalk_base.csv`
and the columns added by the build script (external classifications + SOFI)
have **zero column-name overlap**, so there is no risk of editing the "wrong
copy" of any field.

Field-level guarantee: the editable `crosswalk/directory_crosswalk_base.csv`
and the columns added by the build script (external classifications + SOFI)
have **zero column-name overlap**, so there is no risk of editing the "wrong
copy" of any field.

## What gets built (DERIVED — written to `{githubOutputRoot}/reference_data_manager/`, never edited by hand)

| Output                                         | Built by                                      | Source                                                                                                |
|------------------------------------------------|-----------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `directory_crosswalk.csv` (wide computed)      | `2_build_directory_crosswalk.r`               | `crosswalk/directory_crosswalk_base.csv` + external classifications (`unicef-drp/Country-and-Region-Metadata` GitHub) + `reference_tables/reference_sofi_progress.csv` |
| Legacy-named xlsx files (e.g. `DIRECTORY_COUNTRY.xlsx`, `REFERENCE_*.xlsx`) | `3_export_legacy_xlsx.r`                      | Each editable repo CSV is re-exported as xlsx with the legacy SharePoint sheet name                    |
| Legacy-named Stata `.dta` files (one per editable CSV + wide crosswalk) | `3b_export_legacy_dta.r`                      | Each editable repo CSV is re-exported as `.dta` for the legacy Stata Decision Engine and CMRS Preparation pipelines |
| `crosswalk_check.csv` (optional diff vs archive snapshot) | `4_crosswalk_check.r` (opt-in)                | Built crosswalk + archived xlsx snapshot                                                              |

The pipeline **never writes to the legacy SharePoint Export folder**. To
update SharePoint, copy from the repo output mirror manually after review.

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
