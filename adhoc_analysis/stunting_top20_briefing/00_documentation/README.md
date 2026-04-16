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
| `02_codes/4_create_ppt.r` | Generates a UNICEF-branded PowerPoint (`stunting_top20_briefing.pptx`) that keeps template cover/thank-you slides and adds analysis charts plus narrative. Includes statistic callout slides (1, 2, and 4 stats per slide) for key metrics. Also produces an Excel companion workbook (`stunting_top20_briefing_data.xlsx`) with one sheet per figure slide so data can be reviewed or charts recreated in Excel. |

## Data Source

- **Input:** `cmrs2_series_accepted.parquet` from `analysisDatasetsOutputDir` (resolved via `profile_OSE-DA-NT.R`).
- **Indicator:** `ANT_HAZ_NE2_MOD` — JME modeled stunting prevalence (height-for-age < -2 SD), children under 5.
- **Filter:** National aggregates only (SEX = _T, RESIDENCE = _T, WEALTH = _T, REGION = _T).

## Outputs

| File | Description |
|------|-------------|
| `stunting_rankings.csv` | Combined human-readable rankings with baseline/current values and change. |
| `stunting_rankings.rds` | R list object with three data frames + metadata (for PPT script). |
| `stunting_top20_briefing.pptx` | PowerPoint opening with a full-bleed branded photo cover, followed by a title slide, chart slides, narrative bullet slides, and a thank-you closing slide. |
| `stunting_top20_briefing_data.xlsx` | Excel workbook with one sheet per figure slide (7 sheets when burden data exist). Columns match the chart data so figures can be recreated in Excel. |

## Dependencies

R packages: `arrow`, `dplyr`, `tidyr`, `readr`, `ggplot2`, `countrycode`, `officer`, `rvg`, `openxlsx`.

## Brand Assets

- Brand root (resolved via `nutritionRoot`): `github/documentation/unicef_brand`
- Global UNICEF guidance/template resources remain in scope and are still used.

## Template Icons

Seven nutrition-related icons were extracted from the UNICEF Branded Presentation Template (slides 65–70 contain ~200 programme icons). These are stored in `01_inputs/icons/` and used on section divider slides:

| File | Description | Used on |
|------|-------------|---------|
| `nutrition.png` | Smiling face with spoon in blue circle | Overview section slide |
| `children.png` | Two children figures in blue circle | Prevalence section slide |
| `infant.png` | Baby figure in blue circle | Burden section slide |
| `breastfeeding.png` | Mother breastfeeding baby in blue circle | Available for future use |
| `food_security.png` | Bowl with wheat/grain in blue circle | Available for future use |
| `mother_and_baby.png` | Mother holding baby in blue circle | Available for future use |
| `baby.png` | Crawling baby in blue circle | Available for future use |

To extract additional icons, inspect slides 65–70 of the template PPTX (icons are `p:pic` shapes with descriptive `descr` alt-text attributes).
- Office-specific resources (Innocenti) in `OneDrive_1_4-15-2026` are complementary and should be used for local office identity assets (e.g., signature, letterhead, office naming), not as a replacement for global UNICEF brand guidance.
- The PPT script searches for `UNICEF Branded Presentation Template 2026.pptx` (then 2025) in the brand root first, then inside `OneDrive_*` subfolders, with a legacy fallback to `_extracted/template_2026.pptx`.

## Slide Modules

| Module | Purpose |
|--------|----------|
| `02_codes/00_pptx_design_tokens.r` | UNICEF brand colours, font specs, text-box constraints. All slide modules consume this. |
| `02_codes/00_pptx_title_slide.r` | Title slide generation: variant selection (excluding slide 9), text replacement with auto-fit and auto-width, multi-line support via `\n`, vertical spacing adjustments. |
| `02_codes/00_pptx_bullet_slide.r` | Full-width numbered bullet slides using layout "8_Title and Content". Supports sub-bullets (level 2), automatic pagination with "(continued)", continued numbering across slides, and configurable spacing between top-level bullet groups. |
| `02_codes/00_pptx_section_slide.r` | Overview and section break slides using layouts "Title and Content" / "2_Title and Content" (template slides 30–31 design). Left side: title + body text; right side: empty picture placeholder for the user to insert their own photo in PowerPoint. Used for the presentation overview and as section dividers between content blocks. |

## Notes

- "Improvement" is measured as absolute reduction in stunting prevalence (percentage points).
- The latest year and baseline years are derived automatically from the data.
- Charts use UNICEF colour and typography settings for presentation readability.
- All figure slides show 15 countries (optimal for horizontal bar/dot charts on widescreen slides).
- The before/after dot plot (slide 7) is sorted by the latest-year value (lowest at top) with a legend ordered to match left-to-right positioning (latest year first, then baseline year).
