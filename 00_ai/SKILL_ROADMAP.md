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

7. Efficient Parquet Loading Skill
- Purpose: ensure all parquet reads use column selection, predicate pushdown, and Arrow Table splice for in-place column updates — avoiding full-file materialization into R memory.
- Skill file: `00_ai/analysis_datasets/EFFICIENT_PARQUET_SKILL.md`
- Key patterns: (1) read-only with `open_dataset()` + `select(any_of(...))` + `filter()` pushdown; (2) compute-and-splice via slim `col_select` read + `as_data_frame = FALSE` Arrow Table + `$AddColumn()`; (3) schema inspection via `open_dataset(path)$schema` (not `read_schema()`).
- Key constraint: `arrow::read_schema()` does not work on parquet files — always use `open_dataset()$schema`.
- Trigger: any new or modified code that calls `read_parquet()` or reads from analysis_datasets parquets.

8. Projections Pipeline Migration and Validation Skill
- Purpose: guide migration of projections pipeline from DW-Production CSV inputs to analysis_datasets parquet inputs, and validate output parity with old DW output.
- Skill file: `00_ai/projections_progress_class/PROJECTIONS_MIGRATION_SKILL.md`
- Key constraints: (1) parquet values are proportions (×100 needed); (2) accepted parquet has ALL surveys, not just preferred — do not filter to priority=1; (3) series parquets have Subnational_Status=NA, filter must handle `is.na() | == "0"`; (4) all prevalence must be `stata_round(x, 1)` before use in any calculation or output; (5) AARR rounded to 2dp; (6) `country_recent` must sort by `desc(source_priority)` to pick preferred survey.
- Key deliverable: validation recipe comparing `progress_2030_appended.xlsx` new vs old with expected acceptable difference table.
- Trigger: migrating a new indicator to parquet, changing input staging in `1a_import_inputs.r`, or debugging value differences in projections output.

9. Analysis Datasets Build Conventions Skill
- Purpose: document the two-field DataSourceDecision/Category system, confidential handling convention, hardcoded business rules (ZWE 2879, BHR overweight, NIC series), `write_accepted_subset()` semantics, Stata rounding, proportion/percent, indicator prefix, and DATA_SOURCE_PRIORITY meaning — all conventions that caused bugs during migration.
- Skill file: `00_ai/analysis_datasets/BUILD_CONVENTIONS_SKILL.md`
- Key constraint: `DataSourceDecisionCategory` is the filter field (stays "Accepted" for confidential rows); `DataSourceDecision` is the metadata field (set to "Accepted and Confidential"). Swapping them removes rows from accepted subsets.
- Key constraint: accepted parquets contain both priority=0 and priority=1 rows. Filtering to priority=1 upstream breaks AARR regression in downstream scripts.
- Trigger: editing any `2_build_cmrs2_*.r` script, `0_layer2_utils.r`, adding new hardcoded corrections, or debugging missing rows in accepted parquets.

10. PowerPoint Generation Skill
- Purpose: guide creation and extension of UNICEF-branded PowerPoint slide modules using the officer + xml2 approach, covering OOXML pitfalls, modular slide-function pattern, design token usage, and integration into orchestrator scripts.
- Skill file: `00_ai/PPTX_GENERATION_SKILL.md`
- Key constraint: `<a:endParaRPr>` must be the last child of `<a:p>` — inserting `<a:r>` after it causes invisible text.
- Key constraint: UNICEF template title slides have empty placeholders (no `<a:r>`, only `<a:endParaRPr>`). Must clone font props and insert run before endParaRPr.
- Trigger: building a new slide-type module, editing existing `00_pptx_*.r` modules, or debugging missing text in generated PPTX.

11. Codes Naming Convention Skill
- Purpose: document the numeric-prefix naming convention for scripts in `02_codes/` and `012_codes/` folders — `0_` for utilities, `00_` for module libraries, `1_` for conductors, `1a_`/`1b_` for sub-steps, `2_`+ for ordered pipeline steps.
- Skill file: `00_ai/CODES_NAMING_CONVENTION_SKILL.md`
- Key rule: `0_` and `00_` scripts are never sourced by the conductor. `00_` is for self-contained modules with public APIs; `0_` is for general helpers.
- Trigger: creating, renaming, or reordering scripts in any codes folder.

12. Stunting Briefing Content And Source Governance Skill
- Purpose: improve the analytical content of the stunting top-20 briefing while enforcing dataset-only numeric sourcing and citation discipline for any document-derived context.
- Skill file: `00_ai/stunting_top20_briefing/STUNTING_TOP20_BRIEFING_CONTENT_SKILL.md`
- Key rule: numeric claims must come from approved `analysis_datasets` or in-scope `DW-Production` outputs unless the user explicitly approves an exception.
- Key rule: any document used for context must be stored locally if external and registered in the briefing source registry before it is cited.
- Trigger: extending `adhoc_analysis/stunting_top20_briefing/`, adding new analysis or slide text, or using external documents for ideas or framing.

13. Source Discovery And Content Agreement Skill
- Purpose: define analytical content before document production, separate data sources from context sources, and guide source discovery for analysis-backed briefs and decks.
- Skill file: `00_ai/skill_SOURCE_DISCOVERY_AND_CONTENT_AGREEMENT.md`
- Key rule: before producing a polished brief or PowerPoint, create a content-agreement note covering audience, questions, approved sources, structure, and unresolved decisions.
- Key rule: external working source libraries belong in the external Analysis Space `github` folder, not in this repository.
- Trigger: any analysis task that is expected to end in a brief, presentation, or narrative output.

14. Markdown Review And Tracked Changes Skill
- Purpose: manage iterative markdown review using a paired `.review.md` workflow plus a visible `.tracked.md` file and a fresh next-round review copy.
- Skill file: `00_ai/skill_MARKDOWN_REVIEW_AND_TRACKED_CHANGES.md`
- Key rule: review copies should preserve the full document text and use sparse `>>>` comments only where needed.
- Key rule: tracked markdown should use a clear red/green add-delete scheme in Markdown Preview, closer to Word track changes than plain `<mark>`/`~~` styling.
- Trigger: any markdown-based document review workflow where the user wants both editable review copies and visible tracked changes.

## Definition Of Done For A Skill

- Clear trigger condition.
- Clear input contract.
- Explicit output artifact list.
- Safe fallback behavior when required files are inaccessible.
- Example usage snippet in markdown.

## Near-Term Next Step

Convert one backlog item into a concrete markdown skill spec and pilot it on the further transformation workflow.