# ---------------------------------------------------------------------------
# Module:  00_pptx_title_slide.r
# Purpose: Generate a UNICEF-branded title slide by replacing placeholder
#          text in one of the 11 title-slide variants from the template.
# Depends: officer, xml2, 00_pptx_design_tokens.r (unicef_tokens)
#
# Public API:
#   pick_title_variant(title, variant, seed)
#     → integer slide index (1–11), respects exclude_variants in tokens
#
#   apply_title_text(pptx, slide_index, title, subtitle, section, date)
#     → modifies pptx in place (XML mutation), returns pptx invisibly
#     → widens title & subtitle boxes to 7.5", enables normAutofit,
#       adjusts vertical spacing, supports \n for multi-line fields
#
#   make_title_slide(template_path, title, subtitle, section, date,
#                    variant, seed)
#     → standalone convenience: returns a pptx with a single title slide
# ---------------------------------------------------------------------------

# Source design tokens if not already loaded
if (!exists("unicef_tokens", envir = .GlobalEnv)) {
  source(file.path(dirname(sys.frame(1)$ofile %||% "."), "00_pptx_design_tokens.r"))
}

# ========================================================================
# pick_title_variant
# ========================================================================
#' Choose which of the 11 title-slide designs to use.
#'
#' @param title Character. Used for deterministic hashing when variant and
#'   seed are both NULL.
#' @param variant Integer 1-11 or NULL. Explicit choice.
#' @param seed Integer or NULL. RNG seed for random selection.
#' @return Integer slide index (1-11).
pick_title_variant <- function(title, variant = NULL, seed = NULL) {
  n_variants <- unicef_tokens$title_slide$n_variants
  exclude    <- unicef_tokens$title_slide$exclude_variants %||% integer(0)
  pool       <- setdiff(seq_len(n_variants), exclude)
  if (!is.null(variant)) {
    stopifnot(is.numeric(variant), variant >= 1, variant <= n_variants)
    if (variant %in% exclude) warning("Variant ", variant, " is excluded; using anyway because it was explicit.")
    chosen <- as.integer(variant)
  } else if (!is.null(seed)) {
    set.seed(seed)
    chosen <- sample(pool, 1L)
  } else {
    hash_val <- sum(utf8ToInt(title)) %% length(pool) + 1L
    chosen <- pool[hash_val]
  }
  message("Title slide: using variant ", chosen, " of ", n_variants,
          if (length(exclude)) paste0(" (excluding ", paste(exclude, collapse = ","), ")") else "")
  chosen
}

# ========================================================================
# apply_title_text
# ========================================================================
#' Replace placeholder text on a title slide that is already in a pptx.
#'
#' Works by scanning shapes for placeholders with known types/names.
#' Text is truncated to fit the text box if it exceeds the calculated
#' character limit.
#'
#' @param pptx An officer pptx object.
#' @param slide_index Integer. Which slide in pptx to modify.
#' @param title Character.
#' @param subtitle Character.
#' @param section Character (optional).
#' @param date Character (optional, default today).
#' @return The pptx object (modified in place via XML mutation).
apply_title_text <- function(pptx,
                             slide_index,
                             title,
                             subtitle = "",
                             section  = "",
                             date     = format(Sys.Date(), "%d %B %Y")) {

  title    <- .fit_text(title,    unicef_tokens$title_slide$title_limits)
  subtitle <- .fit_text(subtitle, unicef_tokens$title_slide$subtitle_limits)
  section  <- .fit_text(section,  unicef_tokens$title_slide$section_limits)
  date     <- .fit_text(date,     unicef_tokens$title_slide$date_limits)

  sl_xml <- pptx$slide$get_slide(slide_index)$get()
  sl_ns  <- xml2::xml_ns(sl_xml)
  sps    <- xml2::xml_find_all(sl_xml, "//p:sp", sl_ns)

  for (sp in sps) {
    ph_nodes <- xml2::xml_find_all(sp, ".//p:ph", sl_ns)
    if (length(ph_nodes) == 0) next

    ph_type <- xml2::xml_attr(ph_nodes[[1]], "type")

    new_text <- NULL
    if (!is.na(ph_type) && ph_type == "title") {
      new_text <- title
    } else if (!is.na(ph_type) && ph_type == "body") {
      nvPr <- xml2::xml_find_first(sp, ".//p:cNvPr", sl_ns)
      shape_name <- xml2::xml_attr(nvPr, "name")
      if (grepl("Text Placeholder 3", shape_name, fixed = TRUE)) {
        new_text <- subtitle
      } else if (grepl("Text Placeholder 4", shape_name, fixed = TRUE)) {
        new_text <- section
      } else if (grepl("Text Placeholder 5", shape_name, fixed = TRUE)) {
        new_text <- date
      }
    }

    if (!is.null(new_text)) {
      .replace_shape_text(sp, sl_ns, new_text)
      # Enable auto-shrink so long text fits without overlapping neighbours
      body_pr <- xml2::xml_find_first(sp, ".//a:bodyPr", sl_ns)
      if (!inherits(body_pr, "xml_missing")) {
        existing_fit <- xml2::xml_find_first(body_pr, ".//a:normAutofit", sl_ns)
        if (inherits(existing_fit, "xml_missing")) {
          fit_node <- xml2::read_xml('<a:normAutofit xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/>')
          xml2::xml_add_child(body_pr, fit_node)
        }
      }
      # Widen title and subtitle text boxes to use more of the slide width
      if (ph_type == "title" ||
          (!is.na(ph_type) && ph_type == "body" &&
           grepl("Text Placeholder 3", xml2::xml_attr(
             xml2::xml_find_first(sp, ".//p:cNvPr", sl_ns), "name"), fixed = TRUE))) {
        ext_node <- xml2::xml_find_first(sp, ".//a:xfrm/a:ext", sl_ns)
        if (!inherits(ext_node, "xml_missing")) {
          xml2::xml_set_attr(ext_node, "cx", as.character(as.integer(7.5 * 914400)))
        }
      }
    }
  }

  # --- Adjust vertical spacing between text groups -------------------------
  # Template boxes are tightly packed; add breathing room between title/subtitle
  # and between section/date by nudging y-positions.
  .nudge_shape_y <- function(sps, sl_ns, shape_name, delta_in) {
    for (sp in sps) {
      nvPr <- xml2::xml_find_first(sp, ".//p:cNvPr", sl_ns)
      if (inherits(nvPr, "xml_missing")) next
      nm <- xml2::xml_attr(nvPr, "name")
      if (!is.na(nm) && grepl(shape_name, nm, fixed = TRUE)) {
        off_node <- xml2::xml_find_first(sp, ".//a:xfrm/a:off", sl_ns)
        if (!inherits(off_node, "xml_missing")) {
          cur_y <- as.numeric(xml2::xml_attr(off_node, "y"))
          xml2::xml_set_attr(off_node, "y", as.character(as.integer(cur_y + delta_in * 914400)))
        }
      }
    }
  }
  .nudge_shape_y(sps, sl_ns, "Text Placeholder 3", 0.30)  # subtitle down
  .nudge_shape_y(sps, sl_ns, "Text Placeholder 4", -0.20) # section up
  .nudge_shape_y(sps, sl_ns, "Text Placeholder 5", 0.18)  # date down

  invisible(pptx)
}

# ========================================================================
# make_title_slide (standalone convenience)
# ========================================================================
#' Build a pptx containing exactly one title slide with text replaced.
#'
#' @param template_path Path to the UNICEF .pptx template.
#' @param title,subtitle,section,date Character fields.
#' @param variant,seed Passed to pick_title_variant().
#' @return An officer pptx object with one slide.
make_title_slide <- function(template_path,
                             title,
                             subtitle = "",
                             section  = "",
                             date     = format(Sys.Date(), "%d %B %Y"),
                             variant  = NULL,
                             seed     = NULL) {

  stopifnot(file.exists(template_path))

  # Workaround: zip library cannot handle very long paths
  if (nchar(template_path) > 200) {
    tmp_template <- file.path(tempdir(), "unicef_template_tmp.pptx")
    file.copy(template_path, tmp_template, overwrite = TRUE)
    template_path <- tmp_template
  }

  chosen <- pick_title_variant(title, variant = variant, seed = seed)

  pptx <- read_pptx(template_path)
  n_total <- length(pptx)

  # Remove every slide except the chosen title variant
  remove_indices <- setdiff(seq_len(n_total), chosen)
  for (idx in sort(remove_indices, decreasing = TRUE)) {
    pptx <- remove_slide(pptx, index = idx)
  }

  apply_title_text(pptx, 1L, title, subtitle, section, date)

  pptx
}


# ========================================================================
# Internal helpers
# ========================================================================

#' Truncate text to fit within a text-box, with ellipsis when needed.
#' Uses a generous limit — PowerPoint auto-shrinks text that slightly
#' overflows, so we only truncate truly excessive input.
.fit_text <- function(text, limits) {
  if (is.null(text) || !nzchar(text)) return("")
  # Allow 50% overflow before truncating, since OOXML auto-fit handles mild excess
  max_chars <- as.integer(limits$max_chars * 1.5)
  if (nchar(text) > max_chars) {
    text <- paste0(substr(text, 1, max_chars - 1), "\u2026")
    message("  Text truncated to ", max_chars, " chars: '",
            substr(text, 1, 60), "...'")
  }
  text
}

#' Replace all text in a shape while preserving formatting.
#' Handles empty placeholders (only <a:endParaRPr>, no <a:r>) by inserting
#' a properly ordered <a:r> BEFORE <a:endParaRPr> with matching font props.
#' Supports line breaks via \n — each line becomes a separate <a:p>.
.replace_shape_text <- function(sp, ns, new_text) {
  lines <- strsplit(new_text, "\n", fixed = TRUE)[[1]]
  txBody <- xml2::xml_find_first(sp, ".//p:txBody", ns)
  if (inherits(txBody, "xml_missing")) return(invisible(NULL))

  # Capture the first <a:p> as a formatting template
  first_p <- xml2::xml_find_first(txBody, ".//a:p", ns)
  if (inherits(first_p, "xml_missing")) return(invisible(NULL))

  # Build <a:rPr> string from <a:endParaRPr> (font specs)
  end_rpr <- xml2::xml_find_first(first_p, ".//a:endParaRPr", ns)
  rpr_inner <- ""
  end_rpr_str <- ""
  if (!inherits(end_rpr, "xml_missing")) {
    end_rpr_str <- as.character(end_rpr)
    lang <- xml2::xml_attr(end_rpr, "lang")
    rpr_attrs <- if (!is.na(lang)) paste0(' lang="', lang, '"') else ""
    kids <- xml2::xml_children(end_rpr)
    kid_strs <- vapply(kids, function(k) as.character(k), character(1))
    rpr_inner <- paste0('<a:rPr', rpr_attrs, '>', paste(kid_strs, collapse = ""), '</a:rPr>')
  }

  # Remove all existing <a:p> elements
  all_ps <- xml2::xml_find_all(txBody, ".//a:p", ns)
  for (p_node in all_ps) xml2::xml_remove(p_node)

  # Insert one <a:p> per line
  a_ns <- "http://schemas.openxmlformats.org/drawingml/2006/main"
  for (line in lines) {
    safe <- gsub("&", "&amp;", line, fixed = TRUE)
    safe <- gsub("<", "&lt;", safe, fixed = TRUE)
    safe <- gsub(">", "&gt;", safe, fixed = TRUE)
    p_xml <- paste0(
      '<a:p xmlns:a="', a_ns, '">',
      '<a:r>', rpr_inner, '<a:t>', safe, '</a:t></a:r>',
      end_rpr_str,
      '</a:p>'
    )
    xml2::xml_add_child(txBody, xml2::read_xml(p_xml))
  }

  invisible(NULL)
}
