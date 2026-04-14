# Projections Pipeline Migration and Validation Skill

Last updated: 2026-04-14

## Purpose

Guide AI agents through migrating the projections pipeline from DW-Production
CSV inputs to analysis_datasets parquet inputs, and validating output parity
with the old DW-Production output.

---

## Trigger

Apply this skill when:
- Migrating a new indicator's input from DW-Production CSV to analysis_datasets parquet.
- Adding or changing how `1a_import_inputs.r` reads upstream data.
- Debugging value differences between old and new projections output.
- Modifying rounding, priority selection, or filtering logic in any projection script.

---

## Key Constraints

### 1. Parquet values are proportions; projections expect percent

Analysis_datasets parquets store `VALUE` on a 0–1 proportion scale.
The projections pipeline expects 0–100 percent scale.
`read_analysis_parquet_as_char()` in `1a_import_inputs.r` multiplies by 100.

**Anti-pattern:** Forgetting the ×100 conversion produces projections with
baseline values like 0.093 instead of 9.3.

### 2. Parquet indicator codes lack the NT_ prefix

Parquet stores `ANT_WHZ_NE2`; projections expect `NT_ANT_WHZ_NE2`.
`read_analysis_parquet_as_char()` prepends `NT_`.

### 3. Accepted parquet contains ALL surveys, not just preferred

The `cmrs2_*_accepted.parquet` files contain both `DATA_SOURCE_PRIORITY = 1`
(preferred) and `DATA_SOURCE_PRIORITY = 0` (non-preferred) rows for the same
country + year.

**Critical rule:** Do NOT filter to priority=1 only. The AARR regression in
scripts 4 and 7 (wasting, EXBF) intentionally uses ALL surveys for non-baseline
years. Only the baseline year is reduced to the single preferred row.

The relevant code pattern:
```r
country_aarr <- country_surveys %>%
  group_by(REF_AREA, survey_year) %>%
  mutate(
    keep_for_aarr = if_else(
      survey_year == first(year_baseline),
      row_number() == 1,    # baseline year: keep only preferred
      TRUE                   # all other years: keep ALL surveys
    )
  )
```

### 4. Subnational_Status differs between parquet types

- Non-series parquets (ant, iycf): `Subnational_Status = "0"` for national rows.
- Series parquets (series): `Subnational_Status = NA` for all rows (national by default).

The national-level filter must handle both:
```r
dplyr::filter(is.na(Subnational_Status) | as.character(Subnational_Status) == "0")
```

**Anti-pattern:** Filtering only `== "0"` drops all series rows because NA != "0".

### 5. Prevalence must be rounded to 1dp before use in calculations

All prevalence values (`r_baseline`, `r_recent`, `r_2012`, `r_2024`, etc.)
must be rounded to 1 decimal place using `stata_round(x, 1)` at the point of
assignment — before they flow into AARR formulas, threshold comparisons, or
output exports.

The Stata-aligned rounding function (defined in each script):
```r
stata_round <- function(x, digits = 0) {
  factor <- 10 ^ digits
  ifelse(is.na(x), NA_real_, sign(x) * floor(abs(x) * factor + 0.5) / factor)
}
```

**Where to round:**
- At assignment of baseline: `r_2012 = stata_round(OBS_VALUE, round_digits_prev)`
- At assignment of latest: `r_2024 = stata_round(OBS_VALUE, round_digits_prev)`
- For survey scripts (4, 7): `r_baseline = stata_round(first(OBS_VALUE), round_digits_prev)` and `r_recent = stata_round(OBS_VALUE, round_digits_prev)`
- The AARR regression input (`prev_for_aarr`) was already correctly rounded.
- The `projected_value_2030` formula then receives pre-rounded inputs.

**Exception — stunting number-affected calculation:**
Script 5 computes `baseline_numb = r_2012_prop * basepop_value_2012` using the
unrounded proportion. The prevalence `r_2012` is rounded separately for AARR
and display. Do not round `r_2012_prop` — it's for number calculations.

### 6. AARR must be rounded to 2dp before use in calculations

`current_AARR` and `required_AARR_2030` are both rounded to 2 decimal places
using `stata_round(x, 2)`. This was already correct in all scripts.

### 7. country_recent must prefer the priority survey

When multiple surveys exist for the same country + year, `country_recent` must
sort by `desc(source_priority)` before `slice_head(n = 1)` to select the
preferred survey's value as the latest value. The old DW exports had the
preferred row first by convention.

```r
country_recent <- country_surveys %>%
  group_by(REF_AREA) %>%
  arrange(desc(survey_year), desc(source_priority)) %>%
  slice_head(n = 1) %>%
  ...
```

### 8. Confidential rows must be excluded from projections

Rows with `DataSourceDecision == "Accepted and Confidential"` are for regional
aggregation only. They must be filtered out before country-level projections.
This is handled in `1a_import_inputs.r` after loading series data.

### 9. SEX remapping for anemia

The ANE_WOM_15_49_MOD indicator uses `SEX = "F"` in the parquet (target
population is women 15–49). Remap to `"_T"` so downstream `SEX == "_T"` filters
retain anemia rows.

---

## Validation Recipe: Compare New vs Old Output

After any migration change, compare `progress_2030_appended.xlsx`:

```r
library(openxlsx); library(dplyr)

new <- read.xlsx(new_path) %>% mutate(across(everything(), as.character))
old <- read.xlsx(old_path) %>% mutate(across(everything(), as.character))

keys <- c("INDICATOR", "REF_AREA", "reporting_level")

# 1. Row coverage
only_new <- anti_join(new %>% distinct(across(all_of(keys))),
                      old %>% distinct(across(all_of(keys))), by = keys)
only_old <- anti_join(old %>% distinct(across(all_of(keys))),
                      new %>% distinct(across(all_of(keys))), by = keys)

# 2. Value comparison (tolerance for regional rounding)
matched <- inner_join(new, old, by = keys, suffix = c(".new", ".old"))
for (col in c("baseline_value", "latest_value", "current_aarr",
              "required_aarr_2030", "projected_value_2030")) {
  cn <- paste0(col, ".new"); co <- paste0(col, ".old")
  diffs <- matched %>%
    filter(!is.na(.data[[cn]]) & !is.na(.data[[co]])) %>%
    mutate(diff = abs(as.numeric(.data[[cn]]) - as.numeric(.data[[co]]))) %>%
    filter(diff > 0.001)
  cat(col, "diffs >0.001:", nrow(diffs), "\n")
}

# 3. Classification match
for (col in c("fullclassification_2030", "unicef_classification_2030",
              "simpleclassification")) {
  cn <- paste0(col, ".new"); co <- paste0(col, ".old")
  cat(col, "mismatches:", sum(matched[[cn]] != matched[[co]], na.rm = TRUE), "\n")
}
```

### Expected acceptable differences

| Category | Cause | Acceptable? |
|----------|-------|-------------|
| NIC missing (3 rows) | Confidential — excluded from projections | Yes |
| Regional baseline/latest diffs <0.05 | Old DW regional data was unrounded; new pipeline rounds to 1dp | Yes |
| Regional projected_value_2030 diffs of 0.1 | Cascade from rounded baseline | Yes |
| Classification flips at exact threshold | Rounding 5.04→5.0 or 3.03→3.0 triggers threshold | Yes — correct Stata behavior |
| Country baseline/latest diffs | Should be 0 after rounding fix | No — investigate |
| current_aarr diffs | Should be 0 | No — investigate |
| Classification flips not at threshold boundary | Likely a priority or rounding bug | No — investigate |

---

## Common Pitfalls Encountered During Migration

| Pitfall | Symptom | Root Cause | Fix |
|---------|---------|------------|-----|
| 158 BW_LBW countries missing | Only Regional/Global rows in output | `Subnational_Status == "0"` filter dropped NAs | Use `is.na() \| == "0"` |
| Wasting latest_value wrong | BFA shows 10.3 instead of 9.3 | `country_recent` didn't sort by priority | Add `desc(source_priority)` to arrange |
| All country values unrounded | BFA baseline = 10.7283 instead of 10.7 | Parquet has full precision | Round at assignment with `stata_round` |
| `analysisDatasetsInputDir` not defined | Error on script start | Variable only set inside config block | Add fallback derivation after config block |
| LBW data not loading | BW_LBW rows missing from staged input | Old CSV import removed but not added to parquet path | Add `"BW_LBW"` to `series_indicators` |
| `NOT_NT_BF_EXBF` only in new | 1 extra row in new output | EXBF complement indicator — intentional | Not a bug |

---

## Checklist for Migrating a New Indicator

1. Add indicator code (without NT_ prefix) to appropriate `indicators` vector in `1a_import_inputs.r`.
2. Verify `read_analysis_parquet_as_char()` handles the parquet's column layout.
3. Check `Subnational_Status` handling — series vs non-series.
4. Check if `SEX` or `AGE` need remapping (e.g., anemia `F` → `_T`).
5. Check if confidential rows exist and need filtering.
6. Round all prevalence at assignment to 1dp using `stata_round`.
7. Run pipeline: `Rscript 1_execute.r`
8. Compare with old output using validation recipe above.
9. Verify 0 country-level value diffs and 0 current_aarr diffs.
10. Confirm classification mismatches are only at threshold boundaries for regional rows.
