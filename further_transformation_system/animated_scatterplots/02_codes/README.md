# Animated Scatterplots Execute Folder

This README documents the execute pipeline in this folder.

Entrypoint:
- 1_execute.r

## Visual Schema

```mermaid
flowchart LR
    A[{nutritionRoot}/github/analysis_datasets\ncmrs2_series_accepted.parquet] --> E[1_execute.r]
    B[DW inter/groups_for_agg.csv] --> E
    C[DW input/base_population_1990_2030.csv] --> E
    D[DW inter/agg_domain/agg_ant_wasting.csv] --> E

    E --> F[Load shared functions + refs\nset .produce_gif/.produce_mp4]
    F --> G[Regional workers\nstunting/overweight/wasting]
    F --> H[Country workers\nstunting global + regional]

    G --> O[{nutritionRoot}/github/animated_scatterplots\nregional GIF/MP4 + looped GIF/MP4 + frames]
    H --> O2[{nutritionRoot}/github/animated_scatterplots/stunting_countries\nall-countries + per-region GIF/MP4]
```

Analysis summary:
- Builds animated prevalence-vs-burden scatterplots for regional and country views.
- Applies year-window filtering (currently 2000 to 2024 in active workers).
- Supports centralized output-format control in the conductor (`.produce_gif`, `.produce_mp4`).
- Country global stunting mode supports change-based label/focus ISO3 sets.

Final outputs and storage:
- Regional outputs under `{nutritionRoot}/github/animated_scatterplots`:
  - `{indicator}_regions_bubble.gif/.mp4`
  - `{indicator}_filler_loops_UNICEFblue_slide.gif/.mp4`
  - `{indicator}_frames_unicef/`
- Country stunting outputs under `{nutritionRoot}/github/animated_scatterplots/stunting_countries`:
  - `{indicator}_countries_all.gif/.mp4`
  - `{indicator}_countries_{region_slug}.gif/.mp4`

Used by other execute scripts:
- No direct downstream execute-script dependency currently documented.
- These are presentation/reporting assets and are not read by another execute script in this repo.
