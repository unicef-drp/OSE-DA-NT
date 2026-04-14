# ---------------------------------------------------------------------------
# Script:  4_create_ppt.r
# Purpose: Generate a UNICEF-branded PowerPoint briefing with charts and
#          narrative on stunting top-20 country rankings.
# Input:   03_outputs/stunting_rankings.rds
# Output:  03_outputs/stunting_top20_briefing.pptx
# Brand:   Uses UNICEF Branded Presentation Template 2025.pptx (preferred)
# Dependencies: officer, rvg, ggplot2, scales
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(scales)
  library(xml2)
})

for (pkg in c("officer", "rvg")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
}
library(officer)
library(rvg)

# --- Paths ----------------------------------------------------------------
if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}
# Output to external location (outside git) to avoid large files in repo
adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis", "stunting_top20_briefing")
output_dir <- file.path(adhoc_output_root, "03_outputs")
rds_path   <- file.path(output_dir, "stunting_rankings.rds")

if (!file.exists(rds_path)) {
  stop("Rankings file not found: ", rds_path, ". Run 3_stunting_rankings.r first.")
}

results <- readRDS(rds_path)

latest_year <- results$metadata$latest_year
yr_10_ago   <- results$metadata$yr_10_ago
yr_20_ago   <- results$metadata$yr_20_ago
has_numbers <- !is.null(results$highest_number)

# --- UNICEF brand assets --------------------------------------------------
brand_dir <- file.path(nutritionRoot, "github", "documentation", "unicef_brand", "_extracted")
template_2025 <- file.path(
  nutritionRoot,
  "github",
  "documentation",
  "unicef_brand",
  "OneDrive_1_4-13-2026",
  "UNICEF Branded Presentation Template 2025.pptx"
)
template_fallback <- file.path(brand_dir, "template_2026.pptx")

template_path <- if (file.exists(template_2025)) template_2025 else template_fallback

if (!file.exists(template_path)) {
  stop("UNICEF template not found: ", template_path)
}

# --- UNICEF brand colours -------------------------------------------------
unicef_cyan    <- "#00AEEF"
unicef_dark    <- "#374EA2"
unicef_green   <- "#00833D"
unicef_yellow  <- "#FFC20E"
unicef_orange  <- "#F26A21"
unicef_red     <- "#E2231A"
unicef_magenta <- "#961A49"
unicef_purple  <- "#6A1E74"
unicef_warmgrey <- "#777779"
unicef_coolgrey <- "#ADAFB2"
unicef_black   <- "#1D1D1B"
brand_font     <- "Noto Sans"

# --- ggplot2 theme (UNICEF brand-aligned) ---------------------------------
theme_unicef <- theme_minimal(base_size = 16, base_family = brand_font) +
  theme(
    plot.title       = element_text(face = "bold", size = 24, colour = unicef_dark),
    plot.subtitle    = element_text(size = 16, colour = unicef_warmgrey, margin = margin(b = 10)),
    plot.caption     = element_text(size = 11, colour = unicef_coolgrey, hjust = 0),
    axis.title       = element_text(size = 14, colour = unicef_warmgrey),
    axis.text        = element_text(size = 13, colour = unicef_black),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "#E6E6E6", linewidth = 0.5),
    panel.grid.minor   = element_blank(),
    legend.position  = "none",
    plot.margin      = margin(10, 20, 10, 10)
  )

# --- Chart 1: Highest prevalence (horizontal bar) ------------------------
p_highest <- results$highest %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = prevalence)) +
  geom_col(fill = unicef_cyan, width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", prevalence)),
            hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
  coord_flip(ylim = c(0, max(results$highest$prevalence, na.rm = TRUE) * 1.15)) +
  labs(
    title = NULL, subtitle = NULL,
    caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
    x = NULL, y = "Prevalence (%)"
  ) +
  scale_y_continuous(labels = label_percent(scale = 1)) +
  theme_unicef

# --- Chart 2: 10-year improvers ------------------------------------------
p_improve_10 <- results$improve_10yr %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = abs(change_pp))) +
  geom_col(fill = unicef_green, width = 0.7) +
  geom_text(aes(label = sprintf("-%.1f pp", abs(change_pp))),
            hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
  coord_flip(ylim = c(0, max(abs(results$improve_10yr$change_pp), na.rm = TRUE) * 1.15)) +
  labs(
    title = NULL, subtitle = NULL,
    caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
    x = NULL, y = "Reduction (pp)"
  ) +
  theme_unicef

# --- Chart 3: 20-year improvers ------------------------------------------
p_improve_20 <- results$improve_20yr %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = abs(change_pp))) +
  geom_col(fill = unicef_dark, width = 0.7) +
  geom_text(aes(label = sprintf("-%.1f pp", abs(change_pp))),
            hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
  coord_flip(ylim = c(0, max(abs(results$improve_20yr$change_pp), na.rm = TRUE) * 1.15)) +
  labs(
    title = NULL, subtitle = NULL,
    caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
    x = NULL, y = "Reduction (pp)"
  ) +
  theme_unicef

# --- Chart 4: Before/after dot plot for 10-year improvers -----------------
p_dot_10 <- results$improve_10yr %>%
  head(15) %>%
  arrange(current_value) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(y = label)) +
  geom_segment(aes(x = current_value, xend = baseline_value, yend = label),
               colour = unicef_coolgrey, linewidth = 0.6) +
  geom_point(aes(x = current_value,  colour = "current"),  size = 2.5) +
  geom_point(aes(x = baseline_value, colour = "baseline"), size = 2.5) +
  scale_colour_manual(
    values = c("current" = unicef_green, "baseline" = unicef_orange),
    labels = setNames(c(as.character(latest_year), as.character(yr_10_ago)),
                      c("current", "baseline")),
    breaks = c("current", "baseline")
  ) +
  labs(
    title = NULL,
    subtitle = NULL,
    caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
    x = "Prevalence (%)", y = NULL, colour = NULL
  ) +
  scale_x_continuous(labels = label_percent(scale = 1)) +
  theme_unicef +
  theme(legend.position = "top", legend.text = element_text(size = 13))

# --- Build PowerPoint using UNICEF branded template -----------------------
# Keep key template slides so title and thank-you slides stay brand-authentic.
pptx <- read_pptx(template_path)

n_template_slides <- length(pptx)
keep_slides <- c(1, 17, 71)
if (n_template_slides > 0) {
  for (i in seq(n_template_slides, 1)) {
    if (!(i %in% keep_slides)) {
      pptx <- remove_slide(pptx, index = i)
    }
  }
}

# --- Slide 1: Replace title/subtitle via direct XML text replacement ------
# Template slide 1 uses a non-standard layout ("2_Number slide") so
# ph_location_label() cannot target its placeholders. Instead we edit the
# text nodes in the slide XML directly, preserving all original formatting,
# position and styling from the template.
pptx <- on_slide(pptx, index = 1)

slide_xml <- pptx$slide$get_slide(1)$get()
sl_ns <- xml2::xml_ns(slide_xml)
sps <- xml2::xml_find_all(slide_xml, "//p:sp", sl_ns)

for (sp in sps) {
  t_nodes <- xml2::xml_find_all(sp, ".//a:t", sl_ns)
  combined <- paste(sapply(t_nodes, xml2::xml_text), collapse = "")

  if (grepl("Presentation title here", combined) && length(t_nodes) > 0) {
    xml2::xml_set_text(t_nodes[[1]],
      "Stunting: where burdens remain highest and where progress is fastest")
    if (length(t_nodes) > 1) for (j in 2:length(t_nodes)) xml2::xml_set_text(t_nodes[[j]], "")
  }

  if (grepl("Your subheadings here", combined) && length(t_nodes) > 0) {
    xml2::xml_set_text(t_nodes[[1]],
      paste0("Executive Director briefing  |  ", format(Sys.Date(), "%d %B %Y")))
    if (length(t_nodes) > 1) for (j in 2:length(t_nodes)) xml2::xml_set_text(t_nodes[[j]], "")
  }
}

# Slide 2 is retained from the template as a branded nutrition photo divider.

# --- Slide 3: Headline summary -------------------------------------------
top_high_country <- results$highest$country_name[1]
top_high_prev <- results$highest$prevalence[1]
top_10_country <- results$improve_10yr$country_name[1]
top_10_drop <- abs(results$improve_10yr$change_pp[1])
top_20_country <- results$improve_20yr$country_name[1]
top_20_drop <- abs(results$improve_20yr$change_pp[1])

summary_lines <- list(
  fpar(ftext(
    "This briefing presents country rankings based on modelled stunting estimates for children under 5 years, covering both prevalence and the number of children affected.",
    prop = fp_text(font.size = 22, font.family = brand_font, color = unicef_black)
  )),
  fpar(ftext("", prop = fp_text(font.size = 10, font.family = brand_font))),
  fpar(ftext(paste0(
    "Highest current prevalence: ", top_high_country, " at ",
    sprintf("%.1f", top_high_prev), " per cent in ", latest_year, "."),
    prop = fp_text(font.size = 20, font.family = brand_font, color = unicef_dark, bold = TRUE)
  )),
  fpar(ftext(paste0(
    "Fastest 10-year reduction: ", top_10_country, " with a decline of ",
    sprintf("%.1f", top_10_drop), " percentage points (", yr_10_ago, "\u2013", latest_year, ")."),
    prop = fp_text(font.size = 20, font.family = brand_font, color = unicef_dark, bold = TRUE)
  )),
  fpar(ftext(paste0(
    "Fastest 20-year reduction: ", top_20_country, " with a decline of ",
    sprintf("%.1f", top_20_drop), " percentage points (", yr_20_ago, "\u2013", latest_year, ")."),
    prop = fp_text(font.size = 20, font.family = brand_font, color = unicef_dark, bold = TRUE)
  ))
)

if (has_numbers) {
  top_num_country <- results$highest_number$country_name[1]
  top_num_val <- results$highest_number$number_thousands[1]
  summary_lines <- c(summary_lines, list(
    fpar(ftext(paste0(
      "Highest burden: ", top_num_country, " with an estimated ",
      sprintf("%.1f", top_num_val / 1000), " million stunted children in ", latest_year, "."),
      prop = fp_text(font.size = 20, font.family = brand_font, color = unicef_dark, bold = TRUE)
    ))
  ))
}

summary_lines <- c(summary_lines, list(
  fpar(ftext("", prop = fp_text(font.size = 10, font.family = brand_font))),
  fpar(ftext(
    "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates.",
    prop = fp_text(font.size = 14, font.family = brand_font, color = unicef_warmgrey, italic = TRUE)
  ))
))

summary_text <- do.call(block_list, summary_lines)

pptx <- pptx %>%
  add_slide(layout = "Title and Content", master = "UNICEF") %>%
  ph_with(value = "What this briefing shows",
          location = ph_location_type(type = "title")) %>%
  ph_with(value = summary_text,
          location = ph_location_type(type = "body"))

# =========================================================================
# SECTION A: Prevalence
# =========================================================================

pptx <- pptx %>%
  add_slide(layout = "Title Slide", master = "UNICEF") %>%
  ph_with(value = fpar(ftext("Stunting prevalence",
    prop = fp_text(font.size = 36, bold = TRUE, color = unicef_dark, font.family = brand_font))),
    location = ph_location_type(type = "ctrTitle")) %>%
  ph_with(value = fpar(ftext("Countries with the highest rates and fastest reductions",
    prop = fp_text(font.size = 20, color = unicef_warmgrey, font.family = brand_font))),
    location = ph_location_type(type = "subTitle"))

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Highest stunting prevalence (", latest_year, ")"),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_highest),
          location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Biggest reduction in stunting: ", yr_10_ago, "\u2013", latest_year),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_improve_10),
          location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Stunting prevalence: before and after (", yr_10_ago, " vs ", latest_year, ")"),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_dot_10),
          location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Biggest reduction in stunting: ", yr_20_ago, "\u2013", latest_year),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_improve_20),
          location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))

# =========================================================================
# SECTION B: Burden (number of stunted children)
# =========================================================================

if (has_numbers) {
  # --- Burden charts -------------------------------------------------------
  fmt_millions <- function(x) sprintf("%.1f M", x / 1000)

  p_highest_num <- results$highest_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = number_thousands)) +
    geom_col(fill = unicef_magenta, width = 0.7) +
    geom_text(aes(label = fmt_millions(number_thousands)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
    coord_flip(ylim = c(0, max(results$highest_number$number_thousands, na.rm = TRUE) * 1.15)) +
    labs(
      title    = paste0("Top 15 countries: highest number of stunted children (", latest_year, ")"),
      subtitle = "Children under 5 years, modelled estimates (millions)",
      caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
      x = NULL, y = "Stunted children (millions)"
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_10_num <- results$improve_10yr_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_green, width = 0.7) +
    geom_text(aes(label = sprintf("\u2013%.1f M", abs(change_th) / 1000)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
    coord_flip(ylim = c(0, max(abs(results$improve_10yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(
      title    = paste0("Biggest reduction in stunted numbers: ", yr_10_ago, "\u2013", latest_year),
      subtitle = "Absolute decrease in number of stunted children (millions)",
      caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
      x = NULL, y = "Reduction (millions)"
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_20_num <- results$improve_20yr_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_dark, width = 0.7) +
    geom_text(aes(label = sprintf("\u2013%.1f M", abs(change_th) / 1000)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
    coord_flip(ylim = c(0, max(abs(results$improve_20yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(
      title    = paste0("Biggest reduction in stunted numbers: ", yr_20_ago, "\u2013", latest_year),
      subtitle = "Absolute decrease in number of stunted children (millions)",
      caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
      x = NULL, y = "Reduction (millions)"
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  # --- Section divider: Burden ---------------------------------------------
  pptx <- pptx %>%
    add_slide(layout = "Title Slide", master = "UNICEF") %>%
    ph_with(value = fpar(ftext("Stunting burden: number of children affected",
      prop = fp_text(font.size = 36, bold = TRUE, color = unicef_dark, font.family = brand_font))),
      location = ph_location_type(type = "ctrTitle")) %>%
    ph_with(value = fpar(ftext("Countries with the highest absolute numbers and largest reductions",
      prop = fp_text(font.size = 20, color = unicef_warmgrey, font.family = brand_font))),
      location = ph_location_type(type = "subTitle"))

  pptx <- pptx %>%
    add_slide(layout = "Title Only", master = "UNICEF") %>%
    ph_with(value = paste0("Highest number of stunted children (", latest_year, ")"),
            location = ph_location_type(type = "title")) %>%
    ph_with(value = dml(ggobj = p_highest_num),
            location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))

  pptx <- pptx %>%
    add_slide(layout = "Title Only", master = "UNICEF") %>%
    ph_with(value = paste0("Biggest reduction in stunted numbers: ", yr_10_ago, "\u2013", latest_year),
            location = ph_location_type(type = "title")) %>%
    ph_with(value = dml(ggobj = p_improve_10_num),
            location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))

  pptx <- pptx %>%
    add_slide(layout = "Title Only", master = "UNICEF") %>%
    ph_with(value = paste0("Biggest reduction in stunted numbers: ", yr_20_ago, "\u2013", latest_year),
            location = ph_location_type(type = "title")) %>%
    ph_with(value = dml(ggobj = p_improve_20_num),
            location = ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3))
}

# =========================================================================
# Key findings and narrative
# =========================================================================

top3_highest <- paste(head(results$highest$country_name, 3), collapse = ", ")
top3_improv  <- paste(head(results$improve_10yr$country_name, 3), collapse = ", ")
max_change_10 <- sprintf("%.1f", max(abs(results$improve_10yr$change_pp), na.rm = TRUE))
max_change_20 <- sprintf("%.1f", max(abs(results$improve_20yr$change_pp), na.rm = TRUE))

body_props   <- fp_text(font.size = 20, color = unicef_black, font.family = brand_font)
bold_props   <- fp_text(font.size = 20, color = unicef_dark, bold = TRUE, font.family = brand_font)
source_props <- fp_text(font.size = 14, color = unicef_warmgrey, italic = TRUE, font.family = brand_font)

narrative_items <- list(
  fpar(
    ftext("Highest prevalence: ", prop = bold_props),
    ftext(paste0("As of ", latest_year, ", the countries with the highest stunting prevalence ",
                 "among children under 5 years include ", top3_highest, ". ",
                 "These countries continue to carry a large share of the global burden."),
          prop = body_props)
  ),
  fpar(ftext("", prop = body_props)),
  fpar(
    ftext("10-year progress: ", prop = bold_props),
    ftext(paste0("Between ", yr_10_ago, " and ", latest_year, ", ",
                 top3_improv, " achieved the largest absolute reductions in stunting prevalence, ",
                 "with the top performer reducing prevalence by ", max_change_10, " percentage points."),
          prop = body_props)
  ),
  fpar(ftext("", prop = body_props)),
  fpar(
    ftext("20-year progress: ", prop = bold_props),
    ftext(paste0("Over the past two decades (", yr_20_ago, "\u2013", latest_year, "), ",
                 "the most substantial declines reached up to ", max_change_20, " percentage points."),
          prop = body_props)
  )
)

if (has_numbers) {
  top3_num <- paste(head(results$highest_number$country_name, 3), collapse = ", ")
  top_num_val_m <- sprintf("%.1f", results$highest_number$number_thousands[1] / 1000)
  narrative_items <- c(narrative_items, list(
    fpar(ftext("", prop = body_props)),
    fpar(
      ftext("Absolute burden: ", prop = bold_props),
      ftext(paste0("By number of children affected, ", top3_num,
                   " bear the greatest burden, with ", results$highest_number$country_name[1],
                   " alone accounting for an estimated ", top_num_val_m,
                   " million stunted children in ", latest_year, "."),
            prop = body_props)
    )
  ))
}

narrative_items <- c(narrative_items, list(
  fpar(ftext("", prop = body_props)),
  fpar(
    ftext("Note: Estimates are based on UNICEF/WHO/World Bank Joint Malnutrition Estimates (JME) ",
          prop = source_props),
    ftext("modelled country series. Improvement is measured as absolute reduction in prevalence (percentage points) or number of children affected (thousands).",
          prop = source_props)
  )
))

narrative_block <- do.call(block_list, narrative_items)

pptx <- pptx %>%
  add_slide(layout = "Title and Content", master = "UNICEF") %>%
  ph_with(value = "Key findings and programme implications",
          location = ph_location_type(type = "title")) %>%
  ph_with(value = narrative_block,
          location = ph_location_type(type = "body"))

# --- Move retained thank-you slide to the end -----------------------------
pptx <- move_slide(pptx, index = 3, to = length(pptx))

# --- Save -----------------------------------------------------------------
pptx_path <- file.path(output_dir, "stunting_top20_briefing.pptx")
print(pptx, target = pptx_path)
message("PowerPoint saved: ", pptx_path)

# --- Excel workbook with one sheet per figure slide -----------------------
if (!requireNamespace("openxlsx", quietly = TRUE)) install.packages("openxlsx")
library(openxlsx)

wb <- createWorkbook()

# Sheet 1: Highest prevalence (slide 5)
s1 <- results$highest %>% head(15) %>%
  select(rank, REF_AREA, country_name, year, prevalence)
addWorksheet(wb, "Highest prevalence")
writeData(wb, "Highest prevalence", s1)

# Sheet 2: 10-year improvement (slide 6)
s2 <- results$improve_10yr %>% head(15) %>%
  select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
addWorksheet(wb, "10yr improvement")
writeData(wb, "10yr improvement", s2)

# Sheet 3: Before-after dot plot (slide 7)
s3 <- results$improve_10yr %>% head(15) %>%
  arrange(current_value) %>%
  select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp)
addWorksheet(wb, "10yr before-after")
writeData(wb, "10yr before-after", s3)

# Sheet 4: 20-year improvement (slide 8)
s4 <- results$improve_20yr %>% head(15) %>%
  select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
addWorksheet(wb, "20yr improvement")
writeData(wb, "20yr improvement", s4)

if (has_numbers) {
  # Sheet 5: Highest number (slide 10)
  s5 <- results$highest_number %>% head(15) %>%
    select(rank, REF_AREA, country_name, year, number_thousands)
  addWorksheet(wb, "Highest number")
  writeData(wb, "Highest number", s5)

  # Sheet 6: 10-year reduction in number (slide 11)
  s6 <- results$improve_10yr_number %>% head(15) %>%
    select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)
  addWorksheet(wb, "10yr number reduction")
  writeData(wb, "10yr number reduction", s6)

  # Sheet 7: 20-year reduction in number (slide 12)
  s7 <- results$improve_20yr_number %>% head(15) %>%
    select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)
  addWorksheet(wb, "20yr number reduction")
  writeData(wb, "20yr number reduction", s7)
}

xlsx_path <- file.path(output_dir, "stunting_top20_briefing_data.xlsx")
saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("Excel data saved: ", xlsx_path)
