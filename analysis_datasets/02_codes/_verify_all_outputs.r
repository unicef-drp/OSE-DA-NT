suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(haven)
})

out_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_datasets"
source_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard"

dim_cols <- c("SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION")

file_specs <- list(
  list(output = "cmrs2_series.parquet", source = "CMRS_SERIES_*.dta"),
  list(output = "cmrs2_ant.parquet", source = "CMRS_ANT.dta"),
  list(output = "cmrs2_bw.parquet", source = "CMRS_BW.dta"),
  list(output = "cmrs2_iod.parquet", source = "CMRS_IOD.dta"),
  list(output = "cmrs2_iycf_bf.parquet", source = "CMRS_IYCF.dta"),
  list(output = "cmrs2_iycf_cf.parquet", source = "CMRS_IYCF.dta")
)

source_specs <- list(
  list(
    label = "series_all",
    sources = c("CMRS_SERIES_ANE.dta", "CMRS_SERIES_ANT.dta", "CMRS_SERIES_DANT.dta", "CMRS_SERIES_SANT.dta", "CMRS_SERIES_VAS.dta"),
    outputs = c("cmrs2_series.parquet")
  ),
  list(label = "ant", source = "CMRS_ANT.dta", outputs = c("cmrs2_ant.parquet")),
  list(label = "bw", source = "CMRS_BW.dta", outputs = c("cmrs2_bw.parquet")),
  list(label = "iod", source = "CMRS_IOD.dta", outputs = c("cmrs2_iod.parquet")),
  list(label = "iycf", source = "CMRS_IYCF.dta", outputs = c("cmrs2_iycf_bf.parquet", "cmrs2_iycf_cf.parquet"))
)

compare_specs <- list(
  list(label = "Indicator", candidates = c("IndicatorCode", "INDICATOR", "indicator")),
  list(label = "standard_disagg", candidates = c("standard_disagg", "StandardDisaggregations")),
  list(label = "REF_AREA/ISO3", candidates = c("ISO3Code", "CND_Country_Code", "REF_AREA")),
  list(label = "TIME_PERIOD/year", candidates = c("CMRS_year", "warehouse_year", "middle_year", "TIME_PERIOD"))
)

pick_first_existing <- function(nms, candidates) {
  hits <- candidates[candidates %in% nms]
  if (length(hits) == 0) return(NULL)
  hits[[1]]
}

read_output_subset <- function(path, select_cols = NULL, n_max = Inf) {
  tab <- if (is.null(select_cols)) {
    arrow::read_parquet(path, as_data_frame = FALSE)
  } else {
    arrow::read_parquet(path, as_data_frame = FALSE, col_select = any_of(select_cols))
  }

  df <- as_tibble(tab)

  if (is.finite(n_max)) {
    df <- head(df, n_max)
  }

  df %>% mutate(across(everything(), as.character))
}

normalize_values <- function(x) {
  x <- as.character(x)
  x[is.na(x) | trimws(x) == ""] <- "<MISSING>"
  x
}

count_table <- function(x) {
  tibble(value = normalize_values(x)) %>%
    count(value, name = "n")
}

compare_distribution <- function(src_df, out_df, src_col, out_col, label) {
  src_tbl <- count_table(src_df[[src_col]]) %>% rename(n_src = n)
  out_tbl <- count_table(out_df[[out_col]]) %>% rename(n_out = n)

  cmp <- full_join(src_tbl, out_tbl, by = "value") %>%
    mutate(
      n_src = coalesce(n_src, 0L),
      n_out = coalesce(n_out, 0L),
      diff = n_out - n_src
    ) %>%
    filter(diff != 0)

  pass <- nrow(cmp) == 0
  cat("  ", label, " distribution:", if (pass) "PASS" else "FAIL", "\n", sep = "")

  if (pass) {
    cat("    Levels checked:", nrow(src_tbl), "\n")
  } else {
    print(head(cmp, 10))
  }

  pass
}

compare_joint_distribution <- function(src_df, out_df, src_cols, out_cols, label) {
  src_tbl <- src_df %>%
    transmute(across(all_of(src_cols), ~ normalize_values(.x))) %>%
    count(across(everything()), name = "n_src")

  out_tbl <- out_df %>%
    transmute(across(all_of(out_cols), ~ normalize_values(.x)))
  names(out_tbl) <- src_cols
  out_tbl <- out_tbl %>% count(across(everything()), name = "n_out")

  cmp <- full_join(src_tbl, out_tbl, by = src_cols) %>%
    mutate(
      n_src = coalesce(n_src, 0L),
      n_out = coalesce(n_out, 0L),
      diff = n_out - n_src
    ) %>%
    filter(diff != 0)

  pass <- nrow(cmp) == 0
  cat("  ", label, " joint distribution:", if (pass) "PASS" else "FAIL", "\n", sep = "")

  if (pass) {
    cat("    Combinations checked:", nrow(src_tbl), "\n")
  } else {
    print(head(cmp, 10))
  }

  pass
}

all_pass <- TRUE

for (spec in file_specs) {
  f <- spec$output
  path <- file.path(out_dir, f)

  cat("\n========================================\n")
  cat("FILE:", f, "\n")

  if (!file.exists(path)) {
    cat("  *** FILE NOT FOUND ***\n")
    all_pass <- FALSE
    next
  }

  schema <- names(read_output_subset(path, n_max = 0))
  df <- read_output_subset(path, select_cols = unique(c(dim_cols, "indicator", "INDICATOR", "IndicatorCode")))

  cat("  Rows:", nrow(df), " Cols:", length(schema), "\n")

  present <- intersect(dim_cols, names(df))
  missing_cols <- setdiff(dim_cols, names(df))
  if (length(missing_cols) > 0) {
    cat("  Dim cols NOT present:", paste(missing_cols, collapse = ", "), "\n")
    all_pass <- FALSE
  }

  cat("  --- NA counts ---\n")
  for (d in present) {
    na_count <- sum(is.na(df[[d]]) | df[[d]] == "")
    cat("    ", d, ":", na_count, "missing/blank values\n")
    if (na_count > 0) all_pass <- FALSE
  }

  cat("  --- Value distributions ---\n")
  for (d in present) {
    tbl <- sort(table(df[[d]], useNA = "ifany"), decreasing = TRUE)
    vals <- paste0(names(tbl), "=", as.integer(tbl))
    cat("    ", d, ":", paste(head(vals, 10), collapse = ", "), "\n")
  }

  ind_col <- pick_first_existing(names(df), c("indicator", "INDICATOR", "IndicatorCode"))
  if (!is.null(ind_col)) {
    ind_vals <- sort(unique(df[[ind_col]]))
    cat("  Indicators (", length(ind_vals), ") from ", ind_col, ": ",
        paste(head(ind_vals, 15), collapse = ", "), "\n", sep = "")
  }

  rm(df)
  invisible(gc())
}

for (spec in source_specs) {
  src_files <- if (!is.null(spec$sources)) spec$sources else c(spec$source)
  src_paths <- file.path(source_dir, src_files)
  out_paths <- file.path(out_dir, spec$outputs)

  cat("\n========================================\n")
  cat("SOURCE CHECK:", paste(src_files, collapse = " + "), " -> ", paste(spec$outputs, collapse = " + "), "\n")

  if (any(!file.exists(src_paths))) {
    missing_sources <- src_files[!file.exists(src_paths)]
    cat("  *** SOURCE FILE NOT FOUND ***\n")
    cat("  Missing source(s):", paste(missing_sources, collapse = ", "), "\n")
    all_pass <- FALSE
    next
  }

  missing_outputs <- spec$outputs[!file.exists(out_paths)]
  if (length(missing_outputs) > 0) {
    cat("  *** OUTPUT FILE(S) NOT FOUND: ", paste(missing_outputs, collapse = ", "), " ***\n", sep = "")
    all_pass <- FALSE
    next
  }

  src_schema <- names(read_dta(src_paths[1], n_max = 0))
  out_schema <- unique(unlist(lapply(out_paths, function(p) names(read_output_subset(p, n_max = 0)))))

  missing_from_output <- setdiff(src_schema, out_schema)
  schema_pass <- length(missing_from_output) == 0
  cat("  Original source columns preserved:", if (schema_pass) "PASS" else "FAIL", "\n")
  if (schema_pass) {
    cat("    Columns preserved:", length(src_schema), "of", length(src_schema), "\n")
  } else {
    cat("    Missing columns:", paste(head(missing_from_output, 15), collapse = ", "), "\n")
    all_pass <- FALSE
  }

  select_candidates <- unique(unlist(lapply(compare_specs, function(x) x$candidates)))
  src_select <- intersect(src_schema, select_candidates)
  out_select <- intersect(out_schema, select_candidates)

  if (length(src_select) == 0) src_select <- src_schema[1]
  if (length(out_select) == 0) out_select <- out_schema[1]

  src_df <- bind_rows(lapply(src_paths, function(p) {
    read_dta(p, col_select = any_of(src_select)) %>% mutate(across(everything(), as.character))
  }))
  out_df <- bind_rows(lapply(out_paths, function(p) read_output_subset(p, select_cols = out_select)))

  row_pass <- nrow(src_df) == nrow(out_df)
  cat("  Row count:", if (row_pass) "PASS" else "FAIL",
      "(source=", nrow(src_df), ", output=", nrow(out_df), ")\n", sep = "")
  if (!row_pass) all_pass <- FALSE

  for (cmp in compare_specs) {
    src_col <- pick_first_existing(names(src_df), cmp$candidates)
    out_col <- pick_first_existing(names(out_df), cmp$candidates)

    if (!is.null(src_col) && !is.null(out_col)) {
      pass <- compare_distribution(src_df, out_df, src_col, out_col, cmp$label)
      if (!pass) all_pass <- FALSE
    }
  }

  ind_src <- pick_first_existing(names(src_df), c("IndicatorCode", "INDICATOR", "indicator"))
  ind_out <- pick_first_existing(names(out_df), c("IndicatorCode", "INDICATOR", "indicator"))
  disagg_src <- pick_first_existing(names(src_df), c("standard_disagg", "StandardDisaggregations"))
  disagg_out <- pick_first_existing(names(out_df), c("standard_disagg", "StandardDisaggregations"))

  if (!is.null(ind_src) && !is.null(ind_out) && !is.null(disagg_src) && !is.null(disagg_out)) {
    pass <- compare_joint_distribution(
      src_df, out_df,
      src_cols = c(ind_src, disagg_src),
      out_cols = c(ind_out, disagg_out),
      label = "Indicator x standard_disagg"
    )
    if (!pass) all_pass <- FALSE
  }

  rm(src_df, out_df)
  invisible(gc())
}

cat("\n\n========================================\n")
cat(if (all_pass) "VERIFICATION COMPLETE: PASS\n" else "VERIFICATION COMPLETE: FAIL\n")
cat("========================================\n")
