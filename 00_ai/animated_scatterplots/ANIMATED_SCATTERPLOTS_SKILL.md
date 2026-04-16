# Animated Scatterplots Pipeline Skill

Last updated: 2026-04-16

## Purpose

Guide AI agents through building and extending animated regional
bubble-scatterplot visualizations in the animated_scatterplots pipeline.

---

## Trigger

Apply this skill when:
- Adding a new indicator to the animated scatterplots pipeline.
- Editing `0_scatterplot_functions.r` or any `animated_scatterplot_*.R` script.
- Debugging animation rendering, label positioning, or data loading issues.
- Changing the filler-loop panel overlay behavior.

---

## Architecture: Shared Functions + Thin Config Scripts

The pipeline uses a shared-functions pattern. All reusable logic lives in
`0_scatterplot_functions.r`. Each indicator script is a thin config file
(~35 lines) that calls shared functions with indicator-specific parameters.

**Do not duplicate plotting or rendering logic into indicator scripts.**
If a new indicator needs different behavior, add a parameter to the shared
function or create a new shared loader function.

---

## Data Loading Patterns

### Standard path: country-level parquet → regional aggregation

Most indicators use `load_regional_series()`:
1. Reads `cmrs2_series_accepted.parquet` filtered by `IndicatorCode` and `SEX == "_T"`
2. Converts proportion (0–1 `r` column) to percent
3. Joins with crosswalk (`UNICEF_REP_REG_GLOBAL` classification) and population
4. Computes population-weighted regional prevalence and `pop_affected`

The parquet stores indicator codes **without** the `NT_` prefix
(e.g. `ANT_HAZ_NE2_MOD`, not `NT_ANT_HAZ_NE2_MOD`).

### Special case: pre-aggregated CSV

Some indicators (e.g. wasting) are not in the country-level parquet because
they are produced by a different modeling process. These use dedicated loader
functions (e.g. `load_wasting_series()`) that read pre-aggregated CSVs from
DW-Production's `agg_domain` folder.

**Key difference**: the CSV already has regional prevalence, but region names
may differ from the crosswalk. Always harmonize region names when adding a new
CSV-based loader.

Known region name mismatches (CSV → crosswalk):
- "East Asia and **the** Pacific" → "East Asia and Pacific"
- "Latin America and **the** Caribbean" → "Latin America and Caribbean"
- "East and Southern Africa" → "**Eastern** and Southern Africa"

The CSV uses `INDICATOR` with the `NT_` prefix (e.g. `NT_ANT_WHZ_NE2`).

---

## ggrepel Label Positioning in Animations

Labels in animated scatterplots use `ggrepel::geom_text_repel`. Key parameters
that control frame-to-frame consistency:

| Parameter | Value | Why |
|-----------|-------|-----|
| `seed` | 42 | Deterministic layout — prevents labels bouncing between frames |
| `force` | 0.3 | Low repulsion keeps labels close to their points |
| `force_pull` | 1.5 | Strong pull toward data points (higher than force) |
| `point.padding` | 0.15 | Minimal spacing from point |
| `box.padding` | 0.2 | Minimal spacing between label boxes |

**Anti-pattern**: Using high `force` values (e.g. 2+) causes labels to
oscillate wildly between animation frames. Keep `force_pull > force` and
use `seed` for deterministic placement.

Focus regions get separate `geom_text_repel` layers with larger, bold text.
Non-focus regions near focus regions have their alpha reduced to avoid visual
clutter (controlled by `overlap_threshold`).

---

## Filler Loop Panel Overlays

`render_looped_panel_version()` creates a multi-pass animation:

- **Pass 1**: Clean loop (no blue panel) — gives viewer time to read the legend
- **Passes 2 through N+1**: Each pass shows a slide-in UNICEF-blue panel with
  a headline/subline text pair

The slide-in animation uses magick's `image_draw()` to draw rectangles and
`image_annotate()` for text. The panel slides in from the right over
`slide_frames` (10) frames starting at 20% through each loop.

**Anti-pattern**: Starting the panel on the first pass removes the viewer's
only opportunity to read the legend unobstructed.

---

## gganimate Warnings

`transition_reveal()` produces harmless `geom_path(): Each group consists of
only one observation` warnings. These are expected — each group starts with a
single point on the first revealed frame. They are not actionable and should
not be treated as errors.

---

## Crosswalk Join: Many-to-Many

The crosswalk join uses `relationship = "many-to-many"` because countries can
belong to multiple regions within the `UNICEF_REP_REG_GLOBAL` classification
(e.g. a country in both a sub-region and a parent region). Omitting this
parameter produces a warning. The many-to-many relationship is intentional.

---

## Adding a New Indicator Checklist

1. Determine whether data is in the parquet or requires a special loader.
2. If parquet: identify the `IndicatorCode` (without `NT_` prefix).
   If CSV: add a loader function to `0_scatterplot_functions.r` with region name harmonization.
3. Create `animated_scatterplot_{name}.R` following the existing pattern.
4. Choose `focus_regions`, `focus_colors`, `y_limits`, and headline/subline text.
5. Add `source()` line to `1_execute.r`.
6. Test by uncommenting only the new indicator's source line.

---

## Theme and Visual Conventions

- Plot dimensions: 900×600 pixels
- Base GIF: 120 frames at 6 fps with 10-frame start/end pauses
- Base MP4: 120 frames at 10 fps
- Filler loop MP4: 6 fps
- Color palette: RColorBrewer Set2 as base, with focus-color overrides
- Theme: `theme_minimal(base_size = 12)` with right-positioned legend
- Caption: "Source: UNICEF, WHO & World Bank Joint Child Malnutrition Estimates"
