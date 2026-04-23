# =============================================================================
# Animated scatterplot — Child stunting (ANT_HAZ_NE2_MOD)
# Shared functions are loaded by 1_execute.r via 0_scatterplot_functions.r
# =============================================================================

message("Building animated scatterplot: stunting")

reg_rep <- load_regional_series("ANT_HAZ_NE2_MOD", .crosswalk, .population,
                                year_min = 2000, year_max = 2024)

p <- build_scatterplot(
  reg_rep,
  y_axis_label  = "Stunting prevalence (% <-2 height-for-age z-score)",
  plot_title    = "Child stunting: prevalence and number of children under 5 years who are too short-for-age",
  focus_regions = c("South Asia", "East Asia and Pacific"),
  focus_colors  = c("South Asia" = "#0072B2", "East Asia and Pacific" = "#E69F00")
)

gif_path <- render_base_animations(p, "stunting", outputdir_animated_scatterplots)

render_looped_panel_version(
  gif_path    = gif_path,
  file_prefix = "stunting",
  output_dir  = outputdir_animated_scatterplots,
  headlines   = c(
    "In 1990 there were more than 260 million stunted children globally",
    "More than 60% of children in South Asia were stunted in 1990",
    "In East Asia & Pacific stunting prevalence dropped from 39% to 13%"
  ),
  sublines    = c(
    "By 2024 the number reduced to 150 million, with South Asia and East Asia & Pacific improving the most",
    "By 2024 stunting prevalence was nearly cut in half to 30% and the number of stunted children reduced from 103 million to 56 million",
    "The number of stunted children decreased from 78 million to 15 million"
  )
)

message("Stunting animated scatterplot complete.")