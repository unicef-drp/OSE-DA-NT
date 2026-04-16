# ---------------------------------------------------------------------------
# Module:  00_pptx_bullet_slide.r
# Purpose: Add UNICEF-branded bullet-point slides (no images) to a pptx.
#          Uses layout "8_Title and Content" which has:
#            "Title 1"                — slide title
#            "Content Placeholder 2"  — bullet text area (full width)
#            "Date Placeholder 3"     — presentation title footer
# Depends: officer, xml2
#
# Public API:
#   add_bullet_slides(pptx, title, bullets, levels, style, footer_title,
#                     max_groups, spacing_pt)
#     → appends one or more slides and returns pptx
#     → groups items by top-level (level 1) bullets; sub-bullets stay
#       with their parent and never cause a page split
#     → splits across slides when group count > max_groups
#     → subsequent slides get "(continued)" appended to the title
#     → adds paragraph-after spacing between top-level bullets
# ---------------------------------------------------------------------------

#' Add one or more full-width bullet-point slides.
#'
#' Bullets are grouped by top-level items (level 1). Each group consists of
#' a level-1 bullet and any consecutive sub-bullets (level > 1) beneath it.
#' Splitting only happens between groups — a parent is never separated from
#' its children.
#'
#' @param pptx An officer pptx object.
#' @param title Character. Slide title.
#' @param bullets Character vector of bullet text strings.
#' @param levels Integer vector of indent levels (same length as bullets).
#' @param style An fp_text style applied to all bullets.
#' @param footer_title Character or NULL. Presentation title for the footer.
#' @param max_groups Integer. Max top-level bullet groups per slide (default 3).
#' @param spacing_pt Numeric. Space after each top-level group in pt (default 36,
#'   roughly a full blank line at 18pt font).
#' @return The pptx object with new slide(s) appended.
add_bullet_slides <- function(pptx, title, bullets, levels, style,
                              footer_title = NULL,
                              max_groups = 3,
                              spacing_pt = 36) {
  n <- length(bullets)
  if (n == 0) return(pptx)
  stopifnot(length(levels) == n)

  # --- Group by top-level (level 1) bullets --------------------------------
  # Each group = one level-1 item + any consecutive sub-items that follow it
  group_ids <- cumsum(levels == 1)
  groups    <- split(seq_len(n), group_ids)

  # --- Paginate: max_groups top-level groups per slide ---------------------
  group_pages <- split(seq_along(groups), ceiling(seq_along(groups) / max_groups))

  top_level_so_far <- 0L

  for (i in seq_along(group_pages)) {
    grp_idx <- group_pages[[i]]
    item_idx <- unlist(groups[grp_idx], use.names = FALSE)

    slide_title <- if (i == 1) title else paste0(title, " (continued)")

    body <- unordered_list(
      str_list   = bullets[item_idx],
      level_list = levels[item_idx],
      style      = style
    )

    pptx <- add_slide(pptx, layout = "8_Title and Content", master = "UNICEF")
    pptx <- ph_with(pptx, value = slide_title,
                     location = ph_location_label(ph_label = "Title 1"))
    pptx <- ph_with(pptx, value = body,
                     location = ph_location_label(ph_label = "Content Placeholder 2"))
    if (!is.null(footer_title)) {
      pptx <- ph_with(pptx, value = footer_title,
                       location = ph_location_label(ph_label = "Date Placeholder 3"))
    }

    # --- Post-process XML: spacing and continued numbering -----------------
    sl_idx  <- length(pptx)
    sl_xml  <- pptx$slide$get_slide(sl_idx)$get()
    sl_ns   <- xml2::xml_ns(sl_xml)
    sps     <- xml2::xml_find_all(sl_xml, "//p:sp", sl_ns)

    # Find the content shape by name (ph_type is cleared by ph_with)
    body_sp <- NULL
    for (sp in sps) {
      nv <- xml2::xml_find_first(sp, ".//p:cNvPr", sl_ns)
      if (inherits(nv, "xml_missing")) next
      nm <- xml2::xml_attr(nv, "name")
      if (!is.na(nm) && grepl("Content Placeholder", nm, fixed = TRUE)) {
        body_sp <- sp
        break
      }
    }

    if (!is.null(body_sp)) {
      a_ps <- xml2::xml_find_all(body_sp, ".//a:p", sl_ns)
      page_levels <- levels[item_idx]

      # NOTE: spacing must be injected BEFORE numbering so that <a:spcAft>
      # precedes <a:buAutoNum> in pPr — the OOXML schema requires that
      # order and PowerPoint silently ignores out-of-order elements.

      # --- Spacing after each top-level group's last paragraph -------------
      if (spacing_pt > 0) {
        spacing_indices <- which(
          c(page_levels[-1] == 1, TRUE) & seq_along(page_levels) <= length(a_ps)
        )

        for (pi in spacing_indices) {
          if (pi > length(a_ps)) next
          a_p <- a_ps[[pi]]
          pPr <- xml2::xml_find_first(a_p, ".//a:pPr", sl_ns)
          if (inherits(pPr, "xml_missing")) {
            pPr_xml <- xml2::read_xml(paste0(
              '<a:pPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">',
              '<a:spcAft><a:spcPts val="', spacing_pt * 100, '"/></a:spcAft>',
              '</a:pPr>'
            ))
            xml2::xml_add_child(a_p, pPr_xml, .where = 0)
          } else {
            existing <- xml2::xml_find_first(pPr, ".//a:spcAft", sl_ns)
            if (!inherits(existing, "xml_missing")) xml2::xml_remove(existing)
            spc_xml <- xml2::read_xml(paste0(
              '<a:spcAft xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">',
              '<a:spcPts val="', spacing_pt * 100, '"/></a:spcAft>'
            ))
            xml2::xml_add_child(pPr, spc_xml)
          }
        }
      }

      # --- Continue numbering on overflow slides ---------------------------
      # The layout supplies buAutoNum at the shape default-text level, so
      # paragraphs that inherit from it always restart at 1.  We must
      # inject an explicit <a:buAutoNum> with the correct startAt into
      # EVERY level-1 paragraph on continuation slides so that they form
      # one explicit sequence and PowerPoint cannot fall back to the
      # layout default.
      if (i > 1 && top_level_so_far > 0) {
        lv1_counter <- 0L
        for (k in seq_along(a_ps)) {
          if (k > length(page_levels)) break
          if (page_levels[k] == 1) {
            lv1_counter <- lv1_counter + 1L
            start_val   <- top_level_so_far + lv1_counter
            pPr <- xml2::xml_find_first(a_ps[[k]], ".//a:pPr", sl_ns)
            if (inherits(pPr, "xml_missing")) {
              pPr_xml <- xml2::read_xml(paste0(
                '<a:pPr xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">',
                '<a:buAutoNum type="arabicPeriod" startAt="',
                start_val, '"/></a:pPr>'
              ))
              xml2::xml_add_child(a_ps[[k]], pPr_xml, .where = 0)
            } else {
              existing_bu <- xml2::xml_find_first(pPr, ".//a:buAutoNum", sl_ns)
              if (!inherits(existing_bu, "xml_missing")) xml2::xml_remove(existing_bu)
              bu_xml <- xml2::read_xml(paste0(
                '<a:buAutoNum xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"',
                ' type="arabicPeriod" startAt="', start_val, '"/>'
              ))
              xml2::xml_add_child(pPr, bu_xml)
            }
          }
        }
      }
    }

    # Track how many top-level items have been emitted so far
    top_level_so_far <- top_level_so_far + sum(page_levels == 1)
  }

  pptx
}
