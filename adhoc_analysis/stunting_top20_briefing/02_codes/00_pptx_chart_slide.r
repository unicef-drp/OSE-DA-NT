# ---------------------------------------------------------------------------
# Module:  00_pptx_chart_slide.r
# Purpose: Add data-chart slides to a UNICEF-branded pptx.
#          Two variants:
#            add_chart_slide()        — full-width chart with title
#            add_chart_bullet_slide() — chart (left) + short talking-point
#                                       bullets (right)
#          Both add detailed speaker notes for interpretation.
#
# Layout:  "Title Only" (master "UNICEF")
#   Placeholders used: title (type=title).
#   Chart + bullets + source text are positioned absolutely.
#
# Design reference: Template slides 49-50 (map slides) use a title at
#   (0.85, 0.83) with a subtitle/caption at (0.85, 1.83).  Chart slides
#   follow a similar top zone but push the visual content lower so the
#   branded title area is preserved.
#
# Depends: officer, rvg (dml), 00_pptx_design_tokens.r (unicef_tokens)
#
# Public API:
#   add_chart_slide(pptx, title, chart, source_text, notes, ...)
#   add_chart_bullet_slide(pptx, title, chart, bullets, source_text,
#                          notes, ...)
# ---------------------------------------------------------------------------

if (!exists("unicef_tokens", envir = .GlobalEnv)) {
  source(file.path(dirname(sys.frame(1)$ofile %||% "."), "00_pptx_design_tokens.r"))
}

# ========================================================================
# add_chart_slide — full-width chart
# ========================================================================
#' Add a full-width chart slide with speaker notes.
#'
#' @param pptx   An officer pptx object.
#' @param title  Character. Slide title.
#' @param chart  A ggplot object (will be wrapped in dml()).
#' @param source_text Character or NULL.  Data source note at bottom.
#' @param notes  Character or NULL.  Speaker notes (detailed interpretation).
#'   Supports \\n for multiple paragraphs.
#' @param layout Character. Slide layout (default "Title Only").
#' @param master Character. Master slide name (default "UNICEF").
#' @param chart_left,chart_top,chart_width,chart_height Numeric.
#'   Chart position in inches.  Defaults fill the slide below the title.
#' @return The pptx object with one new slide appended.
add_chart_slide <- function(pptx,
                            title,
                            chart,
                            source_text  = NULL,
                            notes        = NULL,
                            layout       = "Title Only",
                            master       = "UNICEF",
                            chart_left   = 0.5,
                            chart_top    = 1.7,
                            chart_width  = 12.0,
                            chart_height = 5.1) {

  pptx <- add_slide(pptx, layout = layout, master = master)

  # Title — use styled fpar to control size and prevent wrapping
  title_style <- fp_text(
    font.size   = 20,
    font.family = unicef_tokens$font$family,
    color       = unicef_tokens$colour$dark_blue,
    bold        = TRUE
  )
  pptx <- ph_with(pptx, value = fpar(ftext(title, prop = title_style)),
                   location = ph_location_type(type = "title"))

  # Chart (editable vector graphic)
  pptx <- ph_with(pptx, value = dml(ggobj = chart),
                   location = ph_location(left = chart_left, top = chart_top,
                                          width = chart_width, height = chart_height))

  # Source text
  if (!is.null(source_text) && nzchar(source_text)) {
    src_style <- fp_text(
      font.size  = unicef_tokens$font$caption_pt,
      font.family = unicef_tokens$font$family,
      color       = unicef_tokens$colour$warm_grey,
      italic      = TRUE
    )
    pptx <- ph_with(pptx, value = fpar(ftext(source_text, prop = src_style)),
                     location = ph_location(left = 0.9, top = 6.85,
                                            width = 11.5, height = 0.35))
  }

  # Speaker notes
  if (!is.null(notes) && nzchar(notes)) {
    pptx <- .add_speaker_notes(pptx, notes)
  }

  pptx
}


# ========================================================================
# add_chart_bullet_slide — chart (left) + talking-point bullets (right)
# ========================================================================
#' Add a chart slide with short talking-point bullets on the right side.
#'
#' The chart occupies the left ~65% of the slide and the bullet panel
#' occupies the right ~30%.  Bullet text should be very short (a few
#' words each) — just reminders of what to say aloud — while the full
#' interpretation goes into the speaker notes.
#'
#' @param pptx    An officer pptx object.
#' @param title   Character. Slide title.
#' @param chart   A ggplot object.
#' @param bullets Character vector.  2–3 short talking-point strings.
#' @param source_text Character or NULL.  Data source note at bottom.
#' @param notes   Character or NULL.  Speaker notes (detailed interpretation).
#'   Supports \\n for paragraphs.
#' @param bullet_color Hex colour for bullet text (default UNICEF dark blue).
#' @param layout  Character. Layout name (default "Title Only").
#' @param master  Character. Master name (default "UNICEF").
#' @param chart_left,chart_top,chart_width,chart_height Numeric.
#'   Chart position.  Default: left 60% of usable slide area.
#' @param bullet_left,bullet_top,bullet_width,bullet_height Numeric.
#'   Bullet panel position.  Default: right 30% of slide.
#' @return The pptx object with one new slide appended.
add_chart_bullet_slide <- function(pptx,
                                   title,
                                   chart,
                                   bullets,
                                   source_text  = NULL,
                                   notes        = NULL,
                                   bullet_color = unicef_tokens$colour$dark_blue,
                                   layout       = "Title Only",
                                   master       = "UNICEF",
                                   chart_left   = 0.5,
                                   chart_top    = 1.7,
                                   chart_width  = 8.0,
                                   chart_height = 5.1,
                                   bullet_left  = 8.8,
                                   bullet_top   = 1.8,
                                   bullet_width = 3.8,
                                   bullet_height = 4.8) {

  pptx <- add_slide(pptx, layout = layout, master = master)

  # Title — use styled fpar to control size and prevent wrapping
  title_style <- fp_text(
    font.size   = 20,
    font.family = unicef_tokens$font$family,
    color       = unicef_tokens$colour$dark_blue,
    bold        = TRUE
  )
  pptx <- ph_with(pptx, value = fpar(ftext(title, prop = title_style)),
                   location = ph_location_type(type = "title"))

  # Chart (left side)
  pptx <- ph_with(pptx, value = dml(ggobj = chart),
                   location = ph_location(left = chart_left, top = chart_top,
                                          width = chart_width, height = chart_height))

  # Bullet panel (right side)
  bullet_body <- .build_chart_bullets(bullets, bullet_color)
  pptx <- ph_with(pptx, value = bullet_body,
                   location = ph_location(left = bullet_left, top = bullet_top,
                                          width = bullet_width, height = bullet_height))

  # Source text (full width at bottom)
  if (!is.null(source_text) && nzchar(source_text)) {
    src_style <- fp_text(
      font.size  = unicef_tokens$font$caption_pt,
      font.family = unicef_tokens$font$family,
      color       = unicef_tokens$colour$warm_grey,
      italic      = TRUE
    )
    pptx <- ph_with(pptx, value = fpar(ftext(source_text, prop = src_style)),
                     location = ph_location(left = 0.9, top = 6.85,
                                            width = 11.5, height = 0.35))
  }

  # Speaker notes
  if (!is.null(notes) && nzchar(notes)) {
    pptx <- .add_speaker_notes(pptx, notes)
  }

  pptx
}


# ========================================================================
# Internal helpers
# ========================================================================

#' Build a block_list of short bullet items with UNICEF styling.
#' Each bullet uses a literal coloured bullet character (U+2022) as
#' an ftext run so it renders reliably in any freeform text box.
.build_chart_bullets <- function(bullets, color) {

  bullet_marker <- fp_text(
    font.size   = 14,
    font.family = "Arial",
    color       = unicef_tokens$colour$white
  )
  bullet_text <- fp_text(
    font.size   = 14,
    font.family = unicef_tokens$font$family,
    color       = unicef_tokens$colour$white
  )

  pars <- lapply(bullets, function(b) {
    fpar(
      ftext("\u2022  ", prop = bullet_marker),
      ftext(b, prop = bullet_text),
      fp_p = fp_par(
        padding.bottom = 12,
        text.align     = "left"
      )
    )
  })

  do.call(block_list, pars)
}

#' Add speaker notes to the current (last) slide.
#'
#' Uses officer's notes body mechanism.  Supports \\n for paragraph breaks.
.add_speaker_notes <- function(pptx, notes_text) {
  lines <- strsplit(notes_text, "\n", fixed = TRUE)[[1]]

  notes_style <- fp_text(
    font.size   = 12,
    font.family = unicef_tokens$font$family,
    color       = unicef_tokens$colour$black
  )

  pars <- lapply(lines, function(line) {
    fpar(ftext(line, prop = notes_style))
  })

  notes_body <- do.call(block_list, pars)

  pptx <- set_notes(pptx, value = notes_body, location = notes_location_type())

  invisible(pptx)
}
