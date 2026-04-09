print("Execute file to produce nutrition section indicator projeections and targets")

library(readxl)
library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(openxlsx)

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
# SETUP
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
		stop("Package `yaml` is required to load user paths for the projections script.")
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
		file.path(githubFolder, "OSE-DA-NT"),
		file.path(githubFolder, "DW-Production")
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
	message("Loaded NT projection paths from user_config.yml for `", username, "`.")
}

# Set input and output directories
inputdir <- file.path(teamsFolder, "01_dw_prep", "011_rawdata", "nt", "input")
outputdir <- file.path(teamsFolder, "01_dw_prep", "011_rawdata", "nt", "output")
interdir <- file.path(outputdir, "inter")
if (!exists("teamsRawData")) {
	teamsRawData <- file.path(teamsFolder, "01_dw_prep", "011_rawdata")
}

outputdir_projections <- file.path(teamsFolder, "01_dw_prep", "011_rawdata", "nt", "output_projections")
outputdir_projections_input <- file.path(outputdir_projections, "input")
outputdir_projections_temp <- file.path(outputdir_projections, "temp", "split_progress")
outputdir_projections_inter <- file.path(outputdir_projections, "inter")
outputdir_projections_final <- file.path(outputdir_projections, "final")
outputdir_projections_exports <- file.path(outputdir_projections_final, "estimates_projections_targets")

dw_codes_candidates <- c(
	file.path(projectFolder, "further_transformation_system", "projections_progress_class", "012_codes"),
	file.path(projectFolder, "05_projections", "012_codes", "nt")
)
dwCodesNTProj <- dw_codes_candidates[dir.exists(dw_codes_candidates)][1]
if (is.na(dwCodesNTProj) || !nzchar(dwCodesNTProj)) {
	stop(
		"Could not resolve NT projection code directory. Checked: ",
		paste(dw_codes_candidates, collapse = ", ")
	)
}

dir.create(outputdir_projections, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_input, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_temp, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_inter, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_final, recursive = TRUE, showWarnings = FALSE)
dir.create(outputdir_projections_exports, recursive = TRUE, showWarnings = FALSE)

# Set filepaths
pop_path <- file.path(inputdir, "base_population_1990_2030.csv")
pop_path_2022 <- file.path(inputdir, "2022_base_population_1990_2030.csv") # 2022 WPP data
# LBW,SANT,DANT using old population
agg_input_path <- file.path(interdir, "out_dw_nut_country_for_agg.csv")




source(file.path(dwCodesNTProj,  "1a_import_inputs.r"))
source(file.path(dwCodesNTProj,  "1b_population_lookup.r"))
source(file.path(dwCodesNTProj,  "2_ant_ovwt_series.r"))
source(file.path(dwCodesNTProj,  "3_ane_wra_series.r"))
source(file.path(dwCodesNTProj,  "4_ant_wst_survey.r"))
source(file.path(dwCodesNTProj,  "5_ant_stnt_series.r"))
source(file.path(dwCodesNTProj,  "6_bw_lbw_series.r"))
source(file.path(dwCodesNTProj,  "7_iycf_exbf_survey.r"))

source(file.path(dwCodesNTProj, "8_format_output.r"))