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