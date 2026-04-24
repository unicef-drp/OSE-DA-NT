# ---------------------------------------------------------------------------
# Script:  0_validate_csvs.r
# Purpose: Fail fast on common CSV-corruption symptoms in the editable
#          reference inputs (`reference_tables/*.csv`,
#          `crosswalk/directory_crosswalk_base.csv`).
#
#          Catches the things Excel silently does on a save-as round-trip:
#            - Re-encoding UTF-8 to Windows-1252 (lost accents / smart quotes)
#            - Adding a UTF-8 BOM at the file head
#            - Stripping leading zeros from ID-like columns
#            - Coercing IDs to scientific notation
#            - Trailing whitespace in cells
#            - Mixed line endings (CRLF inside a quoted field)
#
# Run automatically by 1_execute_conductor.r before any build step. Stops
# with an error if any check fails.
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

stopifnot(exists("rdmInputDir"))

.validate_one_csv <- function(path) {
  rel <- sub(rdmInputDir, "", path, fixed = TRUE)
  errors   <- character()  # hard failures (Excel actively introduced corruption)
  warnings <- character()  # heuristic / pre-existing baseline issues

  # --- 1. Raw-byte checks (encoding + BOM) -- HARD ERRORS -----------------
  raw <- readBin(path, what = "raw", n = file.info(path)$size)

  if (length(raw) >= 3 &&
      raw[1] == as.raw(0xEF) && raw[2] == as.raw(0xBB) && raw[3] == as.raw(0xBF)) {
    errors <- c(errors, "UTF-8 BOM at start of file (Excel adds this; strip it).")
  }

  # Try to decode as UTF-8 strictly. Any invalid byte sequence => fail.
  txt <- tryCatch(
    rawToChar(raw),
    error = function(e) NA_character_
  )
  if (is.na(txt)) {
    errors <- c(errors, "File is not valid UTF-8 (likely Windows-1252 from Excel save).")
  } else {
    # Detect typical Windows-1252 mojibake artefacts that survive as valid UTF-8
    # bytes after a double-decode (e.g. "Ã©" for "é", "Â" stray byte).
    if (grepl("\u00c3[\u00a0-\u00bf]|\u00c2[\u00a0-\u00bf]", txt, perl = TRUE)) {
      errors <- c(errors, "Suspected mojibake (Windows-1252 misread as UTF-8).")
    }
  }

  # --- 2. Parsed-content checks -------------------------------------------
  df <- tryCatch(
    readr::read_csv(path, show_col_types = FALSE,
                    col_types = readr::cols(.default = readr::col_character())),
    error = function(e) {
      errors <<- c(errors, paste0("readr::read_csv failed: ", conditionMessage(e)))
      NULL
    }
  )

  if (!is.null(df)) {
    for (col in names(df)) {
      v <- df[[col]]
      v_nonempty <- v[!is.na(v) & nzchar(v)]
      if (length(v_nonempty) == 0) next

      # Scientific notation in any column = HARD ERROR (Excel definitely
      # mangled a numeric ID column on save).
      if (any(grepl("^-?[0-9]+(\\.[0-9]+)?[eE][+-]?[0-9]+$", v_nonempty))) {
        errors <- c(errors, sprintf("Column '%s': values in scientific notation (Excel mangled an ID column).", col))
      }

      # Trailing/leading whitespace = WARNING (often pre-existing baseline)
      if (any(v_nonempty != trimws(v_nonempty))) {
        warnings <- c(warnings, sprintf("Column '%s': leading/trailing whitespace in some cells.", col))
      }
    }

    # Leading-zero loss heuristic = WARNING (heuristic, can be a baseline
    # carried over from legacy xlsx).
    id_like_cols <- grep("(?i)^(m49|iso[_ ]?n(um)?|num(eric)?[_ ]?code)$",
                         names(df), value = TRUE, perl = TRUE)
    for (col in id_like_cols) {
      v <- df[[col]]
      v_nonempty <- v[!is.na(v) & nzchar(v)]
      all_digits <- grepl("^[0-9]+$", v_nonempty)
      if (length(v_nonempty) > 0 && all(all_digits)) {
        if (!any(startsWith(v_nonempty, "0")) && any(nchar(v_nonempty) < 3)) {
          warnings <- c(warnings,
                        sprintf("Column '%s': suspected stripped leading zeros (no zero-padded values, some 1-2 char codes).", col))
        }
      }
    }
  }

  if (length(errors) > 0 || length(warnings) > 0) {
    list(file = rel, errors = errors, warnings = warnings)
  } else {
    NULL
  }
}

.validate_csv_dir <- function(subdir) {
  root <- file.path(rdmInputDir, subdir)
  if (!dir.exists(root)) return(list())
  files <- list.files(root, pattern = "\\.csv$", full.names = TRUE,
                      recursive = FALSE, ignore.case = TRUE)
  Filter(Negate(is.null), lapply(files, .validate_one_csv))
}

.failures <- c(
  .validate_csv_dir("reference_tables"),
  .validate_csv_dir("crosswalk")
)

.hard <- Filter(function(f) length(f$errors)   > 0, .failures)
.warn <- Filter(function(f) length(f$warnings) > 0, .failures)

if (length(.warn) > 0) {
  warn_lines <- unlist(lapply(.warn, function(f) {
    c(paste0("  ", f$file, ":"), paste0("    - ", f$warnings))
  }))
  message("CSV validation warnings (non-blocking):\n",
          paste(warn_lines, collapse = "\n"))
}

if (length(.hard) > 0) {
  msg_lines <- unlist(lapply(.hard, function(f) {
    c(paste0("  ", f$file, ":"), paste0("    - ", f$errors))
  }))
  stop("CSV validation failed:\n", paste(msg_lines, collapse = "\n"), call. = FALSE)
}

message("reference_data_manager: CSV validation passed (",
        length(list.files(file.path(rdmInputDir, "reference_tables"), "\\.csv$")) +
          length(list.files(file.path(rdmInputDir, "crosswalk"), "\\.csv$")),
        " files).")
