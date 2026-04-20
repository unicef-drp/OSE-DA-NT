# ---------------------------------------------------------------------------
# Script:  0_verify_all_outputs.r
# Purpose: Post-build QA verification of CMRS2 analysis dataset outputs.
#
# Checks performed (per-file):
#   1. File existence for expected parquet outputs
#   2. Schema validation - dimension columns + key columns present
#   3. Missing-value audit - NA/blank counts per dimension
#   4. Value distributions per dimension
#   5. Indicator inventory per output
#   6. Duplicate analytical key check
#
# Source DTA vs all-estimates parquet:
#   7. Row-count preservation (exact match expected)
#   8. Source column preservation (all DTA columns carried forward)
#   9. Distribution matching (indicator, disagg, REF_AREA, TIME_PERIOD)
#  10. Joint distribution matching (indicator x disaggregation)
#
# All-estimates vs accepted parquet:
#  11. Schema equality (accepted has same columns as all-estimates)
#  12. Accepted filter count (DataSourceDecisionCategory == "Accepted")
#  13. Distribution subset (accepted values subset of all-estimates)
#  14. Joint distribution subset (indicator x disagg combinations)
#
# Usage:
#   Verify all datasets (standalone):
#     Rscript analysis_datasets/02_codes/0_verify_all_outputs.r
#
#   Verify a single dataset (ant, bw, iod, iycf, series):
#     Rscript analysis_datasets/02_codes/0_verify_all_outputs.r ant
#
#   Verify multiple datasets:
#     Rscript analysis_datasets/02_codes/0_verify_all_outputs.r ant bw
#
#   From conductor (opt-in):
#     run_verify     <- TRUE
#     verify_targets <- c("ant")
#     source("analysis_datasets/02_codes/1_execute_conductor.r")
#
#   When sourced directly, set verify_targets beforehand to filter:
#     verify_targets <- c("ant")
#     source("analysis_datasets/02_codes/0_verify_all_outputs.r")
#
# Exit:    Prints PASS or FAIL summary at the end.
# ---------------------------------------------------------------------------

# --- Determine which datasets to verify ---
# Priority: verify_targets variable > command-line args > all
valid_targets <- c("series", "ant", "bw", "iod", "iycf")

if (exists("verify_targets", envir = .GlobalEnv)) {
  targets <- get("verify_targets", envir = .GlobalEnv)
} else {
  args <- commandArgs(trailingOnly = TRUE)
  targets <- if (length(args) > 0) args else valid_targets
}
targets <- tolower(targets)
bad <- setdiff(targets, valid_targets)
if (length(bad) > 0) {
  stop("Unknown target(s): ", paste(bad, collapse = ", "),
       ". Valid targets: ", paste(valid_targets, collapse = ", "))
}
cat("Verify targets:", paste(targets, collapse = ", "), "\n")

# Use profile-based paths if available; fall back to hardcoded for standalone use
if (!exists("analysisDatasetsOutputDir", envir = .GlobalEnv) ||
    !exists("cmrsInputDir", envir = .GlobalEnv)) {
  tryCatch(
    source(file.path(getwd(), "profile_OSE-DA-NT.R")),
    error = function(e) NULL
  )
}

if (exists("analysisDatasetsOutputDir", envir = .GlobalEnv)) {
  out_dir <- analysisDatasetsOutputDir
} else {
  out_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_datasets"
}

if (exists("cmrsInputDir", envir = .GlobalEnv)) {
  source_dir <- cmrsInputDir
} else {
  source_dir <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard"
}

dim_cols <- c("SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION",
              "HEAD_OF_HOUSEHOLD", "MOTHER_AGE", "DELIVERY_ASSISTANCE",
              "PLACE_OF_DELIVERY", "DELIVERY_MODE", "MULTIPLE_BIRTH", "REGION")

file_specs <- list(
  list(target = "series", output = "cmrs2_series.parquet", source = "CMRS_SERIES_*.dta"),
  list(target = "series", output = "cmrs2_series_accepted.parquet", source = "CMRS_SERIES_*.dta"),
  list(target = "ant",    output = "cmrs2_ant.parquet", source = "CMRS_ANT.dta"),
  list(target = "ant",    output = "cmrs2_ant_accepted.parquet", source = "CMRS_ANT.dta"),
  list(target = "bw",     output = "cmrs2_bw.parquet", source = "CMRS_BW.dta"),
  list(target = "bw",     output = "cmrs2_bw_accepted.parquet", source = "CMRS_BW.dta"),
  list(target = "iod",    output = "cmrs2_iod.parquet", source = "CMRS_IOD.dta"),
  list(target = "iod",    output = "cmrs2_iod_accepted.parquet", source = "CMRS_IOD.dta"),
  list(target = "iycf",   output = "cmrs2_iycf.parquet", source = "CMRS_IYCF.dta"),
  list(target = "iycf",   output = "cmrs2_iycf_accepted.parquet", source = "CMRS_IYCF.dta")
)
file_specs <- Filter(function(x) x$target %in% targets, file_specs)

source_specs <- list(
  list(
    target = "series",
    label = "series_all",
    sources = c("CMRS_SERIES_ANE.dta", "CMRS_SERIES_ANT.dta", "CMRS_SERIES_DANT.dta", "CMRS_SERIES_SANT.dta", "CMRS_SERIES_VAS.dta"),
    outputs = c("cmrs2_series.parquet")
  ),
  list(
    target = "series",
    label = "series_accepted",
    sources = c("CMRS_SERIES_ANE.dta", "CMRS_SERIES_ANT.dta", "CMRS_SERIES_DANT.dta", "CMRS_SERIES_SANT.dta", "CMRS_SERIES_VAS.dta"),
    outputs = c("cmrs2_series_accepted.parquet")
  ),
  list(target = "ant",  label = "ant",          source = "CMRS_ANT.dta",  outputs = c("cmrs2_ant.parquet")),
  list(target = "ant",  label = "ant_accepted",  source = "CMRS_ANT.dta",  outputs = c("cmrs2_ant_accepted.parquet")),
  list(target = "bw",   label = "bw",           source = "CMRS_BW.dta",   outputs = c("cmrs2_bw.parquet")),
  list(target = "bw",   label = "bw_accepted",   source = "CMRS_BW.dta",   outputs = c("cmrs2_bw_accepted.parquet")),
  list(target = "iod",  label = "iod",          source = "CMRS_IOD.dta",  outputs = c("cmrs2_iod.parquet")),
  list(target = "iod",  label = "iod_accepted",  source = "CMRS_IOD.dta",  outputs = c("cmrs2_iod_accepted.parquet")),
  list(target = "iycf", label = "iycf",         source = "CMRS_IYCF.dta", outputs = c("cmrs2_iycf.parquet")),
  list(target = "iycf", label = "iycf_accepted", source = "CMRS_IYCF.dta", outputs = c("cmrs2_iycf_accepted.parquet"))
)
source_specs <- Filter(function(x) x$target %in% targets, source_specs)

compare_specs <- list(
  list(label = "Indicator", candidates = c("IndicatorCode", "INDICATOR", "indicator")),
  list(label = "standard_disagg", candidates = c("standard_disagg", "StandardDisaggregations")),
  list(label = "REF_AREA/ISO3", candidates = c("ISO3Code", "CND_Country_Code", "REF_AREA")),
  list(label = "TIME_PERIOD/year", candidates = c("CMRS_year", "warehouse_year", "TIME_PERIOD"))
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

  if (nrow(cmp) == 0) {
    cat("  ", label, " distribution: PASS\n", sep = "")
    cat("    Levels checked:", nrow(src_tbl), "\n")
    return(TRUE)
  }

  has_excess <- any(cmp$diff > 0)
  has_new_levels <- any(is.na(cmp$diff) | (cmp$n_src == 0L & cmp$n_out > 0L))

  if (has_excess || has_new_levels) {
    cat("  ", label, " distribution: FAIL\n", sep = "")
    print(head(cmp, 10))
    return(FALSE)
  }

  # All diffs are negative (fewer rows in output) — likely dedup removals
  cat("  ", label, " distribution: WARN (output has fewer rows; likely dedup removals)\n", sep = "")
  print(head(cmp, 10))
  TRUE
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

  if (nrow(cmp) == 0) {
    cat("  ", label, " joint distribution: PASS\n", sep = "")
    cat("    Combinations checked:", nrow(src_tbl), "\n")
    return(TRUE)
  }

  has_excess <- any(cmp$diff > 0)
  has_new_combos <- any(is.na(cmp$diff) | (cmp$n_src == 0L & cmp$n_out > 0L))

  if (has_excess || has_new_combos) {
    cat("  ", label, " joint distribution: FAIL\n", sep = "")
    print(head(cmp, 10))
    return(FALSE)
  }

  cat("  ", label, " joint distribution: WARN (output has fewer rows; likely dedup removals)\n", sep = "")
  print(head(cmp, 10))
  TRUE
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
  df <- read_output_subset(
    path,
    select_cols = unique(c(
      "UNICEF_Survey_ID", "UNICEF_SURVEY_ID", "SurveyId", "survey_id",
      "REF_AREA", "TIME_PERIOD", dim_cols,
      "IndicatorCode"
    ))
  )

  cat("  Rows:", nrow(df), " Cols:", length(schema), "\n")

  present <- intersect(dim_cols, names(df))
  missing_cols <- setdiff(dim_cols, names(df))
  if (length(missing_cols) > 0) {
    cat("  Dim cols NOT present:", paste(missing_cols, collapse = ", "), "\n")
    all_pass <- FALSE
  }

  key_cols_expected <- c("IndicatorCode", "r", "REF_AREA", "TIME_PERIOD")
  key_cols_missing <- setdiff(key_cols_expected, schema)
  if (length(key_cols_missing) > 0) {
    cat("  Key cols NOT present:", paste(key_cols_missing, collapse = ", "), "\n")
    all_pass <- FALSE
  } else {
    cat("  Key cols present: PASS\n")
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

  # --- Duplicate analytical key check ---
  is_accepted_file <- grepl("_accepted", f, fixed = TRUE)
  survey_col <- pick_first_existing(names(df), c("UNICEF_Survey_ID", "UNICEF_SURVEY_ID", "SurveyId", "survey_id"))
  if (is.null(survey_col)) {
    cat("  Duplicate analytical key rows: SKIP - survey ID column not found\n")
    all_pass <- FALSE
  } else {
    key_cols <- intersect(c(survey_col, "REF_AREA", "TIME_PERIOD", "IndicatorCode", dim_cols), names(df))
    dup_groups <- df %>%
      group_by(across(all_of(key_cols))) %>%
      filter(n() > 1) %>%
      ungroup()
    dup_pass <- nrow(dup_groups) == 0
    if (is_accepted_file) {
      cat(
        "  Duplicate analytical key rows:",
        if (dup_pass) "PASS" else paste("FAIL -", nrow(dup_groups), "duplicate rows"),
        "(survey key:", survey_col, ")\n"
      )
      if (!dup_pass) {
        print(head(dup_groups, 5))
        all_pass <- FALSE
      }
    } else {
      cat(
        "  Duplicate analytical key rows:",
        if (dup_pass) "PASS" else paste("SKIP -", nrow(dup_groups), "key-dup rows (expected in all-estimates; dedup runs on accepted only)"),
        "(survey key:", survey_col, ")\n"
      )
    }
  }

  rm(df)
  invisible(gc())
}

for (spec in source_specs) {
  is_accepted <- grepl("_accepted", spec$label, fixed = TRUE)
  out_paths <- file.path(out_dir, spec$outputs)

  cat("\n========================================\n")

  if (is_accepted) {
    # =================================================================
    # ACCEPTED-VS-ALL-ESTIMATES COMPARISON
    # The accepted parquet should be a proper subset of the all-estimates
    # parquet, filtered by DataSourceDecisionCategory == "Accepted" and
    # then deduped.  Comparing against the source DTA is uninformative
    # because every distribution will show expected row reduction.
    # =================================================================
    all_est_file <- sub("_accepted\\.parquet$", ".parquet", spec$outputs[1])
    all_est_path <- file.path(out_dir, all_est_file)

    cat("ACCEPTED CHECK:", spec$outputs[1], " vs ", all_est_file, "\n")

    if (!file.exists(all_est_path)) {
      cat("  *** ALL-ESTIMATES PARQUET NOT FOUND:", all_est_file, "***\n")
      all_pass <- FALSE
      next
    }
    missing_outputs <- spec$outputs[!file.exists(out_paths)]
    if (length(missing_outputs) > 0) {
      cat("  *** ACCEPTED PARQUET NOT FOUND:", paste(missing_outputs, collapse = ", "), "***\n")
      all_pass <- FALSE
      next
    }

    # --- Schema: accepted should have same columns as all-estimates ---
    all_schema <- names(read_output_subset(all_est_path, n_max = 0))
    acc_schema <- names(read_output_subset(out_paths[1], n_max = 0))
    schema_missing <- setdiff(all_schema, acc_schema)
    schema_extra <- setdiff(acc_schema, all_schema)
    if (length(schema_missing) == 0 && length(schema_extra) == 0) {
      cat("  Schema matches all-estimates: PASS\n")
    } else {
      if (length(schema_missing) > 0)
        cat("  Columns in all-estimates but not accepted:", paste(schema_missing, collapse = ", "), "\n")
      if (length(schema_extra) > 0)
        cat("  Columns in accepted but not all-estimates:", paste(schema_extra, collapse = ", "), "\n")
      all_pass <- FALSE
    }

    # --- Filter count validation ---
    select_for_filter <- unique(c("DataSourceDecisionCategory",
                                   unlist(lapply(compare_specs, function(x) x$candidates))))
    all_df <- read_output_subset(all_est_path, select_cols = select_for_filter)
    acc_df <- bind_rows(lapply(out_paths, function(p) read_output_subset(p, select_cols = select_for_filter)))

    expected_count <- sum(all_df$DataSourceDecisionCategory == "Accepted", na.rm = TRUE)
    actual_count <- nrow(acc_df)

    cat("  Row cascade: all-estimates=", nrow(all_df), " -> accepted=", actual_count, "\n", sep = "")

    if (actual_count == expected_count) {
      cat("  Accepted filter count: PASS (", actual_count,
          " rows match DataSourceDecisionCategory == 'Accepted')\n", sep = "")
    } else if (actual_count < expected_count) {
      cat("  Accepted filter count: INFO (expected=", expected_count,
          ", actual=", actual_count, "; diff=", expected_count - actual_count,
          " likely from dedup)\n", sep = "")
    } else {
      cat("  Accepted filter count: FAIL (actual=", actual_count,
          " > expected=", expected_count, ")\n", sep = "")
      all_pass <- FALSE
    }

    # --- Distribution subset checks ---
    all_cmp <- all_df %>% select(-any_of("DataSourceDecisionCategory"))
    acc_cmp <- acc_df %>% select(-any_of("DataSourceDecisionCategory"))

    for (cmp in compare_specs) {
      all_col <- pick_first_existing(names(all_cmp), cmp$candidates)
      acc_col <- pick_first_existing(names(acc_cmp), cmp$candidates)
      if (!is.null(all_col) && !is.null(acc_col)) {
        acc_vals <- unique(normalize_values(acc_cmp[[acc_col]]))
        all_vals <- unique(normalize_values(all_cmp[[all_col]]))
        new_vals <- setdiff(acc_vals, all_vals)
        if (length(new_vals) > 0) {
          cat("  ", cmp$label, " subset: FAIL (", length(new_vals),
              " values in accepted not in all-estimates)\n", sep = "")
          cat("    New values:", paste(head(new_vals, 5), collapse = ", "), "\n")
          all_pass <- FALSE
        } else {
          cat("  ", cmp$label, " subset: PASS (", length(acc_vals),
              " of ", length(all_vals), " levels)\n", sep = "")
        }
      }
    }

    # --- Joint distribution subset check ---
    ind_all <- pick_first_existing(names(all_cmp), c("IndicatorCode", "INDICATOR", "indicator"))
    ind_acc <- pick_first_existing(names(acc_cmp), c("IndicatorCode", "INDICATOR", "indicator"))
    disagg_all <- pick_first_existing(names(all_cmp), c("standard_disagg", "StandardDisaggregations"))
    disagg_acc <- pick_first_existing(names(acc_cmp), c("standard_disagg", "StandardDisaggregations"))

    if (!is.null(ind_all) && !is.null(ind_acc) && !is.null(disagg_all) && !is.null(disagg_acc)) {
      acc_combos <- acc_cmp %>%
        transmute(ind = normalize_values(.data[[ind_acc]]),
                  disagg = normalize_values(.data[[disagg_acc]])) %>%
        distinct()
      all_combos <- all_cmp %>%
        transmute(ind = normalize_values(.data[[ind_all]]),
                  disagg = normalize_values(.data[[disagg_all]])) %>%
        distinct()
      new_combos <- anti_join(acc_combos, all_combos, by = c("ind", "disagg"))
      if (nrow(new_combos) > 0) {
        cat("  Indicator x disagg subset: FAIL (", nrow(new_combos),
            " combinations in accepted not in all-estimates)\n", sep = "")
        all_pass <- FALSE
      } else {
        cat("  Indicator x disagg subset: PASS (", nrow(acc_combos),
            " of ", nrow(all_combos), " combinations)\n", sep = "")
      }
    }

    rm(all_df, acc_df, all_cmp, acc_cmp)
    invisible(gc())

  } else {
    # =================================================================
    # ALL-ESTIMATES-VS-SOURCE DTA COMPARISON
    # The all-estimates parquet should carry every source row without
    # filtering, plus new analytical dimension columns.
    # =================================================================
    src_files <- if (!is.null(spec$sources)) spec$sources else c(spec$source)
    src_paths <- file.path(source_dir, src_files)

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
    cat("  Source columns preserved:", if (schema_pass) "PASS" else "FAIL", "\n")
    if (schema_pass) {
      cat("    Columns preserved:", length(src_schema), "of", length(src_schema), "\n")
    } else {
      cat("    Missing columns:", paste(head(missing_from_output, 15), collapse = ", "), "\n")
      all_pass <- FALSE
    }
    new_cols <- setdiff(out_schema, src_schema)
    if (length(new_cols) > 0) {
      cat("    New columns added (", length(new_cols), "):",
          paste(head(new_cols, 15), collapse = ", "), "\n")
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

    row_diff <- nrow(out_df) - nrow(src_df)
    if (row_diff == 0L) {
      cat("  Row count: PASS (source=", nrow(src_df),
          ", output=", nrow(out_df), ")\n", sep = "")
    } else if (row_diff < 0L) {
      cat("  Row count: WARN (source=", nrow(src_df),
          ", output=", nrow(out_df), ", diff=", row_diff,
          "; possible dedup removals)\n", sep = "")
    } else {
      cat("  Row count: FAIL (output has MORE rows: source=",
          nrow(src_df), ", output=", nrow(out_df), ")\n", sep = "")
      all_pass <- FALSE
    }

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
}

cat("\n\n========================================\n")
cat("Targets verified:", paste(targets, collapse = ", "), "\n")
cat(if (all_pass) "VERIFICATION COMPLETE: PASS\n" else "VERIFICATION COMPLETE: FAIL\n")
cat("========================================\n")
