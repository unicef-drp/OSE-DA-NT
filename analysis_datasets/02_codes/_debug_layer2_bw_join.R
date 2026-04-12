suppressPackageStartupMessages({
  library(readr)
  library(haven)
  library(dplyr)
})

script_path <- "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/analysis_datasets/02_codes/1_build_layer2_datasets.r"
script_lines <- readLines(script_path)
cut_line <- grep("^input_cmrs_dir <-", script_lines)[1] - 1

eval(parse(text = paste(script_lines[1:cut_line], collapse = "\n")))

map <- read_csv(
  "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/reference_data_manager/indicators/reference_disaggregations.csv",
  show_col_types = FALSE
)
bw <- read_dta(
  "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard/CMRS_BW.dta"
)

map_prepped <- map %>%
  transmute(
    DISAGGREGATION_ID = as.character(.data$ID),
    DISAGGREGATION_CODE = as.character(.data$CND_REGEX),
    DISAGGREGATION_LABEL = as.character(.data$`Standard Disaggregations`),
    SEX = dplyr::na_if(trimws(as.character(.data$HELIX_SEX)), ""),
    AGE = dplyr::na_if(trimws(as.character(.data$HELIX_AGE)), "")
  )

bw_id <- as.character(bw$standard_disagg)
cat("BW rows:", nrow(bw), "\n")
cat("BW distinct standard_disagg:", dplyr::n_distinct(bw$standard_disagg), "\n")
cat("ID match share:", mean(bw_id %in% map_prepped$DISAGGREGATION_ID), "\n")

j1 <- bw %>%
  mutate(disagg_id_key = as.character(.data$standard_disagg)) %>%
  left_join(
    map_prepped %>% select(DISAGGREGATION_ID, SEX, AGE),
    by = c("disagg_id_key" = "DISAGGREGATION_ID"),
    suffix = c("", "_id")
  )

cat("After ID join: SEX non-NA:", sum(!is.na(j1$SEX)), "AGE non-NA:", sum(!is.na(j1$AGE)), "\n")
cat("Sample joined SEX:", paste(head(unique(j1$SEX), 10), collapse = "|"), "\n")

out <- build_layer2_dataset(bw, map)
cat("Function output SEX non-NA:", sum(!is.na(out$SEX)), " AGE non-NA:", sum(!is.na(out$AGE)), "\n")
cat("Function output sample SEX:", paste(head(unique(out$SEX), 10), collapse = "|"), "\n")
