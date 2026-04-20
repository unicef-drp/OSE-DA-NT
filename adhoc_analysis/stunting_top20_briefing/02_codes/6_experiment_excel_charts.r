# ---------------------------------------------------------------------------
# Script:  6_experiment_excel_charts.r
# Purpose: EXPERIMENT — Produce an Excel workbook with native editable charts
#          instead of embedded PNG images. Uses mschart + openxlsx2.
#          Output goes to a separate file so the original is untouched.
# Input:   03_outputs/stunting_rankings.rds (from 3_stunting_rankings.r)
# Output:  03_outputs/stunting_tables_and_figures_EDITABLE.xlsx
# ---------------------------------------------------------------------------

# --- Paths ----------------------------------------------------------------
if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis",
                               "stunting_top20_briefing")
output_dir <- file.path(adhoc_output_root, "03_outputs")

rds_path <- file.path(output_dir, "stunting_rankings.rds")
if (!file.exists(rds_path)) {
  stop("Input not found: ", rds_path, ". Run 3_stunting_rankings.r first.")
}

results <- readRDS(rds_path)
message("[6] Loaded rankings RDS")

# --- Reference years (from results metadata) ------------------------------
latest_year <- results$metadata$latest_year
yr_10_ago   <- results$metadata$yr_10_ago
yr_20_ago   <- results$metadata$yr_20_ago
has_numbers <- !is.null(results$highest_number)

# --- Helper: country label used in charts ---------------------------------
make_label <- function(df) {
  df %>% mutate(label = paste0(country_name, " (", REF_AREA, ")"))
}

# --- Colours (UNICEF brand) -----------------------------------------------
col_cyan    <- "#1CABE2"
col_teal    <- "#00A79D"
col_dark    <- "#003A70"
col_magenta <- "#D4508B"
col_orange  <- "#E36F1E"

# =========================================================================
# Build charts with mschart
# =========================================================================

# --- Theme shared across charts -------------------------------------------
bar_theme <- mschart_theme(
  main_title = fp_text(font.size = 11, bold = TRUE, color = col_dark,
                       font.family = "Calibri"),
  axis_title = fp_text(font.size = 9, color = "#3A3A3A",
                       font.family = "Calibri"),
  axis_text  = fp_text(font.size = 8, color = "#3A3A3A",
                       font.family = "Calibri"),
  legend_text = fp_text(font.size = 8, color = "#3A3A3A",
                        font.family = "Calibri"),
  grid_major_line = fp_border(color = "#D9D9D9", width = 0.5),
  grid_minor_line = fp_border(width = 0)
)

# --- Helper: single-series horizontal bar chart ---------------------------
make_bar_chart <- function(data, value_col, fill_colour, title_text,
                           x_lab = "", y_lab = "Country") {
  df <- data %>%
    head(10) %>%
    make_label() %>%
    mutate(label = factor(label, levels = rev(label)))

  chart_df <- data.frame(
    country = df$label,
    value   = df[[value_col]],
    stringsAsFactors = FALSE
  )

  ms_barchart(chart_df, x = "country", y = "value") %>%
    chart_settings(dir = "horizontal", grouping = "clustered",
                   gap_width = 80, overlap = 100) %>%
    chart_labels(title = title_text, xlab = y_lab, ylab = x_lab) %>%
    chart_data_fill(values = c(value = fill_colour)) %>%
    chart_data_stroke(values = c(value = "transparent")) %>%
    chart_data_labels(show_val = TRUE, num_fmt = "0.0") %>%
    set_theme(bar_theme)
}

# --- Helper: two-series grouped bar for before/after (dot-plot equiv) -----
make_dot_bar_chart <- function(data, baseline_yr, current_yr, title_text,
                               x_lab = "Prevalence (%)",
                               num_fmt = "0.0") {
  df <- data %>%
    head(10) %>%
    make_label() %>%
    arrange(desc(baseline_value)) %>%
    mutate(label = factor(label, levels = label))

  chart_df <- rbind(
    data.frame(country = df$label,
               year    = as.character(baseline_yr),
               value   = df$baseline_value,
               stringsAsFactors = FALSE),
    data.frame(country = df$label,
               year    = as.character(current_yr),
               value   = df$current_value,
               stringsAsFactors = FALSE)
  )

  ms_barchart(chart_df, x = "country", y = "value", group = "year") %>%
    chart_settings(dir = "horizontal", grouping = "clustered",
                   gap_width = 60, overlap = 0) %>%
    chart_labels(title = title_text, xlab = "", ylab = x_lab) %>%
    chart_data_fill(values = setNames(
      c(col_orange, col_teal),
      c(as.character(baseline_yr), as.character(current_yr))
    )) %>%
    chart_data_stroke(values = setNames(
      c("transparent", "transparent"),
      c(as.character(baseline_yr), as.character(current_yr))
    )) %>%
    chart_data_labels(show_val = TRUE, num_fmt = num_fmt) %>%
    set_theme(bar_theme)
}

# =========================================================================
# Figure 1: Highest prevalence
# =========================================================================
fig1_ch <- make_bar_chart(
  results$highest, "prevalence", col_cyan,
  paste0("Top 10 highest stunting prevalence (", latest_year, ")")
)

# =========================================================================
# Figure 2: 10-year prevalence reduction
# =========================================================================
fig2_df <- results$improve_10yr %>%
  head(10) %>%
  make_label() %>%
  mutate(reduction = abs(change_pp),
         label = factor(label, levels = rev(label)))

fig2_ch <- ms_barchart(
  data.frame(country = fig2_df$label, value = fig2_df$reduction),
  x = "country", y = "value"
) %>%
  chart_settings(dir = "horizontal", grouping = "clustered",
                 gap_width = 80, overlap = 100) %>%
  chart_labels(title = paste0("10-year prevalence reduction (",
                              yr_10_ago, "\u2013", latest_year, ")"),
               xlab = "", ylab = "Reduction (pp)") %>%
  chart_data_fill(values = c(value = col_teal)) %>%
  chart_data_stroke(values = c(value = "transparent")) %>%
  chart_data_labels(show_val = TRUE, num_fmt = "0.0") %>%
  set_theme(bar_theme)

# =========================================================================
# Figure 3: 20-year prevalence reduction
# =========================================================================
fig3_df <- results$improve_20yr %>%
  head(10) %>%
  make_label() %>%
  mutate(reduction = abs(change_pp),
         label = factor(label, levels = rev(label)))

fig3_ch <- ms_barchart(
  data.frame(country = fig3_df$label, value = fig3_df$reduction),
  x = "country", y = "value"
) %>%
  chart_settings(dir = "horizontal", grouping = "clustered",
                 gap_width = 80, overlap = 100) %>%
  chart_labels(title = paste0("20-year prevalence reduction (",
                              yr_20_ago, "\u2013", latest_year, ")"),
               xlab = "", ylab = "Reduction (pp)") %>%
  chart_data_fill(values = c(value = col_dark)) %>%
  chart_data_stroke(values = c(value = "transparent")) %>%
  chart_data_labels(show_val = TRUE, num_fmt = "0.0") %>%
  set_theme(bar_theme)

# =========================================================================
# Figure 7: Before/after prevalence — 10-year
# =========================================================================
fig7_ch <- make_dot_bar_chart(
  results$improve_10yr, yr_10_ago, latest_year,
  paste0("Prevalence before and after (", yr_10_ago, " vs ", latest_year, ")")
)

# =========================================================================
# Figure 8: Before/after prevalence — 20-year
# =========================================================================
fig8_ch <- make_dot_bar_chart(
  results$improve_20yr, yr_20_ago, latest_year,
  paste0("Prevalence before and after (", yr_20_ago, " vs ", latest_year, ")")
)

message("[6] Built prevalence charts (Figs 1-3, 7-8)")

# =========================================================================
# Burden charts (if numbers data exists)
# =========================================================================
fig4_ch <- fig5_ch <- fig6_ch <- fig9_ch <- fig10_ch <- NULL

if (has_numbers) {

  # Figure 4: Highest burden
  fig4_ch <- make_bar_chart(
    results$highest_number, "number_thousands", col_magenta,
    paste0("Top 10 highest number of stunted children (", latest_year, ")"),
    x_lab = "Children (thousands)"
  )

  # Figure 5: 10-year burden reduction
  fig5_df <- results$improve_10yr_number %>%
    head(10) %>%
    make_label() %>%
    mutate(reduction_th = abs(change_th),
           label = factor(label, levels = rev(label)))

  fig5_ch <- ms_barchart(
    data.frame(country = fig5_df$label, value = fig5_df$reduction_th),
    x = "country", y = "value"
  ) %>%
    chart_settings(dir = "horizontal", grouping = "clustered",
                   gap_width = 80, overlap = 100) %>%
    chart_labels(title = paste0("10-year burden reduction (",
                                yr_10_ago, "\u2013", latest_year, ")"),
                 xlab = "", ylab = "Reduction (thousands)") %>%
    chart_data_fill(values = c(value = col_teal)) %>%
    chart_data_stroke(values = c(value = "transparent")) %>%
    chart_data_labels(show_val = TRUE, num_fmt = "#,##0") %>%
    set_theme(bar_theme)

  # Figure 6: 20-year burden reduction
  fig6_df <- results$improve_20yr_number %>%
    head(10) %>%
    make_label() %>%
    mutate(reduction_th = abs(change_th),
           label = factor(label, levels = rev(label)))

  fig6_ch <- ms_barchart(
    data.frame(country = fig6_df$label, value = fig6_df$reduction_th),
    x = "country", y = "value"
  ) %>%
    chart_settings(dir = "horizontal", grouping = "clustered",
                   gap_width = 80, overlap = 100) %>%
    chart_labels(title = paste0("20-year burden reduction (",
                                yr_20_ago, "\u2013", latest_year, ")"),
                 xlab = "", ylab = "Reduction (thousands)") %>%
    chart_data_fill(values = c(value = col_dark)) %>%
    chart_data_stroke(values = c(value = "transparent")) %>%
    chart_data_labels(show_val = TRUE, num_fmt = "#,##0") %>%
    set_theme(bar_theme)

  # Figure 9: Before/after burden — 10-year
  fig9_ch <- make_dot_bar_chart(
    results$improve_10yr_number, yr_10_ago, latest_year,
    paste0("Stunted children before and after (",
           yr_10_ago, " vs ", latest_year, ")"),
    x_lab = "Children (thousands)", num_fmt = "#,##0"
  )

  # Figure 10: Before/after burden — 20-year
  fig10_ch <- make_dot_bar_chart(
    results$improve_20yr_number, yr_20_ago, latest_year,
    paste0("Stunted children before and after (",
           yr_20_ago, " vs ", latest_year, ")"),
    x_lab = "Children (thousands)", num_fmt = "#,##0"
  )

  message("[6] Built burden charts (Figs 4-6, 9-10)")
}

# =========================================================================
# Assemble workbook
# =========================================================================
wb <- wb_workbook()

add_sheet_with_chart <- function(wb, sheet_name, data, chart_obj,
                                 chart_dims = "A25:J45") {
  wb <- wb_add_worksheet(wb, sheet_name)
  wb <- wb_add_data(wb, x = data, sheet = sheet_name)
  if (!is.null(chart_obj)) {
    wb <- wb_add_mschart(wb, sheet = sheet_name,
                         dims = chart_dims, graph = chart_obj)
  }
  wb
}

# T1 - Highest prevalence
wb <- add_sheet_with_chart(wb, "T1_highest_prevalence",
                           results$highest, fig1_ch)

# T2 - 10yr prevalence improvement
wb <- add_sheet_with_chart(wb, "T2_improve_10yr_prev",
                           results$improve_10yr, fig2_ch)

# T3 - 20yr prevalence improvement
wb <- add_sheet_with_chart(wb, "T3_improve_20yr_prev",
                           results$improve_20yr, fig3_ch)

if (has_numbers) {
  wb <- add_sheet_with_chart(wb, "T4_highest_number",
                             results$highest_number, fig4_ch)

  wb <- add_sheet_with_chart(wb, "T5_improve_10yr_number",
                             results$improve_10yr_number, fig5_ch)

  wb <- add_sheet_with_chart(wb, "T6_improve_20yr_number",
                             results$improve_20yr_number, fig6_ch)

  wb <- add_sheet_with_chart(wb, "T7_overlap_countries",
                             results$overlap, NULL)

  wb <- add_sheet_with_chart(wb, "T8_concentration",
                             results$concentration, NULL)

  wb <- add_sheet_with_chart(wb, "T9_reduction_conc",
                             results$reduction_concentration, NULL)
}

# Before/after sheets with grouped bar charts
wb <- add_sheet_with_chart(wb, "Fig7_prev_10yr",
  results$improve_10yr %>% head(10) %>% make_label() %>%
    select(label, baseline_value, current_value),
  fig7_ch)

wb <- add_sheet_with_chart(wb, "Fig8_prev_20yr",
  results$improve_20yr %>% head(10) %>% make_label() %>%
    select(label, baseline_value, current_value),
  fig8_ch)

if (has_numbers) {
  wb <- add_sheet_with_chart(wb, "Fig9_burden_10yr",
    results$improve_10yr_number %>% head(10) %>% make_label() %>%
      select(label, baseline_value, current_value),
    fig9_ch)

  wb <- add_sheet_with_chart(wb, "Fig10_burden_20yr",
    results$improve_20yr_number %>% head(10) %>% make_label() %>%
      select(label, baseline_value, current_value),
    fig10_ch)
}

# --- Save -----------------------------------------------------------------
out_path <- file.path(output_dir,
                      "stunting_tables_and_figures_EDITABLE.xlsx")
wb_save(wb, out_path, overwrite = TRUE)
message("[6] Saved editable-chart workbook: ", out_path)
message("[6] Done. Open in Excel to verify charts are editable.")
