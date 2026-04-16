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

# --- Load slide modules ---------------------------------------------------
codes_dir_ppt <- dirname(sys.frame(1)$ofile %||% ".")
source(file.path(codes_dir_ppt, "00_pptx_design_tokens.r"))
source(file.path(codes_dir_ppt, "00_pptx_title_slide.r"))
source(file.path(codes_dir_ppt, "00_pptx_bullet_slide.r"))
source(file.path(codes_dir_ppt, "00_pptx_section_slide.r"))

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
brand_root <- file.path(nutritionRoot, "github", "documentation", "unicef_brand")
brand_dir <- file.path(brand_root, "_extracted")

onedrive_dirs <- list.dirs(brand_root, recursive = FALSE, full.names = TRUE)
onedrive_dirs <- onedrive_dirs[grepl("OneDrive", basename(onedrive_dirs), ignore.case = TRUE)]

# First check brand_root (short path, avoids long-path issues)
template_candidates <- c(
  file.path(brand_root, "UNICEF Branded Presentation Template 2026.pptx"),
  file.path(brand_root, "UNICEF Branded Presentation Template 2025.pptx")
)

# Then check inside OneDrive subfolders
template_candidates <- c(template_candidates, unlist(lapply(onedrive_dirs, function(d) {
  candidates <- c(
    file.path(d, "Brand template_PowerPoint Presentation", "UNICEF Branded Presentation Template 2026.pptx"),
    file.path(d, "UNICEF Branded Presentation Template 2026.pptx"),
    file.path(d, "Brand template_PowerPoint Presentation", "UNICEF Branded Presentation Template 2025.pptx"),
    file.path(d, "UNICEF Branded Presentation Template 2025.pptx")
  )
  candidates[file.exists(candidates)]
})))

# Legacy fallback
template_candidates <- c(template_candidates, file.path(brand_dir, "template_2026.pptx"))
template_path <- template_candidates[file.exists(template_candidates)][1]

if (is.na(template_path) || !nzchar(template_path)) {
  stop(
    "UNICEF template not found. Checked: ",
    paste(template_candidates, collapse = ", ")
  )
}

# Workaround: R's zip library cannot handle very long paths (common with
# OneDrive/Teams sync folders). Copy to a temp file for read_pptx().
if (nchar(template_path) > 200) {
  tmp_template <- file.path(tempdir(), "unicef_template_tmp.pptx")
  file.copy(template_path, tmp_template, overwrite = TRUE)
  message("Copied template to temp path for long-path compatibility: ", tmp_template)
  template_path <- tmp_template
}

# --- UNICEF brand colours (from design tokens) ----------------------------
unicef_cyan    <- unicef_tokens$colour$cyan
unicef_dark    <- unicef_tokens$colour$dark_blue
unicef_green   <- unicef_tokens$colour$green
unicef_yellow  <- unicef_tokens$colour$yellow
unicef_orange  <- unicef_tokens$colour$orange
unicef_red     <- unicef_tokens$colour$red
unicef_magenta <- unicef_tokens$colour$magenta
unicef_purple  <- unicef_tokens$colour$purple
unicef_warmgrey <- unicef_tokens$colour$warm_grey
unicef_coolgrey <- unicef_tokens$colour$cool_grey
unicef_black   <- unicef_tokens$colour$black
brand_font     <- unicef_tokens$font$family

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
# Pick a random title-slide variant (1-11) based on the title text hash,
# keep the branded divider (slide 17) and a random thank-you slide (71-76).
title_text    <- "Stunting: Current Levels and Trends Over Two Decades"
subtitle_text <- "Executive Director briefing"

title_variant <- pick_title_variant(title_text)
thankyou_variant <- sample(71:76, 1)

pptx <- read_pptx(template_path)
n_template_slides <- length(pptx)
keep_slides <- c(17, title_variant, thankyou_variant)
if (n_template_slides > 0) {
  for (i in seq(n_template_slides, 1)) {
    if (!(i %in% keep_slides)) {
      pptx <- remove_slide(pptx, index = i)
    }
  }
}
# Track position of thank-you slide among retained template slides
# After removal, slides are in original template order:
#   position 1 = title_variant (1-11), position 2 = slide 17, position 3 = thank-you
# Apply title text at position 1 (where the title variant naturally sits).
pptx <- apply_title_text(
  pptx, slide_index = 1,
  title    = title_text,
  subtitle = subtitle_text,
  section  = "Office of Strategy and Evidence\nData & Analytics Section - Nutrition",
  date     = format(Sys.Date(), "%B %Y")
)

# Slide 1 is the title (title_variant), slide 2 is the branded divider (17),
# slide 3 is the thank-you.  New slides are appended after slide 3.
# After the deck is built we post-process the PPTX zip to reorder slides
# (see below) because officer::move_slide is non-functional in this version.

# --- Section counter (incremented for each section divider) ---------------
section_num <- 0L

bullet_style <- fp_text(font.size = 18, font.family = brand_font, color = unicef_dark)

# --- Icon paths for section slides ----------------------------------------
icons_dir <- file.path(dirname(codes_dir_ppt), "01_inputs", "icons")
icon_overview   <- file.path(icons_dir, "nutrition.png")
icon_prevalence <- file.path(icons_dir, "children.png")
icon_burden     <- file.path(icons_dir, "infant.png")

# --- Slide 3: Overview (sections of the briefing) ------------------------
section_num <- section_num + 1L
overview_items <- c(
  "What this briefing shows",
  "Stunting prevalence: highest rates and fastest reductions"
)
if (has_numbers) {
  overview_items <- c(overview_items,
    "Stunting burden: number of children affected"
  )
}
overview_items <- c(overview_items, "Key findings and programme implications")

pptx <- add_section_slide(pptx, title = "Overview",
                          items = overview_items, section_number = section_num,
                          style = bullet_style, footer_title = title_text,
                          icon_path = icon_overview)

# --- Headline summary -----------------------------------------------------
top_high_country <- results$highest$country_name[1]
top_high_prev <- results$highest$prevalence[1]
top_10_country <- results$improve_10yr$country_name[1]
top_10_drop <- abs(results$improve_10yr$change_pp[1])
top_20_country <- results$improve_20yr$country_name[1]
top_20_drop <- abs(results$improve_20yr$change_pp[1])

summary_bullets <- c(
  "This briefing presents country rankings based on modelled stunting estimates for children under 5 years, covering both prevalence and the number of children affected.",
  paste0("Highest current prevalence: ", top_high_country, " at ",
         sprintf("%.1f", top_high_prev), " per cent in ", latest_year, "."),
  paste0("Fastest 10-year reduction: ", top_10_country, " with a decline of ",
         sprintf("%.1f", top_10_drop), " percentage points (", yr_10_ago, "\u2013", latest_year, ")."),
  paste0("Fastest 20-year reduction: ", top_20_country, " with a decline of ",
         sprintf("%.1f", top_20_drop), " percentage points (", yr_20_ago, "\u2013", latest_year, ").")
)
summary_levels <- c(1, 2, 2, 2)

if (has_numbers) {
  top_num_country <- results$highest_number$country_name[1]
  top_num_val <- results$highest_number$number_thousands[1]
  summary_bullets <- c(summary_bullets,
    paste0("Highest burden: ", top_num_country, " with an estimated ",
           sprintf("%.1f", top_num_val / 1000), " million stunted children in ", latest_year, ".")
  )
  summary_levels <- c(summary_levels, 2)
}

pptx <- add_bullet_slides(pptx, "What this briefing shows",
                          bullets = summary_bullets, levels = summary_levels,
                          style = bullet_style, footer_title = title_text)

# =========================================================================
# SECTION A: Prevalence
# =========================================================================

section_num <- section_num + 1L
pptx <- add_section_slide(pptx, title = "Stunting prevalence",
                          items = c("Countries with the highest rates and fastest reductions"),
                          section_number = section_num,
                          style = bullet_style, footer_title = title_text,
                          icon_path = icon_prevalence)

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
  section_num <- section_num + 1L
  pptx <- add_section_slide(pptx, title = "Stunting burden: number of children affected",
                            items = c("Countries with the highest absolute numbers and largest reductions"),
                            section_number = section_num,
                            style = bullet_style, footer_title = title_text,
                            icon_path = icon_burden)

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

narrative_bullets <- c(
  paste0("Highest prevalence: As of ", latest_year, ", the countries with the highest stunting prevalence ",
         "among children under 5 years include ", top3_highest, ". ",
         "These countries continue to carry a large share of the global burden."),
  paste0("10-year progress: Between ", yr_10_ago, " and ", latest_year, ", ",
         top3_improv, " achieved the largest absolute reductions in stunting prevalence, ",
         "with the top performer reducing prevalence by ", max_change_10, " percentage points."),
  paste0("20-year progress: Over the past two decades (", yr_20_ago, "\u2013", latest_year, "), ",
         "the most substantial declines reached up to ", max_change_20, " percentage points.")
)
narrative_levels <- c(1, 1, 1)

if (has_numbers) {
  top3_num <- paste(head(results$highest_number$country_name, 3), collapse = ", ")
  top_num_val_m <- sprintf("%.1f", results$highest_number$number_thousands[1] / 1000)
  narrative_bullets <- c(narrative_bullets,
    paste0("Absolute burden: By number of children affected, ", top3_num,
           " bear the greatest burden, with ", results$highest_number$country_name[1],
           " alone accounting for an estimated ", top_num_val_m,
           " million stunted children in ", latest_year, ".")
  )
  narrative_levels <- c(narrative_levels, 1)
}

narrative_bullets <- c(narrative_bullets,
  paste0("Note: Estimates are based on UNICEF/WHO/World Bank Joint Malnutrition Estimates (JME) ",
         "modelled country series. Improvement is measured as absolute reduction in prevalence ",
         "(percentage points) or number of children affected (thousands).")
)
narrative_levels <- c(narrative_levels, 1)

pptx <- add_bullet_slides(pptx, "Key findings and programme implications",
                          bullets = narrative_bullets, levels = narrative_levels,
                          style = bullet_style, footer_title = title_text)

# --- Save and reorder slides ----------------------------------------------
# officer::move_slide() is non-functional in this version, so we post-process
# the saved PPTX zip to reorder the sldIdLst in presentation.xml.
# After removal + appends, the internal order is:
#   1 = title_variant, 2 = slide 17 (divider), 3 = thank-you, 4..N = content
# Desired order:
#   1 = divider, 2 = title, 3..N-1 = content, N = thank-you
pptx_path <- file.path(output_dir, "stunting_top20_briefing.pptx")
print(pptx, target = pptx_path)

.reorder_pptx_slides <- function(pptx_path, new_order) {
  extract_dir <- file.path(tempdir(), paste0("pptx_reorder_", format(Sys.time(), "%H%M%S")))
  on.exit(unlink(extract_dir, recursive = TRUE), add = TRUE)
  utils::unzip(pptx_path, exdir = extract_dir)

  pres_path <- file.path(extract_dir, "ppt", "presentation.xml")
  pres_text <- paste(readLines(pres_path, warn = FALSE), collapse = "\n")

  # Extract all sldId entries in order
  sld_pat <- '<p:sldId\\s+id="\\d+"\\s+r:id="rId\\d+"\\s*/>'
  entries <- regmatches(pres_text, gregexpr(sld_pat, pres_text, perl = TRUE))[[1]]
  stopifnot(length(entries) == length(new_order))

  # Build reordered block
  reordered <- entries[new_order]

  # Replace the sldIdLst content
  lst_pat <- '(<p:sldIdLst[^>]*>)\\s*((?:<p:sldId[^/]*/?>\\s*)+)(</p:sldIdLst>)'
  replacement <- paste0("\\1\n  ", paste(reordered, collapse = "\n  "), "\n\\3")
  pres_text <- sub(lst_pat, replacement, pres_text, perl = TRUE)

  writeLines(pres_text, pres_path)

  # Re-zip (overwrite original)
  wd <- getwd()
  on.exit(setwd(wd), add = TRUE)
  setwd(extract_dir)
  file.remove(pptx_path)
  zip::zip(pptx_path, files = list.files(".", recursive = TRUE, all.files = TRUE))
}

# Build the reorder map:
# Internal positions: 1=title, 2=divider, 3=thankyou, 4..N=content slides
# Desired: divider(2), title(1), content(4..N), thankyou(3)
n_slides <- length(pptx)
new_order <- c(2L, 1L, seq(4L, n_slides), 3L)
.reorder_pptx_slides(pptx_path, new_order)
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
