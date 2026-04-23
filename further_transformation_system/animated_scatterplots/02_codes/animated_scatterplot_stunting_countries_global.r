# =============================================================================
# Animated scatterplot — Country-level child stunting, all-countries figure
# Produces one global figure with all countries (top N per region by burden).
#
# NOTE: country_data loaded here is also used by
#   animated_scatterplot_stunting_countries_regional.r, which must be sourced
#   after this script in 1_execute.r.
#
# Output format: set produce_gif / produce_mp4 to TRUE/FALSE.
# Country highlights: set focus_isos_global to an ISO3 vector to bold-label
#   specific countries. Leave NULL to use automatic top-N-by-burden logic.
#
# Shared functions are loaded by 1_execute.r via 0_scatterplot_functions.r
# =============================================================================

message("Building country-level animated scatterplots: stunting (global)")

# Load country-level stunting data with UNICEF programming-region assignment
country_data <- load_country_series("ANT_HAZ_NE2_MOD", .crosswalk, .population,
                                    year_min = 2000, year_max = 2024)

# Output subfolder
outdir_stunting_countries <- file.path(outputdir_animated_scatterplots, "stunting_countries")

# -----------------------------------------------------------------------------
# Build four focus sets from country-level changes between 2000 and 2024:
# 1) Largest drop in number affected
# 2) Largest drop in prevalence
# 3) Largest increase in number affected
# 4) Largest increase in prevalence
# -----------------------------------------------------------------------------

year_start    <- 2000
year_end      <- 2024
top_n_label   <- 10   # countries to label in each figure
top_n_focus   <- 3    # top N within the label set to bold-highlight

country_2000 <- country_data %>%
  dplyr::filter(year == year_start) %>%
  dplyr::select(
    REF_AREA,
    country_name,
    pop_affected_2000 = pop_affected,
    prevalence_2000 = prevalence
  ) %>%
  dplyr::distinct()

country_2024 <- country_data %>%
  dplyr::filter(year == year_end) %>%
  dplyr::select(
    REF_AREA,
    pop_affected_2024 = pop_affected,
    prevalence_2024 = prevalence
  ) %>%
  dplyr::distinct()

country_change <- country_2000 %>%
  dplyr::inner_join(country_2024, by = "REF_AREA") %>%
  dplyr::mutate(
    delta_number     = pop_affected_2024 - pop_affected_2000,
    delta_prevalence = prevalence_2024 - prevalence_2000
  )

focus_isos_drop_number <- country_change %>%
  dplyr::arrange(delta_number) %>%
  dplyr::slice_head(n = top_n_focus) %>%
  dplyr::pull(REF_AREA)

label_isos_drop_number <- country_change %>%
  dplyr::arrange(delta_number) %>%
  dplyr::slice_head(n = top_n_label) %>%
  dplyr::pull(REF_AREA)

focus_isos_drop_prevalence <- country_change %>%
  dplyr::arrange(delta_prevalence) %>%
  dplyr::slice_head(n = top_n_focus) %>%
  dplyr::pull(REF_AREA)

label_isos_drop_prevalence <- country_change %>%
  dplyr::arrange(delta_prevalence) %>%
  dplyr::slice_head(n = top_n_label) %>%
  dplyr::pull(REF_AREA)

focus_isos_increase_number <- country_change %>%
  dplyr::arrange(dplyr::desc(delta_number)) %>%
  dplyr::slice_head(n = top_n_focus) %>%
  dplyr::pull(REF_AREA)

label_isos_increase_number <- country_change %>%
  dplyr::arrange(dplyr::desc(delta_number)) %>%
  dplyr::slice_head(n = top_n_label) %>%
  dplyr::pull(REF_AREA)

focus_isos_increase_prevalence <- country_change %>%
  dplyr::arrange(dplyr::desc(delta_prevalence)) %>%
  dplyr::slice_head(n = top_n_focus) %>%
  dplyr::pull(REF_AREA)

label_isos_increase_prevalence <- country_change %>%
  dplyr::arrange(dplyr::desc(delta_prevalence)) %>%
  dplyr::slice_head(n = top_n_label) %>%
  dplyr::pull(REF_AREA)

message("  Labels (drop in number, top ", top_n_label, "): ", paste(label_isos_drop_number, collapse = ", "))
message("  Focus  (drop in number, top ", top_n_focus, "): ", paste(focus_isos_drop_number, collapse = ", "))
message("  Labels (drop in prevalence, top ", top_n_label, "): ", paste(label_isos_drop_prevalence, collapse = ", "))
message("  Focus  (drop in prevalence, top ", top_n_focus, "): ", paste(focus_isos_drop_prevalence, collapse = ", "))
message("  Labels (increase in number, top ", top_n_label, "): ", paste(label_isos_increase_number, collapse = ", "))
message("  Focus  (increase in number, top ", top_n_focus, "): ", paste(focus_isos_increase_number, collapse = ", "))
message("  Labels (increase in prevalence, top ", top_n_label, "): ", paste(label_isos_increase_prevalence, collapse = ", "))
message("  Focus  (increase in prevalence, top ", top_n_focus, "): ", paste(focus_isos_increase_prevalence, collapse = ", "))

# Output format is controlled by .produce_gif / .produce_mp4 set in 1_execute.r

# -----------------------------------------------------------------------------
# Global (all-countries) figures, one per focus set
# -----------------------------------------------------------------------------
render_country_global_scatterplot(
  country_data    = country_data,
  indicator_label = "stunting_drop_number",
  y_axis_label    = "Stunting prevalence (% <-2 height-for-age z-score)",
  all_title       = "Child stunting by country: top 10 largest drop in number affected (2000-2024)",
  output_dir      = outdir_stunting_countries,
  label_isos      = label_isos_drop_number,
  focus_isos      = focus_isos_drop_number,
  top_n_per_region = 1000,
  color_by        = "threshold",
  produce_gif     = .produce_gif,
  produce_mp4     = .produce_mp4
)

# render_country_global_scatterplot(
#   country_data    = country_data,
#   indicator_label = "stunting_drop_prevalence",
#   y_axis_label    = "Stunting prevalence (% <-2 height-for-age z-score)",
#   all_title       = "Child stunting by country: top 10 largest prevalence drop (2000-2024)",
#   output_dir      = outdir_stunting_countries,
#   label_isos      = label_isos_drop_prevalence,
#   focus_isos      = focus_isos_drop_prevalence,
#   top_n_per_region = 1000,
#   color_by        = "threshold",
#   produce_gif     = .produce_gif,
#   produce_mp4     = .produce_mp4
# )

# render_country_global_scatterplot(
#   country_data    = country_data,
#   indicator_label = "stunting_increase_number",
#   y_axis_label    = "Stunting prevalence (% <-2 height-for-age z-score)",
#   all_title       = "Child stunting by country: top 10 largest increase in number affected (2000-2024)",
#   output_dir      = outdir_stunting_countries,
#   label_isos      = label_isos_increase_number,
#   focus_isos      = focus_isos_increase_number,
#   top_n_per_region = 1000,
#   color_by        = "threshold",
#   produce_gif     = .produce_gif,
#   produce_mp4     = .produce_mp4
# )

# render_country_global_scatterplot(
#   country_data    = country_data,
#   indicator_label = "stunting_increase_prevalence",
#   y_axis_label    = "Stunting prevalence (% <-2 height-for-age z-score)",
#   all_title       = "Child stunting by country: top 10 largest prevalence increase (2000-2024)",
#   output_dir      = outdir_stunting_countries,
#   label_isos      = label_isos_increase_prevalence,
#   focus_isos      = focus_isos_increase_prevalence,
#   top_n_per_region = 1000,
#   color_by        = "threshold",
#   produce_gif     = .produce_gif,
#   produce_mp4     = .produce_mp4
# )

message("Country-level stunting animated scatterplots (global) complete.")
