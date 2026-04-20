# ---------------------------------------------------------------------------
# Module:  00_pptx_section_slide.r
# Purpose: Add UNICEF-branded section/overview slides with a photo
#          placeholder to a pptx.  Uses the "Picture with Caption" layout
#          (master UNICEF) which provides a split design:
#            Left  (~4.3"):  "Title 1" + "Text Placeholder 3"
#            Right (~6.75"): "Picture Placeholder 2" (empty for user photo)
#            Footer:         "Footer Placeholder 5"
#          The picture placeholder is left empty so the user can insert
#          their own photo in PowerPoint.
# Depends: officer, 00_pptx_design_tokens.r (unicef_tokens)
#
# Public API:
#   add_section_slide(pptx, title, items, section_number, style,
#                     footer_title, icon_path, layout, master)
#     → appends one slide and returns pptx
# ---------------------------------------------------------------------------

# Source design tokens if not already loaded
if (!exists("unicef_tokens", envir = .GlobalEnv)) {
  source(file.path(dirname(sys.frame(1)$ofile %||% "."), "00_pptx_design_tokens.r"))
}

#' Add a section break or overview slide.
#'
#' Creates a slide with a title, optional body text, and an empty picture
#' placeholder on the right.  Suitable for presentation overview pages
#' (listing chapters/sections) and for section dividers between content blocks.
#'
#' @param pptx   An officer pptx object.
#' @param title  Character. Slide title (e.g. "Overview", "Trends").
#' @param items  Character vector of body-text items. Each becomes one
#'   bullet line in the text placeholder. NULL or length-0 to leave
#'   the text area empty.
#' @param levels Integer vector of indent levels (same length as items).
#'   Default is all level 1 (top-level bullets).
#' @param section_number Integer or NULL. If provided, prepended to the
#'   title as "Section N | title".
#' @param style  An fp_text style applied to all items.  If NULL, uses a
#'   default 18pt style from unicef_tokens.
#' @param footer_title Character or NULL. Text for the footer placeholder.
#' @param icon_path Character or NULL. Path to a PNG icon to insert into
#'   Picture Placeholder 2 (right side). If NULL, the placeholder is left
#'   empty for user photos.
#' @param layout Character. Layout name — default "Picture with Caption"
#'   which provides left text + right photo split.
#' @param master Character. Master slide name (default "UNICEF").
#' @return The pptx object with one new slide appended.
add_section_slide <- function(pptx,
                              title,
                              items          = NULL,
                              levels         = NULL,
                              section_number = NULL,
                              style          = NULL,
                              footer_title   = NULL,
                              icon_path      = NULL,
                              layout         = "Picture with Caption",
                              master         = "UNICEF") {

  # Prepend section number to title if provided
  display_title <- if (!is.null(section_number)) {
    paste0("Section ", section_number, " | ", title)
  } else {
    title
  }

  pptx <- add_slide(pptx, layout = layout, master = master)

  # --- Title ---------------------------------------------------------------
  pptx <- ph_with(pptx, value = display_title,
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
                     location = ph_location_label(ph_label = "Text Placeholder 3"))
  }

  # --- Footer (optional) ---------------------------------------------------
  if (!is.null(footer_title)) {
    pptx <- ph_with(pptx, value = footer_title,
                     location = ph_location_label(ph_label = "Footer Placeholder 5"))
  }

  # --- Icon in picture placeholder (optional) ------------------------------
  if (!is.null(icon_path) && file.exists(icon_path)) {
    pptx <- ph_with(pptx, value = external_img(icon_path),
                     location = ph_location_label(ph_label = "Picture Placeholder 2"))
  }
  # If no icon_path, Picture Placeholder 2 is left empty — the user can
  # insert their own photo directly in PowerPoint.

  pptx
}
