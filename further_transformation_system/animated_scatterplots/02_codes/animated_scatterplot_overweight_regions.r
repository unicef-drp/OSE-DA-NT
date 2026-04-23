# =============================================================================
# Animated scatterplot — Child overweight (ANT_WHZ_PO2_MOD)
# Shared functions are loaded by 1_execute.r via 0_scatterplot_functions.r
# =============================================================================

message("Building animated scatterplot: overweight")

reg_rep <- load_regional_series("ANT_WHZ_PO2_MOD", .crosswalk, .population,
                                year_min = 2000, year_max = 2024)

p <- build_scatterplot(
  reg_rep,
  y_axis_label  = "Overweight prevalence (% >+2 weight-for-height z-score)",
  plot_title    = "Child overweight: prevalence and number of children under 5 years who are overweight",
  focus_regions = c("North America", "East Asia and Pacific"),
  focus_colors  = c("North America" = "#D55E00", "East Asia and Pacific" = "#0072B2"),
  y_limits      = c(0, 25)
)

gif_path <- render_base_animations(p, "overweight", outputdir_animated_scatterplots)

render_looped_panel_version(
  gif_path    = gif_path,
  file_prefix = "overweight",
  output_dir  = outputdir_animated_scatterplots,
  headlines   = c(
    "Child overweight has been rising in most regions since 1990",
    "Globally the number of overweight children increased to 35.5 million",
    "There are more than 15 million overweight children in East Asia and Pacific"
  ),
  sublines    = c(
    "By 2024 all regions had overweight prevalence above 7% except South Asia and regions in Sub-Saharan Africa",
    "The increase occurred despite a reduction in U5 population",
    "East Asia and Pacific has seen a steady rising prevalence and number of overweight children since 2000"
  )
)

message("Overweight animated scatterplot complete.")
