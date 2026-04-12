suppressPackageStartupMessages(library(arrow))
suppressPackageStartupMessages(library(dplyr))

bf <- read_parquet("C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_datasets/cmrs2_iycf_bf.parquet")
cf <- read_parquet("C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/analysis_datasets/cmrs2_iycf_cf.parquet")
iycf <- bind_rows(bf, cf) %>% mutate(across(everything(), as.character))

cols <- c("SEX", "AGE", "RESIDENCE", "WEALTH", "EDUCATION", "HEAD_OF_HOUSEHOLD",
          "MOTHER_AGE", "DELIVERY_ASSISTANCE", "PLACE_OF_DELIVERY", "DELIVERY_MODE",
          "MULTIPLE_BIRTH", "REGION")

full_t <- iycf %>% filter(apply(select(., all_of(cols)), 1, function(r) all(r == "_T")))

cat("IYCF rows:", nrow(iycf), "\n")
cat("IYCF fully _T rows:", nrow(full_t), "\n\n")
cat("Fully _T by BackgroundCharacteristics:\n")
print(full_t %>% count(BackgroundCharacteristics, sort = TRUE), n = 80)

cat("\nFully _T by BackgroundCharacteristics + StandardDisaggregations (top 120):\n")
print(full_t %>% count(BackgroundCharacteristics, StandardDisaggregations, sort = TRUE) %>% head(120), n = 120)

non_national <- full_t %>% filter(!(BackgroundCharacteristics %in% c("National", NA_character_) | trimws(coalesce(BackgroundCharacteristics, "")) == ""))
cat("\nNon-National fully _T rows:", nrow(non_national), "\n")
