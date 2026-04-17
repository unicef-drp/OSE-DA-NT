# ---------------------------------------------------------------------------
# Script:  5b_create_two_pager_styled.r
# Purpose: Build a stylized two-page briefing document and companion Excel
#          workbook with data for all figures/tables used in the brief.
# Inputs:  03_outputs/stunting_rankings.rds
# Outputs: 03_outputs/stunting_top20_two_pager_v4_styled.docx
#          03_outputs/stunting_top20_two_pager_v4_styled_data.xlsx
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
if (!file.exists(rds_path)) stop("Rankings not found: ", rds_path)

results <- readRDS(rds_path)
latest_year <- results$metadata$latest_year
yr_10_ago <- results$metadata$yr_10_ago
has_numbers <- !is.null(results$highest_number)

if (!has_numbers) {
  stop("stunting_numbers.parquet-derived rankings are required for this brief.")
}

# --- Figure/table datasets used in brief -----------------------------------
fig1 <- results$highest |>
  utils::head(10) |>
  dplyr::select(rank, REF_AREA, country_name, year, prevalence)

fig2 <- results$improve_10yr_number |>
  utils::head(10) |>
  dplyr::select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)

tbl_overlap <- dplyr::inner_join(
  results$highest |> dplyr::select(REF_AREA, country_name),
  results$highest_number |> dplyr::select(REF_AREA),
  by = "REF_AREA"
) |>
  dplyr::mutate(country_name = ifelse(is.na(country_name), REF_AREA, country_name)) |>
  dplyr::distinct() |>
  dplyr::arrange(country_name) |>
  dplyr::mutate(rank_overlap = dplyr::row_number()) |>
  dplyr::select(rank_overlap, country_name, REF_AREA)

global_total_m <- 150.2
top5_burden_m <- sum(utils::head(results$highest_number$number_thousands, 5), na.rm = TRUE) / 1000
top20_burden_m <- sum(utils::head(results$highest_number$number_thousands, 20), na.rm = TRUE) / 1000
top5_share <- 100 * top5_burden_m / global_total_m
top20_share <- 100 * top20_burden_m / global_total_m

metrics <- data.frame(
  metric = c(
    "Global stunted children",
    "Top 5 burden countries",
    "Top 5 share of global total",
    "Top 20 burden countries",
    "Top 20 share of global total"
  ),
  value = c(
    sprintf("%.1f million", global_total_m),
    sprintf("%.1f million", top5_burden_m),
    sprintf("%.1f%%", top5_share),
    sprintf("%.1f million", top20_burden_m),
    sprintf("%.1f%%", top20_share)
  ),
  stringsAsFactors = FALSE
)

# --- Companion Excel workbook ----------------------------------------------
wb <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb, "Figure1_prevalence")
openxlsx::writeData(wb, "Figure1_prevalence", fig1)
openxlsx::addWorksheet(wb, "Figure2_10yr_burden")
openxlsx::writeData(wb, "Figure2_10yr_burden", fig2)
openxlsx::addWorksheet(wb, "Table_overlap")
openxlsx::writeData(wb, "Table_overlap", tbl_overlap)
openxlsx::addWorksheet(wb, "Brief_metrics")
openxlsx::writeData(wb, "Brief_metrics", metrics)

xlsx_path <- file.path(output_dir, "stunting_top20_two_pager_v4b_styled_data.xlsx")
openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)

# --- Charts for fixed-layout two-pager ------------------------------------
fig1_plot_data <- fig1 |>
  dplyr::mutate(label = paste0(country_name, " (", REF_AREA, ")"),
                label = factor(label, levels = rev(label)))

p1 <- ggplot2::ggplot(fig1_plot_data, ggplot2::aes(x = label, y = prevalence)) +
  ggplot2::geom_col(fill = "#1CABE2", width = 0.72) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", prevalence)),
                     hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  ggplot2::coord_flip(ylim = c(0, max(fig1$prevalence, na.rm = TRUE) * 1.15)) +
  ggplot2::labs(
    title = paste0("Figure 1. Highest stunting prevalence (Top 10, ", latest_year, ")"),
    x = NULL, y = "Prevalence (%)"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", colour = "#003A70", size = 11),
    panel.grid.major.y = ggplot2::element_blank(),
    panel.grid.minor = ggplot2::element_blank()
  )

fig2_plot_data <- fig2 |>
  dplyr::mutate(reduction_th = -change_th,
                label = paste0(country_name, " (", REF_AREA, ")"),
                label = factor(label, levels = rev(label)))

fmt_m <- function(x) sprintf("%.1f", x / 1000)

p2 <- ggplot2::ggplot(fig2_plot_data, ggplot2::aes(x = label, y = reduction_th)) +
  ggplot2::geom_col(fill = "#00A79D", width = 0.72) +
  ggplot2::geom_text(ggplot2::aes(label = fmt_m(reduction_th)),
                     hjust = -0.08, size = 3.0, colour = "#3A3A3A") +
  ggplot2::coord_flip(ylim = c(0, max(fig2_plot_data$reduction_th, na.rm = TRUE) * 1.15)) +
  ggplot2::labs(
    title = paste0("Figure 2. Largest 10-year reduction in stunted numbers (Top 10, ",
                   yr_10_ago, "-", latest_year, ")"),
    subtitle = "Labels show reduction in millions",
    x = NULL, y = "Reduction (thousands)"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", colour = "#003A70", size = 11),
    plot.subtitle = ggplot2::element_text(size = 9, colour = "#4D4D4D"),
    panel.grid.major.y = ggplot2::element_blank(),
    panel.grid.minor = ggplot2::element_blank()
  )

# --- Stylized document helpers --------------------------------------------
add_title <- function(doc, txt) {
  title_run <- officer::ftext(
    txt,
    officer::fp_text(font.size = 20, bold = TRUE, font.family = "Calibri", color = "#FFFFFF")
  )
  title_par <- officer::fpar(
    title_run,
    fp_p = officer::fp_par(text.align = "left", padding.bottom = 4,
                           shading.color = "#003A70")
  )
  officer::body_add_fpar(doc, value = title_par)
}

add_subtitle <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(
        txt,
        officer::fp_text(font.size = 10, italic = TRUE, color = "#5A5A5A", font.family = "Calibri")
      ),
      fp_p = officer::fp_par(padding.top = 2, padding.bottom = 4)
    )
  )
}

add_section <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(
        txt,
        officer::fp_text(font.size = 12, bold = TRUE, color = "#003A70", font.family = "Calibri")
      ),
      fp_p = officer::fp_par(padding.top = 4, padding.bottom = 2)
    )
  )
}

add_body <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(
        txt,
        officer::fp_text(font.size = 10, color = "#1F1F1F", font.family = "Calibri")
      ),
      fp_p = officer::fp_par(line_spacing = 1.05, padding.bottom = 1)
    )
  )
}

add_bullet <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext("• ", officer::fp_text(font.size = 10, color = "#003A70", font.family = "Calibri")),
      officer::ftext(txt, officer::fp_text(font.size = 10, color = "#1F1F1F", font.family = "Calibri")),
      fp_p = officer::fp_par(line_spacing = 1.0, padding.bottom = 0)
    )
  )
}

add_callout <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(
        txt,
        officer::fp_text(font.size = 9.5, bold = TRUE, color = "#003A70", font.family = "Calibri")
      ),
      fp_p = officer::fp_par(
        text.align = "left",
        border.top = officer::fp_border(color = "#1CABE2", width = 1),
        border.bottom = officer::fp_border(color = "#1CABE2", width = 1),
        border.left = officer::fp_border(color = "#1CABE2", width = 1),
        border.right = officer::fp_border(color = "#1CABE2", width = 1),
        shading.color = "#EAF6FB",
        padding.top = 3,
        padding.bottom = 3,
        padding.left = 6,
        padding.right = 6
      )
    )
  )
}

# --- Compose fixed two-page layout ----------------------------------------
doc <- officer::read_docx()

# PAGE 1
doc <- add_title(doc, "Child Stunting: Levels, Trends, and Concentration")
doc <- add_subtitle(doc, paste0("Executive briefing | Data year ", latest_year))

doc <- add_section(doc, "Summary")
doc <- add_body(doc, sprintf("The 2024 Joint Child Malnutrition Estimates showed that child stunting remained severe in several countries and highly concentrated in a relatively small set of high-burden countries. Using the global estimate of %.1f million stunted children in 2024, the top five burden countries accounted for %.1f million children (%.1f%%), and the top 20 accounted for %.1f million (%.1f%%).", global_total_m, top5_burden_m, top5_share, top20_burden_m, top20_share))

doc <- add_callout(
  doc,
  "Regional pattern: highest prevalence is concentrated in sub-Saharan Africa, while highest burden is concentrated in South Asia and sub-Saharan Africa."
)

doc <- add_section(doc, "What the 2024 data showed")
doc <- add_body(doc, "On prevalence, the highest-ranked countries were Burundi (55.3%), Niger (48.3%), Eritrea (48.0%), Angola (47.7%), and Papua New Guinea (47.6%). Four of these five were in sub-Saharan Africa.")
doc <- add_body(doc, "On burden, the picture shifted toward larger-population countries. India had the largest estimated number of stunted children (37.4 million), followed by Nigeria (11.4 million), Pakistan (10.7 million), the Democratic Republic of the Congo (8.7 million), and Ethiopia (6.9 million). This group was concentrated in South Asia and sub-Saharan Africa.")

doc <- officer::body_add_gg(doc, value = p1, width = 5.8, height = 1.8)

overlap_preview <- utils::head(tbl_overlap$country_name, 11)
overlap_line <- paste(overlap_preview, collapse = ", ")
doc <- add_body(doc, paste0("Eleven countries appeared in both top-20 lists: ", overlap_line, ". Targeting these overlap countries can enable an equity-focused approach while also targeting settings where absolute impact can be largest."))

# Start PAGE 2 explicitly.
doc <- officer::body_add_break(doc)

# PAGE 2
doc <- add_section(doc, "Where progress was strongest")
doc <- add_body(doc, sprintf("The strongest 10-year prevalence reductions (%s\u2013%s) were in Libya (13.9 pp), Comoros (11.1 pp), and Nepal (11.0 pp). The strongest 20-year reductions (2004\u2013%s) were in North Korea (27.6 pp), Nepal (25.3 pp), and Tajikistan (24.9 pp). At the upper end, the observed pace was about 1.4 percentage points per year.", yr_10_ago, latest_year, latest_year))
doc <- add_body(doc, sprintf("Progress in burden was also substantial. Over %s\u2013%s, the largest reductions in stunted children were in India (12.6 million), China (3.6 million), Indonesia (2.9 million), Pakistan (2.4 million), and Bangladesh (1.3 million). Over 2004\u2013%s, the largest were in India (27.5 million), China (9.5 million), and Bangladesh (5.0 million).", yr_10_ago, latest_year, latest_year))

doc <- officer::body_add_gg(doc, value = p2, width = 5.8, height = 1.8)

doc <- add_body(doc, "India recorded the largest burden reduction in both windows, yet remained the largest-burden country in 2024, showing that very large gains were possible while absolute burden could still remain high in populous settings. Many sub-Saharan African countries remained prominent in the highest-burden rankings, indicating that prevalence improvements were often offset by child population growth.")

doc <- add_section(doc, "Key messages")
doc <- add_bullet(doc, "Severity and scale should be interpreted together: the highest-prevalence and highest-burden lists overlap, but are not identical.")
doc <- add_bullet(doc, "Burden remained concentrated: the top five countries represented about half, and the top 20 about three quarters, of the global estimate.")
doc <- add_bullet(doc, "The observed upper-end pace of prevalence reduction was about 1.4 pp/year, and large burden reductions were possible at scale.")
doc <- add_bullet(doc, "Regional patterns differed: highest burden and largest reductions were concentrated in South and East Asia, while many sub-Saharan African countries remained prominent in burden rankings.")

doc <- add_section(doc, "Data considerations")
doc <- add_body(doc, "Rankings are based on modeled national estimates for 162 countries. Trend interpretation is appropriate, but year-to-year movement should be interpreted cautiously because modeled series are smoothed. Rapid shocks including conflict may not be reflected immediately.")
doc <- add_body(doc, "Source: OSE-DA-NT outputs from cmrs2_series_accepted.parquet through stunting_rankings.rds and stunting_numbers.parquet.")

doc_path <- file.path(output_dir, "stunting_top20_two_pager_v4b_styled.docx")
print(doc, target = doc_path)

message("Styled two-pager saved: ", doc_path)
message("Styled two-pager data workbook saved: ", xlsx_path)
