# Stunting Top20 Briefing Execute Folder

This README documents the execute pipeline in this folder.

Entrypoint:
- 1_execute_conductor.r

## Visual Schema

```mermaid
flowchart LR
    A[{analysisDatasetsOutputDir}\ncmrs2_series_accepted.parquet] --> B[2_prepare_inputs.r\nfilter stunting modeled + numbers]
    B --> C[{githubOutputRoot}/adhoc_analysis/stunting_top20_briefing/01_inputs\nstunting_modeled.parquet\nstunting_numbers.parquet]

    C --> D[3_stunting_rankings.r\nrankings, overlap, concentration, figures, tables]
    D --> E[{githubOutputRoot}/adhoc_analysis/stunting_top20_briefing/03_outputs\nRDS/CSV/XLSX/MD + figure PNGs]

    E --> F[4_create_two_pager.r\nrender Word brief]
    F --> G[{githubOutputRoot}/adhoc_analysis/stunting_top20_briefing/03_outputs\nstunting_top20_two_pager_v7.docx]
```

Analysis summary:
- Extracts national-total stunting modeled series from accepted CMRS parquet.
- Produces top-20 prevalence and burden rankings and 10-year/20-year improver analyses.
- Generates concentration/overlap metrics, tables, charts, and briefing-ready narrative artifacts.

Final outputs and storage:
- Output root: `{githubOutputRoot}/adhoc_analysis/stunting_top20_briefing/03_outputs`
- Core deliverables include:
  - `stunting_rankings.rds`
  - `stunting_rankings.csv`
  - `stunting_tables_and_figures*.xlsx`
  - `stunting_tables_and_figures*.md`
  - `figures/*.png`
  - `stunting_top20_two_pager_v7.docx`

Used by other execute scripts:
- Upstream dependency: consumes analysis_datasets output from `analysis_datasets/02_codes/1_execute_conductor.r`.
- Downstream dependency: no direct execute-script consumer of this folder's outputs is currently documented in this repo.
