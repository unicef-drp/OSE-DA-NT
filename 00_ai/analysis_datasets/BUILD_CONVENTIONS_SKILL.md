# Analysis Datasets Build Conventions Skill

Last updated: 2026-04-14

## Purpose

Guide AI agents through the conventions, hardcoded business rules, and
data-decision semantics used in the `analysis_datasets/02_codes/` build
pipeline. Misunderstanding these conventions was the source of multiple bugs
during the projections migration.

---

## Trigger

Apply this skill when:
- Editing any `2_build_cmrs2_*.r` script or `0_layer2_utils.r`.
- Adding or modifying confidential overrides for specific countries/indicators.
- Debugging why rows are missing from accepted parquets.
- Adding hardcoded TIME_PERIOD or value corrections.
- Understanding how `write_accepted_subset()` filters rows.

---

## 1. DataSourceDecision vs DataSourceDecisionCategory

These are two separate fields with different roles. Confusing them was the
root cause of the BHR/NIC confidential bug.

| Field | Role | Values | Who sets it |
|-------|------|--------|------------|
| `DataSourceDecisionCategory` | **Filter field** — determines inclusion in accepted subset | `"Accepted"`, `"Rejected"`, etc. | Upstream CMRS production |
| `DataSourceDecision` | **Metadata field** — describes the nature of the acceptance | `"Accepted"`, `"Accepted and Confidential"`, etc. | Upstream CMRS or pipeline overrides |

### The confidential convention

Confidential rows must be included in regional aggregation (they contribute to
regional estimates) but excluded from public country-level outputs (projections,
data warehouse).

The correct way to mark a row confidential:
```r
# CORRECT: Category stays "Accepted" so write_accepted_subset() includes it.
# Decision becomes "Accepted and Confidential" for downstream filtering.
all_data$DataSourceDecision[conf_idx] <- "Accepted and Confidential"
```

The wrong way (caused missing BHR/NIC rows):
```r
# WRONG: This removes the rows from the accepted subset entirely.
all_data$DataSourceDecisionCategory[conf_idx] <- "Confidential"
```

### Downstream filtering

- `write_accepted_subset()` filters on `DataSourceDecisionCategory %in% include_categories` (default: `"Accepted"`).
- Projections pipeline (`1a_import_inputs.r`) additionally filters out `DataSourceDecision == "Accepted and Confidential"` after loading the accepted parquet.
- Regional aggregation in DW-Production uses the accepted parquet directly (confidential rows included).

---

## 2. write_accepted_subset() Function

```r
write_accepted_subset(all_data, output_file, include_categories = "Accepted")
```

- Filters `all_data` to rows where `DataSourceDecisionCategory %in% include_categories`.
- Writes the filtered subset to `{layer2_output_dir}/{output_file}` as a zstd-compressed parquet.
- Default `include_categories = "Accepted"` means confidential rows (which keep `DataSourceDecisionCategory = "Accepted"`) are included.
- Override `include_categories` only if a build script needs non-standard filtering.

---

## 3. Hardcoded Business Rules in build_layer2_dataset()

These are corrections for upstream data issues. They live in
`0_layer2_utils.r` inside `build_layer2_dataset()` and should eventually be
removed when fixed upstream.

### ZWE Survey 2879 — TIME_PERIOD correction

The Zimbabwe National Nutrition Survey (Survey ID 2879) has `TIME_PERIOD = 2013`
in the upstream CMRS data, but field data collection occurred primarily in late
2012.  DW-Production hardcodes this to 2012 in its `1g_country_preferred.R`.

The pipeline applies the same correction:
- `TIME_PERIOD`: `"2013"` → `"2012"`
- `CMRS_year_exact`: `"2013.024..."` → `"2012.92213114754"`

**Why it matters:** `CMRS_year_exact` drives sub-year priority selection. Without
correction, ZWE 2013 could win priority over a survey truly conducted in 2012.

### BHR — Overweight series exclusion

BHR overweight series estimates are unreliable. Marked confidential in
`2_build_cmrs2_series.r`. Additionally excluded from projections in
`1a_import_inputs.r` via:
```r
filter(!(INDICATOR == "NT_ANT_WHZ_PO2_MOD" & REF_AREA == "BHR"))
```

### NIC — All series estimates

All NIC series estimates are unreliable. Entire country flagged confidential in
`2_build_cmrs2_series.r`. This means NIC is absent from projections output
(3 rows: overweight, stunting, LBW).

---

## 4. Stata-Style Rounding

R's `round()` uses banker's rounding (round half to even):
`round(2.5, 0)` → `2`, `round(3.5, 0)` → `4`.

The pipeline uses a Stata-aligned function that always rounds 0.5 up:
```r
stata_round <- function(x, digits = 0) {
  factor <- 10 ^ digits
  ifelse(is.na(x), NA_real_, sign(x) * floor(abs(x) * factor + 0.5) / factor)
}
# stata_round(2.5, 0) → 3, stata_round(3.5, 0) → 4
```

**Where it matters:**
- Prevalence rounded to 1dp before use in AARR and threshold comparisons.
- AARR rounded to 2dp before use in classification.
- Threshold boundary cases (e.g., 5.05 rounds to 5.1 with stata_round but 5.0 with R's round).

---

## 5. Proportion vs Percent Convention

| Data source | Scale | Example |
|-------------|-------|---------|
| Analysis datasets parquets (`VALUE` column) | Proportion 0–1 | 0.093 = 9.3% |
| Projections pipeline (`OBS_VALUE`) | Percent 0–100 | 9.3 |
| Regional aggregation outputs | Percent 0–100 | 9.3 |

`read_analysis_parquet_as_char()` in the projections import script multiplies
`VALUE`, `LOWER_BOUND`, and `UPPER_BOUND` by 100 during import.

---

## 6. Indicator Code Prefix Convention

| Context | Code format | Example |
|---------|-------------|---------|
| Analysis datasets parquets | No prefix | `ANT_WHZ_NE2` |
| Projections pipeline, DW output | `NT_` prefix | `NT_ANT_WHZ_NE2` |

The prefix is prepended during parquet import in `read_analysis_parquet_as_char()`.

---

## 7. DATA_SOURCE_PRIORITY Field

| Value | Meaning |
|-------|---------|
| `1` | Preferred source — used for headline country estimates |
| `0` | Non-preferred source — used in AARR regression but not as headline value |

The accepted parquet contains **both** preferred and non-preferred rows for the
same country + year + indicator. This is intentional:
- The AARR regression in projections scripts 4 and 7 uses all surveys.
- Only the baseline year is reduced to the preferred row.
- The latest value (`country_recent`) selects the preferred row via `desc(source_priority)` sort.

**Anti-pattern:** Filtering the parquet to `DATA_SOURCE_PRIORITY == 1` before
passing to downstream scripts removes surveys needed for AARR regression.

---

## Checklist: Adding a New Hardcoded Correction

1. Identify the upstream CMRS issue and document it in `00_documentation/UPSTREAM_SOURCE_DATA_FLAGS.md`.
2. Implement correction in `build_layer2_dataset()` in `0_layer2_utils.r` with a clear comment and message.
3. If the correction marks rows confidential, use the `DataSourceDecision` field (not `DataSourceDecisionCategory`).
4. Rebuild affected dataset: `Rscript analysis_datasets/02_codes/2_build_cmrs2_*.r`.
5. Verify with `0_verify_all_outputs.r`.
6. If the correction affects projections, re-run `1_execute.r` and compare output.
