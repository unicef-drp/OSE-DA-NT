# Stunting Top 20 Country Briefing

**Request:** ED briefing on stunting — top 20 countries by highest levels and biggest improvers (10-year and 20-year windows).

**Date created:** 2026-04-13

## Folder Structure

```
stunting_top20_briefing/
  00_documentation/       ← this README, session learnings, governance docs
  00_documentation/old/   ← archived content iterations from earlier workflow
  01_inputs/              ← local copy of stunting modeled data (generated at runtime)
  02_codes/               ← analysis and product-generation scripts
  03_outputs/             ← rankings, tables/figures workbook, markdown, PNGs, products
  03_outputs/figures/     ← PNG figure images from data analysis step
```

## Workflow

1. **Data analysis** (script 3): Crunch the data, produce an Excel workbook
   with summary tables and a `figures/` folder with chart PNGs, plus a markdown
   file listing all figures with key findings and points of interest.
2. **Human review**: Iterative review of the markdown and Excel using a review
   document and track-change document (three-file pattern).
3. **Content agreement**: Outline the target product (e.g. 2-page brief) with a
   word/paragraph budget matched to available space.
4. **Product content**: Draft the narrative for the specific product.
5. **Product generation**: Run a product script (5*.r) to produce the final
   output (DOCX, PPTX, etc.).

## Execution Order

Run scripts from the **repository root** (so `profile_OSE-DA-NT.R` resolves):

| Script | Purpose |
|--------|---------|
| `02_codes/1_execute_conductor.r` | **Entrypoint.** Sources steps 1–2 below. Product scripts (step 3) are run manually after review. |
| `02_codes/2_prepare_inputs.r` | Copies stunting modeled estimates (ANT_HAZ_NE2_MOD) from `analysisDatasetsOutputDir` into `01_inputs/`. Filters to national-level totals. |
| `02_codes/3_stunting_rankings.r` | Computes top-20 rankings (prevalence and burden), overlap and concentration analysis, generates Excel workbook (`stunting_tables_and_figures.xlsx`), PNG figures (7 charts), and markdown with key findings (`stunting_tables_and_figures.md` + `.review.md`). Also writes RDS and CSV for downstream use. |
| `02_codes/5_create_ppt.r` | *(secondary, revisit later)* Generates a UNICEF-branded PowerPoint. |
| `02_codes/5b_create_ppt_from_content_master.r` | *(secondary)* Test PPT from markdown content master. |
| `02_codes/5c_create_ppt_combined.r` | *(secondary)* Combined PPT with speaker notes. |
| `02_codes/5d_create_two_pager_brief.r` | *(secondary)* Unstyled two-page briefing document. |
| `02_codes/5e_create_two_pager_styled.r` | Stylized fixed-layout two-page briefing document. |

## Data Source

- **Input:** `cmrs2_series_accepted.parquet` from `analysisDatasetsOutputDir` (resolved via `profile_OSE-DA-NT.R`).
- **Indicator:** `ANT_HAZ_NE2_MOD` — JME modeled stunting prevalence (height-for-age < -2 SD), children under 5.
- **Filter:** National aggregates only (SEX = _T, RESIDENCE = _T, WEALTH = _T, REGION = _T).

## Outputs

### Data analysis outputs (script 3)

| File | Description |
|------|-------------|
| `stunting_rankings.rds` | R list object with all ranking data frames, overlap, concentration, and metadata. |
| `stunting_rankings.csv` | Combined human-readable rankings with baseline/current values and change. |
| `stunting_tables_and_figures.xlsx` | Excel workbook with one sheet per summary table (T1–T8). |
| `stunting_tables_and_figures.md` | Markdown listing all figures, tables, key findings, and points of interest. |
| `stunting_tables_and_figures.review.md` | Clean review copy for human editing. |
| `figures/fig1_highest_prevalence.png` | Top-20 highest stunting prevalence bar chart. |
| `figures/fig2_highest_burden.png` | Top-20 highest number of stunted children bar chart. |
| `figures/fig3_10yr_prevalence_reduction.png` | Top-20 10-year prevalence reduction bar chart. |
| `figures/fig4_20yr_prevalence_reduction.png` | Top-20 20-year prevalence reduction bar chart. |
| `figures/fig5_10yr_burden_reduction.png` | Top-20 10-year burden reduction bar chart. |
| `figures/fig6_20yr_burden_reduction.png` | Top-20 20-year burden reduction bar chart. |
| `figures/fig7_before_after_10yr.png` | Before/after dot plot for 10-year prevalence change. |

### Product outputs (scripts 5*.r — run after review)

| File | Description |
|------|-------------|
| `stunting_top20_briefing.pptx` | UNICEF-branded PowerPoint (from 5_create_ppt.r). |
| `stunting_top20_briefing_data.xlsx` | Companion workbook for the PPT. |
| `stunting_top20_two_pager_v4b_styled.docx` | Stylized two-page briefing document (from 5e). |
| `stunting_top20_two_pager_v4b_styled_data.xlsx` | Companion workbook for the styled two-pager. |

## Dependencies

R packages: `arrow`, `dplyr`, `tidyr`, `readr`, `ggplot2`, `countrycode`, `officer`, `rvg`, `openxlsx`.

## Brand Assets

- Brand root (resolved via `nutritionRoot`): `github/documentation/unicef_brand`
- Global UNICEF guidance/template resources remain in scope and are still used.
- Office-specific resources (Innocenti) in `OneDrive_1_4-15-2026` are complementary and should be used for local office identity assets (e.g., signature, letterhead, office naming), not as a replacement for global UNICEF brand guidance.
- The PPT script searches for `UNICEF Branded Presentation Template 2026.pptx` (then 2025) in the brand root first, then inside `OneDrive_*` subfolders, with a legacy fallback to `_extracted/template_2026.pptx`.

## Slide Modules

| Module | Purpose |
|--------|----------|
| `02_codes/00_pptx_design_tokens.r` | UNICEF brand colours, font specs, text-box constraints. All slide modules consume this. |
| `02_codes/00_pptx_title_slide.r` | Title slide generation: variant selection (excluding slide 9), text replacement with auto-fit and auto-width, multi-line support via `\n`, vertical spacing adjustments. |
| `02_codes/00_pptx_bullet_slide.r` | Full-width numbered bullet slides using layout "8_Title and Content". Supports sub-bullets (level 2), automatic pagination with "(continued)", continued numbering across slides, and configurable spacing between top-level bullet groups. |
| `02_codes/00_pptx_section_slide.r` | Overview and section break slides using layouts "Title and Content" / "2_Title and Content" (template slides 30–31 design). Left side: title + body text; right side: empty picture placeholder for the user to insert their own photo in PowerPoint. Used for the presentation overview and as section dividers between content blocks. |

## Content Governance

Use these local documents when extending the briefing content:

- `00_documentation/CONTENT_PLAN_AND_SOURCE_GOVERNANCE.md` - analysis roadmap, approved numeric-source rules, and citation requirements
- `00_documentation/JME_SOURCE_DISCOVERY_STARTER.md` - starting list of high-priority UNICEF JME background sources for modeled stunting content
- `00_documentation/SESSION_LEARNINGS_2026-04-17.md` - reusable lessons from the current briefing-development session, including markdown review workflow and tracked-change conventions

Previous content iterations (V1–V4 briefing content, content agreements, PPT
content masters, figure audit) have been moved to `00_documentation/old/` for
reference. The current workflow starts from the tables/figures markdown produced
by script 3.

Working source documents and the source registry for this briefing are stored
outside the repository in the Analysis Space `github` folder at:

`C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/adhoc_analysis/stunting_top20_briefing/00_documentation/source_library`

Use that external folder for non-dataset source documents and the active
`source_registry.csv`.

## Notes

- "Improvement" is measured as absolute reduction in stunting prevalence (percentage points).
- The latest year and baseline years are derived automatically from the data.
- Charts use UNICEF colour and typography settings for presentation readability.
- All figure slides show 15 countries (optimal for horizontal bar/dot charts on widescreen slides).
- The before/after dot plot (slide 7) is sorted by the latest-year value (lowest at top) with a legend ordered to match left-to-right positioning (latest year first, then baseline year).
- For markdown drafting rounds, prefer a three-file review pattern: clean draft, tracked draft, and clean review copy.
- For multi-product briefing workflows, settle the two-page narrative brief first; derive the 1-page brief and PowerPoint from it.
- Content agreements and briefing content drafts must account for the physical space available in the target format from the start. A two-page styled brief has roughly one page of usable text once figures, headers, callouts, and margins are included. Draft word budgets alongside the content outline to avoid overproduction.
