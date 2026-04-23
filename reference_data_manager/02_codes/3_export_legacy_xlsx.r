# ---------------------------------------------------------------------------
# Script:  3_export_legacy_xlsx.r
# Purpose: Re-create the SharePoint Export folder layout from the repo CSVs.
#          Each editable CSV in the repo is written as an xlsx file with the
#          same name (and worksheet name) as the legacy SharePoint Export file
#          so downstream consumers (e.g. Stata code, Power BI) keep working.
#
#          The wide computed crosswalk (output of 2_build_directory_crosswalk.r)
#          is also written as both directory_crosswalk.xlsx and the legacy
#          "DIRECTORY_CROSSWALK (Beta).xlsx" — the latter is the editable base
#          (re-exported as-is so the SharePoint folder remains a complete copy).
#
# Outputs are written ONLY to the repo output mirror:
#   {githubOutputRoot}/reference_data_manager/DIRECTORY_COUNTRY.xlsx
#   {githubOutputRoot}/reference_data_manager/DIRECTORY_REGION.xlsx
#   {githubOutputRoot}/reference_data_manager/DIRECTORY_INDICATOR.xlsx
#   {githubOutputRoot}/reference_data_manager/DIRECTORY_CROSSWALK (Beta).xlsx
#   {githubOutputRoot}/reference_data_manager/REFERENCE_*.xlsx
#   {githubOutputRoot}/reference_data_manager/directory_crosswalk.xlsx (computed wide)
#
# This script never writes to the legacy SharePoint Export folder. To update
# SharePoint, copy files manually from the repo output mirror after review.
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

stopifnot(exists("rdmInputDir"), exists("rdmOutputDir"))

# Mapping: repo csv (relative to rdmInputDir) -> legacy xlsx name + sheet name
exports <- tibble::tribble(
  ~repo_csv,                                                  ~xlsx_name,                          ~sheet,
  "reference_tables/directory_country.csv",                   "DIRECTORY_COUNTRY.xlsx",            "DIRECTORY_COUNTRY",
  "reference_tables/directory_region.csv",                    "DIRECTORY_REGION.xlsx",             "DIRECTORY_REGION",
  "reference_tables/reference_background_xter.csv",           "REFERENCE_BACKGROUND_XTER.xlsx",    "REFERENCE_BACKGROUND_XTER",
  "reference_tables/reference_collection_mechanism.csv",      "REFERENCE_COLLECTION_MECHANISM.xlsx", "REFERENCE_COLLECTION_MECHANISM",
  "reference_tables/reference_country_survey_type.csv",       "REFERENCE_COUNTRY_SURVEY_TYPE.xlsx", "REFERENCE_COUNTRY_SURVEY_TYPE",
  "reference_tables/reference_custodians.csv",                "REFERENCE_CUSTODIANS.xlsx",         "REFERENCE_CUSTODIANS",
  "reference_tables/reference_decision.csv",                  "REFERENCE_DECISION.xlsx",           "REFERENCE_DECISION",
  "reference_tables/reference_decision_category.csv",         "REFERENCE_DECISION_CATEGORY.xlsx",  "REFERENCE_DECISION_CATEGORY",
  "reference_tables/reference_delivery_mechanism.csv",        "REFERENCE_DELIVERY_MECHANISM.xlsx", "REFERENCE_DELIVERY_MECHANISM",
  "reference_tables/reference_estimate_type.csv",             "REFERENCE_ESTIMATE_TYPE.xlsx",      "REFERENCE_ESTIMATE_TYPE",
  "reference_tables/reference_month.csv",                     "REFERENCE_MONTH.xlsx",              "REFERENCE_MONTH",
  "reference_tables/reference_nutrition_domain.csv",          "REFERENCE_NUTRITION_DOMAIN.xlsx",   "REFERENCE_NUTRITION_DOMAIN",
  "reference_tables/reference_pop_list.csv",                  "REFERENCE_POP_LIST.xlsx",           "REFERENCE_POP_LIST",
  "reference_tables/reference_psac_child_age.csv",            "REFERENCE_PSAC_CHILD_AGE.xlsx",     "REFERENCE_PSAC_CHILD_AGE",
  "reference_tables/reference_subdomain.csv",                 "REFERENCE_SUBDOMAIN.xlsx",          "REFERENCE_SUBDOMAIN",
  "reference_tables/reference_survey_category.csv",           "REFERENCE_SURVEY_CATEGORY.xlsx",    "REFERENCE_SURVEY_CATEGORY",
  "reference_tables/reference_survey_type.csv",               "REFERENCE_SURVEY_TYPE.xlsx",        "REFERENCE_SURVEY_TYPE",
  "reference_tables/reference_year_assignment_method.csv",    "REFERENCE_YEAR_ASSIGNMENT_METHOD.xlsx", "REFERENCE_YEAR_ASSIGNMENT_METHO",
  "reference_tables/reference_years_of_survey.csv",           "REFERENCE_YEARS_OF_SURVEY.xlsx",    "REFERENCE_YEARS_OF_SURVEY",
  "reference_tables/directory_indicator.csv",                 "DIRECTORY_INDICATOR.xlsx",          "DIRECTORY_INDICATOR",
  "reference_tables/reference_disaggregations.csv",           "REFERENCE_DISAGGREGATIONS.xlsx",    "REFERENCE_DISAGGREGATIONS",
  "crosswalk/directory_crosswalk_base.csv",                   "DIRECTORY_CROSSWALK (Beta).xlsx",   "DIRECTORY_CROSSWALK (Beta)"
)

write_xlsx_repo <- function(df, xlsx_name, sheet) {
  # Re-add the empty SharePoint 'Attachments' column dropped during migration
  # so the rebuilt xlsx matches the legacy SharePoint Export schema exactly.
  if (!"Attachments" %in% names(df)) {
    df$Attachments <- NA_character_
  }

  # Write to repo output mirror only — never touch the original SharePoint folder.
  out_repo <- file.path(rdmOutputDir, xlsx_name)
  dir.create(dirname(out_repo), recursive = TRUE, showWarnings = FALSE)
  writexl::write_xlsx(stats::setNames(list(df), sheet), out_repo)
  message("Wrote: ", out_repo)
}

# --- 1. Editable reference tables --> xlsx ---------------------------------
for (i in seq_len(nrow(exports))) {
  src <- file.path(rdmInputDir, exports$repo_csv[i])
  if (!file.exists(src)) {
    warning("Missing repo csv, skipping: ", src)
    next
  }
  df <- readr::read_csv(src, show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_character()))
  write_xlsx_repo(df, exports$xlsx_name[i], exports$sheet[i])
}

# --- 2. Computed wide crosswalk --> directory_crosswalk.xlsx ---------------
wide_csv <- file.path(rdmOutputDir, "directory_crosswalk.csv")
if (file.exists(wide_csv)) {
  wide <- readr::read_csv(wide_csv, show_col_types = FALSE,
                          col_types = readr::cols(.default = readr::col_character()))
  write_xlsx_repo(wide, "directory_crosswalk.xlsx", "Sheet1")
} else {
  message("Skipping computed wide crosswalk export — run 2_build_directory_crosswalk.r first.")
}
