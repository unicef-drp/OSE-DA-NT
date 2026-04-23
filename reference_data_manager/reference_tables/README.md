# reference_tables/ — DATA ENTRY

Every file in this folder is **editable by hand**. Each CSV maps 1-to-1 to a
legacy SharePoint `DIRECTORY_*` or `REFERENCE_*.xlsx` file and is re-exported
by `02_codes/3_export_legacy_xlsx.r` (xlsx) and `02_codes/3b_export_legacy_dta.r`
(Stata `.dta`).

The legacy `indicators/` subfolder has been consolidated here:
`directory_indicator.csv` and `reference_disaggregations.csv` now live
directly in `reference_tables/`.

Do **not** put any computed/derived output in this folder. Derived outputs go
to `{githubOutputRoot}/reference_data_manager/` and are rebuilt each run.

After editing any CSV here, rerun the conductor:

```r
source("reference_data_manager/02_codes/1_execute_conductor.r")
```
