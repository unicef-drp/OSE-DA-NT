# OSE-DA-NT AI Skills Roadmap

Last updated: 2026-04-12

## Goal

Define practical, repository-specific AI skill modules that improve consistency and reduce rework during migration.

## Starter Skill Backlog

1. Further Transformation Run Skill
- Purpose: guide safe edits and validations in projections_progress_class.
- Inputs: target script, indicator family, expected output files.
- Outputs: ordered edits, updated runbook references, validation summary.

2. CMRS2 Dataset Build Skill
- Purpose: run or validate analysis_datasets CMRS2 build chain.
- Inputs: source availability, target output parquet files.
- Outputs: execution notes and output presence checks.

3. Scope Guard Skill
- Purpose: enforce repository boundary between OSE-DA-NT and DW-Production.
- Inputs: proposed change list.
- Outputs: boundary pass/fail and required user confirmations.

4. Documentation Sync Skill
- Purpose: ensure code and runbooks remain aligned.
- Inputs: changed scripts, changed outputs, changed order.
- Outputs: required documentation updates and completion checklist.

5. Dimension Coverage and Reference Disaggregation Extension Skill
- Purpose: full cycle — audit coverage after a CMRS2 build, diagnose unmapped rows, decide between reference CSV extension vs. hardcoded fallback, and execute safely without breaking DW-Production.
- Skill file: `00_ai/analysis_datasets/DIMENSION_COVERAGE_SKILL.md`
- Key constraint: `reference_disaggregations.csv` is fetched directly by DW-Production from GitHub main branch. Adding rows is safe; modifying existing rows changes DW output and requires approval.
- Key constraint: SDMX codebook values ≠ DW accepted values. Valid HELIX codes must be verified against existing values already in the CSV.
- Trigger: after any CMRS2 build, or when planning to extend the reference mapping for a new disaggregation type.

## Definition Of Done For A Skill

- Clear trigger condition.
- Clear input contract.
- Explicit output artifact list.
- Safe fallback behavior when required files are inaccessible.
- Example usage snippet in markdown.

## Near-Term Next Step

Convert one backlog item into a concrete markdown skill spec and pilot it on the further transformation workflow.