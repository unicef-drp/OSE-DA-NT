print("Execute animated scatterplot pipeline for nutrition indicators")

library(arrow)
library(dplyr)
library(readr)
library(ggplot2)
library(gganimate)
library(scales)
library(grid)
library(RColorBrewer)
library(ggrepel)
library(av)
library(magick)

get_script_path <- function() {
	cmd_args <- commandArgs(trailingOnly = FALSE)
	file_arg <- "--file="
	file_hit <- cmd_args[startsWith(cmd_args, file_arg)]
	if (length(file_hit) > 0) {
		return(normalizePath(sub(file_arg, "", file_hit[1]), winslash = "/", mustWork = FALSE))
	}

	ofiles <- Filter(Negate(is.null), lapply(sys.frames(), function(frame) frame$ofile))
	if (length(ofiles) > 0) {
		return(normalizePath(ofiles[[length(ofiles)]], winslash = "/", mustWork = FALSE))
	}

	NA_character_
}

find_repo_root <- function(start_dir) {
	current <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
	repeat {
		if (dir.exists(file.path(current, ".git"))) {
			return(current)
		}
		parent <- dirname(current)
		if (identical(parent, current)) {
			return(NA_character_)
		}
		current <- parent
	}
}

#------------------------------------------------------------------------------
# SETUP — resolve paths from profile or user_config.yml
#------------------------------------------------------------------------------

if (!exists("teamsFolder") || !exists("projectFolder")) {
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
			". Create it from `_config_template/user_config.yml` or source the project profile manually first."
		)
	}
	if (!requireNamespace("yaml", quietly = TRUE)) {
		stop("Package `yaml` is required to load user paths.")
	}

	config_yaml <- yaml::read_yaml(config_path)
	if (!username %in% names(config_yaml)) {
		stop("No entry for user `", username, "` was found in: ", config_path)
	}

	githubFolder <- config_yaml[[username]]$githubFolder
	teamsRoot <- config_yaml[[username]]$teamsRoot

	script_path <- get_script_path()
	script_repo_root <- if (!is.na(script_path)) find_repo_root(dirname(script_path)) else NA_character_

	project_candidates <- c(
		script_repo_root,
		file.path(githubFolder, "OSE-DA-NT")
	)
	project_candidates <- unique(project_candidates[!is.na(project_candidates) & nzchar(project_candidates)])
	projectFolder <- project_candidates[file.exists(project_candidates)][1]
	if (is.na(projectFolder) || !nzchar(projectFolder)) {
		stop(
			"Could not resolve projectFolder. Checked: ",
			paste(project_candidates, collapse = ", "),
			". Define `projectFolder` before running."
		)
	}

	teamsFolder <- file.path(teamsRoot, "060.DW-MASTER")

	nutritionRoot <- config_yaml[[username]]$nutritionRoot
	if (is.null(nutritionRoot) || !nzchar(nutritionRoot)) {
		nutrition_candidates <- c(
			teamsRoot,
			file.path(dirname(teamsRoot), "Data and Analytics Nutrition - Analysis Space"),
			file.path("C:/Users", username, "UNICEF", "Data and Analytics Nutrition - Analysis Space")
		)
		nutritionRoot <- nutrition_candidates[dir.exists(nutrition_candidates)][1]
	}
	if (is.na(nutritionRoot) || !nzchar(nutritionRoot)) {
		stop("Could not resolve nutritionRoot. Add `nutritionRoot` to user_config.yml.")
	}
	githubOutputRoot <- file.path(nutritionRoot, "github")
	analysisDatasetsInputDir <- file.path(githubOutputRoot, "analysis_datasets")

	message("Loaded animated scatterplot paths from user_config.yml for `", username, "`.")
}

# Ensure analysisDatasetsInputDir and githubOutputRoot are available even when
# the config block above was skipped (e.g. profile_OSE-DA-NT.R already sourced).
if (!exists("githubOutputRoot") || !nzchar(githubOutputRoot)) {
	if (exists("nutritionRoot") && !is.na(nutritionRoot) && nzchar(nutritionRoot)) {
		githubOutputRoot <- file.path(nutritionRoot, "github")
	} else {
		username_fb <- Sys.getenv("USERNAME")
		if (username_fb == "" || is.na(username_fb)) username_fb <- Sys.getenv("USER")
		githubOutputRoot_candidates <- c(
			file.path("C:/Users", username_fb, "UNICEF",
			          "Data and Analytics Nutrition - Analysis Space", "github")
		)
		githubOutputRoot <- githubOutputRoot_candidates[dir.exists(githubOutputRoot_candidates)][1]
		if (is.na(githubOutputRoot) || !nzchar(githubOutputRoot)) {
			stop("Could not resolve githubOutputRoot. Ensure profile or user_config.yml is loaded.")
		}
	}
}
if (!exists("analysisDatasetsInputDir") || !nzchar(analysisDatasetsInputDir)) {
	analysisDatasetsInputDir <- file.path(githubOutputRoot, "analysis_datasets")
}

#------------------------------------------------------------------------------
# Input directories (DW-Production paths for crosswalk and population)
#------------------------------------------------------------------------------
inputdir <- file.path(teamsFolder, "01_dw_prep", "011_rawdata", "nt", "input")
outputdir <- file.path(teamsFolder, "01_dw_prep", "011_rawdata", "nt", "output")
interdir <- file.path(outputdir, "inter")
wasting_csv_path <- file.path(interdir, "agg_domain", "agg_ant_wasting.csv")

#------------------------------------------------------------------------------
# Output directory
#------------------------------------------------------------------------------
outputdir_animated_scatterplots <- file.path(githubOutputRoot, "animated_scatterplots")
dir.create(outputdir_animated_scatterplots, recursive = TRUE, showWarnings = FALSE)

#------------------------------------------------------------------------------
# Resolve code directory
#------------------------------------------------------------------------------
dwCodesScatterplots_candidates <- c(
	if (!is.na(get_script_path())) dirname(get_script_path()) else NA_character_,
	file.path(projectFolder, "further_transformation_system", "animated_scatterplots", "02_codes")
)
dwCodesScatterplots_candidates <- unique(dwCodesScatterplots_candidates[!is.na(dwCodesScatterplots_candidates)])
dwCodesScatterplots <- dwCodesScatterplots_candidates[dir.exists(dwCodesScatterplots_candidates)][1]
if (is.na(dwCodesScatterplots) || !nzchar(dwCodesScatterplots)) {
	stop(
		"Could not resolve animated scatterplot code directory. Checked: ",
		paste(dwCodesScatterplots_candidates, collapse = ", ")
	)
}

message("Input:  ", analysisDatasetsInputDir)
message("Output: ", outputdir_animated_scatterplots)

#------------------------------------------------------------------------------
# Source shared functions and load reference data once
#------------------------------------------------------------------------------
source(file.path(dwCodesScatterplots, "0_scatterplot_functions.r"))

.crosswalk   <- load_crosswalk()
.population  <- load_population()

#------------------------------------------------------------------------------
# Source worker scripts
#------------------------------------------------------------------------------
# Regional (UNICEF reporting regions as data points)
#source(file.path(dwCodesScatterplots, "animated_scatterplot_stunting_regions.r"))
#source(file.path(dwCodesScatterplots, "animated_scatterplot_overweight_regions.r"))
#source(file.path(dwCodesScatterplots, "animated_scatterplot_wasting_regions.r"))

# Country-level — global must be sourced before regional (loads country_data)
source(file.path(dwCodesScatterplots, "animated_scatterplot_stunting_countries_global.r"))
#source(file.path(dwCodesScatterplots, "animated_scatterplot_stunting_countries_regional.r"))
