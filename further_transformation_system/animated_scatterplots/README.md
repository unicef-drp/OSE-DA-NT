# Animated Scatterplots Pipeline

Last updated: 2025-07-15

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

The executor loads libraries, resolves paths from `user_config.yml`, sources
shared functions, loads reference data once, then sources each indicator script.

## Code Structure

| File | Role |
|------|------|
| `1_execute.r` | Pipeline orchestrator — libraries, paths, reference data, sources workers |
| `0_scatterplot_functions.r` | Shared functions used by all indicator scripts |
| `animated_scatterplot_stunting.R` | Stunting indicator config and render calls |
| `animated_scatterplot_overweight.R` | Overweight indicator config and render calls |
| `animated_scatterplot_wasting.R` | Wasting indicator config and render calls |
| `animated_scatterplot_stunting_countries.R` | Country-level stunting scatterplots (all + per-region) |

### Shared Functions (`0_scatterplot_functions.r`)

| Function | Purpose |
|----------|---------|
| `load_crosswalk()` | Reads `groups_for_agg.csv` from DW-Production `interdir` |
| `load_population()` | Reads `base_population_1990_2030.csv` from DW-Production `inputdir` |
| `load_regional_series()` | Reads country-level parquet, aggregates to UNICEF regions with population weighting |
| `load_wasting_series()` | Reads pre-aggregated wasting CSV, harmonizes region names, joins regional population |
| `build_scatterplot()` | Builds the animated ggplot with focus-region highlighting, ggrepel labels |
| `render_base_animations()` | Renders base GIF (6 fps) and MP4 (10 fps) at 900×600 |
| `render_looped_panel_version()` | Creates multi-loop version with UNICEF-blue slide-in panels, exports GIF + frames + MP4 |
| `load_country_names()` | Reads raw `groups_for_agg.csv` to get ISO3→Country name mapping |
| `load_country_series()` | Reads parquet, joins with crosswalk and population, returns country×year data |
| `build_country_scatterplot()` | Builds animated ggplot for country-level data (color by region or uniform) |
| `render_country_scatterplots()` | Renders all-countries + per-region GIF/MP4 outputs |

## Indicator Scripts

Each indicator script is a thin configuration file that:
1. Calls a `load_*` function with the indicator code
2. Calls `build_scatterplot()` with indicator-specific labels, focus regions, colors, and y-axis limits
3. Calls `render_base_animations()` to produce base GIF/MP4
4. Calls `render_looped_panel_version()` with headline/subline text pairs

### Configurable Parameters Per Indicator

| Parameter | Description | Example |
|-----------|-------------|---------|
| `focus_regions` | Regions drawn with bold labels and stronger alpha | `c("South Asia", "East Asia and Pacific")` |
| `focus_colors` | Named color overrides for focus regions | `c("South Asia" = "#0072B2")` |
| `y_limits` | Fixed y-axis range (NULL = auto) | `c(0, 25)` for overweight |
| `headlines` / `sublines` | Text pairs for UNICEF-blue panel overlays in filler loops | 3 pairs per indicator |

## Country-Level Scatterplots

Country-level animated scatterplots show individual countries as bubbles on a
prevalence (%) vs. children affected scatter, animated over time. Each country
is assigned to exactly one UNICEF Programme Region via the `UNICEF_PROG_REG_GLOBAL`
classification in the crosswalk.

### Output Structure

For each indicator, `render_country_scatterplots()` produces:

1. **All-countries plot** — 154 countries colored by region, top 15 labeled by
   children affected. Output: `{indicator}_countries_all.{gif,mp4}`
2. **Per-region plots** — One plot per UNICEF Programme Region (7 regions),
   all countries in UNICEF blue, all labeled (unless >25 countries in a region).
   Output: `{indicator}_countries_{region_slug}.{gif,mp4}`

Region slugs are lowercase, spaces→underscores (e.g., `east_asia_and_pacific`).

### Output Location

```
{nutritionRoot}/github/animated_scatterplots/stunting_countries/
```

16 files total: 8 GIF + 8 MP4 (1 all + 7 regions × 2 formats).

## Input Sources

### Standard Indicators (stunting, overweight)

- **Country series**: `cmrs2_series_accepted.parquet` from `analysisDatasetsInputDir`
  - Indicator codes: `ANT_HAZ_NE2_MOD` (stunting), `ANT_WHZ_PO2_MOD` (overweight)
  - Values in `r` column (proportion 0–1), converted to percent internally
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
- "East Asia and the Pacific" → "East Asia and Pacific"
- "Latin America and the Caribbean" → "Latin America and Caribbean"
- "East and Southern Africa" → "Eastern and Southern Africa"

Population for bubble sizes is still computed from country-level data via the crosswalk.

## Output Location

```
{nutritionRoot}/github/animated_scatterplots/
```

### Output Files Per Indicator

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

## Dependencies

R packages: arrow, dplyr, readr, ggplot2, gganimate, scales, grid,
RColorBrewer, ggrepel, av, magick, gifski, ragg, yaml

## Adding a New Indicator

### Regional-level

1. Create `animated_scatterplot_{name}.R` following the pattern of existing scripts.
2. If the indicator exists in `cmrs2_series_accepted.parquet`, use `load_regional_series()`.
   If it uses a different data source, add a loader function to `0_scatterplot_functions.r`.
3. Add a `source()` line to `1_execute.r` in the worker scripts section.
4. Choose focus regions, colors, y-axis limits, and write headline/subline text.

### Country-level

1. Create `animated_scatterplot_{name}_countries.R` following `animated_scatterplot_stunting_countries.R`.
2. Call `load_country_series()` with the indicator code, then `render_country_scatterplots()`.
3. Add a `source()` line to `1_execute.r`.
4. Set indicator-specific labels, y-axis limits, and output subfolder name.
