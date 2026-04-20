# =============================================================================
# Animated scatterplot — Country-level child stunting (ANT_HAZ_NE2_MOD)
# Produces: one all-countries plot + one plot per UNICEF programming region
# Shared functions are loaded by 1_execute.r via 0_scatterplot_functions.r
# =============================================================================

message("Building country-level animated scatterplots: stunting")

# Load country-level stunting data with UNICEF programming-region assignment
country_data <- load_country_series("ANT_HAZ_NE2_MOD", .crosswalk, .population)

# Output subfolder
outdir_stunting_countries <- file.path(outputdir_animated_scatterplots, "stunting_countries")

# Render all plots
render_country_scatterplots(
  country_data    = country_data,
  indicator_label = "stunting",
  y_axis_label    = "Stunting prevalence (% <-2 height-for-age z-score)",
  all_title       = "Child stunting by country: prevalence and number of children affected",
  region_title_fn = function(r) paste0("Child stunting in ", r),
  output_dir      = outdir_stunting_countries,
  label_top_n_all = 15
)

message("Country-level stunting animated scatterplots complete.")
