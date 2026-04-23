---
applyTo: "**/*"
---

# Nutrition Pipeline Instructions

These instructions apply to work in this repository.

## Repository-Wide Applicability

- This is a nutrition-only repository.
- Do not impose or reintroduce nt-folder-only edit restrictions.
- Unless a user asks for narrower scope, these instructions apply to all folders in this repo.

## Scope And Boundaries

- Treat this repository as nutrition-pipeline-specific.
- Keep DW-Production responsibilities out of scope unless the user explicitly requests cross-repo changes.

## Preferred Working Areas

- analysis_datasets/02_codes/: CMRS2 build and validation scripts.
- further_transformation_system/projections_progress_class/012_codes/: projections and progress classification workflow.
- reference_data_manager/reference_tables/: indicator, disaggregation, country, region, and other reference files (data entry).
- 00_documentation/: cross-pipeline docs (scope, schema, index).
- Pipeline-specific docs live in each pipeline's own 00_documentation/ folder.

## Safety Rules

- Do not rename or remove primary execute scripts without explicit approval.
- Avoid introducing breaking output filename changes.
- Keep hardcoded business rules unless specifically asked to modify them.

## Path And Environment Rules

- Use file.path and config/profile-based path resolution in R.
- Do not add user-specific absolute paths in new logic.
- If a script depends on %USERPROFILE%/.config/user_config.yml, keep fallback behavior explicit.

## Temp And Debug Script Rules

- Never save temporary or diagnostic R/PowerShell scripts to the repository root. Use a system temp path instead: `$tmp = Join-Path $env:TEMP 'script_name.R'` in PowerShell or `tempfile(fileext = ".R")` in R.
- Always clean up temp files after use (Remove-Item / unlink).
- If a diagnostic script is reusable, place it in the appropriate `02_codes/` or `adhoc_analysis/` subfolder with a proper header; otherwise discard it after use.

## Documentation Rules

- If script order or output contracts change, update 00_documentation in the same change.
- Keep runbooks practical, with entrypoint, order, inputs, outputs, and notes.

## Analysis And Document Production Rules

- Before producing a brief, PowerPoint, or polished narrative output, define the content scope first: audience, questions, approved sources, proposed structure, and open decisions.
- Keep numeric claims tied to approved datasets unless the user explicitly approves a document-based exception.
- Do not store working source-document libraries in GitHub; use the external Analysis Space `github` folder instead.
- When working on child anthropometry narrative or briefing content, review the current UNICEF JME pages before drafting content:
	- https://data.unicef.org/topic/nutrition/malnutrition/
	- https://data.unicef.org/resources/jme/