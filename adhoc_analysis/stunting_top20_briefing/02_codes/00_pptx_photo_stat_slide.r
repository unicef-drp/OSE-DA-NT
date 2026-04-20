# ---------------------------------------------------------------------------
# Module:  00_pptx_photo_stat_slide.r
# Purpose: Replace text on retained photo-stat slides (template slides 57-59).
#          Full-bleed photo slides with a large stat overlay, description,
#          photo credit, and caption.  Photos and layout are retained;
#          only text is mutated via XML manipulation.
# Depends: officer, xml2, 00_pptx_design_tokens.r (unicef_tokens)
#
# Template shape identification (slides 57-59):
#   Stat value  — font sz >= 10000 (120pt bold, e.g. "34%", "5.6M")
#   Description — shape name starting with "Shape" (always "Shape 95")
#   Credit      — rotation = 16200000 (270°, "© UNICEF/...")
#   Caption     — rotation = 10800000 (180°, location + context)
#
# Public API:
#   apply_photo_stat_text(pptx, slide_index, value, description,
#                         credit = NULL, caption = NULL)
#     → modifies pptx in place (XML mutation), returns pptx invisibly
# ---------------------------------------------------------------------------

if (!exists("unicef_tokens", envir = .GlobalEnv)) {
  source(file.path(dirname(sys.frame(1)$ofile %||% "."), "00_pptx_design_tokens.r"))
}

# ========================================================================
# apply_photo_stat_text
# ========================================================================
#' Replace text on a retained photo-stat slide.
#'
#' Identifies shapes by their visual characteristics (font size, name
#' pattern, rotation) rather than by name, since shape names vary
#' across the three template variants (slides 57-59).
#'
#' @param pptx An officer pptx object containing a retained photo slide.
#' @param slide_index Integer. Which slide in pptx to modify.
#' @param value Character. The large statistic text (e.g. "34%", "5.6M").
#' @param description Character. Description below the stat value.
#'   Supports \\n for line breaks.
#' @param credit Character or NULL. Photo credit text (e.g. "\u00a9 UNICEF/...").
#'   NULL keeps the original template credit.
#' @param caption Character or NULL. Photo caption at bottom.
#'   NULL keeps the original template caption.
#' @return The pptx object (modified in place), invisibly.
apply_photo_stat_text <- function(pptx, slide_index, value, description,
                                  credit = NULL, caption = NULL) {

  sl_xml <- pptx$slide$get_slide(slide_index)$get()
  sl_ns  <- xml2::xml_ns(sl_xml)
  sps    <- xml2::xml_find_all(sl_xml, "//p:sp", sl_ns)

  # -- Stat value: shape with the largest font size (>= 100pt) -------------
  sp_value <- .phs_find_by_font_size(sps, sl_ns, min_sz = 10000L)
  if (!is.null(sp_value)) {
    .phs_replace_text(sp_value, sl_ns, value)
    message("  Photo stat: replaced stat value \u2192 '", value, "'")
  } else {
    warning("Photo stat slide ", slide_index, ": stat value shape not found")
  }

  # -- Description: shape named "Shape *" (typically "Shape 95") -----------
  sp_desc <- .phs_find_by_name(sps, sl_ns, "^Shape")
  if (!is.null(sp_desc)) {
    .phs_replace_text(sp_desc, sl_ns, description)
    message("  Photo stat: replaced description")
  } else {
    warning("Photo stat slide ", slide_index, ": description shape not found")
  }

  # -- Credit: shape rotated 270deg (16200000 EMU) -------------------------
  if (!is.null(credit)) {
    sp_credit <- .phs_find_by_rotation(sps, sl_ns, 16200000L)
    if (!is.null(sp_credit)) {
      .phs_replace_text(sp_credit, sl_ns, credit)
      message("  Photo stat: replaced credit")
    }
  }

  # -- Caption: shape rotated 180deg (10800000 EMU) ------------------------
  if (!is.null(caption)) {
    sp_caption <- .phs_find_by_rotation(sps, sl_ns, 10800000L)
    if (!is.null(sp_caption)) {
      .phs_replace_text(sp_caption, sl_ns, caption)
      message("  Photo stat: replaced caption")
    }
  }

  invisible(pptx)
}


# ========================================================================
# Internal helpers (prefixed .phs_ to avoid collision with title module)
# ========================================================================

#' Find the first <p:sp> whose first <a:rPr> has sz >= min_sz.
.phs_find_by_font_size <- function(shapes, ns, min_sz) {
  for (sp in shapes) {
    rpr <- xml2::xml_find_first(sp, ".//a:rPr", ns)
    if (!inherits(rpr, "xml_missing")) {
      sz <- xml2::xml_attr(rpr, "sz")
      if (!is.na(sz) && as.integer(sz) >= min_sz) return(sp)
    }
  }
  NULL
}

#' Find the first <p:sp> whose cNvPr name matches a regex pattern.
.phs_find_by_name <- function(shapes, ns, pattern) {
  for (sp in shapes) {
    nvPr <- xml2::xml_find_first(sp, ".//*[local-name()='cNvPr']")
    if (!inherits(nvPr, "xml_missing")) {
      nm <- xml2::xml_attr(nvPr, "name")
      if (!is.na(nm) && grepl(pattern, nm)) return(sp)
    }
  }
  NULL
}

#' Find the first <p:sp> whose <a:xfrm> has a specific rotation.
.phs_find_by_rotation <- function(shapes, ns, rot_value) {
  for (sp in shapes) {
    xfrm <- xml2::xml_find_first(sp, ".//a:xfrm", ns)
    if (!inherits(xfrm, "xml_missing")) {
      rot <- xml2::xml_attr(xfrm, "rot")
      if (!is.na(rot) && rot == as.character(rot_value)) return(sp)
    }
  }
  NULL
}

#' Replace all text in a shape, preserving run-level and paragraph formatting.
#'
#' Captures font properties from the first <a:r>/<a:rPr> (which carries
#' the explicit sz, b, color etc.) rather than from <a:endParaRPr>.
#' Also preserves paragraph properties (alignment, spacing) from <a:pPr>.
.phs_replace_text <- function(sp, ns, new_text) {
  lines  <- strsplit(new_text, "\n", fixed = TRUE)[[1]]
  txBody <- xml2::xml_find_first(sp, ".//p:txBody", ns)
  if (inherits(txBody, "xml_missing")) return(invisible(NULL))

  first_p <- xml2::xml_find_first(txBody, ".//a:p", ns)
  if (inherits(first_p, "xml_missing")) return(invisible(NULL))

  # --- Capture run-level formatting from first <a:r>/<a:rPr> ---------------
  first_run_rpr <- xml2::xml_find_first(first_p, ".//a:r/a:rPr", ns)
  rpr_str <- ""
  if (!inherits(first_run_rpr, "xml_missing")) {
    rpr_str <- as.character(first_run_rpr)
  } else {
    # Fall back to endParaRPr, converting tag name
    end_rpr <- xml2::xml_find_first(first_p, ".//a:endParaRPr", ns)
    if (!inherits(end_rpr, "xml_missing")) {
      rpr_str <- gsub("a:endParaRPr", "a:rPr", as.character(end_rpr), fixed = TRUE)
    }
  }

  # --- Capture <a:endParaRPr> for paragraph termination --------------------
  end_rpr <- xml2::xml_find_first(first_p, ".//a:endParaRPr", ns)
  end_rpr_str <- if (!inherits(end_rpr, "xml_missing")) as.character(end_rpr) else ""

  # --- Capture paragraph properties (alignment, spacing) -------------------
  p_pr <- xml2::xml_find_first(first_p, "./a:pPr", ns)
  ppr_str <- if (!inherits(p_pr, "xml_missing")) as.character(p_pr) else ""

  # --- Remove all existing <a:p> elements ----------------------------------
  all_ps <- xml2::xml_find_all(txBody, ".//a:p", ns)
  for (p_node in all_ps) xml2::xml_remove(p_node)

  # --- Insert one <a:p> per line -------------------------------------------
  a_ns <- "http://schemas.openxmlformats.org/drawingml/2006/main"
  for (line in lines) {
    safe <- gsub("&", "&amp;", line, fixed = TRUE)
    safe <- gsub("<", "&lt;",  safe, fixed = TRUE)
    safe <- gsub(">", "&gt;",  safe, fixed = TRUE)
    p_xml <- paste0(
      '<a:p xmlns:a="', a_ns, '">',
      ppr_str,
      '<a:r>', rpr_str, '<a:t>', safe, '</a:t></a:r>',
      end_rpr_str,
      '</a:p>'
    )
    xml2::xml_add_child(txBody, xml2::read_xml(p_xml))
  }

  invisible(NULL)
}
