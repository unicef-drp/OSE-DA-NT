# =============================================================================
# Animated scatterplot — Country-level child stunting, per-region figures
# Produces one figure per UNICEF programming region.
#
# Output format: set produce_gif / produce_mp4 to TRUE/FALSE.
# Country highlights: set focus_isos_regional_default for a shared set across
#   all regions, or focus_isos_by_region for per-region overrides.
#   Leave NULL to use the automatic top-N-by-burden logic.
#
# Shared functions are loaded by 1_execute.r via 0_scatterplot_functions.r
# =============================================================================

message("Building country-level animated scatterplots: stunting (regional)")

# country_data loaded by animated_scatterplot_stunting_countries_global.r,
# which must be sourced first in 1_execute.r.

# Output subfolder (same as global so all stunting-country outputs are together)
outdir_stunting_countries <- file.path(outputdir_animated_scatterplots, "stunting_countries")

# -----------------------------------------------------------------------------
# Country highlight sets — edit these to control which countries are bold-
# labelled. Use ISO3 codes. Set to NULL to use automatic top-N-by-burden.
# -----------------------------------------------------------------------------

# Applied to all regions when no region-specific set is defined (NULL = auto top-3 per region)
focus_isos_regional_default <- NULL

# Per-region highlight overrides — takes precedence over focus_isos_regional_default
# Example: focus_isos_by_region <- list("South Asia" = c("IND", "PAK", "BGD", "NPL"))
focus_isos_by_region <- list()

# -----------------------------------------------------------------------------
# Per-region figures
# -----------------------------------------------------------------------------
render_country_regional_scatterplots(
  country_data         = country_data,
  indicator_label      = "stunting",
  y_axis_label         = "Stunting prevalence (% <-2 height-for-age z-score)",
  region_title_fn      = function(r) paste0("Child stunting in ", r),
  output_dir           = outdir_stunting_countries,
  focus_isos           = focus_isos_regional_default,
  focus_isos_by_region = focus_isos_by_region,
  color_by             = "threshold",
  produce_gif          = TRUE,
  produce_mp4          = TRUE
)

message("Country-level stunting animated scatterplots (regional) complete.")
