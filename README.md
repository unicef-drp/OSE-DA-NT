# OSE-DA-NT

Combined Nutrition Database pipeline workspace for CMRS-based processing, post-processing, and further transformation workflows.

## Purpose

This repository is being built as the new Combined Nutrition Database pipeline workspace to process data from survey and administrative sources that are analyzed separately for each domain.

Legacy documentation shows the nutrition system has historically operated across four linked layers:
- processing system
- post-processing system
- CMRS usage/transformation
- further transformation and reporting

OSE-DA-NT is being documented and built to absorb the nutrition-owned parts of that workflow in a cleaner repository structure.

Current focus:
- Consolidate nutrition processing logic in one repository.
- Move post-processing and further transformation workflows here, starting with the further transformation system.
- Keep logic modular so downstream production workflows can consume stable outputs.

## Scope Boundary With DW-Production

This repository and DW-Production are intentionally separate.

- OSE-DA-NT: nutrition pipeline construction, harmonization, transformation, and intermediate/analysis outputs.
- DW-Production: regional aggregation and production of the public data warehouse outputs.

External production repository:
- C:/Users/jconkle/Documents/GitHub/DW-Production

## Current Repository Structure

- analysis_datasets/: CMRS ingest and reshaping scripts for parquet and CMRS2 build outputs.
- further_transformation_system/: projection and progress-classification workflows.
- reference_data_manager/: nutrition indicator/disaggregation directory and reference files.
- 00_functions/: shared helper functions (repo-level utilities).
- 00_documentation/: project documentation for workflow, scope, and AI guidance.
- 00_ai/: AI-oriented notes and skill roadmap for future repository automation.

## Execution Entry Points (Current)

Primary scripts currently in use:
- analysis_datasets/02_codes/1_execute_conductor.r
	- Sources CMRS2 build scripts for series and non-series nutrition domains.
- further_transformation_system/projections_progress_class/012_codes/1_execute.r
	- Runs the projections/progress pipeline and writes final projection outputs.

## Configuration Notes

Several scripts read user-specific paths from:
- %USERPROFILE%/.config/user_config.yml

Expected keys include:
- githubFolder
- teamsRoot

When path objects are not preloaded, scripts may auto-resolve project and teams paths from user config.

## Recommended Path Setup Approach

This repo now includes a profile script:
- profile_OSE-DA-NT.R

Recommended approach for OSE-DA-NT:
- Use one profile script + user_config.yml for path setup.
- Avoid hostname-based path branching inside pipeline scripts.

Why this is better than hostname blocks in execute scripts:
- Easier maintenance: users update one config file, not multiple scripts.
- Better portability: works across laptop changes and OS differences.
- Cleaner code: build scripts focus on data logic, not machine routing.

Nutrition-team compatibility:
- The profile defines shared repo roots (projectFolder, cmrsInputDir, githubOutputRoot, analysisDatasetsOutputDir) and each subfolder script derives its local paths from those roots.

Quick start:
1. Copy _config_template/user_config.yml to %USERPROFILE%/.config/user_config.yml
2. Replace placeholders with your paths.
3. In R, run: source("profile_OSE-DA-NT.R")
4. Then run entry scripts, for example:
	- analysis_datasets/02_codes/1_execute_conductor.r
	- further_transformation_system/projections_progress_class/012_codes/1_execute.r

## Documentation

Start here:
- 00_documentation/DOCUMENTATION_INDEX.md

Core docs:
- 00_documentation/REPO_SCOPE_AND_BOUNDARIES.md
- 00_documentation/ANALYSIS_DATASETS_RUNBOOK.md
- 00_documentation/FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md
- 00_documentation/COMBINED_NUTRITION_DATABASE_SCHEMA.md
- 00_documentation/LEGACY_DOCUMENTATION_CROSSWALK.md

AI instructions:
- .github/copilot-instructions.md
- .github/instructions/nutrition-pipeline.instructions.md

## Migration Status

Migration is in progress. The first stage in this repo is further transformation system onboarding.

Planned next stages:
- Post-processing migration into this repository.
- Expanded documentation for reference_data_manager and output interfaces.
- Repository-level test and QA checklists for each stage.
