# Legacy Documentation Crosswalk

Last updated: 2026-04-12

## Purpose

This document records what was learned from the legacy Combined Nutrition Databases documentation set and translates it into repo-level documentation needs for OSE-DA-NT.

## Legacy Corpus Reviewed

Reviewed source groups included:
- Overall Combined Nutrition Databases instruction manual.
- Domain manuals for adult anthropometry, anaemia, birthweight, child anthropometry, iodine, IYCF, school-age anthropometry, and vitamin A.
- CMRS usage manuals and notes.
- Indicator appendix and indicator/disaggregation reference workbooks.
- Data source catalogue and survey directory reference files.
- Supporting instructions for CRAVE, SOWC, warehouse outputs, and consultations.
- Video transcripts documenting CMRS preparation and transformation workflows.

Notes:
- A small number of legacy files were auxiliary artifacts or partially unreadable exports, but equivalent content was recoverable from adjacent manuals, workbooks, or duplicated files in the same corpus.
- The iodine `.txt` export remained cloud-provider sensitive, but the equivalent `.docx` manual was readable.

## Main Legacy Workflow Model

The legacy documentation consistently describes a multi-stage nutrition system:

1. Processing system
- Data source catalogue maintenance.
- Microdata archiving and recoding.
- Domain-specific reanalysis or external series preparation.

2. Post-processing system
- Data warehouse import preparation.
- Decision engine integration.
- CMRS-ready harmonized outputs.

3. CMRS usage and transformation
- Common reporting transformations.
- Public/non-public filtering and decision handling.
- Indicator, country, year, and disaggregation navigation.

4. Further transformation and reporting
- Aggregation.
- SDG, SOWC, CRAVE, and appendix/report outputs.
- Projection and target-oriented products.

## Implications For OSE-DA-NT

OSE-DA-NT should document itself around those same operational layers, while keeping DW-Production responsibilities separate.

Current mapping:
- analysis_datasets/: CMRS-oriented canonical reshaping and validation.
- reference_data_manager/: indicator and disaggregation reference assets.
- further_transformation_system/: projections, progress classification, and downstream nutrition transformations.

Planned documentation should continue to make clear which parts of the old post-processing and further transformation workflow are now being absorbed here.

## Key Reference Assets Found In Legacy Materials

The legacy corpus repeatedly relies on these structured assets:
- Indicator directory.
- Survey directory / data source catalogue.
- Country directory / code crosswalks.
- Decision reference tables.
- Disaggregation reference tables.
- Indicator appendix files describing custodianship, time-trend status, and available disaggregations.

Current repo alignment:
- reference_data_manager/indicators/directory_indicator.csv
- reference_data_manager/indicators/reference_disaggregations.csv

The repo should eventually document whether additional legacy reference assets also need first-class repository homes.

## Domain Coverage Learned From Legacy Manuals

Legacy manuals show that the nutrition system is not a single monolithic database. It is a coordinated set of domain-specific workflows with shared metadata and reporting standards.

Documented domain families observed in the legacy set:
- Child anthropometry.
- School-age and adolescent anthropometry.
- Adult anthropometry.
- Anaemia.
- Birthweight.
- Iodine.
- Infant and young child feeding.
- Vitamin A.

This supports keeping repo documentation organized around shared infrastructure plus domain-specific workflows.

## CMRS Practices Worth Preserving In New Docs

The CMRS manuals and transcripts repeatedly emphasize:
- Clear distinction between country identifiers and coding systems.
- Explicit indicator/domain/sub-domain definitions.
- Careful handling of disaggregation fields and subnational status.
- Use of accepted versus non-accepted decisions.
- Awareness of what can be publicly shared.
- Avoiding accidental overwrite of canonical assets.

These practices should remain explicit in future runbooks and AI instructions.

## Documentation Gaps Still To Fill In OSE-DA-NT

- A fuller analysis_datasets runbook tied to current file inputs and outputs.
- Reference-data-manager documentation covering indicator and disaggregation schemas.
- A migration note for post-processing responsibilities being moved from legacy folders into this repo.
- Output interface documentation for downstream consumers, including DW-Production.