# OSE-DA-NT Documentation Index

Last updated: 2026-04-12

## Read First

1. README.md
2. 00_documentation/REPO_SCOPE_AND_BOUNDARIES.md
3. 00_documentation/ANALYSIS_DATASETS_RUNBOOK.md
4. 00_documentation/FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md
5. 00_documentation/COMBINED_NUTRITION_DATABASE_SCHEMA.md
6. 00_documentation/LEGACY_DOCUMENTATION_CROSSWALK.md
7. .github/copilot-instructions.md

## Core Repository Docs

- REPO_SCOPE_AND_BOUNDARIES.md
  - Defines what belongs in OSE-DA-NT versus DW-Production.
  - Captures migration principles for avoiding cross-repo scope drift.

- FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md
  - Documents the active projections/progress-classification pipeline.
  - Lists current execution entrypoint, script order, and expected outputs.

- ANALYSIS_DATASETS_RUNBOOK.md
  - Documents the active CMRS2/layer-2 build area.
  - Describes entrypoints, reference dependencies, and current migration-state path issues.

- COMBINED_NUTRITION_DATABASE_SCHEMA.md
  - Provides a high-level end-to-end visual schema of the Combined Nutrition Database workflow.
  - Shows the OSE-DA-NT to DW-Production boundary.

- LEGACY_DOCUMENTATION_CROSSWALK.md
  - Summarizes the reviewed legacy CND manuals and reference assets.
  - Maps legacy workflow concepts into OSE-DA-NT documentation priorities.

## AI Guidance

- .github/copilot-instructions.md
  - Repository-wide AI guidance and workflow constraints.

- .github/instructions/nutrition-pipeline.instructions.md
  - Scoped instructions applied to this repository's code and docs.

- 00_ai/SKILLS_ROADMAP.md
  - Draft skill backlog for incremental AI-agent capability in this repo.

## Planned Additions

- reference_data_manager schema notes
- quality checks and test execution guide
- migration checklists for each subsystem moved from legacy workflows