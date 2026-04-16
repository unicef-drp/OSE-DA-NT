# ---------------------------------------------------------------------------
# Module:  00_pptx_design_tokens.r
# Purpose: Shared UNICEF brand constants for PowerPoint generation.
#          All slide modules consume these tokens to maintain visual
#          consistency without duplicating colour / font definitions.
# ---------------------------------------------------------------------------

unicef_tokens <- list(
  # --- Colours (hex) -------------------------------------------------------
  colour = list(
    cyan       = "#00AEEF",
    dark_blue  = "#374EA2",
    green      = "#00833D",
    yellow     = "#FFC20E",
    orange     = "#F26A21",
    red        = "#E2231A",
    magenta    = "#961A49",
    purple     = "#6A1E74",
    warm_grey  = "#777779",
    cool_grey  = "#ADAFB2",
    black      = "#1D1D1B",
    white      = "#FFFFFF"
  ),

  # --- Typography ----------------------------------------------------------
  font = list(
    family     = "Noto Sans",
    title_pt   = 36,
    subtitle_pt = 20,
    section_pt = 16,
    date_pt    = 14,
    body_pt    = 16,
    caption_pt = 9,
    credit_pt  = 8
  ),

  # --- Title slide text-box constraints (inches) --------------------------
  # Derived from UNICEF Branded Presentation Template 2025/2026 title slides 1-11.
  # All 11 share the same placeholder positions and sizes.
  # Note: apply_title_text() widens title & subtitle to 7.5" at runtime.
  title_slide = list(
    n_variants       = 11L,
    exclude_variants = c(9L),   # slide 9: older child, not under-5
    title_width_in = 5.04,
    title_height_in = 1.40,
    subtitle_width_in = 5.04,
    subtitle_height_in = 0.51,
    section_width_in = 5.04,
    section_height_in = 0.36,
    date_width_in = 5.04,
    date_height_in = 0.37
  )
)

# --- Approximate character limit per text box -----------------------------
# Rule of thumb for Noto Sans: chars_per_inch ~ 72 / font_pt, assuming
# average character width is roughly (font_pt * 0.55) points.
# max_chars = floor(box_width / (font_pt * 0.55 / 72)) * max_lines
.estimate_max_chars <- function(box_w_in, box_h_in, font_pt, line_spacing = 1.2) {
  char_width_in <- font_pt * 0.38 / 72
  chars_per_line <- floor(box_w_in / char_width_in)
  line_height_in <- font_pt * line_spacing / 72
  max_lines <- max(1L, floor(box_h_in / line_height_in))
  list(chars_per_line = chars_per_line, max_lines = max_lines,
       max_chars = chars_per_line * max_lines)
}

unicef_tokens$title_slide$title_limits <- with(
  unicef_tokens,
  .estimate_max_chars(title_slide$title_width_in, title_slide$title_height_in, font$title_pt)
)
unicef_tokens$title_slide$subtitle_limits <- with(
  unicef_tokens,
  .estimate_max_chars(title_slide$subtitle_width_in, title_slide$subtitle_height_in, font$subtitle_pt)
)
unicef_tokens$title_slide$section_limits <- with(
  unicef_tokens,
  .estimate_max_chars(title_slide$section_width_in, title_slide$section_height_in, font$section_pt)
)
unicef_tokens$title_slide$date_limits <- with(
  unicef_tokens,
  .estimate_max_chars(title_slide$date_width_in, title_slide$date_height_in, font$date_pt)
)
