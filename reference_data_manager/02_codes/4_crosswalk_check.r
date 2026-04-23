# ---------------------------------------------------------------------------
# Script:  4_crosswalk_check.r
# Purpose: Compare the current computed directory_crosswalk.csv against an
#          archived snapshot, listing all changed (Country x Classification)
#          cells. Replaces the legacy Stata script:
#            Maintenance/Crosswalk Checks/Crosswalk Check Preparation.do
#
# Inputs:
#   - {rdmOutputDir}/directory_crosswalk.csv          (current build)
#   - {refSharepointDir}/Archive/<oldfile>.xlsx      (archived snapshot)
#     The archive file name can be set via:
#         crosswalk_check_archive <- "DIRECTORY_CROSSWALK (Beta)_20241212"
#     before sourcing. Default is the most recent file in the Archive folder.
#
# Output:
#   - {rdmOutputDir}/crosswalk_check.csv  (long: Country, Classification,
#                                          Class_New, Class_Old, Changed)
# ---------------------------------------------------------------------------

if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

stopifnot(exists("rdmOutputDir"))

current_csv <- file.path(rdmOutputDir, "directory_crosswalk.csv")
if (!file.exists(current_csv)) {
  stop("Current crosswalk not built. Run 2_build_directory_crosswalk.r first.")
}

# Resolve archive snapshot
archive_file <- NULL
if (exists("refSharepointDir") && dir.exists(file.path(refSharepointDir, "Archive"))) {
  arch_dir <- file.path(refSharepointDir, "Archive")
  if (exists("crosswalk_check_archive", envir = .GlobalEnv)) {
    archive_file <- file.path(arch_dir,
                              paste0(get("crosswalk_check_archive"), ".xlsx"))
  } else {
    cands <- list.files(arch_dir,
                        pattern = "^DIRECTORY_CROSSWALK \\(Beta\\)_.*\\.xlsx$",
                        full.names = TRUE)
    if (length(cands) > 0) {
      archive_file <- cands[order(file.info(cands)$mtime, decreasing = TRUE)][1]
    }
  }
}

if (is.null(archive_file) || !file.exists(archive_file)) {
  stop("No archive crosswalk found. Set crosswalk_check_archive or place an ",
       "xlsx in {refSharepointDir}/Archive/.")
}

message("Comparing against archive: ", archive_file)

new <- readr::read_csv(current_csv, show_col_types = FALSE,
                       col_types = readr::cols(.default = readr::col_character()))
old <- readxl::read_excel(archive_file,
                          sheet = "DIRECTORY_CROSSWALK (Beta)") %>%
  dplyr::mutate(dplyr::across(dplyr::everything(), as.character))

# Standardise key column to ISO3Code in both
key_aliases <- c("ISO3Code", "ISO-3 Code", "ISO_Code", "ISO3")
norm_key <- function(df) {
  hit <- intersect(key_aliases, names(df))
  if (length(hit) == 0) stop("No ISO3 key column in dataset")
  if (hit[1] != "ISO3Code") names(df)[names(df) == hit[1]] <- "ISO3Code"
  df
}
new <- norm_key(new)
old <- norm_key(old)

# Compare on the intersection of classification columns (everything that is
# not an identifier/notes column).
id_cols   <- intersect(c("ISO3Code", "ID", "Country", "CND_Country_Code", "M49",
                         "WB_Code", "Notes", "Color Tag", "Color.Tag",
                         "Compliance Asset Id", "Compliance.Asset.Id",
                         "Attachments"),
                       union(names(new), names(old)))
class_cols <- intersect(setdiff(names(new), id_cols),
                        setdiff(names(old), id_cols))

new_long <- new %>%
  dplyr::select(dplyr::all_of(c("ISO3Code", "Country", class_cols))) %>%
  tidyr::pivot_longer(dplyr::all_of(class_cols),
                      names_to  = "Classification",
                      values_to = "Class_New")

old_long <- old %>%
  dplyr::select(dplyr::all_of(c("ISO3Code", intersect("Country", names(old)), class_cols))) %>%
  tidyr::pivot_longer(dplyr::all_of(class_cols),
                      names_to  = "Classification",
                      values_to = "Class_Old")

diff <- dplyr::full_join(new_long, old_long,
                         by = c("ISO3Code", "Country", "Classification")) %>%
  dplyr::mutate(Changed = as.integer(
    ifelse(is.na(Class_New) & is.na(Class_Old), 0L,
           !identical(Class_New, Class_Old) | (Class_New != Class_Old))
  ))

out <- file.path(rdmOutputDir, "crosswalk_check.csv")
readr::write_csv(diff, out)
message("Wrote: ", out, "  (", sum(diff$Changed == 1, na.rm = TRUE),
        " changed cells out of ", nrow(diff), ")")

invisible(diff)
