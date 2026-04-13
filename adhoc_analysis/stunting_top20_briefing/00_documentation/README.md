# Stunting Top 20 Country Briefing

**Request:** ED briefing on stunting — top 20 countries by highest levels and biggest improvers (10-year and 20-year windows).

**Date created:** 2026-04-13

## Folder Structure

```
stunting_top20_briefing/
  00_documentation/   ← this README
  01_inputs/          ← local copy of stunting modeled data (generated at runtime)
  02_codes/           ← analysis and visualization scripts
  03_outputs/         ← rankings CSV, RDS, and PowerPoint
```

## Execution Order

Run scripts from the **repository root** (so `profile_OSE-DA-NT.R` resolves):

| Script | Purpose |
|--------|---------|
| `02_codes/1_execute_conductor.r` | **Entrypoint.** Sources all steps below in order. |
| `02_codes/2_prepare_inputs.r` | Copies stunting modeled estimates (ANT_HAZ_NE2_MOD) from `analysisDatasetsOutputDir` into `01_inputs/`. Filters to national-level totals. |
| `02_codes/3_stunting_rankings.r` | Computes three top-20 rankings: highest prevalence, biggest 10-year improvers, biggest 20-year improvers. Writes CSV and RDS to `03_outputs/`. |
| `02_codes/4_create_ppt.r` | Generates a UNICEF-branded PowerPoint (`stunting_top20_briefing.pptx`) that keeps template cover/thank-you slides and adds analysis charts plus narrative. |

## Data Source

- **Input:** `cmrs2_series_accepted.parquet` from `analysisDatasetsOutputDir` (resolved via `profile_OSE-DA-NT.R`).
- **Indicator:** `ANT_HAZ_NE2_MOD` — JME modeled stunting prevalence (height-for-age < -2 SD), children under 5.
- **Filter:** National aggregates only (SEX = _T, RESIDENCE = _T, WEALTH = _T, REGION = _T).

## Outputs

| File | Description |
|------|-------------|
| `stunting_rankings.csv` | Combined human-readable rankings with baseline/current values and change. |
| `stunting_rankings.rds` | R list object with three data frames + metadata (for PPT script). |
| `stunting_top20_briefing.pptx` | PowerPoint with template-based cover and thank-you slides, a branded nutrition divider slide, chart slides, and narrative slides for ED briefing. |

## Dependencies

R packages: `arrow`, `dplyr`, `tidyr`, `readr`, `ggplot2`, `countrycode`, `officer`, `rvg`.

## Notes

- "Improvement" is measured as absolute reduction in stunting prevalence (percentage points).
- The latest year and baseline years are derived automatically from the data.
- Charts use UNICEF colour and typography settings for presentation readability.
