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
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(y = label)) +
  geom_segment(aes(x = current_value, xend = baseline_value, yend = label),
               colour = unicef_coolgrey, linewidth = 0.6) +
  geom_point(aes(x = baseline_value), colour = unicef_orange, size = 2.5) +
  geom_point(aes(x = current_value),  colour = unicef_green,  size = 2.5) +
  labs(
    title = NULL,
    subtitle = paste0("Orange = ", yr_10_ago, "  |  Green = ", latest_year),
    caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
    x = "Prevalence (%)", y = NULL
  ) +
  scale_x_continuous(labels = label_percent(scale = 1)) +
  theme_unicef

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

# --- Reusable text properties ---------------------------------------------
title_props   <- fp_text(font.size = 36, bold = TRUE, color = unicef_dark, font.family = brand_font)
body_props    <- fp_text(font.size = 22, color = unicef_black, font.family = brand_font)
bold_props    <- fp_text(font.size = 22, color = unicef_dark, bold = TRUE, font.family = brand_font)
source_props  <- fp_text(font.size = 14, color = unicef_warmgrey, italic = TRUE, font.family = brand_font)
bullet_marker <- "\u2022  "

set_shape_text <- function(slide_xml, shape_name, new_text) {
  sp <- xml2::xml_find_first(
    slide_xml,
    sprintf("//p:sp[p:nvSpPr/p:cNvPr[@name='%s']]", shape_name),
    xml2::xml_ns(slide_xml)
  )
  if (inherits(sp, "xml_missing")) return(FALSE)

  p_node <- xml2::xml_find_first(sp, ".//a:p", xml2::xml_ns(slide_xml))
  if (inherits(p_node, "xml_missing")) return(FALSE)

  r_nodes <- xml2::xml_find_all(p_node, ".//a:r", xml2::xml_ns(slide_xml))
  if (length(r_nodes) > 0) {
    t_node <- xml2::xml_find_first(r_nodes[[1]], ".//a:t", xml2::xml_ns(slide_xml))
    if (!inherits(t_node, "xml_missing")) {
      xml2::xml_set_text(t_node, new_text)
      if (length(r_nodes) > 1) {
        for (j in 2:length(r_nodes)) xml2::xml_remove(r_nodes[[j]])
      }
      return(TRUE)
    }
  }

  xml2::xml_add_child(p_node, "a:r", .where = 0)
  new_r <- xml2::xml_find_first(p_node, ".//a:r", xml2::xml_ns(slide_xml))
  xml2::xml_add_child(new_r, "a:t", new_text)
  TRUE
}

set_shape_xfrm <- function(slide_xml, shape_name, left, top, width, height) {
  emu <- function(inches) as.integer(round(inches * 914400))
  sp <- xml2::xml_find_first(
    slide_xml,
    sprintf("//p:sp[p:nvSpPr/p:cNvPr[@name='%s']]", shape_name),
    xml2::xml_ns(slide_xml)
  )
  if (inherits(sp, "xml_missing")) return(FALSE)

  xfrm <- xml2::xml_find_first(sp, ".//a:xfrm", xml2::xml_ns(slide_xml))
  if (inherits(xfrm, "xml_missing")) return(FALSE)

  off <- xml2::xml_find_first(xfrm, "./a:off", xml2::xml_ns(slide_xml))
  ext <- xml2::xml_find_first(xfrm, "./a:ext", xml2::xml_ns(slide_xml))
  if (inherits(off, "xml_missing") || inherits(ext, "xml_missing")) return(FALSE)

  xml2::xml_set_attr(off, "x", as.character(emu(left)))
  xml2::xml_set_attr(off, "y", as.character(emu(top)))
  xml2::xml_set_attr(ext, "cx", as.character(emu(width)))
  xml2::xml_set_attr(ext, "cy", as.character(emu(height)))
  TRUE
}

get_shape_xfrm <- function(slide_xml, shape_name) {
  sp <- xml2::xml_find_first(
    slide_xml,
    sprintf("//p:sp[p:nvSpPr/p:cNvPr[@name='%s']]", shape_name),
    xml2::xml_ns(slide_xml)
  )
  if (inherits(sp, "xml_missing")) return(NULL)

  off <- xml2::xml_find_first(sp, ".//a:xfrm/a:off", xml2::xml_ns(slide_xml))
  ext <- xml2::xml_find_first(sp, ".//a:xfrm/a:ext", xml2::xml_ns(slide_xml))
  if (inherits(off, "xml_missing") || inherits(ext, "xml_missing")) return(NULL)

  emu_to_in <- function(x) as.numeric(x) / 914400
  list(
    left = emu_to_in(xml2::xml_attr(off, "x")),
    top = emu_to_in(xml2::xml_attr(off, "y")),
    width = emu_to_in(xml2::xml_attr(ext, "cx")),
    height = emu_to_in(xml2::xml_attr(ext, "cy"))
  )
}

wrap_to_box <- function(text, box_width, font_size_pt) {
  clean <- trimws(gsub("\\s+", " ", text))
  if (nchar(clean) == 0) return("")
  # Approximate character capacity per line from box width and font size.
  chars_per_line <- max(12, floor((box_width * 72) / (font_size_pt * 0.56)))
  paste(strwrap(clean, width = chars_per_line), collapse = "\n")
}

estimate_text_height <- function(text, font_size_pt, line_spacing = 1.15, pad = 0.08) {
  if (nchar(text) == 0) return(pad * 2)
  lines <- length(strsplit(text, "\\n", fixed = FALSE)[[1]])
  ((lines * font_size_pt * line_spacing) / 72) + (2 * pad)
}

truncate_wrapped_to_height <- function(text_wrapped, font_size_pt, max_height, line_spacing = 1.15, pad = 0.08) {
  lines <- strsplit(text_wrapped, "\\n", fixed = FALSE)[[1]]
  max_lines <- max(1, floor(((max_height - 2 * pad) * 72) / (font_size_pt * line_spacing)))
  if (length(lines) <= max_lines) return(text_wrapped)
  kept <- lines[seq_len(max_lines)]
  kept[length(kept)] <- paste0(sub("[[:space:]]+$", "", kept[length(kept)]), "...")
  paste(kept, collapse = "\n")
}

# Chart placement: below title area (title ends at ~1.85 in)
chart_loc <- ph_location(left = 0.5, top = 2.0, width = 11.8, height = 5.0)

# ==========================================================================
# SLIDE 1: Cover (template slide - replace text via XML)
# ==========================================================================
pptx <- on_slide(pptx, index = 1)

slide_xml <- pptx$slide$get_slide(1)$get()

# Replace known slide 1 placeholders by shape name to avoid overlay boxes.
set_shape_text(slide_xml, "Title 2", "Stunting: Top 20 Country Rankings")
set_shape_text(slide_xml, "Text Placeholder 3", "Briefing for the Executive Director")

set_shape_text(slide_xml, "Text Placeholder 4", "April 2026")
set_shape_text(slide_xml, "Text Placeholder 5", "Data & Analytics Section, Office of Strategy and Evidence - Innocenti")

# ==========================================================================
# SLIDE 2: Nutrition photo divider + contents overview
# (Template slide 17 is kept at index 2, branded nutrition photo)
# Add a text overlay with the presentation outline
# ==========================================================================
pptx <- on_slide(pptx, index = 2)

# Replace the template text on the photo slide via XML
slide2_xml <- pptx$slide$get_slide(2)$get()
set_shape_text(slide2_xml, "TextBox 6", "Overview")

# Add overview content as overlay text box on the photo slide
overview_items <- list(
  fpar(ftext(paste0(bullet_marker, "Section 1: Stunting prevalence"),
    prop = fp_text(font.size = 22, color = "white", bold = TRUE, font.family = brand_font))),
  fpar(ftext(paste0("     Highest rates and biggest reductions"),
    prop = fp_text(font.size = 18, color = "white", font.family = brand_font))),
  fpar(ftext("", prop = fp_text(font.size = 12, font.family = brand_font)))
)

if (has_numbers) {
  overview_items <- c(overview_items, list(
    fpar(ftext(paste0(bullet_marker, "Section 2: Stunting burden"),
      prop = fp_text(font.size = 22, color = "white", bold = TRUE, font.family = brand_font))),
    fpar(ftext(paste0("     Number of children affected"),
      prop = fp_text(font.size = 18, color = "white", font.family = brand_font))),
    fpar(ftext("", prop = fp_text(font.size = 12, font.family = brand_font)))
  ))
}

overview_items <- c(overview_items, list(
  fpar(ftext(paste0(bullet_marker, "Key findings and programme implications"),
    prop = fp_text(font.size = 22, color = "white", bold = TRUE, font.family = brand_font)))
))

# Use body placeholder instead of a free text box to avoid stacked layers.
pptx <- ph_with(
  pptx,
  value = do.call(block_list, overview_items),
  location = ph_location_type(type = "body", type_idx = 1)
)
pptx <- ph_with(
  pptx,
  value = "",
  location = ph_location_type(type = "body", type_idx = 2)
)

# ==========================================================================
# SLIDE 3: Key headline findings (bulleted, easy to scan)
# ==========================================================================
top_high_country <- results$highest$country_name[1]
top_high_prev <- results$highest$prevalence[1]
top_10_country <- results$improve_10yr$country_name[1]
top_10_drop <- abs(results$improve_10yr$change_pp[1])
top_20_country <- results$improve_20yr$country_name[1]
top_20_drop <- abs(results$improve_20yr$change_pp[1])

bullet_items <- list(
  fpar(ftext(paste0(bullet_marker, top_high_country, ": highest prevalence at ",
    sprintf("%.1f", top_high_prev), " per cent (", latest_year, ")"),
    prop = body_props)),
  fpar(ftext("", prop = fp_text(font.size = 8, font.family = brand_font))),
  fpar(ftext(paste0(bullet_marker, top_10_country, ": largest 10-year reduction (",
    sprintf("%.1f", top_10_drop), " percentage points, ", yr_10_ago, "\u2013", latest_year, ")"),
    prop = body_props)),
  fpar(ftext("", prop = fp_text(font.size = 8, font.family = brand_font))),
  fpar(ftext(paste0(bullet_marker, top_20_country, ": largest 20-year reduction (",
    sprintf("%.1f", top_20_drop), " percentage points, ", yr_20_ago, "\u2013", latest_year, ")"),
    prop = body_props))
)

if (has_numbers) {
  top_num_country <- results$highest_number$country_name[1]
  top_num_val <- results$highest_number$number_thousands[1]
  bullet_items <- c(bullet_items, list(
    fpar(ftext("", prop = fp_text(font.size = 8, font.family = brand_font))),
    fpar(ftext(paste0(bullet_marker, top_num_country, ": highest burden with ",
      sprintf("%.1f", top_num_val / 1000), " million stunted children (", latest_year, ")"),
      prop = body_props))
  ))
}

bullet_items <- c(bullet_items, list(
  fpar(ftext("", prop = fp_text(font.size = 14, font.family = brand_font))),
  fpar(ftext("Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates, modelled series.",
    prop = source_props))
))

pptx <- pptx %>%
  add_slide(layout = "Title and Content", master = "UNICEF") %>%
  ph_with(value = "Stunting at a glance",
          location = ph_location_type(type = "title")) %>%
  ph_with(value = do.call(block_list, bullet_items),
          location = ph_location_type(type = "body"))

# ==========================================================================
# SECTION A: Prevalence (section divider using photo slide layout)
# ==========================================================================
pptx <- pptx %>%
  add_slide(layout = "UNICEF Photo slide", master = "UNICEF") %>%
  ph_with(value = fpar(ftext("Stunting prevalence",
    prop = fp_text(font.size = 44, bold = TRUE, color = unicef_dark, font.family = brand_font))),
    location = ph_location_type(type = "title")) %>%
  ph_with(value = fpar(ftext("Countries with the highest rates and fastest reductions",
    prop = fp_text(font.size = 22, color = unicef_warmgrey, font.family = brand_font))),
    location = ph_location_type(type = "body", type_idx = 1)) %>%
  ph_with(value = "", location = ph_location_type(type = "body", type_idx = 2))

# --- Chart slides: prevalence ---------------------------------------------
pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Highest stunting prevalence (", latest_year, ")"),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_highest), location = chart_loc)

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Biggest 10-year reduction in stunting (",
    yr_10_ago, "\u2013", latest_year, ")"),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_improve_10), location = chart_loc)

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Before and after: prevalence in ",
    yr_10_ago, " vs ", latest_year),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_dot_10), location = chart_loc)

pptx <- pptx %>%
  add_slide(layout = "Title Only", master = "UNICEF") %>%
  ph_with(value = paste0("Biggest 20-year reduction in stunting (",
    yr_20_ago, "\u2013", latest_year, ")"),
          location = ph_location_type(type = "title")) %>%
  ph_with(value = dml(ggobj = p_improve_20), location = chart_loc)

# ==========================================================================
# SECTION B: Burden (number of stunted children)
# ==========================================================================

if (has_numbers) {
  # --- Burden charts -------------------------------------------------------
  fmt_millions <- function(x) sprintf("%.1f M", x / 1000)

  p_highest_num <- results$highest_number %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = number_thousands)) +
    geom_col(fill = unicef_magenta, width = 0.7) +
    geom_text(aes(label = fmt_millions(number_thousands)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
    coord_flip(ylim = c(0, max(results$highest_number$number_thousands, na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL,
      caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
      x = NULL, y = "Stunted children (millions)"
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_10_num <- results$improve_10yr_number %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_green, width = 0.7) +
    geom_text(aes(label = sprintf("\u2013%.1f M", abs(change_th) / 1000)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
    coord_flip(ylim = c(0, max(abs(results$improve_10yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL,
      caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
      x = NULL, y = "Reduction (millions)"
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_20_num <- results$improve_20yr_number %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_dark, width = 0.7) +
    geom_text(aes(label = sprintf("\u2013%.1f M", abs(change_th) / 1000)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font) +
    coord_flip(ylim = c(0, max(abs(results$improve_20yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL,
      caption  = "Source: UNICEF/WHO/World Bank Joint Malnutrition Estimates",
      x = NULL, y = "Reduction (millions)"
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  # --- Section divider: Burden (using photo layout) ------------------------
  pptx <- pptx %>%
    add_slide(layout = "UNICEF Photo slide", master = "UNICEF") %>%
    ph_with(value = fpar(ftext("Stunting burden",
      prop = fp_text(font.size = 44, bold = TRUE, color = unicef_dark, font.family = brand_font))),
      location = ph_location_type(type = "title")) %>%
    ph_with(value = fpar(ftext("Number of children under 5 affected",
      prop = fp_text(font.size = 22, color = unicef_warmgrey, font.family = brand_font))),
      location = ph_location_type(type = "body", type_idx = 1)) %>%
    ph_with(value = "", location = ph_location_type(type = "body", type_idx = 2))

  pptx <- pptx %>%
    add_slide(layout = "Title Only", master = "UNICEF") %>%
    ph_with(value = paste0("Highest number of stunted children (", latest_year, ")"),
            location = ph_location_type(type = "title")) %>%
    ph_with(value = dml(ggobj = p_highest_num), location = chart_loc)

  pptx <- pptx %>%
    add_slide(layout = "Title Only", master = "UNICEF") %>%
    ph_with(value = paste0("Biggest 10-year reduction in numbers (",
      yr_10_ago, "\u2013", latest_year, ")"),
            location = ph_location_type(type = "title")) %>%
    ph_with(value = dml(ggobj = p_improve_10_num), location = chart_loc)

  pptx <- pptx %>%
    add_slide(layout = "Title Only", master = "UNICEF") %>%
    ph_with(value = paste0("Biggest 20-year reduction in numbers (",
      yr_20_ago, "\u2013", latest_year, ")"),
            location = ph_location_type(type = "title")) %>%
    ph_with(value = dml(ggobj = p_improve_20_num), location = chart_loc)
}

# ==========================================================================
# Key findings (bulleted narrative, easy to scan)
# ==========================================================================
top3_highest  <- paste(head(results$highest$country_name, 3), collapse = ", ")
top3_improv   <- paste(head(results$improve_10yr$country_name, 3), collapse = ", ")
max_change_10 <- sprintf("%.1f", max(abs(results$improve_10yr$change_pp), na.rm = TRUE))
max_change_20 <- sprintf("%.1f", max(abs(results$improve_20yr$change_pp), na.rm = TRUE))

findings <- list(
  fpar(ftext(paste0(bullet_marker, "Highest prevalence: ", top3_highest,
    " lead in ", latest_year), prop = bold_props)),
  fpar(ftext("", prop = fp_text(font.size = 8, font.family = brand_font))),
  fpar(ftext(paste0(bullet_marker, "10-year progress: ", top3_improv,
    " achieved the largest reductions (up to ", max_change_10, " pp)"),
    prop = body_props)),
  fpar(ftext("", prop = fp_text(font.size = 8, font.family = brand_font))),
  fpar(ftext(paste0(bullet_marker, "20-year progress: declines reached up to ",
    max_change_20, " percentage points (", yr_20_ago, "\u2013", latest_year, ")"),
    prop = body_props))
)

if (has_numbers) {
  top3_num <- paste(head(results$highest_number$country_name, 3), collapse = ", ")
  top_num_m <- sprintf("%.1f", results$highest_number$number_thousands[1] / 1000)
  findings <- c(findings, list(
    fpar(ftext("", prop = fp_text(font.size = 8, font.family = brand_font))),
    fpar(ftext(paste0(bullet_marker, "Absolute burden: ", top3_num,
      " bear the greatest numbers; ", results$highest_number$country_name[1],
      " alone has ", top_num_m, " million"), prop = body_props))
  ))
}

findings <- c(findings, list(
  fpar(ftext("", prop = fp_text(font.size = 14, font.family = brand_font))),
  fpar(ftext(
    "Source: UNICEF/WHO/World Bank JME modelled series. Improvement measured as absolute reduction.",
    prop = source_props))
))

pptx <- pptx %>%
  add_slide(layout = "Title and Content", master = "UNICEF") %>%
  ph_with(value = "Key findings and programme implications",
          location = ph_location_type(type = "title")) %>%
  ph_with(value = do.call(block_list, findings),
          location = ph_location_type(type = "body"))

# --- Move retained thank-you slide to the end -----------------------------
slide_text <- pptx_summary(pptx)
slide_ids <- unique(slide_text$slide_id)
thanks_id <- unique(slide_text$slide_id[trimws(slide_text$text) == "Thank you."])
if (length(thanks_id) > 0) {
  thanks_index <- match(thanks_id[1], slide_ids)
  if (!is.na(thanks_index) && thanks_index < length(pptx)) {
    pptx <- move_slide(pptx, index = thanks_index, to = length(pptx))
  }
}

# --- Save -----------------------------------------------------------------
pptx_path <- file.path(output_dir, "stunting_top20_briefing.pptx")
save_ok <- TRUE
save_err <- NULL

tryCatch(
  {
    print(pptx, target = pptx_path)
  },
  error = function(e) {
    save_ok <<- FALSE
    save_err <<- conditionMessage(e)
  }
)

if (save_ok) {
  message("PowerPoint saved: ", pptx_path)
} else {
  fallback_name <- paste0(
    "stunting_top20_briefing_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    ".pptx"
  )
  fallback_path <- file.path(output_dir, fallback_name)
  print(pptx, target = fallback_path)
  message("Primary output was locked; saved fallback PowerPoint: ", fallback_path)
  if (!is.null(save_err)) message("Primary save error: ", save_err)
}
