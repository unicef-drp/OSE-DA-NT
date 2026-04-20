# ---------------------------------------------------------------------------
# Script:  3_stunting_rankings.r
# Purpose: Compute top-20 country rankings for stunting (prevalence and
#          burden), generate summary tables, figures, concentration metrics,
#          and overlap analysis. Produces:
#            - stunting_rankings.rds (R list for downstream scripts)
#            - stunting_rankings.csv (combined human-readable)
#            - stunting_tables_and_figures_vN.xlsx (one sheet per table, auto-versioned)
#            - stunting_tables_and_figures_v2.md (clean v2)
#            - stunting_tables_and_figures_v2.review.md (review copy v2)
#            - stunting_tables_and_figures_v2_tracked.md (track changes)
#            - figures/ folder with PNG charts (Figures 1-10)
# Input:   01_inputs/stunting_modeled.parquet
#          01_inputs/stunting_numbers.parquet (if available)
# ---------------------------------------------------------------------------

# --- Paths ----------------------------------------------------------------
if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
# Output to external location (outside git) to avoid large files in repo
adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis", "stunting_top20_briefing")
input_dir  <- file.path(adhoc_output_root, "01_inputs")
output_dir <- file.path(adhoc_output_root, "03_outputs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# --- Load data ------------------------------------------------------------
parquet_path <- file.path(input_dir, "stunting_modeled.parquet")
if (!file.exists(parquet_path)) {
  stop("Input not found: ", parquet_path, ". Run 2_prepare_inputs.r first.")
}

stnt <- read_parquet(parquet_path) %>%
  mutate(
    TIME_PERIOD = as.integer(TIME_PERIOD),
    r       = as.numeric(r)
  ) %>%
  filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(r))

# Detect scale: if max > 1, values are percentages; otherwise proportions
if (max(stnt$r, na.rm = TRUE) <= 1) {
  stnt <- stnt %>% mutate(r = r * 100)
  message("Converted r from proportion to percentage scale.")
}

# --- Determine reference years --------------------------------------------
latest_year <- max(stnt$TIME_PERIOD, na.rm = TRUE)
yr_10_ago   <- latest_year - 10
yr_20_ago   <- latest_year - 20

message("Latest year in data: ", latest_year)
message("10-year baseline:    ", yr_10_ago)
message("20-year baseline:    ", yr_20_ago)

# --- Country name lookup (from source data, not external packages) --------
country_lookup <- stnt %>%
  distinct(REF_AREA, CountryName) %>%
  rename(country_name = CountryName)

add_country_name <- function(df) {
  df %>% left_join(country_lookup, by = "REF_AREA")
}

# --- 1. Top 20 highest current prevalence ---------------------------------
top20_highest <- stnt %>%
  filter(TIME_PERIOD == latest_year) %>%
  arrange(desc(r)) %>%
  head(20) %>%
  add_country_name() %>%
  mutate(rank = row_number()) %>%
  select(rank, REF_AREA, country_name, year = TIME_PERIOD, prevalence = r)

message("\n=== Top 20 highest stunting prevalence (", latest_year, ") ===")
print(top20_highest, n = 20)

# --- Helper: compute improvement ------------------------------------------
compute_improvement <- function(data, baseline_year, latest_yr) {
  baseline <- data %>%
    filter(TIME_PERIOD == baseline_year) %>%
    select(REF_AREA, baseline_value = r)

  current <- data %>%
    filter(TIME_PERIOD == latest_yr) %>%
    select(REF_AREA, current_value = r)

  inner_join(baseline, current, by = "REF_AREA") %>%
    mutate(
      change_pp = current_value - baseline_value,
      pct_change = (current_value - baseline_value) / baseline_value * 100
    ) %>%
    filter(change_pp < 0) %>%
    arrange(change_pp) %>%
    head(20) %>%
    add_country_name() %>%
    mutate(rank = row_number()) %>%
    select(rank, REF_AREA, country_name,
           baseline_value, current_value,
           change_pp, pct_change)
}

# --- 2. Top 20 biggest improvers in 10 years ------------------------------
top20_improve_10 <- compute_improvement(stnt, yr_10_ago, latest_year)
message("\n=== Top 20 biggest improvers (", yr_10_ago, "-", latest_year, ") ===")
print(top20_improve_10, n = 20)

# --- 3. Top 20 biggest improvers in 20 years ------------------------------
top20_improve_20 <- compute_improvement(stnt, yr_20_ago, latest_year)
message("\n=== Top 20 biggest improvers (", yr_20_ago, "-", latest_year, ") ===")
print(top20_improve_20, n = 20)

# --- Number-based rankings ------------------------------------------------
num_parquet_path <- file.path(input_dir, "stunting_numbers.parquet")
has_numbers <- file.exists(num_parquet_path)

top20_highest_num    <- NULL
top20_improve_10_num <- NULL
top20_improve_20_num <- NULL

if (has_numbers) {
  stnt_num <- read_parquet(num_parquet_path) %>%
    mutate(
      TIME_PERIOD = as.integer(TIME_PERIOD),
      r       = as.numeric(r)
    ) %>%
    filter(!is.na(REF_AREA), !is.na(TIME_PERIOD), !is.na(r))
  message("\nNumber data: ", nrow(stnt_num), " rows")

  # Extend country lookup with any codes only in the numbers data
  num_lookup <- stnt_num %>%
    distinct(REF_AREA, CountryName) %>%
    rename(country_name = CountryName)
  country_lookup <- bind_rows(country_lookup, num_lookup) %>%
    distinct(REF_AREA, .keep_all = TRUE)

  # Prevalence lookups by year (to enrich burden tables)
  prev_by_year <- stnt %>%
    distinct(REF_AREA, TIME_PERIOD, .keep_all = TRUE) %>%
    select(REF_AREA, TIME_PERIOD, prevalence = r)

  prev_current <- prev_by_year %>%
    filter(TIME_PERIOD == latest_year) %>%
    select(REF_AREA, prevalence = prevalence)

  # Top 20 highest number of stunted children (r in thousands)
  top20_highest_num <- stnt_num %>%
    filter(TIME_PERIOD == latest_year) %>%
    arrange(desc(r)) %>%
    head(20) %>%
    add_country_name() %>%
    mutate(rank = row_number()) %>%
    select(rank, REF_AREA, country_name, year = TIME_PERIOD, number_thousands = r) %>%
    left_join(prev_current, by = "REF_AREA")

  message("\n=== Top 20 highest number of stunted children (", latest_year, ") ===")
  print(top20_highest_num, n = 20)

  # Improvement in numbers
  compute_improvement_num <- function(data, baseline_year, latest_yr) {
    baseline <- data %>%
      filter(TIME_PERIOD == baseline_year) %>%
      select(REF_AREA, baseline_value = r)
    current <- data %>%
      filter(TIME_PERIOD == latest_yr) %>%
      select(REF_AREA, current_value = r)
    inner_join(baseline, current, by = "REF_AREA") %>%
      mutate(
        change_th  = current_value - baseline_value,
        pct_change = (current_value - baseline_value) / baseline_value * 100
      ) %>%
      filter(change_th < 0) %>%
      arrange(change_th) %>%
      head(20) %>%
      add_country_name() %>%
      mutate(rank = row_number()) %>%
      select(rank, REF_AREA, country_name,
             baseline_value, current_value,
             change_th, pct_change)
  }

  prev_baseline_10 <- prev_by_year %>%
    filter(TIME_PERIOD == yr_10_ago) %>%
    select(REF_AREA, baseline_prevalence = prevalence)
  prev_current_10 <- prev_by_year %>%
    filter(TIME_PERIOD == latest_year) %>%
    select(REF_AREA, current_prevalence = prevalence)

  top20_improve_10_num <- compute_improvement_num(stnt_num, yr_10_ago, latest_year) %>%
    left_join(prev_baseline_10, by = "REF_AREA") %>%
    left_join(prev_current_10, by = "REF_AREA")
  message("\n=== Top 20 biggest reduction in stunted numbers (", yr_10_ago, "-", latest_year, ") ===")
  print(top20_improve_10_num, n = 20)

  prev_baseline_20 <- prev_by_year %>%
    filter(TIME_PERIOD == yr_20_ago) %>%
    select(REF_AREA, baseline_prevalence = prevalence)
  prev_current_20 <- prev_by_year %>%
    filter(TIME_PERIOD == latest_year) %>%
    select(REF_AREA, current_prevalence = prevalence)

  top20_improve_20_num <- compute_improvement_num(stnt_num, yr_20_ago, latest_year) %>%
    left_join(prev_baseline_20, by = "REF_AREA") %>%
    left_join(prev_current_20, by = "REF_AREA")
  message("\n=== Top 20 biggest reduction in stunted numbers (", yr_20_ago, "-", latest_year, ") ===")
  print(top20_improve_20_num, n = 20)
} else {
  message("\nNo stunting number data found. Burden rankings skipped.")
}

# --- Overlap and concentration metrics ------------------------------------
tbl_overlap <- NULL
concentration <- NULL

if (has_numbers) {
  tbl_overlap <- inner_join(
    top20_highest %>% select(REF_AREA, country_name),
    top20_highest_num %>% select(REF_AREA),
    by = "REF_AREA"
  ) %>%
    mutate(country_name = ifelse(is.na(country_name), REF_AREA, country_name)) %>%
    distinct() %>%
    arrange(country_name) %>%
    mutate(rank_overlap = row_number()) %>%
    select(rank_overlap, country_name, REF_AREA)

  global_total_m <- 150.2
  india_burden_m <- top20_highest_num %>%
    filter(REF_AREA == "IND") %>%
    pull(number_thousands) / 1000
  india_share    <- 100 * india_burden_m / global_total_m
  top5_burden_m  <- sum(head(top20_highest_num$number_thousands, 5), na.rm = TRUE) / 1000
  top10_burden_m <- sum(head(top20_highest_num$number_thousands, 10), na.rm = TRUE) / 1000
  top20_burden_m <- sum(head(top20_highest_num$number_thousands, 20), na.rm = TRUE) / 1000
  top5_share     <- 100 * top5_burden_m / global_total_m
  top10_share    <- 100 * top10_burden_m / global_total_m
  top20_share    <- 100 * top20_burden_m / global_total_m

  concentration <- data.frame(
    metric = c(
      "Global stunted children (2024)",
      "India alone",
      "India share of global total",
      "Top 5 burden countries",
      "Top 5 share of global total",
      "Top 10 burden countries",
      "Top 10 share of global total",
      "Top 20 burden countries",
      "Top 20 share of global total",
      "Overlap countries (both top-20 lists)"
    ),
    value = c(
      sprintf("%.1f million", global_total_m),
      sprintf("%.1f million", india_burden_m),
      sprintf("%.1f%%", india_share),
      sprintf("%.1f million", top5_burden_m),
      sprintf("%.1f%%", top5_share),
      sprintf("%.1f million", top10_burden_m),
      sprintf("%.1f%%", top10_share),
      sprintf("%.1f million", top20_burden_m),
      sprintf("%.1f%%", top20_share),
      as.character(nrow(tbl_overlap))
    ),
    stringsAsFactors = FALSE
  )

  # --- T9: Reduction concentration (20-year) --------------------------------
  global_20yr_baseline_m <- 201.9
  global_20yr_reduction_m <- global_20yr_baseline_m - global_total_m

  # India's 20-year reduction
  india_red_row <- top20_improve_20_num %>% filter(REF_AREA == "IND")
  india_red_m   <- abs(india_red_row$change_th) / 1000

  top5_red_m  <- sum(abs(head(top20_improve_20_num$change_th, 5)), na.rm = TRUE) / 1000
  top10_red_m <- sum(abs(head(top20_improve_20_num$change_th, 10)), na.rm = TRUE) / 1000
  top20_red_m <- sum(abs(head(top20_improve_20_num$change_th, 20)), na.rm = TRUE) / 1000

  india_red_share <- 100 * india_red_m / global_20yr_reduction_m
  top5_red_share  <- 100 * top5_red_m  / global_20yr_reduction_m
  top10_red_share <- 100 * top10_red_m / global_20yr_reduction_m
  top20_red_share <- 100 * top20_red_m / global_20yr_reduction_m

  reduction_concentration <- data.frame(
    metric = c(
      paste0("Global stunted children (", yr_20_ago, ")"),
      paste0("Global stunted children (", latest_year, ")"),
      "Global reduction (20-year)",
      "India alone (reduction)",
      "India share of global reduction",
      "Top 5 reducers",
      "Top 5 share of global reduction",
      "Top 10 reducers",
      "Top 10 share of global reduction",
      "Top 20 reducers",
      "Top 20 share of global reduction"
    ),
    value = c(
      sprintf("%.1f million", global_20yr_baseline_m),
      sprintf("%.1f million", global_total_m),
      sprintf("%.1f million", global_20yr_reduction_m),
      sprintf("%.1f million", india_red_m),
      sprintf("%.1f%%", india_red_share),
      sprintf("%.1f million", top5_red_m),
      sprintf("%.1f%%", top5_red_share),
      sprintf("%.1f million", top10_red_m),
      sprintf("%.1f%%", top10_red_share),
      sprintf("%.1f million", top20_red_m),
      sprintf("%.1f%%", top20_red_share)
    ),
    stringsAsFactors = FALSE
  )

  message("\n=== Concentration metrics ===")
  print(concentration)
  message("\n=== Reduction concentration (20-year) ===")
  print(reduction_concentration)
  message("\n=== Overlap countries (prevalence AND burden top 20) ===")
  print(tbl_overlap, n = 30)
}

# --- Save results (RDS) --------------------------------------------------
results <- list(
  highest              = top20_highest,
  improve_10yr         = top20_improve_10,
  improve_20yr         = top20_improve_20,
  highest_number       = top20_highest_num,
  improve_10yr_number  = top20_improve_10_num,
  improve_20yr_number  = top20_improve_20_num,
  overlap              = tbl_overlap,
  concentration        = concentration,
  reduction_concentration = reduction_concentration,
  metadata = list(
    latest_year = latest_year,
    yr_10_ago   = yr_10_ago,
    yr_20_ago   = yr_20_ago,
    has_numbers = has_numbers,
    generated   = Sys.time()
  )
)

saveRDS(results, file.path(output_dir, "stunting_rankings.rds"))
message("\nSaved: ", file.path(output_dir, "stunting_rankings.rds"))

# Combined CSV for easy review
combined_csv <- bind_rows(
  top20_highest %>% mutate(ranking = "highest_prevalence",
                           baseline_value = NA_real_, current_value = prevalence,
                           change_pp = NA_real_, pct_change = NA_real_) %>%
    select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
  top20_improve_10 %>% mutate(ranking = paste0("improve_10yr_", yr_10_ago, "_", latest_year)) %>%
    select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
  top20_improve_20 %>% mutate(ranking = paste0("improve_20yr_", yr_20_ago, "_", latest_year)) %>%
    select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
)

if (has_numbers && !is.null(top20_highest_num)) {
  num_csv <- bind_rows(
    top20_highest_num %>% mutate(ranking = "highest_number",
                                 baseline_value = NA_real_, current_value = number_thousands,
                                 change_pp = NA_real_, pct_change = NA_real_) %>%
      select(ranking, rank, REF_AREA, country_name, prevalence, baseline_value, current_value, change_pp, pct_change),
    top20_improve_10_num %>% mutate(ranking = paste0("improve_10yr_number_", yr_10_ago, "_", latest_year)) %>%
      rename(change_pp = change_th) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_prevalence, current_prevalence, baseline_value, current_value, change_pp, pct_change),
    top20_improve_20_num %>% mutate(ranking = paste0("improve_20yr_number_", yr_20_ago, "_", latest_year)) %>%
      rename(change_pp = change_th) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_prevalence, current_prevalence, baseline_value, current_value, change_pp, pct_change)
  )
  combined_csv <- bind_rows(combined_csv, num_csv)
}

write_csv(combined_csv, file.path(output_dir, "stunting_rankings.csv"))
message("Saved: ", file.path(output_dir, "stunting_rankings.csv"))

# --- Excel workbook: tables and figure data -------------------------------
wb <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb, "T1_highest_prevalence")
openxlsx::writeData(wb, "T1_highest_prevalence", top20_highest)

openxlsx::addWorksheet(wb, "T2_improve_10yr_prev")
openxlsx::writeData(wb, "T2_improve_10yr_prev", top20_improve_10)

openxlsx::addWorksheet(wb, "T3_improve_20yr_prev")
openxlsx::writeData(wb, "T3_improve_20yr_prev", top20_improve_20)

if (has_numbers) {
  openxlsx::addWorksheet(wb, "T4_highest_number")
  openxlsx::writeData(wb, "T4_highest_number", top20_highest_num)

  openxlsx::addWorksheet(wb, "T5_improve_10yr_number")
  openxlsx::writeData(wb, "T5_improve_10yr_number", top20_improve_10_num)

  openxlsx::addWorksheet(wb, "T6_improve_20yr_number")
  openxlsx::writeData(wb, "T6_improve_20yr_number", top20_improve_20_num)

  openxlsx::addWorksheet(wb, "T7_overlap_countries")
  openxlsx::writeData(wb, "T7_overlap_countries", tbl_overlap)

  openxlsx::addWorksheet(wb, "T8_concentration")
  openxlsx::writeData(wb, "T8_concentration", concentration)

  openxlsx::addWorksheet(wb, "T9_reduction_conc")
  openxlsx::writeData(wb, "T9_reduction_conc", reduction_concentration)
}

# Auto-version: find existing stunting_tables_and_figures_vN.xlsx and increment
existing_xlsx <- list.files(output_dir, pattern = "^stunting_tables_and_figures_v[0-9]+\\.xlsx$")
if (length(existing_xlsx) > 0) {
  existing_versions <- as.integer(sub(".*_v(\\d+)\\.xlsx$", "\\1", existing_xlsx))
  next_version <- max(existing_versions) + 1L
} else {
  next_version <- 1L
}
xlsx_path <- file.path(output_dir, sprintf("stunting_tables_and_figures_v%d.xlsx", next_version))
# saveWorkbook deferred until after figures are generated and embedded

# --- Figures (PNG + SVG) ---------------------------------------------------
fig_dir <- file.path(output_dir, "figures")
svg_dir <- file.path(fig_dir, "svg")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(svg_dir, recursive = TRUE, showWarnings = FALSE)

make_label <- function(df) {

  df %>% mutate(
    label = paste0(country_name, " (", REF_AREA, ")"),
    label = factor(label, levels = rev(label))
  )
}

# --- Prevalence threshold classification (de Onis et al 2018) -------------
# Very low <2.5%, Low 2.5-<10%, Medium 10-<20%, High 20-<30%, Very high >=30%
threshold_colors <- c(
  "Very low"  = "#2DC937",
  "Low"       = "#99C140",
  "Medium"    = "#E7B416",

  "High"      = "#DB7B2B",
  "Very high" = "#CC3232"
)

classify_threshold <- function(prev) {
  dplyr::case_when(
    prev < 2.5  ~ "Very low",
    prev < 10   ~ "Low",
    prev < 20   ~ "Medium",
    prev < 30   ~ "High",
    TRUE        ~ "Very high"
  )
}

# Figure 1: Highest prevalence (top 10)
f1_data <- top20_highest %>% head(10) %>% make_label() %>%
  mutate(threshold = classify_threshold(prevalence))
fig1 <- ggplot(f1_data, aes(x = label, y = prevalence, fill = threshold)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", prevalence)),
            hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  coord_flip(ylim = c(0, max(f1_data$prevalence, na.rm = TRUE) * 1.15)) +
  scale_fill_manual(values = threshold_colors, name = "Threshold",
                    drop = FALSE) +
  labs(title = paste0("Figure 1. Highest stunting prevalence (Top 10, ", latest_year, ")"),
       x = NULL, y = "Prevalence (%)") +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        legend.position = "bottom", legend.text = element_text(size = 7),
        legend.title = element_text(size = 8))

ggsave(file.path(fig_dir, "fig1_highest_prevalence.png"), fig1,
       width = 7, height = 6, dpi = 150)
ggsave(file.path(svg_dir, "fig1_highest_prevalence.svg"), fig1,
       width = 7, height = 6, device = "svg")
message("Saved: fig1_highest_prevalence.png + .svg")

# Figure 2: 10-year prevalence reduction (top 10)
f2_data <- top20_improve_10 %>% head(10) %>%
  mutate(reduction = abs(change_pp)) %>% make_label()
fig2 <- ggplot(f2_data, aes(x = label, y = reduction)) +
  geom_col(fill = "#00A79D", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f pp", reduction)),
            hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  coord_flip(ylim = c(0, max(f2_data$reduction, na.rm = TRUE) * 1.15)) +
  labs(title = paste0("Figure 2. Largest 10-year prevalence reduction (", yr_10_ago, "\u2013", latest_year, ")"),
       x = NULL, y = "Reduction (pp)") +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

ggsave(file.path(fig_dir, "fig2_10yr_prevalence_reduction.png"), fig2,
       width = 7, height = 6, dpi = 150)
ggsave(file.path(svg_dir, "fig2_10yr_prevalence_reduction.svg"), fig2,
       width = 7, height = 6, device = "svg")
message("Saved: fig2_10yr_prevalence_reduction.png + .svg")

# Figure 3: 20-year prevalence reduction (top 10)
f3_data <- top20_improve_20 %>% head(10) %>%
  mutate(reduction = abs(change_pp)) %>% make_label()
fig3 <- ggplot(f3_data, aes(x = label, y = reduction)) +
  geom_col(fill = "#003A70", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f pp", reduction)),
            hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  coord_flip(ylim = c(0, max(f3_data$reduction, na.rm = TRUE) * 1.15)) +
  labs(title = paste0("Figure 3. Largest 20-year prevalence reduction (", yr_20_ago, "\u2013", latest_year, ")"),
       x = NULL, y = "Reduction (pp)") +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

ggsave(file.path(fig_dir, "fig3_20yr_prevalence_reduction.png"), fig3,
       width = 7, height = 6, dpi = 150)
ggsave(file.path(svg_dir, "fig3_20yr_prevalence_reduction.svg"), fig3,
       width = 7, height = 6, device = "svg")
message("Saved: fig3_20yr_prevalence_reduction.png + .svg")

# Figure 4: Highest burden (top 10)
if (has_numbers) {
  f4_data <- top20_highest_num %>% head(10) %>% make_label() %>%
    mutate(threshold = classify_threshold(prevalence))
  fig4 <- ggplot(f4_data, aes(x = label, y = number_thousands, fill = threshold)) +
    geom_col(width = 0.7) +
    geom_text(aes(label = sprintf("%.1f M", number_thousands / 1000)),
              hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
    coord_flip(ylim = c(0, max(f4_data$number_thousands, na.rm = TRUE) * 1.15)) +
    scale_fill_manual(values = threshold_colors, name = "Prevalence\nthreshold",
                      drop = FALSE) +
    labs(title = paste0("Figure 4. Highest number of stunted children (Top 10, ", latest_year, ")"),
         x = NULL, y = "Children (thousands)") +
    theme_minimal(base_size = 9) +
    theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
          panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
          legend.position = "bottom", legend.text = element_text(size = 7),
          legend.title = element_text(size = 8))

  ggsave(file.path(fig_dir, "fig4_highest_burden.png"), fig4,
         width = 7, height = 6, dpi = 150)
  ggsave(file.path(svg_dir, "fig4_highest_burden.svg"), fig4,
         width = 7, height = 6, device = "svg")
  message("Saved: fig4_highest_burden.png + .svg")
}

# Figure 5: 10-year burden reduction (top 10)
if (has_numbers) {
  f5_data <- top20_improve_10_num %>% head(10) %>%
    mutate(reduction_th = abs(change_th)) %>% make_label()
  fig5 <- ggplot(f5_data, aes(x = label, y = reduction_th)) +
    geom_col(fill = "#00A79D", width = 0.7) +
    geom_text(aes(label = sprintf("%.1f M", reduction_th / 1000)),
              hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
    coord_flip(ylim = c(0, max(f5_data$reduction_th, na.rm = TRUE) * 1.15)) +
    labs(title = paste0("Figure 5. Largest 10-year reduction in stunted children (", yr_10_ago, "\u2013", latest_year, ")"),
         subtitle = "Labels in millions",
         x = NULL, y = "Reduction (thousands)") +
    theme_minimal(base_size = 9) +
    theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
          plot.subtitle = element_text(size = 8, colour = "#4D4D4D"),
          panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

  ggsave(file.path(fig_dir, "fig5_10yr_burden_reduction.png"), fig5,
         width = 7, height = 6, dpi = 150)
  ggsave(file.path(svg_dir, "fig5_10yr_burden_reduction.svg"), fig5,
         width = 7, height = 6, device = "svg")
  message("Saved: fig5_10yr_burden_reduction.png + .svg")
}

# Figure 6: 20-year burden reduction (top 10)
if (has_numbers) {
  f6_data <- top20_improve_20_num %>% head(10) %>%
    mutate(reduction_th = abs(change_th)) %>% make_label()
  fig6 <- ggplot(f6_data, aes(x = label, y = reduction_th)) +
    geom_col(fill = "#003A70", width = 0.7) +
    geom_text(aes(label = sprintf("%.1f M", reduction_th / 1000)),
              hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
    coord_flip(ylim = c(0, max(f6_data$reduction_th, na.rm = TRUE) * 1.15)) +
    labs(title = paste0("Figure 6. Largest 20-year reduction in stunted children (", yr_20_ago, "\u2013", latest_year, ")"),
         subtitle = "Labels in millions",
         x = NULL, y = "Reduction (thousands)") +
    theme_minimal(base_size = 9) +
    theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
          plot.subtitle = element_text(size = 8, colour = "#4D4D4D"),
          panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

  ggsave(file.path(fig_dir, "fig6_20yr_burden_reduction.png"), fig6,
         width = 7, height = 6, dpi = 150)
  ggsave(file.path(svg_dir, "fig6_20yr_burden_reduction.svg"), fig6,
         width = 7, height = 6, device = "svg")
  message("Saved: fig6_20yr_burden_reduction.png + .svg")
}

# --- Dot plot helper (shared theme for Figures 7-10) ----------------------
dot_theme <- theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        legend.position = "top", legend.text = element_text(size = 8),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

make_dot_plot <- function(data, baseline_yr, current_yr, title_text,
                          x_lab = "Prevalence (%)", x_fmt = waiver(),
                          color_by_threshold = FALSE) {
  p <- ggplot(data, aes(y = label)) +
    geom_segment(aes(x = current_value, xend = baseline_value, yend = label),
                 colour = "#AAAAAA", linewidth = 0.5)

  if (color_by_threshold && "threshold_baseline" %in% names(data)) {
    p <- p +
      geom_point(aes(x = baseline_value, fill = threshold_baseline),
                 shape = 21, size = 2.5, colour = "grey30", stroke = 0.3) +
      geom_point(aes(x = current_value, fill = threshold_current),
                 shape = 21, size = 2.5, colour = "grey30", stroke = 0.3) +
      scale_fill_manual(values = threshold_colors, name = "Threshold",
                        drop = FALSE)
  } else {
    p <- p +
      geom_point(aes(x = baseline_value, colour = "baseline"), size = 2.2) +
      geom_point(aes(x = current_value,  colour = "current"),  size = 2.2) +
      scale_colour_manual(
        values = stats::setNames(c("#E36F1E", "#00A79D"), c("baseline", "current")),
        labels = stats::setNames(c(as.character(baseline_yr), as.character(current_yr)),
                                 c("baseline", "current")),
        breaks = c("baseline", "current")
      )
  }

  p + scale_x_reverse(labels = x_fmt) +
    labs(title = title_text, x = x_lab, y = NULL, colour = NULL, fill = NULL) +
    dot_theme
}

# Figure 7: Before/after dot plot — 10-year prevalence
f7_data <- top20_improve_10 %>%
  head(10) %>%
  arrange(desc(baseline_value)) %>%
  make_label() %>%
  mutate(threshold_baseline = classify_threshold(baseline_value),
         threshold_current  = classify_threshold(current_value))

fig7 <- make_dot_plot(f7_data, yr_10_ago, latest_year,
  title_text = paste0("Figure 7. Stunting prevalence before and after (", yr_10_ago, " vs ", latest_year, ")"),
  color_by_threshold = TRUE)

ggsave(file.path(fig_dir, "fig7_before_after_prev_10yr.png"), fig7,
       width = 7, height = 5, dpi = 150)
ggsave(file.path(svg_dir, "fig7_before_after_prev_10yr.svg"), fig7,
       width = 7, height = 5, device = "svg")
message("Saved: fig7_before_after_prev_10yr.png + .svg")

# Figure 8: Before/after dot plot — 20-year prevalence
f8_data <- top20_improve_20 %>%
  head(10) %>%
  arrange(desc(baseline_value)) %>%
  make_label() %>%
  mutate(threshold_baseline = classify_threshold(baseline_value),
         threshold_current  = classify_threshold(current_value))

fig8 <- make_dot_plot(f8_data, yr_20_ago, latest_year,
  title_text = paste0("Figure 8. Stunting prevalence before and after (", yr_20_ago, " vs ", latest_year, ")"),
  color_by_threshold = TRUE)

ggsave(file.path(fig_dir, "fig8_before_after_prev_20yr.png"), fig8,
       width = 7, height = 5, dpi = 150)
ggsave(file.path(svg_dir, "fig8_before_after_prev_20yr.svg"), fig8,
       width = 7, height = 5, device = "svg")
message("Saved: fig8_before_after_prev_20yr.png + .svg")

# Figure 9: Before/after dot plot — 10-year burden
if (has_numbers) {
  f9_data <- top20_improve_10_num %>%
    head(10) %>%
    arrange(desc(baseline_value)) %>%
    make_label() %>%
    mutate(threshold_baseline = classify_threshold(baseline_prevalence),
           threshold_current  = classify_threshold(current_prevalence))

  fig9 <- make_dot_plot(f9_data, yr_10_ago, latest_year,
    title_text = paste0("Figure 9. Stunted children before and after (", yr_10_ago, " vs ", latest_year, ")"),
    x_lab = "Children (thousands)",
    x_fmt = function(x) sprintf("%.1f M", x / 1000),
    color_by_threshold = TRUE)

  ggsave(file.path(fig_dir, "fig9_before_after_burden_10yr.png"), fig9,
         width = 7, height = 5, dpi = 150)
  ggsave(file.path(svg_dir, "fig9_before_after_burden_10yr.svg"), fig9,
         width = 7, height = 5, device = "svg")
  message("Saved: fig9_before_after_burden_10yr.png + .svg")
}

# Figure 10: Before/after dot plot — 20-year burden
if (has_numbers) {
  f10_data <- top20_improve_20_num %>%
    head(10) %>%
    arrange(desc(baseline_value)) %>%
    make_label() %>%
    mutate(threshold_baseline = classify_threshold(baseline_prevalence),
           threshold_current  = classify_threshold(current_prevalence))

  fig10 <- make_dot_plot(f10_data, yr_20_ago, latest_year,
    title_text = paste0("Figure 10. Stunted children before and after (", yr_20_ago, " vs ", latest_year, ")"),
    x_lab = "Children (thousands)",
    x_fmt = function(x) sprintf("%.1f M", x / 1000),
    color_by_threshold = TRUE)

  ggsave(file.path(fig_dir, "fig10_before_after_burden_20yr.png"), fig10,
         width = 7, height = 5, dpi = 150)
  ggsave(file.path(svg_dir, "fig10_before_after_burden_20yr.svg"), fig10,
         width = 7, height = 5, device = "svg")
  message("Saved: fig10_before_after_burden_20yr.png + .svg")
}

# --- Embed figures into Excel sheets --------------------------------------
# Place each figure image below the data table (starting ~row 25) on the
# matching sheet. Image dimensions in Excel units (width in columns ≈ inches).
img_start_row <- 24

openxlsx::insertImage(wb, "T1_highest_prevalence",
                      file.path(fig_dir, "fig1_highest_prevalence.png"),
                      startRow = img_start_row, startCol = 1, width = 7, height = 6,
                      units = "in")

openxlsx::insertImage(wb, "T2_improve_10yr_prev",
                      file.path(fig_dir, "fig2_10yr_prevalence_reduction.png"),
                      startRow = img_start_row, startCol = 1, width = 7, height = 6,
                      units = "in")

openxlsx::insertImage(wb, "T3_improve_20yr_prev",
                      file.path(fig_dir, "fig3_20yr_prevalence_reduction.png"),
                      startRow = img_start_row, startCol = 1, width = 7, height = 6,
                      units = "in")

if (has_numbers) {
  openxlsx::insertImage(wb, "T4_highest_number",
                        file.path(fig_dir, "fig4_highest_burden.png"),
                        startRow = img_start_row, startCol = 1, width = 7, height = 6,
                        units = "in")

  openxlsx::insertImage(wb, "T5_improve_10yr_number",
                        file.path(fig_dir, "fig5_10yr_burden_reduction.png"),
                        startRow = img_start_row, startCol = 1, width = 7, height = 6,
                        units = "in")

  openxlsx::insertImage(wb, "T6_improve_20yr_number",
                        file.path(fig_dir, "fig6_20yr_burden_reduction.png"),
                        startRow = img_start_row, startCol = 1, width = 7, height = 6,
                        units = "in")
}

# Before/after dot plots — each gets its own sheet with data + image
fig_img_start <- 14  # image starts below the data rows

openxlsx::addWorksheet(wb, "Fig7_prev_10yr")
openxlsx::writeData(wb, "Fig7_prev_10yr", f7_data)
openxlsx::insertImage(wb, "Fig7_prev_10yr",
                      file.path(fig_dir, "fig7_before_after_prev_10yr.png"),
                      startRow = fig_img_start, startCol = 1, width = 7, height = 5,
                      units = "in")

openxlsx::addWorksheet(wb, "Fig8_prev_20yr")
openxlsx::writeData(wb, "Fig8_prev_20yr", f8_data)
openxlsx::insertImage(wb, "Fig8_prev_20yr",
                      file.path(fig_dir, "fig8_before_after_prev_20yr.png"),
                      startRow = fig_img_start, startCol = 1, width = 7, height = 5,
                      units = "in")

if (has_numbers) {
  openxlsx::addWorksheet(wb, "Fig9_burden_10yr")
  openxlsx::writeData(wb, "Fig9_burden_10yr", f9_data)
  openxlsx::insertImage(wb, "Fig9_burden_10yr",
                        file.path(fig_dir, "fig9_before_after_burden_10yr.png"),
                        startRow = fig_img_start, startCol = 1, width = 7, height = 5,
                        units = "in")

  openxlsx::addWorksheet(wb, "Fig10_burden_20yr")
  openxlsx::writeData(wb, "Fig10_burden_20yr", f10_data)
  openxlsx::insertImage(wb, "Fig10_burden_20yr",
                        file.path(fig_dir, "fig10_before_after_burden_20yr.png"),
                        startRow = fig_img_start, startCol = 1, width = 7, height = 5,
                        units = "in")
}

openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("Saved: ", xlsx_path)

# --- Markdown v3: sheet-by-sheet with figures and findings ----------------
top1_prev <- top20_highest[1, ]
top1_impr10 <- top20_improve_10[1, ]
top1_impr20 <- top20_improve_20[1, ]
max_pace_10 <- sprintf("%.1f", max(abs(top20_improve_10$change_pp), na.rm = TRUE) / 10)

md_lines <- c(
  "# Stunting Rankings \u2014 Tables and Figures (v3)",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
  paste0("Data year: ", latest_year, " | 10-year baseline: ", yr_10_ago, " | 20-year baseline: ", yr_20_ago),
  "",
  "---",
  "",
  "## T1 \u2014 Highest prevalence (top 20)",
  "",
  paste0("**Figure:** `fig1_highest_prevalence.png` (top 10)"),
  "",
  paste0("**Key finding:** ", top1_prev$country_name, " had the highest stunting prevalence at ",
         sprintf("%.1f", top1_prev$prevalence), "% in ", latest_year,
         ". The top five were ", paste(top20_highest$country_name[1:5], collapse = ", "), "."),
  "",
  "**Points of interest:** The highest-prevalence countries are concentrated in sub-Saharan Africa, with one Pacific country (Papua New Guinea) in the top five. Severity (prevalence) and scale (burden) should be interpreted together; the two lists overlap but are not identical.",
  "",
  "---",
  "",
  "## T2 \u2014 Biggest 10-year prevalence reduction (top 20)",
  "",
  paste0("**Figure:** `fig2_10yr_prevalence_reduction.png` (top 10)"),
  "",
  paste0("**Key finding:** The fastest reducer was ", top1_impr10$country_name,
         " with a decline of ", sprintf("%.1f", abs(top1_impr10$change_pp)), " percentage points (",
         yr_10_ago, "\u2013", latest_year, "). At the upper end, the pace was about ",
         max_pace_10, " percentage points per year."),
  "",
  "**Points of interest:** Modeled estimates are suitable for trend interpretation but rapid shocks (conflict, crises) may not be immediately reflected because of a lack of data in affected countries.",
  "",
  "---",
  "",
  "## T3 \u2014 Biggest 20-year prevalence reduction (top 20)",
  "",
  paste0("**Figure:** `fig3_20yr_prevalence_reduction.png` (top 10)"),
  "",
  paste0("**Key finding:** The largest reduction over two decades was ", top1_impr20$country_name,
         " with ", sprintf("%.1f", abs(top1_impr20$change_pp)),
         " percentage points (", yr_20_ago, "\u2013", latest_year, ")."),
  "",
  "**Points of interest:** Several countries appear in both the 10-year and 20-year top improver lists, suggesting sustained long-run progress.",
  ""
)

if (has_numbers) {
  top1_num   <- top20_highest_num[1, ]
  top1_num10 <- top20_improve_10_num[1, ]
  top1_num20 <- top20_improve_20_num[1, ]

  md_lines <- c(md_lines,
    "---", "",
    "## T4 \u2014 Highest burden: number of stunted children (top 20)",
    "",
    paste0("**Figure:** `fig4_highest_burden.png` (top 10)"),
    "",
    paste0("**Key finding:** ", top1_num$country_name, " had the largest estimated number of stunted children (",
           sprintf("%.1f", top1_num$number_thousands / 1000), " million). The top five were ",
           paste(top20_highest_num$country_name[1:5], collapse = ", "), "."),
    "",
    "**Points of interest:** The highest-burden countries span South Asia and sub-Saharan Africa. Countries with the largest burden reductions (e.g. India) can still remain the largest-burden country.",
    "",
    "---", "",
    "## T5 \u2014 Biggest 10-year burden reduction (top 20)",
    "",
    paste0("**Figure:** `fig5_10yr_burden_reduction.png` (top 10)"),
    "",
    paste0("**Key finding:** ", top1_num10$country_name,
           " had the largest 10-year reduction in number of stunted children (",
           sprintf("%.1f", abs(top1_num10$change_th) / 1000), " million fewer, ",
           yr_10_ago, "\u2013", latest_year, ")."),
    "",
    "**Points of interest:** Large burden reductions were concentrated in South and East Asia, while many sub-Saharan African countries remained high-burden despite some prevalence improvement, suggesting population growth offset prevalence reductions.",
    "",
    "---", "",
    "## T6 \u2014 Biggest 20-year burden reduction (top 20)",
    "",
    paste0("**Figure:** `fig6_20yr_burden_reduction.png` (top 10)"),
    "",
    paste0("**Key finding:** ", top1_num20$country_name,
           " had the largest 20-year reduction (",
           sprintf("%.1f", abs(top1_num20$change_th) / 1000), " million fewer, ",
           yr_20_ago, "\u2013", latest_year, ")."),
    "",
    "**Points of interest:** The 20-year window shows that very large absolute reductions are possible at scale, even in countries that remain in the highest-burden list.",
    "",
    "---", "",
    "## T7 \u2014 Overlap countries (both prevalence and burden top 20)",
    "",
    "**Figure:** none (table only)",
    "",
    paste0("**Key finding:** ", nrow(tbl_overlap), " countries appeared in both the top-20 prevalence and top-20 burden lists: ",
           paste(tbl_overlap$country_name, collapse = ", "), "."),
    "",
    "**Points of interest:** Targeting these overlap countries can enable an equity-focused approach while also targeting settings where absolute impact can be largest.",
    "",
    "---", "",
    "## T8 \u2014 Concentration metrics",
    "",
    "**Figure:** none (summary table)",
    "",
    paste0("**Key finding:** Of the ", sprintf("%.1f", global_total_m),
           " million stunted children globally, India alone accounted for ",
           sprintf("%.1f", india_burden_m), " million (",
           sprintf("%.1f%%", india_share), "). The top 5 burden countries accounted for ",
           sprintf("%.1f%%", top5_share), ", the top 10 for ",
           sprintf("%.1f%%", top10_share), ", and the top 20 for ", sprintf("%.1f%%", top20_share), "."),
    "",
    "**Points of interest:** Burden is highly concentrated; the top 20 countries represent about three quarters of the global total.",
    "",
    "---", "",
    "## T9 \u2014 Reduction concentration (20-year)",
    "",
    "**Figure:** none (summary table)",
    "",
    paste0("**Key finding:** The global number of stunted children fell from ",
           sprintf("%.1f", global_20yr_baseline_m), " million in ", yr_20_ago,
           " to ", sprintf("%.1f", global_total_m), " million in ", latest_year,
           ", a reduction of ", sprintf("%.1f", global_20yr_reduction_m), " million. India alone accounted for ",
           sprintf("%.1f", india_red_m), " million of that reduction (",
           sprintf("%.1f%%", india_red_share), "). The top 5 reducers accounted for ",
           sprintf("%.1f%%", top5_red_share), ", the top 10 for ",
           sprintf("%.1f%%", top10_red_share), ", and the top 20 for ",
           sprintf("%.1f%%", top20_red_share), "."),
    "",
    "**Points of interest:** Reduction in global stunting burden has been even more concentrated than current burden itself, with a handful of populous countries driving the bulk of progress.",
    ""
  )
}

md_lines <- c(md_lines,
  "---", "",
  "## Fig7 \u2014 Prevalence before and after, 10-year (dot plot)",
  "",
  paste0("**Figure:** `fig7_before_after_prev_10yr.png` (top 10)"),
  "",
  paste0("**Key finding:** The dot plot shows the shift in prevalence from ", yr_10_ago,
         " to ", latest_year, " for the top 10 improvers, visualizing both the starting point and the magnitude of change."),
  "",
  "**Points of interest:** Countries that started at higher prevalence levels tended to show larger absolute reductions, but relative progress varied widely.",
  "",
  "---", "",
  "## Fig8 \u2014 Prevalence before and after, 20-year (dot plot)",
  "",
  paste0("**Figure:** `fig8_before_after_prev_20yr.png` (top 10)"),
  "",
  paste0("**Key finding:** Over 20 years (", yr_20_ago, "\u2013", latest_year,
         "), the top 10 improvers showed substantial prevalence shifts. The longer time window reveals larger cumulative reductions."),
  "",
  "**Points of interest:** Countries with the largest 20-year reductions often started from very high prevalence levels (>40%).",
  ""
)

if (has_numbers) {
  md_lines <- c(md_lines,
    "---", "",
    "## Fig9 \u2014 Burden before and after, 10-year (dot plot)",
    "",
    paste0("**Figure:** `fig9_before_after_burden_10yr.png` (top 10)"),
    "",
    paste0("**Key finding:** The dot plot shows the shift in number of stunted children from ", yr_10_ago,
           " to ", latest_year, " for the top 10 reducers. Large-population countries dominate the largest absolute reductions."),
    "",
    "**Points of interest:** The magnitude of reduction in populous countries (e.g. India, China) dwarfs reductions elsewhere in absolute terms, even when smaller countries show faster relative progress.",
    "",
    "---", "",
    "## Fig10 \u2014 Burden before and after, 20-year (dot plot)",
    "",
    paste0("**Figure:** `fig10_before_after_burden_20yr.png` (top 10)"),
    "",
    paste0("**Key finding:** Over 20 years (", yr_20_ago, "\u2013", latest_year,
           "), the largest burden reductions were concentrated in a small number of very populous countries."),
    "",
    "**Points of interest:** The 20-year view reinforces that global stunting reductions have been driven disproportionately by progress in a handful of countries with very large child populations.",
    ""
  )
}

md_lines <- c(md_lines,
  "---", "",
  "## Data Source", "",
  "OSE-DA-NT stunting outputs from `cmrs2_series_accepted.parquet` through `2_prepare_inputs.r` and `3_stunting_rankings.r`.",
  "Includes `stunting_modeled.parquet` (prevalence) and `stunting_numbers.parquet` (burden).",
  paste0("Rankings universe: ", nrow(stnt %>% filter(TIME_PERIOD == latest_year) %>% distinct(REF_AREA)), " countries."),
  ""
)

doc_dir <- file.path(getwd(), "adhoc_analysis", "stunting_top20_briefing", "00_documentation")

# --- v3 clean markdown ----------------------------------------------------
md_v3_path <- file.path(doc_dir, "stunting_tables_and_figures_v3.md")
writeLines(md_lines, md_v3_path)
message("Saved: ", md_v3_path)

# --- v3 review copy -------------------------------------------------------
review_v3_path <- file.path(doc_dir, "stunting_tables_and_figures_v3.review.md")
writeLines(md_lines, review_v3_path)
message("Saved: ", review_v3_path)

# --- v3 tracked-changes markdown ------------------------------------------
# ~~strikethrough~~ = removed from v2, **bold** = added in v3
trk <- c(
  "# Stunting Rankings \u2014 Tables and Figures (v3 \u2014 tracked changes from v2)",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
  paste0("Data year: ", latest_year, " | 10-year baseline: ", yr_10_ago, " | 20-year baseline: ", yr_20_ago),
  "",
  "*Legend: ~~strikethrough~~ = removed from v2, **bold** = added/changed in v3*",
  "",
  "---",
  "",
  "## Global changes (v2 \u2192 v3)",
  "",
  "- Dot plots (Figures 7\u201310) now show **top 10** countries instead of ~~top 15~~.",
  "- T8 Concentration metrics: **added India\u2019s individual share** and **top 10 tier**.",
  "- **New T9**: Reduction concentration metrics (20-year) \u2014 shows how much of the global reduction was India/top 5/top 10/top 20.",
  "",
  "---",
  "",
  "## T1\u2013T7 \u2014 *(unchanged from v2)*",
  "",
  "---",
  "",
  "## T8 \u2014 Concentration metrics",
  "",
  paste0("Key finding: Of the ", sprintf("%.1f", global_total_m),
         " million stunted children globally, **India alone accounted for ",
         sprintf("%.1f", india_burden_m), " million (",
         sprintf("%.1f%%", india_share), ")**. The top 5 burden countries accounted for ",
         sprintf("%.1f%%", top5_share), ", **the top 10 for ",
         sprintf("%.1f%%", top10_share), ",** and the top 20 for ", sprintf("%.1f%%", top20_share), "."),
  "",
  "Points of interest: *(unchanged)*",
  "",
  "---",
  "",
  "## **T9 \u2014 Reduction concentration (20-year)** *(NEW)*",
  "",
  paste0("Global stunted children fell from ", sprintf("%.1f", global_20yr_baseline_m),
         "M (", yr_20_ago, ") to ", sprintf("%.1f", global_total_m),
         "M (", latest_year, "), a reduction of ", sprintf("%.1f", global_20yr_reduction_m), "M."),
  "",
  paste0("- India alone: ", sprintf("%.1f", india_red_m), "M (",
         sprintf("%.1f%%", india_red_share), " of global reduction)"),
  paste0("- Top 5: ", sprintf("%.1f%%", top5_red_share)),
  paste0("- Top 10: ", sprintf("%.1f%%", top10_red_share)),
  paste0("- Top 20: ", sprintf("%.1f%%", top20_red_share)),
  "",
  "---",
  "",
  "## Figs 7\u201310 \u2014 Dot plots",
  "",
  "- All reduced from ~~top 15~~ to **top 10** countries.",
  "- Figure content and axis design unchanged from v2.",
  ""
)

trk_v3_path <- file.path(doc_dir, "stunting_tables_and_figures_v3_tracked.md")
writeLines(trk, trk_v3_path)
message("Saved: ", trk_v3_path)
