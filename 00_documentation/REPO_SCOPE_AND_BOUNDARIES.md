# Repository Scope And Boundaries

Last updated: 2026-04-12

## Objective

This document defines operational boundaries between OSE-DA-NT and DW-Production while this combined nutrition database pipeline is being migrated.

Legacy documentation reviewed for this migration shows that the nutrition workflow has historically spanned data processing, post-processing, CMRS transformation, and further transformation/reporting. OSE-DA-NT should preserve that conceptual flow without reabsorbing DW production/publication responsibilities.

## Repository Roles

OSE-DA-NT (this repository):
- Nutrition data intake and canonical reshaping.
- Post-processing and further transformation logic.
- Intermediate artifacts used for analysis and downstream consumption.
- Nutrition-specific runbooks and migration documentation.
- Nutrition reference assets that support indicator and disaggregation standardization.

DW-Production (external repository):
- Regional aggregation pipelines used in production workflows.
- Public data warehouse formatting and publication delivery.
- Cross-sector production orchestration and release process.

DW-Production path:
- C:/Users/jconkle/Documents/GitHub/DW-Production

## Design Principles For This Migration

1. Keep interfaces stable
- Scripts in OSE-DA-NT should produce predictable outputs for downstream consumers.

2. Keep scope clear
- Do not move DW publication or upload responsibilities into OSE-DA-NT.

3. Keep logic traceable
- Explicit script ordering and runbooks should be documented in 00_documentation.

4. Keep configuration portable
- Use file.path and profile/config-based path resolution, not hardcoded user-specific absolute paths.

5. Keep confidentiality handling explicit
- Any confidentiality filtering behavior must remain documented and unchanged unless intentionally revised.

6. Keep reference assets visible
- Indicator, survey, country, decision, and disaggregation reference logic should be documented as first-class dependencies, not hidden only in legacy workbooks.

7. Keep GitHub focused on code and small controlled assets
- Do not use this repository as a storage location for working source-document libraries, briefing packets, or large analytical support files.
- Store those materials in the external Analysis Space `github` folder under the relevant workflow subfolder.

## Migration Phases

Phase 1 (active):
- Further transformation system setup and documentation in this repository.

Phase 2 (planned):
- Post-processing migration and runbook documentation.

Phase 3 (planned):
- Validation checklists and reproducibility checks for handoff to production consumers.

## Country Name Sourcing Rule

Country names displayed in outputs (charts, tables, markdown, slide decks, briefs) must always be drawn from the UNICEF datasets that serve as primary inputs to each pipeline. Acceptable sources include:

- The `CountryName` column in CMRS-based parquet files (e.g. `cmrs2_series_accepted.parquet`).
- The `Country` column in `groups_for_agg.csv` from DW-Production reference data.

Do not use the `countrycode` R package or any other external name-mapping library. This ensures names in outputs are consistent with the upstream data and avoids discrepancies introduced by third-party lookup tables.

When a script needs country names, build a lookup table from the source data early in the pipeline and join it onto derived data frames.

## Working Agreement

When implementation touches both repositories:
- Build and validate transformation logic in OSE-DA-NT first.
- Use documented interfaces to pass outputs to DW-Production workflows.
- Keep repository-level responsibilities unchanged unless explicitly approved.

## SharePoint / Analysis Space Storage

The external SharePoint-synced Analysis Space folder is the primary storage location for all large and binary files. The repo stores only code, small reference tables, and documentation about itself.

**SharePoint path** (resolved as `githubOutputRoot` via `profile_OSE-DA-NT.R`):
```
C:/Users/{user}/UNICEF/Data and Analytics Nutrition - Analysis Space/github/
```

**What lives on SharePoint:**
- Large input data (parquet files, source CSVs)
- Generated outputs (xlsx, docx, pptx, png, rds, gif, mp4)
- Source library documents (PDFs, external references, background papers)
- Brand assets and templates (logos, color palettes, slide masters)
- Working briefing packets and analytical support files

**What lives in the repo:**
- R scripts (`.r`)
- Reference CSVs that drive indicator/disaggregation/country logic (small, version-controlled)
- AI instructions and skills (`00_ai/`)
- Documentation about the repo, pipelines, and conventions (`00_documentation/`, pipeline `00_documentation/` folders)
- Configuration templates (`_config_template/`)
- Profile loader (`profile_OSE-DA-NT.R`)

**Rule:** If a file is too large to diff meaningfully in git, or is a binary artifact produced by a pipeline, it belongs on SharePoint, not in the repo.

## Folder Structure Rules

### Top-Level Layout

```
OSE-DA-NT/
├── .github/                    # GitHub config and copilot instructions
├── .gitignore
├── profile_OSE-DA-NT.R         # Path resolver (reads user_config.yml)
├── README.md
├── _config_template/           # Template for user-specific config
├── 00_ai/                      # Cross-pipeline AI instructions and skills
├── 00_documentation/           # Cross-pipeline documentation only
├── 00_functions/               # Cross-pipeline shared R functions
├── adhoc_analysis/             # One-off analyses and briefings
│   └── {analysis_name}/
│       ├── 00_documentation/
│       ├── 01_inputs/
│       └── 02_codes/
├── analysis_datasets/          # CMRS2 / layer-2 build area
│   ├── 00_documentation/
│   └── 02_codes/
├── further_transformation_system/
│   ├── 00_documentation/       # Cross-FTS docs only
│   ├── animated_scatterplots/
│   │   ├── 00_documentation/
│   │   └── 02_codes/
│   └── projections_progress_class/
│       ├── 00_documentation/
│       └── 012_codes/          # Legacy prefix (do not rename)
└── reference_data_manager/
    ├── 00_documentation/
    └── indicators/
```

### Standard Pipeline Subfolder Convention

Every pipeline or analysis gets these subfolders (create only those that apply):

| Folder | Purpose |
|--------|---------|
| `00_documentation/` | Runbooks, content agreements, render specs, README |
| `01_inputs/` | Small reference inputs tracked in git (CSVs, lookup tables) |
| `02_codes/` | R scripts with numbered prefixes |
| `02_codes/old/` | Archived or superseded scripts (kept for reference) |

### Graduation Principle

- Documentation and functions start inside their pipeline folder.
- Only move to the root `00_documentation/`, `00_functions/`, or `00_ai/` when they apply to multiple pipelines.
- Root-level `00_documentation/` holds only cross-cutting docs (schema, scope, index, crosswalk).

## File Naming Rules

### R Scripts (`.r`)

| Rule | Example |
|------|---------|
| Always lowercase `.r` extension | `1_execute.r`, not `1_execute.R` |
| Numbered prefix for execution order | `0_` utils, `1_` conductor, `2_`+ pipeline steps |
| `0_` prefix for utility/function modules | `0_scatterplot_functions.r` |
| `00_` prefix for module libraries | `00_nt_functions.r` |
| `1_execute*.r` for conductors | `1_execute.r`, `1_execute_conductor.r` |
| `1a_`, `1b_` for conductor sub-steps | `1a_import_inputs.r` |
| `2_`–`9_` for ordered pipeline steps | `3_preferred_ant.r` |
| Lowercase snake_case for descriptive part | `8_format_output.r` |

### Documentation (`.md`)

| Rule | Example |
|------|---------|
| `UPPER_SNAKE_CASE.md` for standalone docs | `FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md` |
| `README.md` for pipeline overviews | Always title-case `README` |
| Single underscore between words | `instruction_chart_design.md`, not `instruction__chart_design.md` |
| AI skills: `SKILL_NAME_SKILL.md` or `skill_name.md` | `BUILD_CONVENTIONS_SKILL.md` |
| AI instructions: `instruction_topic.md` | `instruction_nutrition-pipeline.md` |

### Data Files

| Rule | Example |
|------|---------|
| `lowercase_snake_case` for all data files | `cmrs_fields.xlsx`, `directory_indicator.csv` |
| Descriptive names reflecting content | `reference_disaggregations.csv` |
| Version suffixes only when multiple versions coexist | `content_v6.md` |

### General Rules

- No spaces in filenames (use underscores).
- No double underscores.
- No uppercase letters in data file names or R script names.
- Documentation `.md` files may use UPPER_SNAKE_CASE for visibility in directory listings.