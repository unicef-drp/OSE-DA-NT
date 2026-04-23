# Projections Progress Class Execute Folder

This README documents the execute pipeline in this folder.

Entrypoint:
- 1_execute.r

## Visual Schema

```mermaid
flowchart LR
    A[{nutritionRoot}/github/analysis_datasets\ncmrs2_series_accepted.parquet\ncmrs2_ant_accepted.parquet\ncmrs2_iycf_accepted.parquet] --> B[1a_import_inputs.r\nstandardize + stage projection inputs]
    C[DW inter regional outputs\nRegional_Output_*.xlsx + agg_ant_wasting.csv] --> B
    D[DW inter/groups_for_agg.csv] --> B
    E[DW input/base_population_1990_2030.csv] --> F[1b_population_lookup.r + indicator scripts]

    B --> G[2-7 indicator scripts\nAARR, targets, classifications, trajectories]
    F --> G
    G --> H[{nutritionRoot}/github/projections_progress_class/inter\n*_progress_2030.csv + modeled/projected files]
    H --> I[8_format_output.r\nappend + finalize]
    I --> J[{nutritionRoot}/github/projections_progress_class/final\nprogress_2030_appended.csv/.xlsx]
```

Analysis summary:
- Imports accepted country inputs from analysis_datasets and combines them with DW regional aggregates.
- Computes indicator-specific baseline/latest values, current AARR, required AARR, and 2030 classifications.
- Produces modeled, projected, and target trajectories plus final appended progress outputs.

Final outputs and storage:
- Root: `{nutritionRoot}/github/projections_progress_class`
- Key locations:
  - `input/` staged projection inputs
  - `inter/` indicator-level progress and modeled/projected outputs
  - `final/` canonical appended outputs:
    - `progress_2030_appended.csv`
    - `progress_2030_appended.xlsx`

Used by other execute scripts:
- Upstream dependency: consumes analysis_datasets outputs from `analysis_datasets/02_codes/1_execute_conductor.r`.
- Downstream dependency: no direct execute-script consumer of projections final outputs is currently documented in this repo.
