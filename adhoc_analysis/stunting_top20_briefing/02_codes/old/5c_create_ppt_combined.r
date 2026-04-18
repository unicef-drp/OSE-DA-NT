# ---------------------------------------------------------------------------
# Script:  4c_create_ppt_combined.r
# Purpose: Generate a UNICEF-branded PowerPoint by combining:
#          (a) narrative content parsed from the markdown PPT content master
#          (b) chart and design logic from the existing slide modules
#          Speaker notes from the content master are written directly into
#          PowerPoint slides (not only to a companion text file).
# Inputs:  03_outputs/stunting_rankings.rds
#          00_documentation/PPT_CONTENT_MASTER_V1_2026-04-17.md
# Outputs: 03_outputs/stunting_top20_briefing_combined.pptx
#          03_outputs/stunting_top20_briefing_combined_data.xlsx
#          03_outputs/stunting_top20_briefing_combined_notes.txt
# ---------------------------------------------------------------------------

if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
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

adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis",
                               "stunting_top20_briefing")
output_dir  <- file.path(adhoc_output_root, "03_outputs")
rds_path    <- file.path(output_dir, "stunting_rankings.rds")
content_path <- file.path(
  projectFolder,
  "adhoc_analysis", "stunting_top20_briefing", "00_documentation",
  "PPT_CONTENT_MASTER_V1_2026-04-17.md"
)

if (!file.exists(rds_path))    stop("Rankings not found: ", rds_path)
if (!file.exists(content_path)) stop("Content master not found: ", content_path)

results     <- readRDS(rds_path)
latest_year <- results$metadata$latest_year
yr_10_ago   <- results$metadata$yr_10_ago
yr_20_ago   <- results$metadata$yr_20_ago
has_numbers <- !is.null(results$highest_number)

message("[4c] Loaded rankings: ", latest_year, ", 10yr=", yr_10_ago,
        ", 20yr=", yr_20_ago, ", burden=", has_numbers)

# =========================================================================
# 1. Parse content master
# =========================================================================

.parse_content_master <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  header_idx <- grep("^### Slide [0-9]+ - ", lines)
  if (length(header_idx) == 0) stop("No slide sections in: ", path)

  slides <- list()
  for (i in seq_along(header_idx)) {
    start <- header_idx[i]
    end   <- if (i < length(header_idx)) header_idx[i + 1] - 1L else length(lines)
    block <- lines[start:end]

    m <- regexec("^### Slide ([0-9]+) - (.+)$", block[1])
    parts <- regmatches(block[1], m)[[1]]

    slides[[parts[2]]] <- list(
      number  = as.integer(parts[2]),
      label   = parts[3],
      type    = trimws(paste(.field(block, "Slide type"), collapse = " ")),
      on_slide     = .field(block, "On-slide text"),
      speaker_notes = .field(block, "Speaker notes"),
      chart_desc    = .field(block, "Chart/table")
    )
  }
  slides
}

# Extract a named field block from slide markdown lines
.field <- function(block, name) {
  prefix <- paste0("- ", name, ":")
  idx <- which(startsWith(block, prefix))
  if (length(idx) == 0) return(character(0))

  # Inline value on the same line as the field header
  inline <- trimws(sub(paste0("^\\Q", prefix, "\\E"), "",
                       block[idx[1]], perl = TRUE))

  start <- idx[1] + 1L
  if (start > length(block)) {
    return(if (nzchar(inline)) inline else character(0))
  }

  # Find where the next field or structural element starts
  stop_at <- length(block) + 1L
  for (j in seq.int(start, length(block))) {
    if (grepl("^- [^:]+:", block[j]) ||
        grepl("^Proposed figure:", block[j]) ||
        grepl("^Optional companion table preview:", block[j]) ||
        grepl("^### Slide ", block[j])) {
      stop_at <- j
      break
    }
  }

  body <- if (start < stop_at) sub("^  ", "", block[start:(stop_at - 1L)])
          else character(0)
  out <- if (nzchar(inline)) c(inline, body) else body

  # Trim leading/trailing blank lines
  while (length(out) > 0 && !nzchar(trimws(out[1])))          out <- out[-1]
  while (length(out) > 0 && !nzchar(trimws(out[length(out)]))) out <- out[-length(out)]
  out
}

slides <- .parse_content_master(content_path)
message("[4c] Parsed ", length(slides), " slide sections from content master")

# Helpers ------------------------------------------------------------------

.nonempty <- function(x) x[nzchar(trimws(x))]

.title_from <- function(sl, fallback = sl$label) {
  ne <- .nonempty(sl$on_slide)
  if (length(ne) >= 1) trimws(ne[1]) else fallback
}

.items_from <- function(sl) {
  ne <- .nonempty(sl$on_slide)
  if (length(ne) <= 1) character(0) else trimws(ne[-1])
}

.numbered_bullets <- function(lines) {
  bullets <- character(0); cur <- ""
  for (ln in lines) {
    if (!nzchar(trimws(ln))) next
    if (grepl("^[0-9]+\\.\\s+", ln)) {
      if (nzchar(cur)) bullets <- c(bullets, cur)
      cur <- sub("^[0-9]+\\.\\s+", "", trimws(ln))
    } else if (nzchar(cur)) {
      cur <- paste(cur, trimws(ln))
    }
  }
  if (nzchar(cur)) bullets <- c(bullets, cur)
  bullets
}

.notes_text <- function(lines) {
  if (length(lines) == 0) return("")
  paras <- list(); cur <- character(0)
  for (ln in lines) {
    if (!nzchar(trimws(ln))) {
      if (length(cur)) { paras[[length(paras) + 1L]] <- paste(trimws(cur), collapse = " "); cur <- character(0) }
    } else {
      cur <- c(cur, ln)
    }
  }
  if (length(cur)) paras[[length(paras) + 1L]] <- paste(trimws(cur), collapse = " ")
  paste(unlist(paras), collapse = "\n\n")
}

# =========================================================================
# 2. Brand assets and template
# =========================================================================

brand_root <- file.path(nutritionRoot, "github", "documentation", "unicef_brand")
brand_dir  <- file.path(brand_root, "_extracted")

onedrive_dirs <- list.dirs(brand_root, recursive = FALSE, full.names = TRUE)
onedrive_dirs <- onedrive_dirs[grepl("OneDrive", basename(onedrive_dirs), ignore.case = TRUE)]

template_candidates <- c(
  file.path(brand_root, "UNICEF Branded Presentation Template 2026.pptx"),
  file.path(brand_root, "UNICEF Branded Presentation Template 2025.pptx")
)
template_candidates <- c(template_candidates, unlist(lapply(onedrive_dirs, function(d) {
  cands <- c(
    file.path(d, "Brand template_PowerPoint Presentation",
              "UNICEF Branded Presentation Template 2026.pptx"),
    file.path(d, "UNICEF Branded Presentation Template 2026.pptx"),
    file.path(d, "Brand template_PowerPoint Presentation",
              "UNICEF Branded Presentation Template 2025.pptx"),
    file.path(d, "UNICEF Branded Presentation Template 2025.pptx")
  )
  cands[file.exists(cands)]
})))
template_candidates <- c(template_candidates,
                         file.path(brand_dir, "template_2026.pptx"))
template_path <- template_candidates[file.exists(template_candidates)][1]

if (is.na(template_path) || !nzchar(template_path)) {
  stop("UNICEF template not found. Checked:\n",
       paste(template_candidates, collapse = "\n"))
}

if (nchar(template_path) > 200) {
  tmp <- file.path(tempdir(), "unicef_template_tmp.pptx")
  file.copy(template_path, tmp, overwrite = TRUE)
  message("[4c] Copied template to temp path for long-path compatibility")
  template_path <- tmp
}

message("[4c] Template: ", basename(template_path))

# =========================================================================
# 3. Brand colours, fonts, ggplot theme
# =========================================================================

unicef_cyan     <- unicef_tokens$colour$cyan
unicef_dark     <- unicef_tokens$colour$dark_blue
unicef_green    <- unicef_tokens$colour$green
unicef_orange   <- unicef_tokens$colour$orange
unicef_magenta  <- unicef_tokens$colour$magenta
unicef_warmgrey <- unicef_tokens$colour$warm_grey
unicef_coolgrey <- unicef_tokens$colour$cool_grey
unicef_black    <- unicef_tokens$colour$black
brand_font      <- unicef_tokens$font$family

bullet_style <- fp_text(font.size = 18, font.family = brand_font,
                        color = unicef_dark)

chart_caption <- paste(
  "Data source: OSE-DA-NT stunting briefing outputs derived from",
  "cmrs2_series_accepted.parquet via stunting_rankings.rds"
)

theme_unicef <- theme_minimal(base_size = 16, base_family = brand_font) +
  theme(
    plot.title       = element_text(face = "bold", size = 24, colour = unicef_dark),
    plot.subtitle    = element_text(size = 16, colour = unicef_warmgrey, margin = margin(b = 10)),
    plot.caption     = element_text(size = 10, colour = unicef_coolgrey, hjust = 0),
    axis.title       = element_text(size = 14, colour = unicef_warmgrey),
    axis.text        = element_text(size = 13, colour = unicef_black),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "#E6E6E6", linewidth = 0.5),
    panel.grid.minor   = element_blank(),
    legend.position  = "none",
    plot.margin      = margin(10, 20, 10, 10)
  )

fmt_millions <- function(x) sprintf("%.1f M", x / 1000)

# =========================================================================
# 4. Build charts from rankings data
# =========================================================================

p_highest <- results$highest %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")"),
         label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = prevalence)) +
  geom_col(fill = unicef_cyan, width = 0.7) +
  geom_text(aes(label = sprintf("%.1f%%", prevalence)),
            hjust = -0.1, size = 4.4, colour = unicef_warmgrey,
            family = brand_font) +
  coord_flip(ylim = c(0, max(results$highest$prevalence, na.rm = TRUE) * 1.15)) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption,
       x = NULL, y = "Prevalence (%)") +
  scale_y_continuous(labels = scales::label_percent(scale = 1)) +
  theme_unicef

p_improve_10 <- results$improve_10yr %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")"),
         label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = abs(change_pp))) +
  geom_col(fill = unicef_green, width = 0.7) +
  geom_text(aes(label = sprintf("-%.1f pp", abs(change_pp))),
            hjust = -0.1, size = 4.4, colour = unicef_warmgrey,
            family = brand_font) +
  coord_flip(ylim = c(0, max(abs(results$improve_10yr$change_pp), na.rm = TRUE) * 1.15)) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption,
       x = NULL, y = "Reduction (pp)") +
  theme_unicef

p_dot_10 <- results$improve_10yr %>%
  head(15) %>%
  arrange(current_value) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")"),
         label = factor(label, levels = rev(label))) %>%
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
  labs(title = NULL, subtitle = NULL, caption = chart_caption,
       x = "Prevalence (%)", y = NULL, colour = NULL) +
  scale_x_continuous(labels = scales::label_percent(scale = 1)) +
  theme_unicef +
  theme(legend.position = "top", legend.text = element_text(size = 13))

p_improve_20 <- results$improve_20yr %>%
  head(15) %>%
  mutate(label = paste0(country_name, " (", REF_AREA, ")"),
         label = factor(label, levels = rev(label))) %>%
  ggplot(aes(x = label, y = abs(change_pp))) +
  geom_col(fill = unicef_dark, width = 0.7) +
  geom_text(aes(label = sprintf("-%.1f pp", abs(change_pp))),
            hjust = -0.1, size = 4.4, colour = unicef_warmgrey,
            family = brand_font) +
  coord_flip(ylim = c(0, max(abs(results$improve_20yr$change_pp), na.rm = TRUE) * 1.15)) +
  labs(title = NULL, subtitle = NULL, caption = chart_caption,
       x = NULL, y = "Reduction (pp)") +
  theme_unicef

if (has_numbers) {
  p_highest_num <- results$highest_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")"),
           label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = number_thousands)) +
    geom_col(fill = unicef_magenta, width = 0.7) +
    geom_text(aes(label = fmt_millions(number_thousands)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey,
              family = brand_font) +
    coord_flip(ylim = c(0, max(results$highest_number$number_thousands, na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL, caption = chart_caption,
         x = NULL, y = "Stunted children (millions)") +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_10_num <- results$improve_10yr_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")"),
           label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_green, width = 0.7) +
    geom_text(aes(label = sprintf("-%.1f M", abs(change_th) / 1000)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey,
              family = brand_font) +
    coord_flip(ylim = c(0, max(abs(results$improve_10yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL, caption = chart_caption,
         x = NULL, y = "Reduction (millions)") +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef

  p_improve_20_num <- results$improve_20yr_number %>%
    head(15) %>%
    mutate(label = paste0(country_name, " (", REF_AREA, ")"),
           label = factor(label, levels = rev(label))) %>%
    ggplot(aes(x = label, y = abs(change_th))) +
    geom_col(fill = unicef_dark, width = 0.7) +
    geom_text(aes(label = sprintf("-%.1f M", abs(change_th) / 1000)),
              hjust = -0.1, size = 4.4, colour = unicef_warmgrey,
              family = brand_font) +
    coord_flip(ylim = c(0, max(abs(results$improve_20yr_number$change_th), na.rm = TRUE) * 1.15)) +
    labs(title = NULL, subtitle = NULL, caption = chart_caption,
         x = NULL, y = "Reduction (millions)") +
    scale_y_continuous(labels = function(x) paste0(round(x / 1000, 1), " M")) +
    theme_unicef
}

message("[4c] Built chart objects from rankings data")

# =========================================================================
# 5. Build PowerPoint
# =========================================================================

# Map chart slides to their ggplot objects
chart_map <- list(
  "6"  = p_highest,
  "7"  = p_improve_10,
  "8"  = p_dot_10,
  "9"  = p_improve_20
)
if (has_numbers) {
  chart_map[["11"]] <- p_highest_num
  chart_map[["12"]] <- p_improve_10_num
  chart_map[["13"]] <- p_improve_20_num
}

# --- Initialise template --------------------------------------------------
title_lines <- .nonempty(slides[["2"]]$on_slide)
title_text    <- if (length(title_lines) >= 1) trimws(title_lines[1]) else "Child Stunting"
subtitle_text <- if (length(title_lines) >= 2) trimws(title_lines[2]) else "Executive Director briefing"

title_variant   <- pick_title_variant(title_text)
thankyou_variant <- sample(71:76, 1)

pptx <- read_pptx(template_path)
n_template_slides <- length(pptx)
keep_slides <- c(17, title_variant, thankyou_variant)

for (i in seq(n_template_slides, 1)) {
  if (!(i %in% keep_slides)) pptx <- remove_slide(pptx, index = i)
}

# After removal: position 1 = title_variant, 2 = slide 17 (divider), 3 = thank-you
pptx <- apply_title_text(
  pptx, slide_index = 1,
  title    = title_text,
  subtitle = subtitle_text,
  section  = "Office of Strategy and Evidence\nData & Analytics Section - Nutrition",
  date     = format(Sys.Date(), "%B %Y")
)

# Helper: add a chart slide with title from content master
.add_chart_slide <- function(pptx, slide_title, ggobj) {
  pptx <- officer::add_slide(pptx, layout = "Title Only", master = "UNICEF")
  pptx <- officer::ph_with(pptx, value = slide_title,
                            location = officer::ph_location_type(type = "title"))
  officer::ph_with(
    pptx,
    value = rvg::dml(ggobj = ggobj),
    location = officer::ph_location(left = 0.7, top = 1.5,
                                     width = 11.3, height = 5.3)
  )
}

# Helper: add speaker notes to the current last slide
.add_notes <- function(pptx, notes_text) {
  if (!nzchar(notes_text)) return(pptx)
  sl_idx <- length(pptx)
  pptx <- officer::set_notes(
    pptx,
    value = officer::block_list(officer::fpar(officer::ftext(
      notes_text,
      prop = officer::fp_text(font.size = 12, font.family = brand_font)
    ))),
    location = officer::notes_location_type(type = "body"),
    index = sl_idx
  )
  pptx
}

# Track which slide numbers we emit (for notes mapping)
emitted_order <- character(0)

# --- Slide 3: Overview ----------------------------------------------------
pptx <- add_section_slide(
  pptx,
  title = .title_from(slides[["3"]]),
  items = .items_from(slides[["3"]]),
  style = bullet_style,
  footer_title = title_text
)
pptx <- .add_notes(pptx, .notes_text(slides[["3"]]$speaker_notes))
emitted_order <- c(emitted_order, "3")

# --- Slide 4: What this briefing showed (bullets) -------------------------
s4_bullets <- .numbered_bullets(slides[["4"]]$on_slide)
pptx <- add_bullet_slides(
  pptx,
  title   = slides[["4"]]$label,
  bullets = s4_bullets,
  levels  = rep(1L, length(s4_bullets)),
  style   = bullet_style,
  footer_title = title_text,
  max_groups   = 4
)
pptx <- .add_notes(pptx, .notes_text(slides[["4"]]$speaker_notes))
emitted_order <- c(emitted_order, "4")

# --- Slide 5: Prevalence section divider ----------------------------------
pptx <- add_section_slide(
  pptx,
  title = .title_from(slides[["5"]]),
  items = .items_from(slides[["5"]]),
  style = bullet_style,
  footer_title = title_text
)
pptx <- .add_notes(pptx, .notes_text(slides[["5"]]$speaker_notes))
emitted_order <- c(emitted_order, "5")

# --- Slides 6-9: Prevalence charts ---------------------------------------
for (sn in c("6", "7", "8", "9")) {
  pptx <- .add_chart_slide(pptx, .title_from(slides[[sn]]), chart_map[[sn]])
  pptx <- .add_notes(pptx, .notes_text(slides[[sn]]$speaker_notes))
  emitted_order <- c(emitted_order, sn)
}

# --- Slides 10-13: Burden section (conditional) ---------------------------
if (has_numbers) {
  # Slide 10: section divider
  pptx <- add_section_slide(
    pptx,
    title = .title_from(slides[["10"]]),
    items = .items_from(slides[["10"]]),
    style = bullet_style,
    footer_title = title_text
  )
  pptx <- .add_notes(pptx, .notes_text(slides[["10"]]$speaker_notes))
  emitted_order <- c(emitted_order, "10")

  # Slides 11-13: burden charts
  for (sn in c("11", "12", "13")) {
    pptx <- .add_chart_slide(pptx, .title_from(slides[[sn]]), chart_map[[sn]])
    pptx <- .add_notes(pptx, .notes_text(slides[[sn]]$speaker_notes))
    emitted_order <- c(emitted_order, sn)
  }
}

# --- Slide 14: Key findings (bullets) ------------------------------------
s14_bullets <- .numbered_bullets(slides[["14"]]$on_slide)
pptx <- add_bullet_slides(
  pptx,
  title   = slides[["14"]]$label,
  bullets = s14_bullets,
  levels  = rep(1L, length(s14_bullets)),
  style   = bullet_style,
  footer_title = title_text,
  max_groups   = 4
)
pptx <- .add_notes(pptx, .notes_text(slides[["14"]]$speaker_notes))
emitted_order <- c(emitted_order, "14")

message("[4c] Built slide content: ", length(pptx), " slides in memory")

# =========================================================================
# 6. Save, reorder slides, write companions
# =========================================================================

pptx_path <- file.path(output_dir, "stunting_top20_briefing_combined.pptx")
print(pptx, target = pptx_path)
message("[4c] Wrote PPTX (before reorder): ", pptx_path)

# --- Slide reorder --------------------------------------------------------
# Internal order after removal + appends:
#   1 = title_variant, 2 = slide 17 (divider), 3 = thank-you, 4..N = content
# Desired order:
#   divider(2), title(1), content(4..N), thank-you(3)

.reorder_pptx_slides <- function(pptx_path, new_order) {
  extract_dir <- file.path(tempdir(),
                           paste0("pptx_reorder_", format(Sys.time(), "%H%M%S")))
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

n_slides  <- length(pptx)
new_order <- c(2L, 1L, seq(4L, n_slides), 3L)
.reorder_pptx_slides(pptx_path, new_order)
message("[4c] PowerPoint saved (reordered): ", pptx_path)

# --- Excel workbook -------------------------------------------------------
wb <- createWorkbook()

addWorksheet(wb, "Highest prevalence")
writeData(wb, "Highest prevalence",
          results$highest %>% head(15) %>%
            select(rank, REF_AREA, country_name, year, prevalence))

addWorksheet(wb, "10yr improvement")
writeData(wb, "10yr improvement",
          results$improve_10yr %>% head(15) %>%
            select(rank, REF_AREA, country_name, baseline_value,
                   current_value, change_pp, pct_change))

addWorksheet(wb, "10yr before-after")
writeData(wb, "10yr before-after",
          results$improve_10yr %>% head(15) %>%
            arrange(current_value) %>%
            select(rank, REF_AREA, country_name, baseline_value,
                   current_value, change_pp))

addWorksheet(wb, "20yr improvement")
writeData(wb, "20yr improvement",
          results$improve_20yr %>% head(15) %>%
            select(rank, REF_AREA, country_name, baseline_value,
                   current_value, change_pp, pct_change))

if (has_numbers) {
  addWorksheet(wb, "Highest number")
  writeData(wb, "Highest number",
            results$highest_number %>% head(15) %>%
              select(rank, REF_AREA, country_name, year, number_thousands))

  addWorksheet(wb, "10yr number reduction")
  writeData(wb, "10yr number reduction",
            results$improve_10yr_number %>% head(15) %>%
              select(rank, REF_AREA, country_name, baseline_value,
                     current_value, change_th, pct_change))

  addWorksheet(wb, "20yr number reduction")
  writeData(wb, "20yr number reduction",
            results$improve_20yr_number %>% head(15) %>%
              select(rank, REF_AREA, country_name, baseline_value,
                     current_value, change_th, pct_change))
}

xlsx_path <- file.path(output_dir, "stunting_top20_briefing_combined_data.xlsx")
saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("[4c] Excel data saved: ", xlsx_path)

# --- Speaker notes text backup --------------------------------------------
notes_path <- file.path(output_dir, "stunting_top20_briefing_combined_notes.txt")
note_lines <- unlist(lapply(slides, function(sl) {
  txt <- .notes_text(sl$speaker_notes)
  c(paste0("Slide ", sl$number, " - ", sl$label),
    if (nzchar(txt)) txt else "(no speaker notes)",
    "")
}), use.names = FALSE)
writeLines(note_lines, notes_path)
message("[4c] Speaker notes backup saved: ", notes_path)

message("[4c] Done. Three files written to: ", output_dir)
