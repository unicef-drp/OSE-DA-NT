# import and restructure CMRS series and non-series datasets

if (!exists("projectFolder", envir = .GlobalEnv) || !exists("analysisCodes", envir = .GlobalEnv)) {
	source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

source(file.path(analysisCodes, "2_build_cmrs2_series.r"))
source(file.path(analysisCodes, "2_build_cmrs2_bw.r"))
source(file.path(analysisCodes, "2_build_cmrs2_iod.r"))
source(file.path(analysisCodes, "2_build_cmrs2_ant.r"))
source(file.path(analysisCodes, "2_build_cmrs2_iycf.r"))
