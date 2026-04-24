# ---------------------------------------------------------------------------
# Script:  3b_export_legacy_dta.r
# Purpose: Re-create the legacy `CND Import/*.dta` Stata files from the repo
#          CSVs. Closes the documented gap from the CND overall instruction
#          manual Section 3.B: "Excel files go to Sharepoint Export ; and the
#          Stata files to CND Import."
#
#          The legacy Stata Decision Engine and CMRS Preparation pipelines
#          read these .dta files. They will be retired once those pipelines
#          are migrated, but until then this keeps them refreshable from the
#          repo without going through Access.
#
# Outputs (written ONLY to repo output mirror under `dta/`; never to SharePoint):
#   {githubOutputRoot}/reference_data_manager/dta/DIRECTORY_COUNTRY.dta
#   {githubOutputRoot}/reference_data_manager/dta/DIRECTORY_INDICATOR.dta
#   {githubOutputRoot}/reference_data_manager/dta/REFERENCE_*.dta
#   {githubOutputRoot}/reference_data_manager/dta/directory_crosswalk.dta (computed wide)
#
# To update the legacy CND Import/ folder, copy from the repo output mirror
# manually after review. This script never touches the SharePoint folder.
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

stopifnot(exists("rdmInputDir"), exists("rdmOutputDir"))

dta_out_dir <- file.path(rdmOutputDir, "dta")
dir.create(dta_out_dir, recursive = TRUE, showWarnings = FALSE)

# Mapping: repo csv (relative to rdmInputDir) -> legacy dta name
# Subset matches the 18 .dta files historically produced to CND Import/.
dta_exports <- tibble::tribble(
  ~repo_csv,                                                  ~dta_name,
  "reference_tables/directory_country.csv",                   "DIRECTORY_COUNTRY.dta",
  "reference_tables/directory_indicator.csv",                 "DIRECTORY_INDICATOR.dta",
  "reference_tables/reference_disaggregations.csv",           "REFERENCE_DISAGGREGATIONS.dta",
  "reference_tables/reference_background_xter.csv",           "REFERENCE_BACKGROUND_XTER.dta",
  "reference_tables/reference_collection_mechanism.csv",      "REFERENCE_COLLECTION_MECHANISM.dta",
  "reference_tables/reference_custodians.csv",                "REFERENCE_CUSTODIANS.dta",
  "reference_tables/reference_decision.csv",                  "REFERENCE_DECISION.dta",
  "reference_tables/reference_decision_category.csv",         "REFERENCE_DECISION_CATEGORY.dta",
  "reference_tables/reference_delivery_mechanism.csv",        "REFERENCE_DELIVERY_MECHANISM.dta",
  "reference_tables/reference_estimate_type.csv",             "REFERENCE_ESTIMATE_TYPE.dta",
  "reference_tables/reference_month.csv",                     "REFERENCE_MONTH.dta",
  "reference_tables/reference_nutrition_domain.csv",          "REFERENCE_NUTRITION_DOMAIN.dta",
  "reference_tables/reference_psac_child_age.csv",            "REFERENCE_PSAC_CHILD_AGE.dta",
  "reference_tables/reference_subdomain.csv",                 "REFERENCE_SUBDOMAIN.dta",
  "reference_tables/reference_survey_category.csv",           "REFERENCE_SURVEY_CATEGORY.dta",
  "reference_tables/reference_year_assignment_method.csv",    "REFERENCE_YEAR_ASSIGNMENT_METHOD.dta",
  "reference_tables/reference_years_of_survey.csv",           "REFERENCE_YEARS_OF_SURVEY.dta"
)

# Stata variable names cannot contain spaces, dots, or start with a digit.
# `haven::write_dta` will error out otherwise. Sanitise once here.
sanitise_stata_names <- function(nms) {
  nms <- gsub("[^A-Za-z0-9_]", "_", nms)
  nms <- ifelse(grepl("^[0-9]", nms), paste0("v_", nms), nms)
  # Stata variable name max length is 32 characters
  ifelse(nchar(nms) > 32, substr(nms, 1, 32), nms)
}

write_dta_repo <- function(df, dta_name) {
  names(df) <- sanitise_stata_names(names(df))
  out_repo <- file.path(dta_out_dir, dta_name)
  haven::write_dta(df, out_repo)
  message("Wrote: ", out_repo)
}

# --- 1. Editable reference tables --> dta ----------------------------------
for (i in seq_len(nrow(dta_exports))) {
  src <- file.path(rdmInputDir, dta_exports$repo_csv[i])
  if (!file.exists(src)) {
    warning("Missing repo csv, skipping: ", src)
    next
  }
  df <- readr::read_csv(src, show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_character()))
  write_dta_repo(df, dta_exports$dta_name[i])
}

# --- 2. Computed wide crosswalk --> directory_crosswalk.dta ---------------
wide_csv <- file.path(rdmOutputDir, "directory_crosswalk.csv")
if (file.exists(wide_csv)) {
  wide <- readr::read_csv(wide_csv, show_col_types = FALSE,
                          col_types = readr::cols(.default = readr::col_character()))
  write_dta_repo(wide, "directory_crosswalk.dta")
} else {
  message("Skipping wide crosswalk dta export — run 2_build_directory_crosswalk.r first.")
}
