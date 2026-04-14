# OSE-DA-NT AI Skills Roadmap

Last updated: 2026-04-14

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

6. Ad-Hoc Briefing Generation Skill
- Purpose: generate UNICEF-branded PowerPoint briefings with companion Excel data workbooks from ranking/analysis results.
- Inputs: RDS results object (rankings + metadata), UNICEF brand template, indicator family.
- Outputs: branded PowerPoint (template cover/thank-you + chart slides + narrative), Excel workbook with one sheet per figure slide.
- Key conventions: 15 countries per chart (optimal for horizontal bar/dot plots); dot plots sorted by latest-year value with legend ordered left-to-right (lowest first); auto-install of officer/rvg/openxlsx.
- Reference implementation: `adhoc_analysis/stunting_top20_briefing/02_codes/4_create_ppt.r`.
- Trigger: when creating a new ad-hoc indicator briefing or extending an existing one with additional slides or outputs.
6. Analytical Key Duplicate Triage Skill
- Purpose: fast diagnosis/resolution of duplicate analytical keys, with emphasis on accepted-output failures.
- Inputs: target dataset, verify output, duplicate key fields, sampled colliding rows.
- Outputs: root-cause classification (upstream duplicate vs derivation collision), recommended fix path (reference mapping vs fallback logic), and rerun/verification checklist.
- Trigger: any `Duplicate analytical key rows: FAIL` in `0_verify_all_outputs.r`.

## Definition Of Done For A Skill

- Clear trigger condition.
- Clear input contract.
- Explicit output artifact list.
- Safe fallback behavior when required files are inaccessible.
- Example usage snippet in markdown.

## Near-Term Next Step

Convert one backlog item into a concrete markdown skill spec and pilot it on the further transformation workflow.