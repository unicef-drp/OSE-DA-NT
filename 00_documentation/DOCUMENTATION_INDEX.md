# OSE-DA-NT Documentation Index

Last updated: 2026-04-20

## Read First

1. README.md
2. 00_documentation/REPO_SCOPE_AND_BOUNDARIES.md
3. analysis_datasets/00_documentation/ANALYSIS_DATASETS_RUNBOOK.md
4. further_transformation_system/00_documentation/FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md
5. 00_documentation/COMBINED_NUTRITION_DATABASE_SCHEMA.md
6. 00_documentation/LEGACY_DOCUMENTATION_CROSSWALK.md
7. .github/copilot-instructions.md

## Cross-Pipeline Docs (00_documentation/)

- REPO_SCOPE_AND_BOUNDARIES.md
  - Defines what belongs in OSE-DA-NT versus DW-Production.
  - Captures migration principles for avoiding cross-repo scope drift.
  - File naming rules, folder structure rules, SharePoint/Analysis Space storage rules.

- COMBINED_NUTRITION_DATABASE_SCHEMA.md
  - Provides a high-level end-to-end visual schema of the Combined Nutrition Database workflow.
  - Shows the OSE-DA-NT to DW-Production boundary.

- LEGACY_DOCUMENTATION_CROSSWALK.md
  - Summarizes the reviewed legacy CND manuals and reference assets.
  - Maps legacy workflow concepts into OSE-DA-NT documentation priorities.

## Pipeline-Specific Docs (in pipeline 00_documentation/ folders)

- further_transformation_system/00_documentation/FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md
  - Documents the active projections/progress-classification pipeline.
  - Lists current execution entrypoint, script order, and expected outputs.

- analysis_datasets/00_documentation/ANALYSIS_DATASETS_RUNBOOK.md
  - Documents the active CMRS2/layer-2 build area.
  - Describes entrypoints, reference dependencies, and current migration-state path issues.

- analysis_datasets/00_documentation/UPSTREAM_SOURCE_DATA_FLAGS.md
  - Documents known upstream data quality issues and CMRS source flags.

## AI Guidance

- .github/copilot-instructions.md
  - Repository-wide AI guidance and workflow constraints.

- .github/instructions/nutrition-pipeline.instructions.md
  - Scoped instructions applied to this repository's code and docs.

- 00_ai/SKILL_ROADMAP.md
  - Draft skill backlog for incremental AI-agent capability in this repo.

## Pipeline READMEs

- further_transformation_system/animated_scatterplots/README.md
  - Pipeline README for animated regional bubble-scatterplots.
  - Covers code structure, indicator configs, input sources (including wasting special case), output files, and how to add new indicators.

## Planned Additions

- reference_data_manager schema notes
- quality checks and test execution guide
- migration checklists for each subsystem moved from legacy workflows