# ---------------------------------------------------------------------------
# Module:  00_pptx_section_slide.r
# Purpose: Add UNICEF-branded section/overview slides with a photo
#          placeholder to a pptx.  Uses layouts derived from template
#          slides 30–31:
#            "Title and Content"      (slideLayout31, master UNICEF)
#            "2_Title and Content"    (slideLayout19, master UNICEF)
#          Both provide:
#            "Title 1"               — slide title
#            "Content Placeholder 2" — body text area (left ~55 %)
#            "Picture Placeholder 2" — photo area    (right ~45 %)
#            "Footer Placeholder 4"  — footer
#          The picture placeholder is left empty so the user can insert
#          their own photo in PowerPoint.
# Depends: officer, 00_pptx_design_tokens.r (unicef_tokens)
#
# Public API:
#   add_section_slide(pptx, title, items, style, footer_title,
#                     layout, master)
#     → appends one slide and returns pptx
# ---------------------------------------------------------------------------

# Source design tokens if not already loaded
if (!exists("unicef_tokens", envir = .GlobalEnv)) {
  source(file.path(dirname(sys.frame(1)$ofile %||% "."), "00_pptx_design_tokens.r"))
}

#' Add a section break or overview slide.
#'
#' Creates a slide with a title, optional body text, and an empty picture
#' placeholder.  Suitable for presentation overview pages (listing
#' chapters/sections) and for section dividers between content blocks.
#'
#' @param pptx   An officer pptx object.
#' @param title  Character. Slide title (e.g. "Overview", "Section 2: Trends").
#' @param items  Character vector of body-text items. Each becomes one
#'   bullet line in the content placeholder. NULL or length-0 to leave
#'   the content area empty.
#' @param levels Integer vector of indent levels (same length as items).
#'   Default is all level 1 (top-level bullets).
#' @param style  An fp_text style applied to all items.  If NULL, uses a
#'   default 18pt style from unicef_tokens.
#' @param footer_title Character or NULL. Text for the footer placeholder.
#' @param layout Character. Layout name — "Title and Content" (slide-30
#'   style) or "2_Title and Content" (slide-31 style). Both are visually
#'   identical (left text + right photo).
#' @param master Character. Master slide name (default "UNICEF").
#' @return The pptx object with one new slide appended.
add_section_slide <- function(pptx,
                              title,
                              items        = NULL,
                              levels       = NULL,
                              style        = NULL,
                              footer_title = NULL,
                              layout       = "Title and Content",
                              master       = "UNICEF") {

  pptx <- add_slide(pptx, layout = layout, master = master)

  # --- Title ---------------------------------------------------------------
  pptx <- ph_with(pptx, value = title,
                   location = ph_location_label(ph_label = "Title 1"))

  # --- Body text (optional) ------------------------------------------------
  if (!is.null(items) && length(items) > 0) {
    if (is.null(levels)) levels <- rep(1L, length(items))
    stopifnot(length(levels) == length(items))

    if (is.null(style)) {
      style <- officer::fp_text(
        font.size   = 18,
        font.family = unicef_tokens$font$family,
        color       = unicef_tokens$colour$dark_grey
      )
    }

    body <- unordered_list(
      str_list   = items,
      level_list = levels,
      style      = style
    )
    pptx <- ph_with(pptx, value = body,
                     location = ph_location_label(ph_label = "Content Placeholder 2"))
  }

  # --- Footer (optional) ---------------------------------------------------
  if (!is.null(footer_title)) {
    pptx <- ph_with(pptx, value = footer_title,
                     location = ph_location_label(ph_label = "Footer Placeholder 4"))
  }

  # Picture Placeholder 2 is intentionally left empty — the user inserts
 # their own photo directly in PowerPoint.

  pptx
}
