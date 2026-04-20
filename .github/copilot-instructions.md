# OSE-DA-NT AI Agent Instructions

## Project Purpose

OSE-DA-NT is the nutrition pipeline workspace for CMRS-based processing and further transformation.

This repository is in migration build-out. Initial priority is the further transformation system.

## Scope Boundary

- OSE-DA-NT handles nutrition processing, post-processing, and transformation logic.
- DW-Production handles regional aggregation and public data warehouse production outputs.
- OSE-DA-NT is already nutrition-only, so agents should not enforce nt-folder-only scope constraints.

Do not move DW publication responsibilities into this repository unless explicitly requested.

## Required Context Before Editing

Always read:
1. README.md
2. 00_documentation/REPO_SCOPE_AND_BOUNDARIES.md
3. 00_documentation/FURTHER_TRANSFORMATION_SYSTEM_RUNBOOK.md
4. Any local README in the target folder being edited
5. 00_ai agent instructions and skills in this folder and subfolders for specific pipelines

## Coding And Path Rules

- Prefer file.path for paths in R scripts.
- Avoid hardcoded absolute user paths unless already entrenched and required for compatibility.
- Preserve script entrypoint names and output filenames unless a change is explicitly requested.
- Keep hardcoded business rules intact unless instructed otherwise.
- Load all `library()` calls in the conductor (`1_execute*.r`) only. Child scripts must not load libraries themselves.
- Country names must come from the UNICEF datasets that are the primary input files (e.g. the `CountryName` column in CMRS parquets, or `groups_for_agg.csv`). Do not use the `countrycode` R package or any other external name-mapping source.

## Documentation Rules

- When changing execution order, update runbooks in 00_documentation in the same change.
- When adding new pipeline outputs, document location and purpose.
- Keep migration-state documentation explicit and dated.

## AI Agent Behavior

- Prioritize safe, minimal changes.
- Do not silently refactor unrelated scripts.
- Surface blockers early when external files are not locally accessible.
- Maintain clear separation between current behavior and proposed future behavior.