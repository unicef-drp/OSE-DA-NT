# ---------------------------------------------------------------------------
# Script:  3_stunting_rankings.r
# Purpose: Compute top-20 country rankings for stunting (prevalence and
#          burden), generate summary tables, figures, concentration metrics,
#          and overlap analysis. Produces:
#            - stunting_rankings.rds (R list for downstream scripts)
#            - stunting_rankings.csv (combined human-readable)
#            - stunting_tables_and_figures.xlsx (one sheet per table)
#            - stunting_tables_and_figures.md (figures list + key findings)
#            - stunting_tables_and_figures.review.md (clean review copy)
#            - figures/ folder with PNG charts (Figures 1-7)
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

# --- Country name lookup --------------------------------------------------
add_country_name <- function(df) {
  df %>% mutate(
    country_name = countrycode(REF_AREA, origin = "iso3c", destination = "country.name",
                               warn = FALSE)
  )
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

  # Top 20 highest number of stunted children (r in thousands)
  top20_highest_num <- stnt_num %>%
    filter(TIME_PERIOD == latest_year) %>%
    arrange(desc(r)) %>%
    head(20) %>%
    add_country_name() %>%
    mutate(rank = row_number()) %>%
    select(rank, REF_AREA, country_name, year = TIME_PERIOD, number_thousands = r)

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

  top20_improve_10_num <- compute_improvement_num(stnt_num, yr_10_ago, latest_year)
  message("\n=== Top 20 biggest reduction in stunted numbers (", yr_10_ago, "-", latest_year, ") ===")
  print(top20_improve_10_num, n = 20)

  top20_improve_20_num <- compute_improvement_num(stnt_num, yr_20_ago, latest_year)
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
  top5_burden_m  <- sum(head(top20_highest_num$number_thousands, 5), na.rm = TRUE) / 1000
  top20_burden_m <- sum(head(top20_highest_num$number_thousands, 20), na.rm = TRUE) / 1000
  top5_share     <- 100 * top5_burden_m / global_total_m
  top20_share    <- 100 * top20_burden_m / global_total_m

  concentration <- data.frame(
    metric = c(
      "Global stunted children (2024)",
      "Top 5 burden countries",
      "Top 5 share of global total",
      "Top 20 burden countries",
      "Top 20 share of global total",
      "Overlap countries (both top-20 lists)"
    ),
    value = c(
      sprintf("%.1f million", global_total_m),
      sprintf("%.1f million", top5_burden_m),
      sprintf("%.1f%%", top5_share),
      sprintf("%.1f million", top20_burden_m),
      sprintf("%.1f%%", top20_share),
      as.character(nrow(tbl_overlap))
    ),
    stringsAsFactors = FALSE
  )

  message("\n=== Concentration metrics ===")
  print(concentration)
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
      select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
    top20_improve_10_num %>% mutate(ranking = paste0("improve_10yr_number_", yr_10_ago, "_", latest_year)) %>%
      rename(change_pp = change_th) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change),
    top20_improve_20_num %>% mutate(ranking = paste0("improve_20yr_number_", yr_20_ago, "_", latest_year)) %>%
      rename(change_pp = change_th) %>%
      select(ranking, rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
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
}

xlsx_path <- file.path(output_dir, "stunting_tables_and_figures.xlsx")
openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("Saved: ", xlsx_path)

# --- Figures (PNG) --------------------------------------------------------
fig_dir <- file.path(output_dir, "figures")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

make_label <- function(df) {
  df %>% mutate(
    label = paste0(country_name, " (", REF_AREA, ")"),
    label = factor(label, levels = rev(label))
  )
}

# Figure 1: Highest prevalence (top 20)
f1_data <- top20_highest %>% make_label()
fig1 <- ggplot(f1_data, aes(x = label, y = prevalence)) +
  geom_col(fill = "#1CABE2", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", prevalence)),
            hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  coord_flip(ylim = c(0, max(f1_data$prevalence, na.rm = TRUE) * 1.15)) +
  labs(title = paste0("Figure 1. Highest stunting prevalence (Top 20, ", latest_year, ")"),
       x = NULL, y = "Prevalence (%)") +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

ggsave(file.path(fig_dir, "fig1_highest_prevalence.png"), fig1,
       width = 7, height = 6, dpi = 150)
message("Saved: fig1_highest_prevalence.png")

# Figure 2: Highest burden (top 20)
if (has_numbers) {
  f2_data <- top20_highest_num %>% make_label()
  fig2 <- ggplot(f2_data, aes(x = label, y = number_thousands)) +
    geom_col(fill = "#D4508B", width = 0.7) +
    geom_text(aes(label = sprintf("%.1f M", number_thousands / 1000)),
              hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
    coord_flip(ylim = c(0, max(f2_data$number_thousands, na.rm = TRUE) * 1.15)) +
    labs(title = paste0("Figure 2. Highest number of stunted children (Top 20, ", latest_year, ")"),
         x = NULL, y = "Children (thousands)") +
    theme_minimal(base_size = 9) +
    theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
          panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

  ggsave(file.path(fig_dir, "fig2_highest_burden.png"), fig2,
         width = 7, height = 6, dpi = 150)
  message("Saved: fig2_highest_burden.png")
}

# Figure 3: 10-year prevalence reduction (top 20)
f3_data <- top20_improve_10 %>%
  mutate(reduction = abs(change_pp)) %>% make_label()
fig3 <- ggplot(f3_data, aes(x = label, y = reduction)) +
  geom_col(fill = "#00A79D", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f pp", reduction)),
            hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  coord_flip(ylim = c(0, max(f3_data$reduction, na.rm = TRUE) * 1.15)) +
  labs(title = paste0("Figure 3. Largest 10-year prevalence reduction (", yr_10_ago, "\u2013", latest_year, ")"),
       x = NULL, y = "Reduction (pp)") +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

ggsave(file.path(fig_dir, "fig3_10yr_prevalence_reduction.png"), fig3,
       width = 7, height = 6, dpi = 150)
message("Saved: fig3_10yr_prevalence_reduction.png")

# Figure 4: 20-year prevalence reduction (top 20)
f4_data <- top20_improve_20 %>%
  mutate(reduction = abs(change_pp)) %>% make_label()
fig4 <- ggplot(f4_data, aes(x = label, y = reduction)) +
  geom_col(fill = "#003A70", width = 0.7) +
  geom_text(aes(label = sprintf("%.1f pp", reduction)),
            hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  coord_flip(ylim = c(0, max(f4_data$reduction, na.rm = TRUE) * 1.15)) +
  labs(title = paste0("Figure 4. Largest 20-year prevalence reduction (", yr_20_ago, "\u2013", latest_year, ")"),
       x = NULL, y = "Reduction (pp)") +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

ggsave(file.path(fig_dir, "fig4_20yr_prevalence_reduction.png"), fig4,
       width = 7, height = 6, dpi = 150)
message("Saved: fig4_20yr_prevalence_reduction.png")

# Figure 5: 10-year burden reduction (top 20)
if (has_numbers) {
  f5_data <- top20_improve_10_num %>%
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
  message("Saved: fig5_10yr_burden_reduction.png")
}

# Figure 6: 20-year burden reduction (top 20)
if (has_numbers) {
  f6_data <- top20_improve_20_num %>%
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
  message("Saved: fig6_20yr_burden_reduction.png")
}

# Figure 7: Before/after dot plot — 10-year prevalence
f7_data <- top20_improve_10 %>%
  head(15) %>%
  arrange(current_value) %>%
  make_label()

fig7 <- ggplot(f7_data, aes(y = label)) +
  geom_segment(aes(x = current_value, xend = baseline_value, yend = label),
               colour = "#AAAAAA", linewidth = 0.5) +
  geom_point(aes(x = current_value,  colour = "current"),  size = 2.2) +
  geom_point(aes(x = baseline_value, colour = "baseline"), size = 2.2) +
  scale_colour_manual(
    values = stats::setNames(c("#00A79D", "#E36F1E"), c("current", "baseline")),
    labels = stats::setNames(c(as.character(latest_year), as.character(yr_10_ago)),
                             c("current", "baseline")),
    breaks = c("current", "baseline")
  ) +
  labs(title = paste0("Figure 7. Stunting prevalence before and after (", yr_10_ago, " vs ", latest_year, ")"),
       x = "Prevalence (%)", y = NULL, colour = NULL) +
  theme_minimal(base_size = 9) +
  theme(plot.title = element_text(face = "bold", colour = "#003A70", size = 10),
        legend.position = "top", legend.text = element_text(size = 8),
        panel.grid.major.y = element_blank(), panel.grid.minor = element_blank())

ggsave(file.path(fig_dir, "fig7_before_after_10yr.png"), fig7,
       width = 7, height = 5, dpi = 150)
message("Saved: fig7_before_after_10yr.png")

# --- Markdown: figures and key findings -----------------------------------
top1_prev <- top20_highest[1, ]
top1_impr10 <- top20_improve_10[1, ]
top1_impr20 <- top20_improve_20[1, ]
max_pace_10 <- sprintf("%.1f", max(abs(top20_improve_10$change_pp), na.rm = TRUE) / 10)

md_lines <- c(
  "# Stunting Rankings — Tables, Figures, and Key Findings",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  paste0("Data year: ", latest_year, " | 10-year baseline: ", yr_10_ago, " | 20-year baseline: ", yr_20_ago),
  "",
  "---",
  "",
  "## Figures",
  "",
  paste0("- **Figure 1.** Highest stunting prevalence (Top 20, ", latest_year, ") — `fig1_highest_prevalence.png`")
)

if (has_numbers) {
  md_lines <- c(md_lines,
    paste0("- **Figure 2.** Highest number of stunted children (Top 20, ", latest_year, ") — `fig2_highest_burden.png`"))
}

md_lines <- c(md_lines,
  paste0("- **Figure 3.** Largest 10-year prevalence reduction (", yr_10_ago, "\u2013", latest_year, ") — `fig3_10yr_prevalence_reduction.png`"),
  paste0("- **Figure 4.** Largest 20-year prevalence reduction (", yr_20_ago, "\u2013", latest_year, ") — `fig4_20yr_prevalence_reduction.png`")
)

if (has_numbers) {
  md_lines <- c(md_lines,
    paste0("- **Figure 5.** Largest 10-year reduction in stunted children (", yr_10_ago, "\u2013", latest_year, ") — `fig5_10yr_burden_reduction.png`"),
    paste0("- **Figure 6.** Largest 20-year reduction in stunted children (", yr_20_ago, "\u2013", latest_year, ") — `fig6_20yr_burden_reduction.png`"))
}

md_lines <- c(md_lines,
  paste0("- **Figure 7.** Prevalence before and after (", yr_10_ago, " vs ", latest_year, ") — `fig7_before_after_10yr.png`"),
  "",
  "## Tables (in Excel workbook `stunting_tables_and_figures.xlsx`)",
  "",
  "- **T1** Highest prevalence (top 20)",
  "- **T2** Biggest 10-year prevalence improvement (top 20)",
  "- **T3** Biggest 20-year prevalence improvement (top 20)"
)

if (has_numbers) {
  md_lines <- c(md_lines,
    "- **T4** Highest burden — number of stunted children (top 20)",
    "- **T5** Biggest 10-year burden reduction (top 20)",
    "- **T6** Biggest 20-year burden reduction (top 20)",
    "- **T7** Overlap countries appearing on both prevalence and burden top-20 lists",
    "- **T8** Concentration metrics (global total, top-5 share, top-20 share)")
}

md_lines <- c(md_lines, "",
  "---", "",
  "## Key Findings", "",

  paste0("1. **Highest prevalence**: ", top1_prev$country_name, " had the highest stunting prevalence at ",
         sprintf("%.1f", top1_prev$prevalence), "% in ", latest_year,
         ". The top five included ", paste(top20_highest$country_name[1:5], collapse = ", "), "."),
  ""
)

if (has_numbers) {
  top1_num <- top20_highest_num[1, ]
  md_lines <- c(md_lines,
    paste0("2. **Highest burden**: ", top1_num$country_name, " had the largest estimated number of stunted children (",
           sprintf("%.1f", top1_num$number_thousands / 1000), " million). The top five included ",
           paste(top20_highest_num$country_name[1:5], collapse = ", "), "."),
    ""
  )
}

md_lines <- c(md_lines,
  paste0("3. **10-year prevalence progress**: The fastest reducer was ", top1_impr10$country_name,
         " with a decline of ", sprintf("%.1f", abs(top1_impr10$change_pp)), " percentage points (",
         yr_10_ago, "\u2013", latest_year, "). At the upper end, the pace was about ",
         max_pace_10, " percentage points per year."),
  "",
  paste0("4. **20-year prevalence progress**: The largest reduction over two decades was ",
         top1_impr20$country_name, " with ", sprintf("%.1f", abs(top1_impr20$change_pp)),
         " percentage points (", yr_20_ago, "\u2013", latest_year, ")."),
  ""
)

if (has_numbers) {
  top1_num10 <- top20_improve_10_num[1, ]
  md_lines <- c(md_lines,
    paste0("5. **10-year burden reduction**: ", top1_num10$country_name,
           " had the largest reduction in number of stunted children (",
           sprintf("%.1f", abs(top1_num10$change_th) / 1000), " million fewer)."),
    "",
    paste0("6. **Concentration**: Of the ", sprintf("%.1f", global_total_m),
           " million stunted children globally, the top 5 burden countries accounted for ",
           sprintf("%.1f%%", top5_share), " and the top 20 for ", sprintf("%.1f%%", top20_share), "."),
    "",
    paste0("7. **Overlap**: ", nrow(tbl_overlap), " countries appeared in both the top-20 prevalence and top-20 burden lists: ",
           paste(tbl_overlap$country_name, collapse = ", "), "."),
    ""
  )
}

md_lines <- c(md_lines,
  "---", "",
  "## Points of Interest", "",
  "- Severity (prevalence) and scale (burden) should be interpreted together; the two lists overlap but are not identical.",
  "- The highest-prevalence countries are concentrated in sub-Saharan Africa, while the highest-burden countries span South Asia and sub-Saharan Africa.",
  "- Large burden reductions were concentrated in South and East Asia, while many sub-Saharan African countries remained high-burden despite some prevalence improvement.",
  "- Countries with the largest burden reductions (e.g. India) can still remain the largest-burden country, showing that absolute burden can persist in populous settings.",
  "- Modeled estimates are suitable for trend interpretation but rapid shocks (conflict, crises) may not be immediately reflected.",
  "",
  "---", "",
  "## Data Source", "",
  "OSE-DA-NT stunting outputs from `cmrs2_series_accepted.parquet` through `2_prepare_inputs.r` and `3_stunting_rankings.r`.",
  "Includes `stunting_modeled.parquet` (prevalence) and `stunting_numbers.parquet` (burden).",
  paste0("Rankings universe: ", nrow(stnt %>% filter(TIME_PERIOD == latest_year) %>% distinct(REF_AREA)), " countries."),
  ""
)

md_path <- file.path(output_dir, "stunting_tables_and_figures.md")
writeLines(md_lines, md_path)
message("Saved: ", md_path)

# --- Also create a clean review copy -------------------------------------
review_path <- file.path(output_dir, "stunting_tables_and_figures.review.md")
writeLines(md_lines, review_path)
message("Saved: ", review_path)
