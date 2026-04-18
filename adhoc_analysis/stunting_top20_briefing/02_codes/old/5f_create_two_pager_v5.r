# ---------------------------------------------------------------------------
# Script:  5f_create_two_pager_v5.r
# Purpose: Build a UNICEF-branded two-page briefing document from the approved
#          stunting rankings outputs and the current brief content direction.
# Inputs:  03_outputs/stunting_rankings.rds
#          03_outputs/figures/fig1_highest_prevalence.png
#          03_outputs/figures/fig4_highest_burden.png
#          03_outputs/figures/fig8_before_after_prev_20yr.png
#          03_outputs/figures/fig10_before_after_burden_20yr.png
# Outputs: 03_outputs/stunting_top20_two_pager_v5.docx
# Notes:   Supports an optional OSE_BRIEF_OUTPUT_ROOT override for local tests.
# ---------------------------------------------------------------------------

# --- Namespace checks ------------------------------------------------------
.required_pkgs <- c("officer", "magick")
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

output_root_override <- Sys.getenv("OSE_BRIEF_OUTPUT_ROOT", unset = "")
if (nzchar(output_root_override)) {
  adhoc_output_root <- normalizePath(output_root_override, winslash = "/",
                                     mustWork = FALSE)
} else {
  adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis",
                                 "stunting_top20_briefing")
}

output_dir <- file.path(adhoc_output_root, "03_outputs")
figures_dir <- file.path(output_dir, "figures")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

rds_path <- file.path(output_dir, "stunting_rankings.rds")
if (!file.exists(rds_path)) stop("Rankings not found: ", rds_path)

content_path <- file.path(
  projectFolder,
  "adhoc_analysis", "stunting_top20_briefing", "00_documentation",
  "TWO_PAGER_BRIEF_CONTENT_V5.md"
)
if (!file.exists(content_path)) stop("Brief content markdown not found: ", content_path)

template_path <- file.path(
  githubOutputRoot,
  "documentation", "unicef_brand", "OneDrive_1_4-13-2026",
  "Brand template_Fact Sheet", "Brand template_Fact Sheet", "EN",
  "Brand template_Fact Sheet_EN_A4.docx"
)

if (!file.exists(template_path)) {
  template_path <- NULL
}

results <- readRDS(rds_path)
latest_year <- results$metadata$latest_year
yr_10_ago <- results$metadata$yr_10_ago
yr_20_ago <- results$metadata$yr_20_ago

metric_value <- function(tbl, label) {
  tbl$value[tbl$metric == label][1]
}

metric_num <- function(tbl, label) {
  as.numeric(sub(" .*", "", metric_value(tbl, label)))
}

clean_country_name <- function(x) {
  x <- gsub("^Congo - Kinshasa$", "Democratic Republic of the Congo", x)
  x <- gsub("^Myanmar \\(Burma\\)$", "Myanmar", x)
  x
}

# --- Data points used in narrative -----------------------------------------
highest_prev <- utils::head(results$highest, 5)
highest_burden <- utils::head(results$highest_number, 5)
improve_prev_20 <- utils::head(results$improve_20yr, 10)
improve_burden_20 <- utils::head(results$improve_20yr_number, 20)

global_total_m <- metric_num(results$concentration, "Global stunted children (2024)")
top5_burden_m <- metric_num(results$concentration, "Top 5 burden countries")
top10_burden_m <- metric_num(results$concentration, "Top 10 burden countries")
top20_burden_m <- metric_num(results$concentration, "Top 20 burden countries")
top5_share <- as.numeric(sub("%", "", metric_value(results$concentration, "Top 5 share of global total")))
top10_share <- as.numeric(sub("%", "", metric_value(results$concentration, "Top 10 share of global total")))
top20_share <- as.numeric(sub("%", "", metric_value(results$concentration, "Top 20 share of global total")))

global_2004_m <- metric_num(results$reduction_concentration, "Global stunted children (2004)")
global_reduction_m <- metric_num(results$reduction_concentration, "Global reduction (20-year)")
top5_reduction_m <- metric_num(results$reduction_concentration, "Top 5 reducers")
top10_reduction_m <- metric_num(results$reduction_concentration, "Top 10 reducers")
top20_reduction_m <- metric_num(results$reduction_concentration, "Top 20 reducers")
india_reduction_m <- metric_num(results$reduction_concentration, "India alone (reduction)")
india_reduction_share <- as.numeric(sub("%", "", metric_value(results$reduction_concentration, "India share of global reduction")))
top5_reduction_share <- as.numeric(sub("%", "", metric_value(results$reduction_concentration, "Top 5 share of global reduction")))
top10_reduction_share <- as.numeric(sub("%", "", metric_value(results$reduction_concentration, "Top 10 share of global reduction")))
top20_reduction_share <- as.numeric(sub("%", "", metric_value(results$reduction_concentration, "Top 20 share of global reduction")))

overlap_countries <- sort(unique(intersect(
  utils::head(results$highest$country_name, 20),
  utils::head(results$highest_number$country_name, 20)
)))
overlap_text <- paste(clean_country_name(overlap_countries), collapse = ", ")

top_prev_names <- paste(clean_country_name(highest_prev$country_name), collapse = ", ")
top_burden_names <- paste(clean_country_name(highest_burden$country_name), collapse = ", ")
prev_improvers <- paste(clean_country_name(utils::head(improve_prev_20$country_name, 3)), collapse = ", ")

format_rank_footnote <- function(df, value_col, value_fmt) {
  foot_df <- df[11:20, , drop = FALSE]
  paste(
    paste0(
      clean_country_name(foot_df$country_name),
      " (",
      value_fmt(foot_df[[value_col]]),
      ")"
    ),
    collapse = "; "
  )
}

page1_prev_footnote <- paste0(
  "11-20 prevalence, ", latest_year, ": ",
  format_rank_footnote(
    results$highest,
    "prevalence",
    function(x) sprintf("%.1f%%", x)
  )
)
page1_num_footnote <- paste0(
  "11-20 number of stunted children, ", latest_year, ": ",
  format_rank_footnote(
    results$highest_number,
    "number_thousands",
    function(x) sprintf("%.1fm", x / 1000)
  )
)
page2_prev_footnote <- paste0(
  "11-20 reduction in prevalence, ", yr_20_ago, "-", latest_year, ": ",
  format_rank_footnote(
    results$improve_20yr,
    "change_pp",
    function(x) sprintf("%.1f pp", abs(x))
  )
)
page2_num_footnote <- paste0(
  "11-20 reduction in stunted children, ", yr_20_ago, "-", latest_year, ": ",
  format_rank_footnote(
    results$improve_20yr_number,
    "change_th",
    function(x) sprintf("%.2fm", abs(x) / 1000)
  )
)

fig1_path <- file.path(figures_dir, "fig1_highest_prevalence.png")
fig4_path <- file.path(figures_dir, "fig4_highest_burden.png")
fig8_path <- file.path(figures_dir, "fig8_before_after_prev_20yr.png")
fig10_path <- file.path(figures_dir, "fig10_before_after_burden_20yr.png")

# --- Brand settings --------------------------------------------------------
ucol <- list(
  dark_blue = "#1F4E79",
  cyan = "#00AEEF",
  teal = "#00A79D",
  sky = "#EAF6FB",
  pale = "#F4F8FB",
  light_grey = "#F1F3F5",
  white = "#FFFFFF",
  body = "#1D1D1B",
  muted = "#5A5A5A"
)

# Spacing values mirror the saved tracked Word brief. Officer uses point-based
# paragraph padding, so these map from the Word XML twip values:
# 40 -> 2 pt, 60 -> 3 pt, 80 -> 4 pt, 160 -> 8 pt.
layout <- list(
  kicker_after = 2,
  title_after = 3,
  subtitle_before = 1,
  subtitle_after = 3,
  section_before = 3,
  section_after = 1,
  key_messages_before = 4,
  key_messages_after = 1,
  callout_left = 8,
  body_after = 2,
  footnote_after = 0.5,
  source_before = 3,
  body_line_spacing = 1.05
)

fp_kicker <- officer::fp_text(
  font.size = 8, bold = TRUE, font.family = "Arial", color = ucol$cyan
)
fp_title <- officer::fp_text(
  font.size = 18, bold = TRUE, font.family = "Arial", color = ucol$dark_blue
)
fp_subtitle <- officer::fp_text(
  font.size = 8.5, italic = TRUE, font.family = "Arial", color = ucol$muted
)
fp_section <- officer::fp_text(
  font.size = 11, bold = TRUE, font.family = "Arial", color = ucol$dark_blue
)
fp_body <- officer::fp_text(
  font.size = 8.5, font.family = "Arial", color = ucol$body
)
fp_body_bold <- officer::fp_text(
  font.size = 8.5, bold = TRUE, font.family = "Arial", color = ucol$body
)
fp_callout_head <- officer::fp_text(
  font.size = 9, bold = TRUE, font.family = "Arial", color = ucol$dark_blue
)
fp_callout_body <- officer::fp_text(
  font.size = 8.5, font.family = "Arial", color = ucol$dark_blue
)
fp_source <- officer::fp_text(
  font.size = 7, italic = TRUE, font.family = "Arial", color = ucol$muted
)
fp_fig_caption <- officer::fp_text(
  font.size = 7.5, bold = TRUE, font.family = "Arial", color = ucol$dark_blue
)
fp_footnote <- officer::fp_text(
  font.size = 6.5, font.family = "Arial", color = ucol$muted
)

# --- Helper functions ------------------------------------------------------
add_template_header_text <- function(doc) {
  doc <- officer::headers_replace_all_text(
    doc,
    old_value = "UNICEF Fact Sheet",
    new_value = "UNICEF Data Brief",
    warn = FALSE
  )
  doc <- officer::headers_replace_all_text(
    doc,
    old_value = "Region or country name",
    new_value = "Global stunting brief",
    warn = FALSE
  )
  doc <- officer::headers_replace_all_text(
    doc,
    old_value = "Date ",
    new_value = "Data year ",
    warn = FALSE
  )
  doc <- officer::headers_replace_all_text(
    doc,
    old_value = "2024",
    new_value = as.character(latest_year),
    warn = FALSE
  )
  doc
}

clear_body <- function(doc) {
  n_blocks <- nrow(officer::docx_summary(doc))
  if (n_blocks == 0) return(doc)
  doc <- officer::cursor_begin(doc)
  for (i in seq_len(n_blocks)) {
    doc <- officer::body_remove(doc)
  }
  officer::cursor_end(doc)
}

add_kicker <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(txt, fp_kicker),
      fp_p = officer::fp_par(
        line_spacing = 1,
        padding.bottom = layout$kicker_after,
        keep_with_next = TRUE
      )
    ),
    pos = "after"
  )
}

add_title_block <- function(doc, title, subtitle) {
  doc <- officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(title, fp_title),
      fp_p = officer::fp_par(
        line_spacing = 1,
        border.bottom = officer::fp_border(color = ucol$cyan, width = 1.5),
        padding.bottom = layout$title_after,
        keep_with_next = TRUE
      )
    ),
    pos = "after"
  )
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(subtitle, fp_subtitle),
      fp_p = officer::fp_par(
        line_spacing = 1,
        padding.top = layout$subtitle_before,
        padding.bottom = layout$subtitle_after
      )
    ),
    pos = "after"
  )
}

add_section_head <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(txt, fp_section),
      fp_p = officer::fp_par(
        line_spacing = 1,
        padding.top = layout$section_before,
        padding.bottom = layout$section_after,
        border.bottom = officer::fp_border(color = ucol$cyan, width = 1),
        keep_with_next = TRUE
      )
    ),
    pos = "after"
  )
}

add_body_text <- function(doc, txt, padding_bottom = layout$body_after) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(txt, fp_body),
      fp_p = officer::fp_par(
        line_spacing = layout$body_line_spacing,
        padding.bottom = padding_bottom
      )
    ),
    pos = "after"
  )
}

add_bullet_list <- function(doc, bullets, color = ucol$body, shaded = NULL) {
  bullet_fp <- officer::fp_text(
    font.size = 9, bold = TRUE, font.family = "Arial", color = color
  )
  bullet_body_fp <- officer::fp_text(
    font.size = 8.5, font.family = "Arial", color = color
  )
  for (txt in bullets) {
    para_opts <- list(
      padding.left = layout$callout_left,
      padding.bottom = 0,
      line_spacing = layout$body_line_spacing
    )
    if (!is.null(shaded)) {
      para_opts$shading.color <- shaded
    }
    doc <- officer::body_add_fpar(
      doc,
      officer::fpar(
        officer::ftext("\u2022 ", bullet_fp),
        officer::ftext(txt, bullet_body_fp),
        fp_p = do.call(officer::fp_par, para_opts)
      ),
      pos = "after"
    )
  }
  doc
}

add_callout_box <- function(doc, heading, bullets) {
  doc <- officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(heading, fp_callout_head),
      fp_p = officer::fp_par(
        line_spacing = 1,
        shading.color = ucol$sky,
        border.left = officer::fp_border(color = ucol$cyan, width = 2),
        padding.top = layout$key_messages_before,
        padding.bottom = layout$key_messages_after,
        padding.left = layout$callout_left,
        keep_with_next = TRUE
      )
    ),
    pos = "after"
  )
  doc <- add_bullet_list(doc, bullets, color = ucol$dark_blue, shaded = ucol$sky)
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext("", fp_callout_body),
      fp_p = officer::fp_par(
        line_spacing = 1,
        shading.color = ucol$sky,
        border.left = officer::fp_border(color = ucol$cyan, width = 2),
        padding.bottom = layout$kicker_after
      )
    ),
    pos = "after"
  )
}

add_figure <- function(doc, fig_path, caption, width, height) {
  if (!file.exists(fig_path)) return(doc)
  doc <- officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(caption, fp_fig_caption),
      fp_p = officer::fp_par(padding.top = 2, padding.bottom = 1)
    ),
    pos = "after"
  )
  officer::body_add_img(
    doc,
    src = fig_path,
    width = width,
    height = height,
    style = "Normal",
    pos = "after"
  )
}

add_source_footer <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(txt, fp_source),
      fp_p = officer::fp_par(
        line_spacing = 1,
        padding.top = layout$source_before,
        border.top = officer::fp_border(color = ucol$cyan, width = 0.5)
      )
    ),
    pos = "after"
  )
}

add_footnote_text <- function(doc, txt) {
  officer::body_add_fpar(
    doc,
    officer::fpar(
      officer::ftext(txt, fp_footnote),
      fp_p = officer::fp_par(
        line_spacing = 1,
        padding.bottom = layout$footnote_after
      )
    ),
    pos = "after"
  )
}

clean_md_text <- function(x) {
  x <- enc2utf8(x)
  x <- gsub("\\*\\*", "", x)
  x <- gsub("\\*", "", x)
  x <- gsub("â€”", "\u2014", x, fixed = TRUE)
  x <- gsub("â€“", "\u2013", x, fixed = TRUE)
  x <- gsub("â‰ ", "\u2260", x, fixed = TRUE)
  x <- gsub("âˆ’", "-", x, fixed = TRUE)
  x <- gsub("â€™", "\u2019", x, fixed = TRUE)
  x <- gsub("â€œ", "\u201c", x, fixed = TRUE)
  x <- gsub("â€\u009d", "\u201d", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

parse_md_items <- function(lines) {
  items <- list(
    paragraphs = character(0),
    bullets = character(0),
    figures = character(0),
    sources = character(0),
    footnotes = character(0)
  )
  i <- 1
  while (i <= length(lines)) {
    line <- trimws(lines[i])
    if (!nzchar(line) || identical(line, "---")) {
      i <- i + 1
      next
    }
    if (grepl("^\\*\\*\\[Figure ", line)) {
      fig <- sub("^\\*\\*\\[(Figure [^]]+)\\]\\*\\*$", "\\1", line)
      items$figures <- c(items$figures, clean_md_text(fig))
      i <- i + 1
      next
    }
    if (grepl("^\\*\\*Data source:\\*\\*", line)) {
      src <- sub("^\\*\\*Data source:\\*\\*\\s*", "", line)
      items$sources <- c(items$sources, clean_md_text(src))
      i <- i + 1
      next
    }
    if (grepl("^\\[\\[FOOTNOTE:", line)) {
      foot <- sub("^\\[\\[FOOTNOTE:\\s*(.*?)\\]\\]$", "\\1", line)
      items$footnotes <- c(items$footnotes, clean_md_text(foot))
      i <- i + 1
      next
    }
    if (grepl("^-\\s+", line)) {
      bullet <- sub("^-\\s+", "", line)
      j <- i + 1
      while (j <= length(lines)) {
        nxt <- trimws(lines[j])
        if (!nzchar(nxt) || grepl("^(## |\\*\\*\\[Figure |\\*\\*Data source:\\*\\*|-\\s+|>>>)", nxt)) {
          break
        }
        bullet <- paste(bullet, nxt)
        j <- j + 1
      }
      items$bullets <- c(items$bullets, clean_md_text(bullet))
      i <- j
      next
    }
    para <- line
    j <- i + 1
    while (j <= length(lines)) {
      nxt <- trimws(lines[j])
      if (!nzchar(nxt) || grepl("^(## |\\*\\*\\[Figure |\\*\\*Data source:\\*\\*|-\\s+|>>>)", nxt)) {
        break
      }
      para <- paste(para, nxt)
      j <- j + 1
    }
    items$paragraphs <- c(items$paragraphs, clean_md_text(para))
    i <- j
  }
  items
}

# Re-declare the markdown cleanup helper here so new content files with Word-
# style mojibake are normalized consistently before rendering.
clean_md_text <- function(x) {
  x <- enc2utf8(x)
  x <- gsub("\\*\\*", "", x)
  x <- gsub("\\*", "", x)
  x <- gsub("â€”", "\u2014", x, fixed = TRUE)
  x <- gsub("â€“", "\u2013", x, fixed = TRUE)
  x <- gsub("â€™", "\u2019", x, fixed = TRUE)
  x <- gsub("â€œ", "\u201c", x, fixed = TRUE)
  x <- gsub("â€\u009d", "\u201d", x, fixed = TRUE)
  x <- gsub("â‰ ", "\u2260", x, fixed = TRUE)
  x <- gsub("âˆ’", "-", x, fixed = TRUE)
  x <- gsub("Ã¢â‚¬â€", "\u2014", x, fixed = TRUE)
  x <- gsub("Ã¢â‚¬â€œ", "\u2013", x, fixed = TRUE)
  x <- gsub("Ã¢â€°Â ", "\u2260", x, fixed = TRUE)
  x <- gsub("Ã¢Ë†â€™", "-", x, fixed = TRUE)
  x <- gsub("Ã¢â‚¬â„¢", "\u2019", x, fixed = TRUE)
  x <- gsub("Ã¢â‚¬Å“", "\u201c", x, fixed = TRUE)
  x <- gsub("Ã¢â‚¬\u009d", "\u201d", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

read_brief_content <- function(path) {
  raw_lines <- enc2utf8(readLines(path, warn = FALSE, encoding = "UTF-8"))
  notes <- trimws(raw_lines[grepl("^>>>", trimws(raw_lines))])
  lines <- raw_lines[!grepl("^>>>", trimws(raw_lines))]
  title_idx <- grep("^#\\s+", trimws(lines))[1]
  title <- clean_md_text(sub("^#\\s+", "", trimws(lines[title_idx])))
  kicker_line <- trimws(lines[grepl("^\\[\\[KICKER:", trimws(lines))][1])
  subtitle_line <- trimws(lines[grepl("^\\[\\[SUBTITLE:", trimws(lines))][1])
  page2_kicker_line <- trimws(lines[grepl("^\\[\\[PAGE2_KICKER:", trimws(lines))][1])
  kicker <- if (!is.na(kicker_line) && nzchar(kicker_line)) {
    clean_md_text(sub("^\\[\\[KICKER:\\s*(.*?)\\]\\]$", "\\1", kicker_line))
  } else {
    NA_character_
  }
  subtitle <- if (!is.na(subtitle_line) && nzchar(subtitle_line)) {
    clean_md_text(sub("^\\[\\[SUBTITLE:\\s*(.*?)\\]\\]$", "\\1", subtitle_line))
  } else {
    NA_character_
  }
  page2_kicker <- if (!is.na(page2_kicker_line) && nzchar(page2_kicker_line)) {
    clean_md_text(sub("^\\[\\[PAGE2_KICKER:\\s*(.*?)\\]\\]$", "\\1", page2_kicker_line))
  } else {
    NA_character_
  }
  sections <- list()
  current_name <- NULL
  current_lines <- character(0)
  for (line in lines[(title_idx + 1):length(lines)]) {
    trim_line <- trimws(line)
    if (grepl("^##\\s+", trim_line)) {
      if (!is.null(current_name)) {
        sections[[current_name]] <- parse_md_items(current_lines)
      }
      current_name <- clean_md_text(sub("^##\\s+", "", trim_line))
      current_lines <- character(0)
    } else if (!is.null(current_name)) {
      current_lines <- c(current_lines, line)
    }
  }
  if (!is.null(current_name)) {
    sections[[current_name]] <- parse_md_items(current_lines)
  }
  sources <- unique(unlist(lapply(sections, `[[`, "sources"), use.names = FALSE))
  list(
    title = title,
    kicker = kicker,
    subtitle = subtitle,
    page2_kicker = page2_kicker,
    sections = sections,
    notes = notes,
    sources = sources[nzchar(sources)]
  )
}

apply_editorial_notes <- function(content, overlap_text) {
  section_name <- NULL
  if ("Current Scale: Prevalence" %in% names(content$sections)) {
    section_name <- "Current Scale: Prevalence"
  } else if ("Current Scale: Prevalence & Burden" %in% names(content$sections)) {
    section_name <- "Current Scale: Prevalence & Burden"
  }
  if (any(grepl("List all 11 countries", content$notes, fixed = TRUE)) &&
      !is.null(section_name)) {
    paras <- content$sections[[section_name]]$paragraphs
    idx <- grep("^The prevalence and burden rankings overlap", paras)
    if (length(idx) == 1) {
      paras[idx] <- paste0(
        "The prevalence and burden rankings overlap but are not identical. ",
        "Eleven countries appear in both the top-20 highest-prevalence and ",
        "top-20 highest-burden lists: ", overlap_text, ". Countries with very ",
        "high prevalence but smaller populations may not appear among the ",
        "highest-burden countries, while populous countries with moderate ",
        "prevalence can carry a very large burden."
      )
      content$sections[[section_name]]$paragraphs <- paras
    }
  }
  content
}

figure_path_from_caption <- function(fig_caption, figures_dir) {
  fig_num <- sub("^Figure\\s+([0-9]+).*$", "\\1", fig_caption)
  fig_map <- c(
    "1" = "fig1_highest_prevalence.png",
    "4" = "fig4_highest_burden.png",
    "8" = "fig8_before_after_prev_20yr.png",
    "10" = "fig10_before_after_burden_20yr.png"
  )
  if (!fig_num %in% names(fig_map)) return(NA_character_)
  file.path(figures_dir, unname(fig_map[[fig_num]]))
}

build_figure_panel <- function(fig_captions, figures_dir, panel_name, out_dir) {
  panel_dir <- file.path(out_dir, "figure_panels")
  dir.create(panel_dir, recursive = TRUE, showWarnings = FALSE)
  tiles <- list()
  for (cap in fig_captions) {
    fig_path <- figure_path_from_caption(cap, figures_dir)
    if (is.na(fig_path) || !file.exists(fig_path)) next
    img <- magick::image_read(fig_path)
    img <- magick::image_resize(img, "900x")
    img <- magick::image_border(img, color = "white", geometry = "10x10")
    img_info <- magick::image_info(img)
    cap_img <- magick::image_blank(width = img_info$width[1], height = 90, color = "white")
    cap_img <- magick::image_annotate(
      cap_img, clean_md_text(cap),
      gravity = "northwest", location = "+16+16",
      size = 22, color = ucol$dark_blue, font = "Arial"
    )
    tiles[[length(tiles) + 1]] <- magick::image_append(c(img, cap_img), stack = TRUE)
  }
  if (length(tiles) == 0) return(NULL)
  panel <- if (length(tiles) == 1) {
    tiles[[1]]
  } else {
    spacer <- magick::image_blank(
      width = 22,
      height = max(magick::image_info(tiles[[1]])$height[1],
                   magick::image_info(tiles[[2]])$height[1]),
      color = "white"
    )
    magick::image_append(c(tiles[[1]], spacer, tiles[[2]]), stack = FALSE)
  }
  panel_path <- file.path(panel_dir, paste0(panel_name, ".png"))
  magick::image_write(panel, path = panel_path, format = "png")
  info <- magick::image_info(panel)
  list(path = panel_path, width_px = info$width[1], height_px = info$height[1])
}

add_figure_panel <- function(doc, panel, width_in = 6.35) {
  if (is.null(panel) || !file.exists(panel$path)) return(doc)
  height_in <- width_in * panel$height_px / panel$width_px
  officer::body_add_img(
    doc,
    src = panel$path,
    width = width_in,
    height = height_in,
    style = "Normal",
    pos = "after"
  )
}

# --- Compose document ------------------------------------------------------
if (is.null(template_path)) {
  doc <- officer::read_docx()
} else {
  doc <- officer::read_docx(path = template_path)
  doc <- add_template_header_text(doc)
}

doc <- suppressWarnings(clear_body(doc))
brief_content <- apply_editorial_notes(read_brief_content(content_path), overlap_text)

page_section <- officer::prop_section(
  page_size = officer::page_size(orient = "portrait", width = 8.27, height = 11.69),
  page_margins = officer::page_mar(
    top = 0.82, bottom = 0.55, left = 0.65, right = 0.65,
    header = 0.45, footer = 0.35
  )
)

sections <- brief_content$sections
current_scale_name <- names(sections)[names(sections) == "Current Scale: Prevalence & Burden"][1]
progress_name <- names(sections)[
  names(sections) == "Progress: Reduction in Prevalence and Number of Affected Children Over 20 Years"
][1]
interpret_name <- names(sections)[names(sections) == "Interpreting the Results"][1]
limitations_name <- names(sections)[names(sections) == "Limitations"][1]
if (is.na(current_scale_name) || !nzchar(current_scale_name)) {
  stop("Expected current-scale section not found in ", basename(content_path))
}
if (is.na(progress_name) || !nzchar(progress_name)) {
  stop("Expected progress section not found in ", basename(content_path))
}

page1_figs <- sections[[current_scale_name]]$figures
progress_figs <- sections[[progress_name]]$figures
interpret_figs <- if (!is.na(interpret_name) && nzchar(interpret_name)) {
  sections[[interpret_name]]$figures
} else {
  character(0)
}
page2_figs <- unique(c(progress_figs, interpret_figs))
page1_panel <- build_figure_panel(page1_figs, figures_dir, "page1_pair", output_dir)
page2_panel <- build_figure_panel(page2_figs, figures_dir, "page2_pair", output_dir)
page_sources <- brief_content$sources
page1_source <- if (length(page_sources) >= 1) page_sources[1] else "2025 Joint Child Malnutrition Estimates."
progress_source <- if (length(sections[[progress_name]]$sources) >= 1) {
  sections[[progress_name]]$sources[1]
} else {
  NA_character_
}
interpret_source <- if (!is.na(interpret_name) && nzchar(interpret_name) &&
                        length(sections[[interpret_name]]$sources) >= 1) {
  sections[[interpret_name]]$sources[1]
} else {
  NA_character_
}
page2_source <- if (!is.na(progress_source) && nzchar(progress_source)) {
  progress_source
} else if (!is.na(interpret_source) && nzchar(interpret_source)) {
  interpret_source
} else if (length(page_sources) >= 2) {
  page_sources[length(page_sources)]
} else {
  page1_source
}
page1_footnotes <- if (length(sections[[current_scale_name]]$footnotes) > 0) {
  sections[[current_scale_name]]$footnotes
} else {
  c(page1_prev_footnote, page1_num_footnote)
}
page2_footnotes <- if (length(sections[[progress_name]]$footnotes) > 0) {
  sections[[progress_name]]$footnotes
} else {
  c(page2_prev_footnote, page2_num_footnote)
}

# Page 1
doc <- add_kicker(doc, if (!is.na(brief_content$kicker)) brief_content$kicker else "GLOBAL NUTRITION MONITORING")
doc <- add_title_block(
  doc,
  brief_content$title,
  if (!is.na(brief_content$subtitle)) brief_content$subtitle else
    paste0("JME modeled estimates, ", latest_year,
           " | Stunting (height-for-age < -2 SD), children under 5")
)
doc <- add_callout_box(doc, "Key Messages", sections[["Key Messages"]]$bullets)

doc <- add_section_head(doc, current_scale_name)
for (para in sections[[current_scale_name]]$paragraphs) {
  doc <- add_body_text(doc, para, padding_bottom = 2)
}
doc <- add_figure_panel(doc, page1_panel, width_in = 6.05)
for (footnote in page1_footnotes) {
  doc <- add_footnote_text(doc, footnote)
}
doc <- add_source_footer(doc, paste0("Data source: ", page1_source))

# Page 2
doc <- officer::body_add_break(doc, pos = "after")

doc <- add_kicker(
  doc,
  if (!is.na(brief_content$page2_kicker)) brief_content$page2_kicker else "PATTERNS OF PROGRESS"
)
doc <- add_section_head(doc, progress_name)
for (para in sections[[progress_name]]$paragraphs) {
  doc <- add_body_text(doc, para, padding_bottom = 2)
}
if (length(progress_figs) > 0) {
  doc <- add_figure_panel(doc, page2_panel, width_in = 6.05)
  for (footnote in page2_footnotes) {
    doc <- add_footnote_text(doc, footnote)
  }
  doc <- add_source_footer(doc, paste0("Data source: ", page2_source))
}
if (!is.na(interpret_name) && nzchar(interpret_name)) {
  doc <- add_section_head(doc, interpret_name)
  for (para in sections[[interpret_name]]$paragraphs) {
    doc <- add_body_text(doc, para, padding_bottom = 2)
  }
  if (length(sections[[interpret_name]]$bullets) > 0) {
    doc <- add_bullet_list(doc, sections[[interpret_name]]$bullets, color = ucol$body)
  }
}
if (!is.na(limitations_name) && nzchar(limitations_name)) {
  doc <- add_section_head(doc, limitations_name)
  doc <- add_bullet_list(doc, sections[[limitations_name]]$bullets, color = ucol$body)
} else if ((is.na(interpret_name) || !nzchar(interpret_name)) &&
           length(sections[[progress_name]]$bullets) > 0) {
  doc <- add_section_head(doc, "Limitations")
  doc <- add_bullet_list(doc, sections[[progress_name]]$bullets, color = ucol$body)
}
if (length(progress_figs) == 0 && length(page2_figs) > 0) {
  doc <- add_figure_panel(doc, page2_panel, width_in = 6.05)
  for (footnote in page2_footnotes) {
    doc <- add_footnote_text(doc, footnote)
  }
  doc <- add_source_footer(doc, paste0("Data source: ", page2_source))
}

doc <- officer::body_set_default_section(doc, page_section)

doc_path <- file.path(output_dir, "stunting_top20_two_pager_v5.docx")
save_doc <- function(doc, target) {
  tryCatch(
    {
      print(doc, target = target)
      target
    },
    error = function(e) {
      if (grepl("is open", conditionMessage(e), fixed = TRUE)) {
        alt_target <- file.path(
          dirname(target),
          paste0(
            tools::file_path_sans_ext(basename(target)),
            "_",
            format(Sys.time(), "%Y%m%d_%H%M%S"),
            ".docx"
          )
        )
        print(doc, target = alt_target)
        message("Primary output was open; saved alternate file: ", alt_target)
        return(alt_target)
      }
      stop(e)
    }
  )
}

saved_path <- save_doc(doc, doc_path)
message("Saved: ", saved_path)
