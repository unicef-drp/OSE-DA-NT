if (!exists("analysisCodes", envir = .GlobalEnv)) {
	source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
source(file.path(analysisCodes, "1_layer2_utils.r"))
run_single_dataset("CMRS_ANT.dta", "cmrs2_ant.parquet")
