# ---------------------------------------------------------------------------
# Script:  5_create_two_pager_brief.r
# Purpose: Build a two-page briefing document and companion Excel workbook
#          with one sheet per figure/table dataset used in the brief.
# Inputs:  03_outputs/stunting_rankings.rds
#          00_documentation/BRIEFING_CONTENT_V4_2026-04-17.md
# Outputs: 03_outputs/stunting_top20_two_pager_v4.docx
#          03_outputs/stunting_top20_two_pager_v4_data.xlsx
# ---------------------------------------------------------------------------

# --- Namespace checks ------------------------------------------------------
.required_pkgs <- c("officer", "openxlsx", "ggplot2", "dplyr", "tidyr", "scales")
.missing <- .required_pkgs[!vapply(.required_pkgs, requireNamespace,
                                   FUN.VALUE = logical(1), quietly = TRUE)]
if (length(.missing) > 0) {
  stop("Missing required packages: ", paste(.missing, collapse = ", "),
       ". Install them, then rerun.")
}

# --- Paths -----------------------------------------------------------------
if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis", "stunting_top20_briefing")
output_dir <- file.path(adhoc_output_root, "03_outputs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

rds_path <- file.path(output_dir, "stunting_rankings.rds")
brief_md_path <- file.path(
  projectFolder,
  "adhoc_analysis", "stunting_top20_briefing", "00_documentation",
  "BRIEFING_CONTENT_V4_2026-04-17.md"
)

if (!file.exists(rds_path)) stop("Rankings not found: ", rds_path)
if (!file.exists(brief_md_path)) stop("Brief markdown not found: ", brief_md_path)

results <- readRDS(rds_path)
latest_year <- results$metadata$latest_year
yr_10_ago <- results$metadata$yr_10_ago
yr_20_ago <- results$metadata$yr_20_ago
has_numbers <- !is.null(results$highest_number)

# --- Figure datasets (exported to Excel and used for charts) ---------------
s1 <- results$highest |>
  utils::head(15) |>
  dplyr::select(rank, REF_AREA, country_name, year, prevalence)

s2 <- results$improve_10yr |>
  utils::head(15) |>
  dplyr::select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)

s3 <- results$improve_10yr |>
  utils::head(15) |>
  dplyr::arrange(current_value) |>
  dplyr::select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp)

s4 <- results$improve_20yr |>
  utils::head(15) |>
  dplyr::select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)

if (has_numbers) {
  s5 <- results$highest_number |>
    utils::head(15) |>
    dplyr::select(rank, REF_AREA, country_name, year, number_thousands)

  s6 <- results$improve_10yr_number |>
    utils::head(15) |>
    dplyr::select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)

  s7 <- results$improve_20yr_number |>
    utils::head(15) |>
    dplyr::select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)
}

# --- Excel companion workbook ----------------------------------------------
wb <- openxlsx::createWorkbook()

openxlsx::addWorksheet(wb, "Highest prevalence")
openxlsx::writeData(wb, "Highest prevalence", s1)

openxlsx::addWorksheet(wb, "10yr improvement")
openxlsx::writeData(wb, "10yr improvement", s2)

openxlsx::addWorksheet(wb, "10yr before-after")
openxlsx::writeData(wb, "10yr before-after", s3)

openxlsx::addWorksheet(wb, "20yr improvement")
openxlsx::writeData(wb, "20yr improvement", s4)

if (has_numbers) {
  openxlsx::addWorksheet(wb, "Highest number")
  openxlsx::writeData(wb, "Highest number", s5)

  openxlsx::addWorksheet(wb, "10yr number reduction")
  openxlsx::writeData(wb, "10yr number reduction", s6)

  openxlsx::addWorksheet(wb, "20yr number reduction")
  openxlsx::writeData(wb, "20yr number reduction", s7)
}

xlsx_path <- file.path(output_dir, "stunting_top20_two_pager_v4_data.xlsx")
openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)

# --- Charts for brief ------------------------------------------------------
fmt_millions <- function(x) sprintf("%.1f M", x / 1000)

p1 <- s1 |>
  dplyr::mutate(label = paste0(country_name, " (", REF_AREA, ")"),
                label = factor(label, levels = rev(label))) |>
  ggplot2::ggplot(ggplot2::aes(x = label, y = prevalence)) +
  ggplot2::geom_col(fill = "#1CABE2", width = 0.72) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", prevalence)),
                     hjust = -0.1, size = 3.5, colour = "#4B4B4B") +
  ggplot2::coord_flip(ylim = c(0, max(s1$prevalence, na.rm = TRUE) * 1.15)) +
  ggplot2::labs(
    title = paste0("Figure 1. Highest stunting prevalence, ", latest_year),
    x = NULL, y = "Prevalence (%)"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

p2 <- s2 |>
  dplyr::mutate(reduction_pp = -change_pp,
                label = paste0(country_name, " (", REF_AREA, ")"),
                label = factor(label, levels = rev(label))) |>
  ggplot2::ggplot(ggplot2::aes(x = label, y = reduction_pp)) +
  ggplot2::geom_col(fill = "#00A79D", width = 0.72) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f pp", reduction_pp)),
                     hjust = -0.1, size = 3.5, colour = "#4B4B4B") +
  ggplot2::coord_flip(ylim = c(0, max(-s2$change_pp, na.rm = TRUE) * 1.15)) +
  ggplot2::labs(
    title = paste0("Figure 2. Biggest 10-year prevalence reductions (", yr_10_ago, "-", latest_year, ")"),
    x = NULL, y = "Reduction (percentage points)"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

p3_data <- s3 |>
  dplyr::mutate(label = paste0(country_name, " (", REF_AREA, ")"),
                label = factor(label, levels = unique(label))) |>
  tidyr::pivot_longer(cols = c(baseline_value, current_value),
                      names_to = "period", values_to = "value") |>
  dplyr::mutate(period = dplyr::recode(period,
                                       baseline_value = as.character(yr_10_ago),
                                       current_value = as.character(latest_year)))

p3 <- ggplot2::ggplot(p3_data, ggplot2::aes(x = value, y = label, color = period)) +
  ggplot2::geom_point(size = 2.5) +
  ggplot2::scale_color_manual(values = stats::setNames(
    c("#7A7A7A", "#1CABE2"),
    c(as.character(yr_10_ago), as.character(latest_year))
  )) +
  ggplot2::labs(
    title = paste0("Figure 3. Before and after prevalence (", yr_10_ago, " vs ", latest_year, ")"),
    x = "Prevalence (%)", y = NULL, color = "Year"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

p4 <- s4 |>
  dplyr::mutate(reduction_pp = -change_pp,
                label = paste0(country_name, " (", REF_AREA, ")"),
                label = factor(label, levels = rev(label))) |>
  ggplot2::ggplot(ggplot2::aes(x = label, y = reduction_pp)) +
  ggplot2::geom_col(fill = "#F58220", width = 0.72) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f pp", reduction_pp)),
                     hjust = -0.1, size = 3.5, colour = "#4B4B4B") +
  ggplot2::coord_flip(ylim = c(0, max(-s4$change_pp, na.rm = TRUE) * 1.15)) +
  ggplot2::labs(
    title = paste0("Figure 4. Biggest 20-year prevalence reductions (", yr_20_ago, "-", latest_year, ")"),
    x = NULL, y = "Reduction (percentage points)"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

if (has_numbers) {
  p5 <- s5 |>
    dplyr::mutate(label = paste0(country_name, " (", REF_AREA, ")"),
                  label = factor(label, levels = rev(label))) |>
    ggplot2::ggplot(ggplot2::aes(x = label, y = number_thousands)) +
    ggplot2::geom_col(fill = "#1CABE2", width = 0.72) +
    ggplot2::geom_text(ggplot2::aes(label = fmt_millions(number_thousands)),
                       hjust = -0.1, size = 3.5, colour = "#4B4B4B") +
    ggplot2::coord_flip(ylim = c(0, max(s5$number_thousands, na.rm = TRUE) * 1.15)) +
    ggplot2::labs(
      title = paste0("Figure 5. Highest number of stunted children, ", latest_year),
      x = NULL, y = "Children (millions)"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())

  p6 <- s6 |>
    dplyr::mutate(reduction_thousands = -change_th,
                  label = paste0(country_name, " (", REF_AREA, ")"),
                  label = factor(label, levels = rev(label))) |>
    ggplot2::ggplot(ggplot2::aes(x = label, y = reduction_thousands)) +
    ggplot2::geom_col(fill = "#00A79D", width = 0.72) +
    ggplot2::geom_text(ggplot2::aes(label = fmt_millions(reduction_thousands)),
                       hjust = -0.1, size = 3.5, colour = "#4B4B4B") +
    ggplot2::coord_flip(ylim = c(0, max(-s6$change_th, na.rm = TRUE) * 1.15)) +
    ggplot2::labs(
      title = paste0("Figure 6. Biggest 10-year reduction in stunted numbers (", yr_10_ago, "-", latest_year, ")"),
      x = NULL, y = "Reduction (millions)"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(panel.grid.major.y = ggplot2::element_blank())
}

# --- Build two-pager document ---------------------------------------------
md_lines <- readLines(brief_md_path, warn = FALSE, encoding = "UTF-8")

.add_md_block <- function(doc, lines) {
  for (ln in lines) {
    txt <- trimws(ln)
    if (!nzchar(txt)) {
      doc <- officer::body_add_par(doc, "", style = "Normal")
    } else if (grepl("^# ", txt)) {
      doc <- officer::body_add_par(doc, sub("^#\\s+", "", txt), style = "heading 1")
    } else if (grepl("^## ", txt)) {
      doc <- officer::body_add_par(doc, sub("^##\\s+", "", txt), style = "heading 2")
    } else if (grepl("^### ", txt)) {
      doc <- officer::body_add_par(doc, sub("^###\\s+", "", txt), style = "heading 3")
    } else if (grepl("^- ", txt)) {
      doc <- officer::body_add_par(doc, paste0("- ", sub("^-\\s+", "", txt)), style = "Normal")
    } else {
      doc <- officer::body_add_par(doc, txt, style = "Normal")
    }
  }
  doc
}

doc <- officer::read_docx()
doc <- .add_md_block(doc, md_lines)

doc <- officer::body_add_par(doc, "", style = "Normal")
doc <- officer::body_add_par(doc, "Figures", style = "heading 2")
doc <- officer::body_add_gg(doc, value = p1, width = 6.5, height = 3.4)
doc <- officer::body_add_gg(doc, value = p2, width = 6.5, height = 3.4)
doc <- officer::body_add_gg(doc, value = p3, width = 6.5, height = 3.4)
doc <- officer::body_add_gg(doc, value = p4, width = 6.5, height = 3.4)

if (has_numbers) {
  doc <- officer::body_add_gg(doc, value = p5, width = 6.5, height = 3.4)
  doc <- officer::body_add_gg(doc, value = p6, width = 6.5, height = 3.4)
}

doc_path <- file.path(output_dir, "stunting_top20_two_pager_v4.docx")
print(doc, target = doc_path)

message("Two-pager saved: ", doc_path)
message("Two-pager data workbook saved: ", xlsx_path)
