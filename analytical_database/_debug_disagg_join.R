suppressPackageStartupMessages(library(readr))
suppressPackageStartupMessages(library(haven))
suppressPackageStartupMessages(library(dplyr))

map_path <- "C:/Users/jconkle/Documents/GitHub/OSE-DA-NT/reference_data_manager/indicators/reference_disaggregations.csv"
bw_path <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard/CMRS_BW.dta"
iod_path <- "C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/Combined Nutrition Databases/Common Minimum Reporting Standard/CMRS_IOD.dta"

m <- read_csv(map_path, show_col_types = FALSE)
cat("Map columns:\n")
print(names(m))
cat("class(ID):", class(m[["ID"]]), "\n")
cat("class(Disaggregate ID):", class(m[["Disaggregate ID"]]), "\n")
cat("distinct ID:", n_distinct(m[["ID"]]), "\n")
cat("distinct CND_REGEX:", n_distinct(m[["CND_REGEX"]]), "\n")
print(m %>% select(ID, CND_REGEX, `Standard Disaggregations`) %>% slice_head(n = 20))

bw <- read_dta(bw_path)
iod <- read_dta(iod_path)

cat("\nBW rows:", nrow(bw), "\n")
cat("BW class standard_disagg:", class(bw[["standard_disagg"]]), "\n")
cat("BW distinct standard_disagg:", n_distinct(bw[["standard_disagg"]]), "\n")
cat("BW sample standard_disagg:", paste(head(unique(as.character(bw[["standard_disagg"]])), 20), collapse = "|"), "\n")

cat("\nIOD rows:", nrow(iod), "\n")
cat("IOD class standard_disagg:", class(iod[["standard_disagg"]]), "\n")
cat("IOD distinct standard_disagg:", n_distinct(iod[["standard_disagg"]]), "\n")
cat("IOD sample standard_disagg:", paste(head(unique(as.character(iod[["standard_disagg"]])), 20), collapse = "|"), "\n")

map_ids <- as.character(m[["ID"]])
bw_ids <- as.character(bw[["standard_disagg"]])
iod_ids <- as.character(iod[["standard_disagg"]])

cat("\nBW share of rows with standard_disagg found in map ID:", mean(bw_ids %in% map_ids), "\n")
cat("IOD share of rows with standard_disagg found in map ID:", mean(iod_ids %in% map_ids), "\n")

bw_labels <- as.character(bw[["StandardDisaggregations"]])
iod_labels <- as.character(iod[["StandardDisaggregations"]])
map_codes <- as.character(m[["CND_REGEX"]])

cat("BW share labels found in map CND_REGEX:", mean(bw_labels %in% map_codes), "\n")
cat("IOD share labels found in map CND_REGEX:", mean(iod_labels %in% map_codes), "\n")
