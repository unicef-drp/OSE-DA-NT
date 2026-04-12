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
- reference_data_manager/indicators/: indicator and disaggregation reference files.
- 00_documentation/: runbooks and migration docs.

## Safety Rules

- Do not rename or remove primary execute scripts without explicit approval.
- Avoid introducing breaking output filename changes.
- Keep hardcoded business rules unless specifically asked to modify them.

## Path And Environment Rules

- Use file.path and config/profile-based path resolution in R.
- Do not add user-specific absolute paths in new logic.
- If a script depends on %USERPROFILE%/.config/user_config.yml, keep fallback behavior explicit.

## Documentation Rules

- If script order or output contracts change, update 00_documentation in the same change.
- Keep runbooks practical, with entrypoint, order, inputs, outputs, and notes.