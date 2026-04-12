# ------------------------------------------------------------------
# Project: OSE-DA-NT
# Script: profile_OSE-DA-NT.R
# Purpose: Load user-specific paths from ~/.config/user_config.yml and
#          prepare shared repository path roots for nutrition workflows.
# ------------------------------------------------------------------

set.seed(12345)

repo_name <- "OSE-DA-NT"

username <- Sys.getenv("USERNAME")
if (username == "" || is.na(username)) {
  username <- Sys.getenv("USER")
}

userprofile <- Sys.getenv("USERPROFILE")
if (userprofile == "" || is.na(userprofile)) {
  userprofile <- "~"
}

config_path <- file.path(userprofile, ".config", "user_config.yml")

if (!requireNamespace("yaml", quietly = TRUE)) {
  install.packages("yaml")
}

if (!file.exists(config_path)) {
  stop(
    "Configuration file not found: ", config_path,
    "\nCreate it from _config_template/user_config.yml before running this profile."
  )
}

config_yaml <- yaml::read_yaml(config_path)

# Support two layouts:
# 1) username-scoped entry (preferred)
# 2) top-level keys (legacy/simple)
user_cfg <- NULL
if (!is.null(config_yaml[[username]])) {
  user_cfg <- config_yaml[[username]]
} else {
  user_cfg <- config_yaml
}

githubFolder <- user_cfg$githubFolder
teamsRoot <- user_cfg$teamsRoot
nutritionRoot <- user_cfg$nutritionRoot

if (is.null(githubFolder) || is.null(teamsRoot)) {
  stop(
    "Missing required keys in user_config.yml. Expected githubFolder and teamsRoot",
    " (either under user '", username, "' or at top-level)."
  )
}

project_candidates <- c(
  file.path(githubFolder, repo_name),
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
)
project_candidates <- unique(project_candidates)
projectFolder <- project_candidates[dir.exists(project_candidates)][1]

if (is.na(projectFolder) || !nzchar(projectFolder)) {
  stop(
    "Could not resolve projectFolder. Checked: ",
    paste(project_candidates, collapse = ", ")
  )
}

teamsFolder <- file.path(teamsRoot, "060.DW-MASTER")
if (!dir.exists(teamsFolder)) {
  warning("teamsFolder does not exist yet: ", teamsFolder)
}

if (is.null(nutritionRoot) || !nzchar(nutritionRoot)) {
  nutrition_candidates <- c(
    teamsRoot,
    file.path(dirname(teamsRoot), "Data and Analytics Nutrition - Analysis Space"),
    file.path("C:/Users", username, "UNICEF", "Data and Analytics Nutrition - Analysis Space")
  )
  nutrition_candidates <- unique(nutrition_candidates)
  nutritionRoot <- nutrition_candidates[dir.exists(nutrition_candidates)][1]
}
if (is.na(nutritionRoot) || !nzchar(nutritionRoot) || !dir.exists(nutritionRoot)) {
  stop(
    "Could not resolve nutritionRoot. Add `nutritionRoot` to user_config.yml, e.g. ",
    "C:/Users/<user>/UNICEF/Data and Analytics Nutrition - Analysis Space"
  )
}

githubOutputRoot <- file.path(nutritionRoot, "github")
if (!dir.exists(githubOutputRoot)) dir.create(githubOutputRoot, recursive = TRUE, showWarnings = FALSE)

# Shared repo-level roots.
cmrsInputDir <- file.path(nutritionRoot, "Combined Nutrition Databases", "Common Minimum Reporting Standard")
analysisDatasetsOutputDir <- file.path(githubOutputRoot, "analysis_datasets")
if (!dir.exists(analysisDatasetsOutputDir)) dir.create(analysisDatasetsOutputDir, recursive = TRUE, showWarnings = FALSE)

# OSE-DA-NT repo-centric path objects.
analysisCodes <- file.path(projectFolder, "analysis_datasets", "02_codes")
analysisConductor <- file.path(analysisCodes, "0_execute_conductor.r")
projectionCodes <- file.path(projectFolder, "further_transformation_system", "projections_progress_class", "012_codes")
projectionExecute <- file.path(projectionCodes, "1_execute.r")

# Export variables into global env for downstream scripts.
assign("username", username, envir = .GlobalEnv)
assign("userprofile", userprofile, envir = .GlobalEnv)
assign("config_path", config_path, envir = .GlobalEnv)
assign("githubFolder", githubFolder, envir = .GlobalEnv)
assign("teamsRoot", teamsRoot, envir = .GlobalEnv)
assign("nutritionRoot", nutritionRoot, envir = .GlobalEnv)
assign("githubOutputRoot", githubOutputRoot, envir = .GlobalEnv)
assign("projectFolder", projectFolder, envir = .GlobalEnv)
assign("teamsFolder", teamsFolder, envir = .GlobalEnv)
assign("cmrsInputDir", cmrsInputDir, envir = .GlobalEnv)
assign("analysisDatasetsOutputDir", analysisDatasetsOutputDir, envir = .GlobalEnv)
assign("analysisCodes", analysisCodes, envir = .GlobalEnv)
assign("analysisConductor", analysisConductor, envir = .GlobalEnv)
assign("projectionCodes", projectionCodes, envir = .GlobalEnv)
assign("projectionExecute", projectionExecute, envir = .GlobalEnv)

assign("profile_OSE_DA_NT", TRUE, envir = .GlobalEnv)

message("Loaded OSE-DA-NT profile for user '", username, "'.")
message("projectFolder: ", projectFolder)
message("githubOutputRoot: ", githubOutputRoot)
