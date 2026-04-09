#-------------------------------------------------------------------
# Project: DW-Production
# Script: 8_format_output.r
# Purpose: Finalize appended NT progress output and write one canonical Excel file
#-------------------------------------------------------------------

resolve_nt_projection_dir <- function(dir_name) {
  if (!startsWith(dir_name, "outputdir_projections_")) {
    stop("Unsupported NT projection directory variable: ", dir_name)
  }

  if (exists(dir_name, inherits = TRUE)) {
    return(get(dir_name, inherits = TRUE))
  }

  username <- Sys.getenv("USERNAME")
  if (username == "" || is.na(username)) {
    username <- Sys.getenv("USER")
  }

  userprofile <- Sys.getenv("USERPROFILE")
  if (userprofile == "" || is.na(userprofile)) {
    userprofile <- "~"
  }

  config_path <- file.path(userprofile, ".config", "user_config.yml")
  if (!file.exists(config_path)) {
    stop(
      "user_config.yml not found at: ", config_path,
      ". Source the project profile first or create this config file."
    )
  }

  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package `yaml` is required to resolve NT projection output directories.")
  }

  config_yaml <- yaml::read_yaml(config_path)
  if (!username %in% names(config_yaml)) {
    stop("No entry for user `", username, "` was found in: ", config_path)
  }

  teams_root <- config_yaml[[username]]$teamsRoot
  output_root <- file.path(teams_root, "060.DW-MASTER", "01_dw_prep", "011_rawdata", "nt", "output_projections")
  dir_map <- c(
    outputdir_projections_input = "input",
    outputdir_projections_temp = file.path("temp", "split_progress"),
    outputdir_projections_inter = "inter",
    outputdir_projections_final = "final",
    outputdir_projections_exports = file.path("final", "estimates_projections_targets")
  )

  if (!dir_name %in% names(dir_map)) {
    stop("Unsupported NT projection directory variable: ", dir_name)
  }

  file.path(output_root, dir_map[[dir_name]])
}

outputdir_projections_inter <- resolve_nt_projection_dir("outputdir_projections_inter")
outputdir_projections_final <- resolve_nt_projection_dir("outputdir_projections_final")

progress_files <- c(
  "ow_progress_2030.csv",
  "ane_progress_2030.csv",
  "wst_progress_2030.csv",
  "st_progress_2030.csv",
  "lbw_progress_2030.csv",
  "exbf_progress_2030.csv"
)

progress_numeric_cols <- c(
  "baseline_year", "baseline_value", "latest_year", "latest_value",
  "latest_lower_bound", "latest_upper_bound", "projected_value_2030",
  "target_value_2030", "target_threshhold", "target_percent_change",
  "no_progress_aarr_lower_buffer", "no_progress_aarr_upper_buffer",
  "current_aarr", "required_aarr_2030"
)
progress_integer_cols <- c(
  "latest_data_source_priority", "crossthreshold", "assessment_not_possible_flag"
)

read_nt_progress_append_file <- function(path) {
  progress_df <- readr::read_csv(
    path,
    show_col_types = FALSE,
    col_types = readr::cols(.default = "c")
  )

  dplyr::mutate(
    progress_df,
    dplyr::across(dplyr::any_of(progress_integer_cols), ~ suppressWarnings(as.integer(.x))),
    dplyr::across(dplyr::any_of(progress_numeric_cols), ~ suppressWarnings(as.numeric(.x)))
  )
}

progress_paths <- file.path(outputdir_projections_inter, progress_files)
existing_progress_paths <- progress_paths[file.exists(progress_paths)]
if (length(existing_progress_paths) == 0) {
  stop("No inter progress files found in: ", outputdir_projections_inter)
}

progress <- dplyr::bind_rows(lapply(existing_progress_paths, read_nt_progress_append_file))

# Hardcoded business rules requested by nutrition team.
progress <- dplyr::mutate(
  progress,
  assessment_not_possible_flag = dplyr::if_else(
    INDICATOR == "NT_ANT_HAZ_NE2_MOD" & REF_AREA %in% c("NIC"),
    1L,
    assessment_not_possible_flag
  ),
  fullclassification_2030 = dplyr::if_else(
    INDICATOR == "NT_ANT_HAZ_NE2_MOD" & REF_AREA %in% c("NIC"),
    "Assessment not Possible",
    fullclassification_2030
  ),
  unicef_classification_2030 = dplyr::if_else(
    INDICATOR == "NT_ANT_HAZ_NE2_MOD" & REF_AREA %in% c("NIC"),
    "Assessment not Possible",
    unicef_classification_2030
  )
)

progress <- dplyr::mutate(
  progress,
  assessment_not_possible_flag = dplyr::if_else(
    INDICATOR == "NT_ANT_WHZ_PO2_MOD" & REF_AREA %in% c("NIC"),
    1L,
    assessment_not_possible_flag
  ),
  fullclassification_2030 = dplyr::if_else(
    INDICATOR == "NT_ANT_WHZ_PO2_MOD" & REF_AREA %in% c("NIC"),
    "Assessment not Possible",
    fullclassification_2030
  ),
  unicef_classification_2030 = dplyr::if_else(
    INDICATOR == "NT_ANT_WHZ_PO2_MOD" & REF_AREA %in% c("NIC"),
    "Assessment not Possible",
    unicef_classification_2030
  )
)



final_progress_csv <- file.path(outputdir_projections_final, "progress_2030_appended.csv")
final_progress_xlsx <- file.path(outputdir_projections_final, "progress_2030_appended.xlsx")

readr::write_csv(progress, final_progress_csv)

wb <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb, "Data")
openxlsx::writeData(wb, "Data", progress)
openxlsx::saveWorkbook(wb, final_progress_xlsx, overwrite = TRUE)

cat(
  "NT progress output finalized:\n",
  final_progress_xlsx,
  "\n"
)
