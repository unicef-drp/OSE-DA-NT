# Animated Scatterplots Pipeline

Last updated: 2026-04-23

## Purpose

Produce animated GIF and MP4 bubble-scatterplots showing regional nutrition
trends (prevalence vs. number of affected children over time). Each indicator
gets a base animation plus a looped version with UNICEF-blue panel overlays
carrying headline/subline text messages.

Country-level scatterplots show individual countries within UNICEF programme
regions, with bubble size representing population-affected and animated over
time.

## Entrypoint

```
further_transformation_system/animated_scatterplots/02_codes/1_execute.r
```

The conductor loads libraries, resolves paths from `user_config.yml`, sources
shared functions, loads reference data once, sets output format flags
(`.produce_gif`, `.produce_mp4`), then sources worker scripts.

## Code Structure

| File | Role |
|------|------|
| `1_execute.r` | Pipeline conductor — libraries, paths, reference data, format flags, sources workers |
| `0_scatterplot_functions.r` | Shared functions used by all worker scripts |
| `animated_scatterplot_stunting_regions.r` | Stunting regional indicator config and render calls |
| `animated_scatterplot_overweight_regions.r` | Overweight regional indicator config and render calls |
| `animated_scatterplot_wasting_regions.r` | Wasting regional indicator config and render calls |
| `animated_scatterplot_stunting_countries_global.r` | Country-level stunting global render with category-based highlight sets |
| `animated_scatterplot_stunting_countries_regional.r` | Country-level stunting per-region renders |

### Shared Functions (`0_scatterplot_functions.r`)

| Function | Purpose |
|----------|---------|
| `load_crosswalk()` | Reads `groups_for_agg.csv` from DW-Production `interdir` |
| `load_population()` | Reads `base_population_1990_2030.csv` from DW-Production `inputdir` |
| `load_regional_series()` | Reads country-level parquet, aggregates to UNICEF regions with population weighting (supports `year_min`/`year_max`) |
| `load_wasting_series()` | Reads pre-aggregated wasting CSV, harmonizes region names, joins regional population (supports `year_min`/`year_max`) |
| `build_scatterplot()` | Builds the animated ggplot with focus-region highlighting and ggrepel labels |
| `render_base_animations()` | Renders base GIF and/or MP4 at 900x600 (`produce_gif`, `produce_mp4`) |
| `render_looped_panel_version()` | Creates multi-loop version with UNICEF-blue slide-in panels, exports GIF + frames + MP4 |
| `load_country_names()` | Reads raw `groups_for_agg.csv` to get ISO3-to-country name mapping |
| `load_country_series()` | Reads parquet, joins with crosswalk and population, returns country-year data (supports `year_min`/`year_max`) |
| `build_country_scatterplot()` | Builds country-level animated ggplot with optional explicit `label_isos` and `focus_isos` |
| `render_country_global_scatterplot()` | Renders global country plot (`{indicator}_countries_all`) |
| `render_country_regional_scatterplots()` | Renders one country-level plot per UNICEF region |
| `render_country_scatterplots()` | Backward-compatible wrapper for global + regional country renders |

## Worker Pattern

Each worker script is a thin configuration file that:

1. Calls a `load_*` function for the indicator/source.
2. Calls plotting helpers with indicator-specific labels, focus settings, and y-axis limits.
3. Calls render helpers with conductor-level format flags.

### Configurable Parameters Per Indicator

| Parameter | Description | Example |
|-----------|-------------|---------|
| `focus_regions` | Regions drawn with bold labels and stronger alpha | `c("South Asia", "East Asia and Pacific")` |
| `focus_colors` | Named color overrides for focus regions | `c("South Asia" = "#0072B2")` |
| `y_limits` | Fixed y-axis range (`NULL` = auto) | `c(0, 25)` for overweight |
| `headlines` / `sublines` | Text pairs for UNICEF-blue panel overlays in filler loops | 3 pairs per indicator |
| `year_min` / `year_max` | Year filter for data loading | `2000`, `2024` |

## Country-Level Scatterplots

Country-level animated scatterplots show individual countries as bubbles on a
prevalence (%) vs. children affected scatter, animated over time. Each country
is assigned to exactly one UNICEF Programme Region via the `UNICEF_PROG_REG_GLOBAL`
classification in the crosswalk.

### Global vs Regional Workers

Country-level stunting rendering is split into:

1. `animated_scatterplot_stunting_countries_global.r`
2. `animated_scatterplot_stunting_countries_regional.r`

Global should be sourced before regional when shared `country_data` is reused.

### Change-Based Highlight Sets (Global)

The global worker computes 2000-2024 changes and derives four category sets:

- largest drop in number affected
- largest drop in prevalence
- largest increase in number affected
- largest increase in prevalence

For each category, it derives:

- top 10 ISO3 for labels (`label_isos_*`)
- top 3 ISO3 for bold focus (`focus_isos_*`)

Only one global category call is active by default; the other category calls
are retained as commented alternatives for quick switching.

### Regional-Country Highlight Controls

Regional country rendering supports:

- `focus_isos_regional_default` for a shared highlight set across regions
- `focus_isos_by_region` for per-region overrides (takes precedence)

### Legend Threshold Labels

When `color_by = "threshold"` is used, stunting country plots use cutoff
labels in the legend:

- Very low (<2.5%)
- Low (2.5-<10%)
- Medium (10-<20%)
- High (20-<30%)
- Very high (>=30%)

## Input Sources

### Standard Indicators (stunting, overweight)

- **Country series**: `cmrs2_series_accepted.parquet` from `analysisDatasetsInputDir`
  - Indicator codes: `ANT_HAZ_NE2_MOD` (stunting), `ANT_WHZ_PO2_MOD` (overweight)
  - Values in `r` column (proportion 0-1), converted to percent internally
- **Crosswalk**: `groups_for_agg.csv` from DW-Production `interdir`
- **Population**: `base_population_1990_2030.csv` from DW-Production `inputdir`

### Wasting (special case)

Wasting modeled series are not in the country-level parquet. Instead, the pipeline
reads pre-aggregated regional estimates from:

```
{interdir}/agg_domain/agg_ant_wasting.csv
```

This CSV contains columns: `Classification`, `Region`, `INDICATOR`, `SEX`,
`OBS_VALUE`, `REF_AREA`, `TIME_PERIOD`, `OBS_FOOTNOTE`. The pipeline filters
to `Classification == "UNICEF Regions"` and `INDICATOR == "NT_ANT_WHZ_NE2"`.

Region names in the CSV differ from the crosswalk and are harmonized internally:

- "East Asia and the Pacific" -> "East Asia and Pacific"
- "Latin America and the Caribbean" -> "Latin America and Caribbean"
- "East and Southern Africa" -> "Eastern and Southern Africa"

Population for bubble sizes is still computed from country-level data via the crosswalk.

## Output Format Controls

Format decisions are centralized in the conductor (`1_execute.r`):

- `.produce_gif <- TRUE/FALSE`
- `.produce_mp4 <- TRUE/FALSE`

Workers pass these values through to rendering functions.

## Output Window

Current worker scripts use:

- `year_min = 2000`
- `year_max = 2024`

for the rendered time window.

## Output Location

```
{nutritionRoot}/github/animated_scatterplots/
```

### Regional Output Files Per Indicator

| File | Description |
|------|-------------|
| `{indicator}_regions_bubble.gif` | Base animated scatterplot (120 frames, 6 fps) |
| `{indicator}_regions_bubble.mp4` | MP4 version (120 frames, 10 fps) |
| `{indicator}_filler_loops_UNICEFblue_slide.gif` | Looped version with UNICEF panel overlays |
| `{indicator}_filler_loops_UNICEFblue_slide.mp4` | MP4 of looped version (6 fps) |
| `{indicator}_frames_unicef/` | Individual frame PNGs from looped version |

The looped version has `n_messages + 1` passes: the first pass plays clean
(no panel) so viewers can read the legend, then each subsequent pass shows a
slide-in blue panel with a headline/subline pair.

### Country Output Structure

For each country-level indicator render set:

1. **All-countries plot**: countries colored by region. Output: `{indicator}_countries_all.{gif,mp4}`
2. **Per-region plots**: one output per UNICEF Programme Region. Output: `{indicator}_countries_{region_slug}.{gif,mp4}`

Region slugs are lowercase with spaces replaced by underscores (example: `east_asia_and_pacific`).

## Dependencies

R packages: arrow, dplyr, readr, ggplot2, gganimate, scales, grid,
RColorBrewer, ggrepel, av, magick, gifski, ragg, yaml

## Adding a New Indicator

### Regional-level

1. Create `animated_scatterplot_{name}_regions.r` following the current regional workers.
2. If the indicator exists in `cmrs2_series_accepted.parquet`, use `load_regional_series()`.
3. If it uses a different data source, add a loader function to `0_scatterplot_functions.r`.
4. Add a `source()` line to `1_execute.r` in the worker section.
5. Choose focus regions, colors, y-axis limits, and headline/subline text.

### Country-level

1. Create `animated_scatterplot_{name}_countries_global.r` and optionally `animated_scatterplot_{name}_countries_regional.r`.
2. In global, call `load_country_series()` then `render_country_global_scatterplot()`.
3. In regional, call `render_country_regional_scatterplots()`.
4. Source global before regional in `1_execute.r` when reusing shared `country_data`.
5. Use `.produce_gif` and `.produce_mp4` from the conductor for format control.
