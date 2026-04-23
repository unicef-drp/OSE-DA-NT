# =============================================================================
# Animated scatterplot — Child wasting (NT_ANT_WHZ_NE2)
# Wasting uses pre-aggregated regional estimates from agg_ant_wasting.csv
# Shared functions are loaded by 1_execute.r via 0_scatterplot_functions.r
# =============================================================================

message("Building animated scatterplot: wasting")

reg_rep <- load_wasting_series(wasting_csv_path, .crosswalk, .population,
                               year_min = 2000, year_max = 2024)

p <- build_scatterplot(
  reg_rep,
  y_axis_label  = "Wasting prevalence (% <-2 weight-for-height z-score)",
  plot_title    = "Child wasting: prevalence and number of children under 5 years who are wasted",
  focus_regions = c("South Asia", "West and Central Africa"),
  focus_colors  = c("South Asia" = "#0072B2", "West and Central Africa" = "#D55E00")
)

gif_path <- render_base_animations(p, "wasting", outputdir_animated_scatterplots)

render_looped_panel_version(
  gif_path    = gif_path,
  file_prefix = "wasting",
  output_dir  = outputdir_animated_scatterplots,
  headlines   = c(
    "South Asia has the highest wasting prevalence of any region",
    "Globally the number of wasted children remains stubbornly high",
    "West and Central Africa carries a growing share of the burden"
  ),
  sublines    = c(
    "Despite improvements since 1990, prevalence in South Asia remains above 14%",
    "An estimated 45 million children under 5 were wasted in 2024",
    "Wasting prevalence has remained above 7% in the region since 1990"
  )
)

message("Wasting animated scatterplot complete.")
