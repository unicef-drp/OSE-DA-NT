# ---------------------------------------------------------------------------
# Module:  00_pptx_stat_slide.r
# Purpose: Add statistic callout slides to a UNICEF-branded pptx.
#          Supports 1, 2, or 4 statistics per slide.  Inspired by
#          template slides 53-60 and the N_Number slide layouts.
#          Uses "Title Only" layout (master UNICEF) with absolutely-
#          positioned stat blocks for full control over typography.
#
# Stat blocks use large bold coloured values over smaller grey
# description text, matching the visual weight of the template's
# number-emphasis slides.
#
# Depends: officer, 00_pptx_design_tokens.r (unicef_tokens)
#
# Public API:
#   add_stat_slide(pptx, stats, title, source_text, footer_title,
#                  layout, master)
#     → appends one slide and returns pptx
# ---------------------------------------------------------------------------

# Source design tokens if not already loaded
if (!exists("unicef_tokens", envir = .GlobalEnv)) {
  source(file.path(dirname(sys.frame(1)$ofile %||% "."), "00_pptx_design_tokens.r"))
}

#' Add a statistic callout slide.
#'
#' Each stat is a named list with:
#'   \code{value}  — character string displayed large (e.g. "55.3\%", "37.4M")
#'   \code{label}  — short description shown below the value
#'   \code{color}  — optional hex colour for the value (default UNICEF cyan)
#'
#' @param pptx        An officer pptx object.
#' @param stats       A list of stat lists.
#'   Length must be 1, 2, or 4.
#' @param title       Character or NULL. Slide title shown at top.
#' @param source_text Character or NULL. Data source note at bottom.
#' @param footer_title Character or NULL. Text for footer (unused in
#'   Title Only but reserved for future layout changes).
#' @param layout      Character. Slide layout name (default "Title Only").
#' @param master      Character. Master slide name (default "UNICEF").
#' @return The pptx object with one new slide appended.
add_stat_slide <- function(pptx,
                           stats,
                           title       = NULL,
                           source_text = NULL,
                           footer_title = NULL,
                           layout      = "Title Only",
                           master      = "UNICEF") {

  n <- length(stats)
  stopifnot(n %in% c(1L, 2L, 4L))

  pptx <- add_slide(pptx, layout = layout, master = master)

  # --- Title ---------------------------------------------------------------
  if (!is.null(title)) {
    pptx <- ph_with(pptx, value = title,
                     location = ph_location_type(type = "title"))
  }

  # --- Stat blocks ---------------------------------------------------------
  positions <- .stat_positions(n)
  align <- if (n == 1L) "center" else "left"

  for (i in seq_len(n)) {
    stat <- stats[[i]]
    pos  <- positions[[i]]

    value_colour <- stat$color %||% unicef_tokens$colour$cyan

    value_style <- fp_text(
      font.size   = pos$value_size,
      font.family = unicef_tokens$font$family,
      bold        = TRUE,
      color       = value_colour
    )

    paras <- list(
      fpar(ftext(stat$value, prop = value_style),
           fp_p = fp_par(text.align = align, padding.bottom = 4))
    )

    if (!is.null(stat$label) && nzchar(stat$label)) {
      label_style <- fp_text(
        font.size   = pos$label_size,
        font.family = unicef_tokens$font$family,
        color       = unicef_tokens$colour$warm_grey
      )
      paras[[length(paras) + 1]] <- fpar(
        ftext(stat$label, prop = label_style),
        fp_p = fp_par(text.align = align)
      )
    }

    bl <- do.call(block_list, paras)
    pptx <- ph_with(pptx, value = bl,
                     location = ph_location(
                       left   = pos$left,
                       top    = pos$top,
                       width  = pos$width,
                       height = pos$height
                     ))
  }

  # --- Source attribution --------------------------------------------------
  if (!is.null(source_text)) {
    src_style <- fp_text(
      font.size   = 11,
      font.family = unicef_tokens$font$family,
      color       = unicef_tokens$colour$warm_grey,
      italic      = TRUE
    )
    pptx <- ph_with(pptx,
                     value = fpar(ftext(source_text, prop = src_style),
                                  fp_p = fp_par(text.align = "left")),
                     location = ph_location(left = 0.7, top = 6.8,
                                            width = 11.9, height = 0.4))
  }

  pptx
}


# ---------------------------------------------------------------------------
# Private: compute positions for stat blocks
# ---------------------------------------------------------------------------
# Slide is 13.33" × 7.5".  Title occupies ~top 1.3".
# Body area: y ≈ 1.5–6.5 (5" tall), usable width 11.9" (0.7" margins).
# ---------------------------------------------------------------------------
.stat_positions <- function(n) {
  switch(as.character(n),

    # --- Single stat: centred in the body area ---
    "1" = list(
      list(left = 2.0, top = 2.0, width = 9.3, height = 3.5,
           value_size = 60, label_size = 22)
    ),

    # --- Two stats: side by side ---
    "2" = list(
      list(left = 0.8, top = 2.0, width = 5.5, height = 3.5,
           value_size = 52, label_size = 18),
      list(left = 7.0, top = 2.0, width = 5.5, height = 3.5,
           value_size = 52, label_size = 18)
    ),

    # --- Four stats: 2 × 2 grid ---
    "4" = list(
      list(left = 0.8, top = 1.6, width = 5.5, height = 2.3,
           value_size = 44, label_size = 16),
      list(left = 7.0, top = 1.6, width = 5.5, height = 2.3,
           value_size = 44, label_size = 16),
      list(left = 0.8, top = 4.1, width = 5.5, height = 2.3,
           value_size = 44, label_size = 16),
      list(left = 7.0, top = 4.1, width = 5.5, height = 2.3,
           value_size = 44, label_size = 16)
    )
  )
}
