# Efficient Parquet Loading Skill

Last updated: 2026-04-14

## Purpose

Guide AI agents to load parquet files efficiently in R across all OSE-DA-NT
pipelines. The analysis_datasets parquets have 80-90+ columns and millions of
rows. Loading all columns into an R data.frame when only a handful are needed
causes severe memory pressure (17 GB+), heavy swap usage, and scripts that run
for 25+ minutes without completing.

---

## Trigger

Apply these rules whenever code needs to:
- Read a parquet file from `analysis_datasets/` or any large parquet output.
- Add, update, or overwrite columns in an existing parquet file.
- Filter or aggregate parquet data for a downstream pipeline.

---

## Core Principle

**Never call `arrow::read_parquet(path)` with no column selection on a large
parquet file.** Always identify the columns actually needed and select only
those.

---

## Pattern 1 — Read-Only: Select Columns + Predicate Pushdown

When reading parquet data for downstream use (no write-back to the same file):

```r
# 1. Define only the columns you need
keep_cols <- c("INDICATOR", "REF_AREA", "TIME_PERIOD", "VALUE", "SEX", "AGE")

# 2. Open as dataset (lazy — reads nothing yet)
ds <- arrow::open_dataset(parquet_path)

# 3. Filter at file level via predicate pushdown (arrow evaluates before R)
ds <- ds %>% dplyr::filter(INDICATOR %in% target_indicators)

# 4. Select only needed columns, then collect into R
df <- ds %>%
  dplyr::select(dplyr::any_of(keep_cols)) %>%
  dplyr::collect()
```

**Key points:**
- `open_dataset()` is lazy — it reads metadata only.
- `dplyr::filter()` on an Arrow dataset uses predicate pushdown: rows that
  don't match are never deserialized.
- `dplyr::select(any_of(...))` limits column reads at the file level.
- `collect()` materializes only the filtered/selected subset into R memory.

**Reference implementation:** `1a_import_inputs.r` in
`further_transformation_system/projections_progress_class/012_codes/`.

---

## Pattern 2 — Compute-and-Splice: Add Columns Without Full Materialization

When you need to compute new columns from a subset of existing columns and
write them back to the same parquet file:

```r
# 1. Read schema to discover available columns (metadata only)
schema    <- arrow::open_dataset(parquet_path)$schema
all_names <- schema$names

# 2. Select only the columns needed for computation
needed_cols <- c("REF_AREA", "TIME_PERIOD", "INDICATOR", "SEX", "AGE")
slim_cols   <- intersect(needed_cols, all_names)

# 3. Read slim subset into R
slim <- arrow::read_parquet(parquet_path,
                            col_select = dplyr::all_of(slim_cols))

# 4. Compute result vectors (keep them as plain R vectors)
result_vec <- some_computation(slim)
rm(slim); gc()

# 5. Read full file as Arrow Table (columnar, NOT an R data.frame)
tbl <- arrow::read_parquet(parquet_path, as_data_frame = FALSE)

# 6. Drop old column if present
drop <- intersect("NEW_COLUMN", tbl$schema$names)
if (length(drop) > 0) {
  keep_idx <- which(!tbl$schema$names %in% drop) - 1L
  tbl <- tbl$SelectColumns(keep_idx)
}

# 7. Append new column via Arrow Table API (no R data.frame expansion)
tbl <- tbl$AddColumn(
  tbl$num_columns,
  arrow::field("NEW_COLUMN", arrow::int32()),
  arrow::chunked_array(arrow::Array$create(result_vec, type = arrow::int32()))
)

# 8. Write back with compression
arrow::write_parquet(tbl, parquet_path, compression = "zstd")
```

**Why this works:**
- `as_data_frame = FALSE` reads the parquet as an Arrow Table, which stores
  data in columnar buffers without expanding into R's row-major memory layout.
  An 89-column, 4.2M-row parquet that requires 17 GB as an R data.frame uses
  only ~350 MB as an Arrow Table.
- `$AddColumn()` and `$SelectColumns()` are zero-copy metadata operations on
  the columnar structure — they don't duplicate data.
- The only R-memory cost is the slim subset (20 columns ≈ 6 GB) and the
  result vectors.

**Reference implementations:**
- `assign_priority_to_parquet()` in `analysis_datasets/02_codes/0_layer2_utils.r`
- `3_preferred_series.r` in `analysis_datasets/02_codes/`

---

## Pattern 3 — Schema Inspection

To discover column names without reading any data:

```r
# Correct — uses open_dataset (lazy metadata read)
schema <- arrow::open_dataset(parquet_path)$schema
col_names <- schema$names
col_types <- schema$fields  # list of arrow::field objects

# WRONG — arrow::read_schema() does NOT work on parquet files
# arrow::read_schema(parquet_path)  # Error: Cannot convert character to Buffer
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `read_parquet(path)` with no col_select | Reads all 89 columns → 17 GB | Add `col_select = all_of(needed)` |
| `read_parquet(path)` then `df[, cols]` | Full file already in memory | Move selection to read call |
| Read full df, add column, write back | Peak memory = 2× full file | Use Pattern 2 (Arrow Table splice) |
| `arrow::read_schema(path)` on parquet | Throws error | Use `open_dataset(path)$schema` |
| `as_data_frame = TRUE` just for `AddColumn` | Unnecessary R expansion | Keep as Arrow Table |

---

## Performance Benchmarks (ANT parquet, 89 cols, 4.2M rows)

| Approach | Peak Memory | Wall Time | Completed? |
|---|---|---|---|
| Full `read_parquet()` + add cols + write | 17 GB (heavy swap) | 25+ min | No (killed) |
| Slim read (20 cols) + Arrow Table splice | 6.3 GB compute, 10 GB peak | ~10.7 min | Yes |

---

## Checklist for New Parquet Code

1. [ ] Identify the exact columns needed for the operation.
2. [ ] Use `col_select` or `dplyr::select(any_of(...))` on every read.
3. [ ] If filtering rows, use `open_dataset()` + `dplyr::filter()` for pushdown.
4. [ ] If adding/updating columns in-place, use Arrow Table splice (Pattern 2).
5. [ ] Use `compression = "zstd"` when writing parquet.
6. [ ] Call `rm()` + `gc()` after freeing large intermediate objects.
7. [ ] Never use `arrow::read_schema()` on parquet files — use `open_dataset()$schema`.
