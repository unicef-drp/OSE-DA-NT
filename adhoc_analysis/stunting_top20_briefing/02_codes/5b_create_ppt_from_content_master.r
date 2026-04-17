# ---------------------------------------------------------------------------
# Script:  4b_create_ppt_from_content_master.r
# Purpose: Generate a test PowerPoint driven by the current markdown PPT
#          content master, while reusing the existing UNICEF slide modules
#          and chart logic.
# Inputs:  03_outputs/stunting_rankings.rds
#          00_documentation/PPT_CONTENT_MASTER_V1_2026-04-17.md
# Outputs: 03_outputs/stunting_top20_briefing_from_content_master_v1.pptx
#          03_outputs/stunting_top20_briefing_from_content_master_v1_data.xlsx
# ---------------------------------------------------------------------------

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) {
    if (is.null(x)) y else x
  }
}

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

adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis", "stunting_top20_briefing")
output_dir <- file.path(adhoc_output_root, "03_outputs")
rds_path <- file.path(output_dir, "stunting_rankings.rds")
content_path <- file.path(
  projectFolder,
  "adhoc_analysis",
  "stunting_top20_briefing",
  "00_documentation",
  "PPT_CONTENT_MASTER_V1_2026-04-17.md"
)

if (!file.exists(rds_path)) {
  stop("Rankings file not found: ", rds_path, ". Run 3_stunting_rankings.r first.")
}
if (!file.exists(content_path)) {
  stop("PPT content master not found: ", content_path)
}

results <- readRDS(rds_path)

latest_year <- results$metadata$latest_year
yr_10_ago <- results$metadata$yr_10_ago
yr_20_ago <- results$metadata$yr_20_ago
has_numbers <- !is.null(results$highest_number)

# --- Parse markdown content master ----------------------------------------
.trim_blank_edges <- function(x) {
  while (length(x) > 0 && !nzchar(trimws(x[1]))) x <- x[-1]
  while (length(x) > 0 && !nzchar(trimws(x[length(x)]))) x <- x[-length(x)]
  x
}

.extract_field_block <- function(block_lines, field_name) {
  field_prefix <- paste0("- ", field_name, ":")
  field_idx <- which(startsWith(block_lines, field_prefix))
  if (length(field_idx) == 0) return(character(0))

  first_line <- sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", field_prefix)), "", block_lines[field_idx[1]])
  first_line <- trimws(first_line)

  start_idx <- field_idx[1] + 1L
  if (start_idx > length(block_lines)) {
    return(if (nzchar(first_line)) first_line else character(0))
  }

  stop_idx <- length(block_lines) + 1L
  for (i in seq.int(start_idx, length(block_lines))) {
    line_i <- block_lines[i]
    if (grepl("^- [^:]+:", line_i) ||
        grepl("^Proposed figure:", line_i) ||
        grepl("^Optional companion table preview:", line_i) ||
        grepl("^### Slide ", line_i)) {
      stop_idx <- i
      break
    }
  }

  out <- if (start_idx < stop_idx) block_lines[start_idx:(stop_idx - 1L)] else character(0)
  if (nzchar(first_line)) out <- c(first_line, out)
  out <- sub("^  ", "", out)
  .trim_blank_edges(out)
}

.parse_numbered_items <- function(lines) {
  bullets <- character(0)
  current <- ""

  for (line_i in lines) {
    if (!nzchar(trimws(line_i))) next

    if (grepl("^[0-9]+\\.\\s+", line_i)) {
      if (nzchar(current)) bullets <- c(bullets, current)
      current <- sub("^[0-9]+\\.\\s+", "", trimws(line_i))
    } else if (nzchar(current)) {
      current <- paste(current, trimws(line_i))
    }
  }

  if (nzchar(current)) bullets <- c(bullets, current)
  bullets
}

.parse_slide_sections <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  header_idx <- grep("^### Slide [0-9]+ - ", lines)
  if (length(header_idx) == 0) stop("No slide sections found in: ", path)

  slides <- list()
  for (i in seq_along(header_idx)) {
    start_idx <- header_idx[i]
    end_idx <- if (i < length(header_idx)) header_idx[i + 1] - 1L else length(lines)
    block <- lines[start_idx:end_idx]

    header_match <- regexec("^### Slide ([0-9]+) - (.+)$", block[1])
    header_parts <- regmatches(block[1], header_match)[[1]]
    slide_num <- as.integer(header_parts[2])
    slide_label <- header_parts[3]

    on_slide <- .extract_field_block(block, "On-slide text")
    speaker_notes <- .extract_field_block(block, "Speaker notes")
    slide_type <- .extract_field_block(block, "Slide type")
    chart_desc <- .extract_field_block(block, "Chart/table")

    slides[[as.character(slide_num)]] <- list(
      number = slide_num,
      label = slide_label,
      slide_type = paste(slide_type, collapse = " "),
      on_slide = on_slide,
      speaker_notes = speaker_notes,
      chart_desc = chart_desc
    )
  }

  slides
}

slides <- .parse_slide_sections(content_path)
message("Parsed markdown content master: ", basename(content_path))

.slide_nonempty_lines <- function(slide_obj) {
  slide_obj$on_slide[nzchar(trimws(slide_obj$on_slide))]
}

.slide_title_from_text <- function(slide_obj, fallback = slide_obj$label) {
  nonempty <- .slide_nonempty_lines(slide_obj)
  if (length(nonempty) == 0) return(fallback)
  trimws(nonempty[1])
}

.section_items_from_text <- function(slide_obj) {
  nonempty <- .slide_nonempty_lines(slide_obj)
  if (length(nonempty) <= 1) return(character(0))
  trimws(nonempty[-1])
}

.collapse_note_text <- function(lines) {
  if (length(lines) == 0) return("")

  paragraphs <- list()
  current <- character(0)
  for (line_i in lines) {
    if (!nzchar(trimws(line_i))) {
      if (length(current) > 0) {
        paragraphs[[length(paragraphs) + 1L]] <- paste(trimws(current), collapse = " ")
        current <- character(0)
      }
    } else {
      current <- c(current, line_i)
    }
  }
  if (length(current) > 0) {
    paragraphs[[length(paragraphs) + 1L]] <- paste(trimws(current), collapse = " ")
  }

  paste(unlist(paragraphs, use.names = FALSE), collapse = "\n\n")
}

# --- UNICEF brand assets --------------------------------------------------
brand_root <- file.path(nutritionRoot, "github", "documentation", "unicef_brand")
brand_dir <- file.path(brand_root, "_extracted")

onedrive_dirs <- list.dirs(brand_root, recursive = FALSE, full.names = TRUE)
onedrive_dirs <- onedrive_dirs[grepl("OneDrive", basename(onedrive_dirs), ignore.case = TRUE)]

template_candidates <- c(
  file.path(brand_root, "UNICEF Branded Presentation Template 2026.pptx"),
  file.path(brand_root, "UNICEF Branded Presentation Template 2025.pptx")
)

template_candidates <- c(template_candidates, unlist(lapply(onedrive_dirs, function(d) {
  candidates <- c(
    file.path(d, "Brand template_PowerPoint Presentation", "UNICEF Branded Presentation Template 2026.pptx"),
    file.path(d, "UNICEF Branded Presentation Template 2026.pptx"),
    file.path(d, "Brand template_PowerPoint Presentation", "UNICEF Branded Presentation Template 2025.pptx"),
    file.path(d, "UNICEF Branded Presentation Template 2025.pptx")
  )
  candidates[file.exists(candidates)]
})))

template_candidates <- c(template_candidates, file.path(brand_dir, "template_2026.pptx"))
template_path <- template_candidates[file.exists(template_candidates)][1]

if (is.na(template_path) || !nzchar(template_path)) {
  stop(
    "UNICEF template not found. Checked: ",
    paste(template_candidates, collapse = ", ")
  )
}

if (nchar(template_path) > 200) {
  tmp_template <- file.path(tempdir(), "unicef_template_tmp.pptx")
  file.copy(template_path, tmp_template, overwrite = TRUE)
  message("Copied template to temp path for long-path compatibility: ", tmp_template)
  template_path <- tmp_template
}

# --- UNICEF brand tokens --------------------------------------------------
unicef_cyan <- unicef_tokens$colour$cyan
unicef_dark <- unicef_tokens$colour$dark_blue
unicef_green <- unicef_tokens$colour$green
unicef_orange <- unicef_tokens$colour$orange
unicef_magenta <- unicef_tokens$colour$magenta
unicef_warmgrey <- unicef_tokens$colour$warm_grey
unicef_coolgrey <- unicef_tokens$colour$cool_grey
unicef_black <- unicef_tokens$colour$black
brand_font <- unicef_tokens$font$family
chart_caption <- paste(
  "Data source: OSE-DA-NT stunting briefing outputs derived from",
  "cmrs2_series_accepted.parquet via stunting_rankings.rds"
)

bullet_style <- fp_text(font.size = 18, font.family = brand_font, color = unicef_dark)

# --- ggplot theme ---------------------------------------------------------
theme_unicef <- theme_minimal(base_size = 16, base_family = brand_font) +
  theme(
    plot.title = element_text(face = "bold", size = 24, colour = unicef_dark),
    plot.subtitle = element_text(size = 16, colour = unicef_warmgrey, margin = margin(b = 10)),
    plot.caption = element_text(size = 10, colour = unicef_coolgrey, hjust = 0),
    axis.title = element_text(size = 14, colour = unicef_warmgrey),
    axis.text = element_text(size = 13, colour = unicef_black),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "#E6E6E6", linewidth = 0.5),
    panel.grid.minor = element_blank(),
    legend.position = "none",
    plot.margin = margin(10, 20, 10, 10)
  )

fmt_millions <- function(x) sprintf("%.1f M", x / 1000)

# --- Charts ---------------------------------------------------------------
p_highest <- results$highest %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = prevalence)) +
  geom_col(fill = unicef_cyan, width = 0.7) +
  geom_text(
    aes(label = sprintf("%.1f%%", prevalence)),
    hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font
  ) +
  coord_flip(ylim = c(0, max(results$highest$prevalence, na.rm = TRUE) * 1.15)) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption, x = NULL, y = "Prevalence (%)") +
  scale_y_continuous(labels = scales::label_percent(scale = 1)) +
  theme_unicef

p_improve_10 <- results$improve_10yr %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = abs(change_pp))) +
  geom_col(fill = unicef_green, width = 0.7) +
  geom_text(
    aes(label = sprintf("-%.1f pp", abs(change_pp))),
    hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font
  ) +
  coord_flip(ylim = c(0, max(abs(results$improve_10yr$change_pp), na.rm = TRUE) * 1.15)) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption, x = NULL, y = "Reduction (pp)") +
  theme_unicef

p_dot_10 <- results$improve_10yr %>%
  head(15) %>%
  arrange(current_value) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(y = label)) +
  geom_segment(
    aes(x = current_value, xend = baseline_value, yend = label),
    colour = unicef_coolgrey, linewidth = 0.6
  ) +
  geom_point(aes(x = current_value, colour = "current"), size = 2.5) +
  geom_point(aes(x = baseline_value, colour = "baseline"), size = 2.5) +
  scale_colour_manual(
    values = c("current" = unicef_green, "baseline" = unicef_orange),
    labels = setNames(c(as.character(latest_year), as.character(yr_10_ago)), c("current", "baseline")),
    breaks = c("current", "baseline")
  ) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption, x = "Prevalence (%)", y = NULL, colour = NULL) +
  scale_x_continuous(labels = scales::label_percent(scale = 1)) +
  theme_unicef +
  theme(legend.position = "top", legend.text = element_text(size = 13))

p_improve_20 <- results$improve_20yr %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
  mutate(label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = abs(change_pp))) +
  geom_col(fill = unicef_dark, width = 0.7) +
  geom_text(
    aes(label = sprintf("-%.1f pp", abs(change_pp))),
    hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font
  ) +
  coord_flip(ylim = c(0, max(abs(results$improve_20yr$change_pp), na.rm = TRUE) * 1.15)) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption, x = NULL, y = "Reduction (pp)") +
  theme_unicef

if (has_numbers) {
  p_highest_num <- results$highest_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = number_thousands)) +
    geom_col(fill = unicef_magenta, width = 0.7) +
    geom_text(
      aes(label = fmt_millions(number_thousands)),
      hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font
    ) +
    coord_flip(ylim = c(0, max(results$highest_number$number_thousands, na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL, caption = chart_caption, x = NULL, y = "Stunted children (millions)") +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_10_num <- results$improve_10yr_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_green, width = 0.7) +
    geom_text(
      aes(label = sprintf("-%.1f M", abs(change_th) / 1000)),
      hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font
    ) +
    coord_flip(ylim = c(0, max(abs(results$improve_10yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL, caption = chart_caption, x = NULL, y = "Reduction (millions)") +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_20_num <- results$improve_20yr_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")")) %>%
    mutate(label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_dark, width = 0.7) +
    geom_text(
      aes(label = sprintf("-%.1f M", abs(change_th) / 1000)),
      hjust = -0.1, size = 4.4, colour = unicef_warmgrey, family = brand_font
    ) +
    coord_flip(ylim = c(0, max(abs(results$improve_20yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL, caption = chart_caption, x = NULL, y = "Reduction (millions)") +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef
}

  message("Built chart objects from rankings data.")

.add_chart_slide <- function(pptx, title_text, ggobj) {
  pptx <- officer::add_slide(pptx, layout = "Title Only", master = "UNICEF")
  pptx <- officer::ph_with(
    pptx,
    value = title_text,
    location = officer::ph_location_type(type = "title")
  )
  officer::ph_with(
    pptx,
    value = rvg::dml(ggobj = ggobj),
    location = officer::ph_location(left = 0.7, top = 1.5, width = 11.3, height = 5.3)
  )
}

# --- Build deck -----------------------------------------------------------
title_slide_lines <- .slide_nonempty_lines(slides[["2"]])
title_text <- if (length(title_slide_lines) >= 1) trimws(title_slide_lines[1]) else "Child Stunting"
subtitle_text <- if (length(title_slide_lines) >= 2) trimws(title_slide_lines[2]) else "Executive Director briefing"

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

pptx <- apply_title_text(
  pptx,
  slide_index = 1,
  title = title_text,
  subtitle = subtitle_text,
  section = "Office of Strategy and Evidence\nData & Analytics Section - Nutrition",
  date = format(Sys.Date(), "%B %Y")
)

pptx <- add_section_slide(
  pptx,
  title = .slide_title_from_text(slides[["3"]], fallback = slides[["3"]]$label),
  items = .section_items_from_text(slides[["3"]]),
  style = bullet_style,
  footer_title = title_text
)

slide4_bullets <- .parse_numbered_items(slides[["4"]]$on_slide)
pptx <- add_bullet_slides(
  pptx,
  title = slides[["4"]]$label,
  bullets = slide4_bullets,
  levels = rep(1L, length(slide4_bullets)),
  style = bullet_style,
  footer_title = title_text,
  max_groups = 4
)

pptx <- add_section_slide(
  pptx,
  title = .slide_title_from_text(slides[["5"]], fallback = slides[["5"]]$label),
  items = .section_items_from_text(slides[["5"]]),
  style = bullet_style,
  footer_title = title_text
)

pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["6"]], slides[["6"]]$label), p_highest)
pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["7"]], slides[["7"]]$label), p_improve_10)
pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["8"]], slides[["8"]]$label), p_dot_10)
pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["9"]], slides[["9"]]$label), p_improve_20)

if (has_numbers) {
  pptx <- add_section_slide(
    pptx,
    title = .slide_title_from_text(slides[["10"]], fallback = slides[["10"]]$label),
    items = .section_items_from_text(slides[["10"]]),
    style = bullet_style,
    footer_title = title_text
  )

  pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["11"]], slides[["11"]]$label), p_highest_num)
  pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["12"]], slides[["12"]]$label), p_improve_10_num)
  pptx <- .add_chart_slide(pptx, .slide_title_from_text(slides[["13"]], slides[["13"]]$label), p_improve_20_num)
}

slide14_bullets <- .parse_numbered_items(slides[["14"]]$on_slide)
pptx <- add_bullet_slides(
  pptx,
  title = slides[["14"]]$label,
  bullets = slide14_bullets,
  levels = rep(1L, length(slide14_bullets)),
  style = bullet_style,
  footer_title = title_text,
  max_groups = 4
)

message("Built PowerPoint slide content in memory.")

# --- Save and reorder slides ----------------------------------------------
pptx_path <- file.path(output_dir, "stunting_top20_briefing_from_content_master_v1.pptx")
print(pptx, target = pptx_path)
message("Wrote PPTX before slide reordering: ", pptx_path)

.reorder_pptx_slides <- function(pptx_path, new_order) {
  extract_dir <- file.path(tempdir(), paste0("pptx_reorder_", format(Sys.time(), "%H%M%S")))
  on.exit(unlink(extract_dir, recursive = TRUE), add = TRUE)
  utils::unzip(pptx_path, exdir = extract_dir)

  pres_path <- file.path(extract_dir, "ppt", "presentation.xml")
  pres_text <- paste(readLines(pres_path, warn = FALSE), collapse = "\n")

  sld_pat <- '<p:sldId\\s+id="\\d+"\\s+r:id="rId\\d+"\\s*/>'
  entries <- regmatches(pres_text, gregexpr(sld_pat, pres_text, perl = TRUE))[[1]]
  stopifnot(length(entries) == length(new_order))

  reordered <- entries[new_order]
  lst_pat <- '(<p:sldIdLst[^>]*>)\\s*((?:<p:sldId[^/]*/?>\\s*)+)(</p:sldIdLst>)'
  replacement <- paste0("\\1\n  ", paste(reordered, collapse = "\n  "), "\n\\3")
  pres_text <- sub(lst_pat, replacement, pres_text, perl = TRUE)

  writeLines(pres_text, pres_path)

  wd <- getwd()
  on.exit(setwd(wd), add = TRUE)
  setwd(extract_dir)
  file.remove(pptx_path)
  zip::zip(pptx_path, files = list.files(".", recursive = TRUE, all.files = TRUE))
}

n_slides <- length(pptx)
new_order <- c(2L, 1L, seq(4L, n_slides), 3L)
.reorder_pptx_slides(pptx_path, new_order)
message("PowerPoint saved: ", pptx_path)

# --- Excel workbook with chart data ---------------------------------------
wb <- createWorkbook()

s1 <- results$highest %>% head(15) %>%
  select(rank, REF_AREA, country_name, year, prevalence)
addWorksheet(wb, "Highest prevalence")
writeData(wb, "Highest prevalence", s1)

s2 <- results$improve_10yr %>% head(15) %>%
  select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
addWorksheet(wb, "10yr improvement")
writeData(wb, "10yr improvement", s2)

s3 <- results$improve_10yr %>% head(15) %>%
  arrange(current_value) %>%
  select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp)
addWorksheet(wb, "10yr before-after")
writeData(wb, "10yr before-after", s3)

s4 <- results$improve_20yr %>% head(15) %>%
  select(rank, REF_AREA, country_name, baseline_value, current_value, change_pp, pct_change)
addWorksheet(wb, "20yr improvement")
writeData(wb, "20yr improvement", s4)

if (has_numbers) {
  s5 <- results$highest_number %>% head(15) %>%
    select(rank, REF_AREA, country_name, year, number_thousands)
  addWorksheet(wb, "Highest number")
  writeData(wb, "Highest number", s5)

  s6 <- results$improve_10yr_number %>% head(15) %>%
    select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)
  addWorksheet(wb, "10yr number reduction")
  writeData(wb, "10yr number reduction", s6)

  s7 <- results$improve_20yr_number %>% head(15) %>%
    select(rank, REF_AREA, country_name, baseline_value, current_value, change_th, pct_change)
  addWorksheet(wb, "20yr number reduction")
  writeData(wb, "20yr number reduction", s7)
}

xlsx_path <- file.path(output_dir, "stunting_top20_briefing_from_content_master_v1_data.xlsx")
saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("Excel data saved: ", xlsx_path)

notes_path <- file.path(output_dir, "stunting_top20_briefing_from_content_master_v1_notes.txt")
note_lines <- unlist(lapply(slides, function(slide_obj) {
  note_text <- .collapse_note_text(slide_obj$speaker_notes)
  c(
    paste0("Slide ", slide_obj$number, " - ", slide_obj$label),
    if (nzchar(note_text)) note_text else "No speaker notes.",
    ""
  )
}), use.names = FALSE)
writeLines(note_lines, notes_path)
message("Speaker notes saved: ", notes_path)