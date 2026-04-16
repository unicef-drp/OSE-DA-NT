# Codes Naming Convention Skill

Last updated: 2026-04-16

## Purpose

Guide AI agents on the numeric-prefix naming convention used in `02_codes/`
(and `012_codes/`) folders across this repository. Ensures new scripts are
named consistently and placed in the correct prefix tier.

---

## Trigger

Apply this skill when:
- Creating a new R script in any codes folder.
- Renaming or reordering existing scripts.
- Deciding whether a script should be sourced by the conductor.

---

## 1. Prefix Tiers

| Prefix | Role | Called by conductor? | Examples |
|--------|------|---------------------|----------|
| `0_` | **Shared utilities** — functions, constants, and verification helpers consumed by other scripts via `source()`. | No | `0_layer2_utils.r`, `0_verify_all_outputs.r` |
| `00_` | **Module utilities** — self-contained functional modules sourced by a later orchestrator step, not by the conductor. | No | `00_pptx_design_tokens.r`, `00_pptx_title_slide.r` |
| `1_` | **Conductor / executor** — the single entry-point script that sources pipeline steps in order. One per pipeline. | Yes (it *is* the entry-point) | `1_execute_conductor.r`, `1_execute.r` |
| `1a_`, `1b_` | **Early pipeline steps** — import, lookup, or setup stages run by the conductor or executor before the main processing loop. | Yes (sourced by `1_execute*.r`) | `1a_import_inputs.r`, `1b_population_lookup.r` |
| `2_`, `3_`, `4_`, … | **Ordered pipeline steps** — each prefix digit represents execution order within the pipeline. | Yes (sourced by `1_execute*.r`) | `2_prepare_inputs.r`, `3_stunting_rankings.r`, `4_create_ppt.r` |
| `2_build_*` / `3_preferred_*` | **Domain-grouped steps** — scripts at the same numeric tier that run in parallel or iterate over indicator domains. | Yes | `2_build_cmrs2_ant.r`, `3_preferred_ant.r` |

---

## 2. Key Rules

### 2a. Conductor owns execution order

The `1_execute*.r` script is the single source of truth for which scripts
run and in what order. Individual scripts should be runnable standalone
(for debugging) but should not source each other horizontally.

### 2b. Utility scripts are never in the conductor

Scripts prefixed `0_` or `00_` define functions and constants. They are
sourced by the scripts that need them, not by the conductor. This keeps
the conductor a clean, linear sequence of pipeline steps.

### 2c. Use `00_` for modular function libraries

When a utility script is a self-contained module with a public API
(e.g. slide-generation functions, token definitions), use the `00_`
prefix. Reserve `0_` for general-purpose helpers shared across multiple
pipeline steps.

### 2d. Sub-steps use letter suffixes

When a numeric tier has ordered sub-steps, use letter suffixes:
`1a_`, `1b_`, etc. Do not use underscores or dots for sub-ordering
(e.g. avoid `1.1_` or `1_1_`).

### 2e. Pipeline steps share a prefix when parallel

Scripts that operate on different domains at the same logical stage share
a numeric prefix: `2_build_cmrs2_ant.r`, `2_build_cmrs2_bw.r`, etc.
The conductor may run them in any order.

---

## 3. Folder Examples

### analysis_datasets/02_codes/
```
0_layer2_utils.r          ← shared functions (utility)
0_verify_all_outputs.r    ← verification helper (utility)
1_execute_conductor.r     ← entry-point
2_build_cmrs2_ant.r       ← step 2, domain: anthropometric
2_build_cmrs2_bw.r        ← step 2, domain: birthweight
2_build_cmrs2_iod.r       ← step 2, domain: iodine
2_build_cmrs2_iycf.r      ← step 2, domain: IYCF
2_build_cmrs2_series.r    ← step 2, domain: series
3_preferred_ant.r         ← step 3, domain: anthropometric
3_preferred_bw.r          ← step 3, domain: birthweight
3_preferred_iod.r         ← step 3, domain: iodine
3_preferred_iycf.r        ← step 3, domain: IYCF
3_preferred_series.r      ← step 3, domain: series
```

### adhoc_analysis/stunting_top20_briefing/02_codes/
```
00_pptx_design_tokens.r   ← module utility (tokens)
00_pptx_title_slide.r     ← module utility (title slide)
1_execute_conductor.r     ← entry-point
2_prepare_inputs.r        ← step 2
3_stunting_rankings.r     ← step 3
4_create_ppt.r            ← step 4 (sources 00_ modules internally)
```

### further_transformation_system/projections_progress_class/012_codes/
```
1_execute.r               ← entry-point
1a_import_inputs.r        ← step 1a (sub-step)
1b_population_lookup.r    ← step 1b (sub-step)
2_ant_ovwt_series.r       ← step 2
3_ane_wra_series.r        ← step 3
4_ant_wst_survey.r        ← step 4
5_ant_stnt_series.r       ← step 5
6_bw_lbw_series.r         ← step 6
7_iycf_exbf_survey.r      ← step 7
8_format_output.r         ← step 8
```

---

## 4. Decision Flowchart

```
Is the script an entry-point that sources other scripts in order?
  → Yes: prefix 1_ (e.g. 1_execute_conductor.r)

Does it define shared functions or constants used by multiple scripts?
  → Yes, general helpers: prefix 0_
  → Yes, self-contained module with public API: prefix 00_

Is it a pipeline processing step?
  → Yes: prefix with its execution-order digit (2_, 3_, 4_, …)
  → Yes, and it's a sub-step of an existing tier: add letter suffix (1a_, 1b_)
```
