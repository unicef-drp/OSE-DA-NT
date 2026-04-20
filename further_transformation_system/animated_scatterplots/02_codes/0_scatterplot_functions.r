# =============================================================================
# Shared functions for animated scatterplot pipeline
# Sourced by 1_execute.r before indicator-specific scripts
# =============================================================================

# ---------------------------------------------------------------------------
# Country-name lookup (ISO3 → short display name) from the raw crosswalk CSV
# ---------------------------------------------------------------------------
load_country_names <- function() {
  readr::read_csv(
    file.path(interdir, "groups_for_agg.csv"),
    show_col_types = FALSE
  ) %>%
    dplyr::filter(!is.na(ISO3Code), !is.na(Country)) %>%
    dplyr::distinct(ISO3Code, Country) %>%
    dplyr::rename(REF_AREA = ISO3Code, country_name = Country)
}

# ---------------------------------------------------------------------------
# Prevalence threshold classification (de Onis et al 2018)
# Very low <2.5%, Low 2.5-<10%, Medium 10-<20%, High 20-<30%, Very high >=30%
# ---------------------------------------------------------------------------
threshold_colors <- c(
  "Very low"  = "#2DC937",
  "Low"       = "#99C140",
  "Medium"    = "#E7B416",
  "High"      = "#DB7B2B",
  "Very high" = "#CC3232"
)

threshold_levels <- c("Very low", "Low", "Medium", "High", "Very high")

classify_threshold <- function(prev) {
  dplyr::case_when(
    prev < 2.5  ~ "Very low",
    prev < 10   ~ "Low",
    prev < 20   ~ "Medium",
    prev < 30   ~ "High",
    TRUE        ~ "Very high"
  )
}

# ---------------------------------------------------------------------------
# Load country-level series for one indicator (no regional aggregation)
# Returns one row per country × year with prevalence, pop, pop_affected,
# and the UNICEF programming-region assignment.
# ---------------------------------------------------------------------------
load_country_series <- function(indicator_code, crosswalk, population,
                                classification = "UNICEF_PROG_REG_GLOBAL") {
  series_raw <- arrow::open_dataset(
    file.path(analysisDatasetsInputDir, "cmrs2_series_accepted.parquet")
  ) %>%
    dplyr::filter(IndicatorCode == indicator_code, SEX == "_T") %>%
    dplyr::select(REF_AREA, TIME_PERIOD, r) %>%
    dplyr::collect() %>%
    dplyr::mutate(
      year       = as.integer(TIME_PERIOD),
      prevalence = as.numeric(r) * 100
    ) %>%
    dplyr::filter(!is.na(year), !is.na(prevalence), prevalence > 0)

  cw_region <- crosswalk %>%
    dplyr::filter(Classification == classification) %>%
    dplyr::distinct(REF_AREA, Region)

  country_names <- load_country_names()

  series_raw %>%
    dplyr::inner_join(cw_region, by = "REF_AREA") %>%
    dplyr::inner_join(population, by = c("REF_AREA", "year")) %>%
    dplyr::left_join(country_names, by = "REF_AREA") %>%
    dplyr::mutate(
      pop_affected = prevalence / 100 * pop,
      country_name = dplyr::coalesce(country_name, REF_AREA)
    ) %>%
    dplyr::arrange(Region, country_name, year)
}

# ---------------------------------------------------------------------------
# Build animated country-level scatterplot
#
# country_data: data frame from load_country_series (or a region subset)
# label_top_n : number of countries to label (by latest-year pop_affected)
#               NULL = label all countries
# color_by    : "region" (colour bubbles by Region), "country" (single hue),
#               or "threshold" (colour by prevalence classification)
# ---------------------------------------------------------------------------
build_country_scatterplot <- function(country_data,
                                      y_axis_label,
                                      plot_title,
                                      plot_subtitle = "Modeled estimates \u2014 Year: {round(frame_along)}",
                                      label_top_n   = NULL,
                                      focus_top_n   = 3,
                                      color_by      = c("region", "country", "threshold"),
                                      y_limits      = NULL,
                                      overlap_threshold = 1.5,
                                      plot_width     = 900,
                                      plot_height    = 600) {

  color_by <- match.arg(color_by)

  # Determine which countries get labels --------------------------------
  latest_year <- max(country_data$year, na.rm = TRUE)
  ranked <- country_data %>%
    dplyr::filter(year == latest_year) %>%
    dplyr::arrange(dplyr::desc(pop_affected))

  if (!is.null(label_top_n) && label_top_n < nrow(ranked)) {
    label_isos <- ranked$REF_AREA[seq_len(label_top_n)]
  } else {
    label_isos <- ranked$REF_AREA
  }

  # Determine focus countries (top N by burden per region) --------------
  focus_isos <- ranked %>%
    dplyr::group_by(Region) %>%
    dplyr::slice_max(order_by = pop_affected, n = focus_top_n,
                     with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    dplyr::pull(REF_AREA)

  # Prevalence classification (used when color_by = "threshold") --------
  if (color_by == "threshold") {
    country_data <- country_data %>%
      dplyr::mutate(
        threshold = factor(classify_threshold(prevalence), levels = threshold_levels)
      )
  }

  country_data <- country_data %>%
    dplyr::mutate(
      show_label = REF_AREA %in% label_isos,
      is_focus   = REF_AREA %in% focus_isos
    )

  nolabel_df <- country_data %>% dplyr::filter(!show_label)

  # Per-frame overlap detection: dim non-focus labels near focus labels -
  label_df <- country_data %>%
    dplyr::filter(show_label) %>%
    dplyr::group_by(year) %>%
    dplyr::group_modify(~{
      df <- .x
      focus_idx <- which(df$is_focus)
      overlap_focus <- rep(FALSE, nrow(df))
      if (length(focus_idx) > 0) {
        for (i in seq_len(nrow(df))) {
          if (!df$is_focus[i]) {
            overlap_focus[i] <- any(
              abs(df$prevalence[i] - df$prevalence[focus_idx]) < overlap_threshold
            )
          }
        }
      }
      df$overlap_focus <- overlap_focus
      df
    }) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      label_alpha = dplyr::case_when(
        is_focus      ~ 1,
        overlap_focus ~ 0.1,
        TRUE          ~ 0.5
      )
    )

  focus_labels <- label_df %>% dplyr::filter(is_focus)
  other_labels <- label_df %>% dplyr::filter(!is_focus)

  # Colour palette ------------------------------------------------------
  if (color_by == "region") {
    regions   <- sort(unique(country_data$Region))
    n_regions <- length(regions)
    pal <- RColorBrewer::brewer.pal(max(3, min(8, n_regions)), "Set2")
    base_cols <- pal[seq_len(n_regions)]
    names(base_cols) <- regions
    color_mapping <- ggplot2::aes(color = Region)
    color_scale   <- ggplot2::scale_color_manual(values = base_cols)
  } else if (color_by == "threshold") {
    color_mapping <- ggplot2::aes(color = threshold)
    color_scale   <- ggplot2::scale_color_manual(
      values = threshold_colors, name = "Prevalence\nclassification", drop = FALSE
    )
  } else {
    color_mapping <- ggplot2::aes(color = color_val)
    color_scale   <- ggplot2::scale_color_identity()
    country_data$color_val <- "#1CABE2"
    label_df$color_val     <- "#1CABE2"
    focus_labels$color_val <- "#1CABE2"
    other_labels$color_val <- "#1CABE2"
    nolabel_df$color_val   <- "#1CABE2"
  }

  # Build ggplot --------------------------------------------------------
  p <- ggplot2::ggplot(
    country_data,
    ggplot2::aes(x = year, y = prevalence, size = pop_affected,
                 group = country_name)
  )

  # Paths + points: unlabelled (faintest), non-focus labelled, focus ----
  if (nrow(nolabel_df) > 0) {
    p <- p +
      ggplot2::geom_path(
        data = nolabel_df,
        mapping = color_mapping,
        linewidth = 0.3, alpha = 0.2, show.legend = FALSE
      ) +
      ggplot2::geom_point(
        data = nolabel_df,
        mapping = color_mapping,
        alpha = 0.3
      )
  }

  if (nrow(other_labels) > 0) {
    p <- p +
      ggplot2::geom_path(
        data = other_labels,
        mapping = color_mapping,
        linewidth = 0.4, alpha = 0.4, show.legend = FALSE
      ) +
      ggplot2::geom_point(
        data = other_labels,
        mapping = color_mapping,
        alpha = 0.7
      )
  }

  p <- p +
    ggplot2::geom_path(
      data = focus_labels,
      mapping = color_mapping,
      linewidth = 0.8, alpha = 0.8, show.legend = FALSE
    ) +
    ggplot2::geom_point(
      data = focus_labels,
      mapping = color_mapping,
      alpha = 0.95
    )

  # Labels (ggrepel) — two layers: focus (bold) and non-focus (dimmed) --
  if (nrow(other_labels) > 0) {
    p <- p +
      ggrepel::geom_text_repel(
        data          = other_labels,
        ggplot2::aes(label = country_name, alpha = label_alpha),
        size               = 3,
        fontface           = "plain",
        color              = "black",
        point.padding      = 0.15,
        box.padding        = 0.2,
        force              = 0.3,
        force_pull         = 1.5,
        direction          = "y",
        min.segment.length = 0.1,
        segment.color      = "grey60",
        segment.size       = 0.3,
        max.overlaps       = Inf,
        seed               = 42,
        show.legend        = FALSE
      )
  }

  p <- p +
    ggrepel::geom_text_repel(
      data          = focus_labels,
      ggplot2::aes(label = country_name),
      size               = 4,
      fontface           = "bold",
      color              = "black",
      point.padding      = 0.15,
      box.padding        = 0.2,
      force              = 0.3,
      force_pull         = 1.5,
      direction          = "y",
      min.segment.length = 0.1,
      segment.color      = "grey60",
      segment.size       = 0.3,
      max.overlaps       = Inf,
      seed               = 42,
      show.legend        = FALSE
    ) +
    ggplot2::scale_alpha(range = c(0.1, 1), guide = "none")

  # Scales + theme -----------------------------------------------------
  p <- p +
    color_scale +
    ggplot2::scale_size_continuous(
      name   = "Children affected (in 1000s)",
      range  = c(1, 18),
      labels = scales::label_number(accuracy = 1, big.mark = ",")
    ) +
    ggplot2::scale_y_continuous(
      name   = y_axis_label,
      limits = y_limits,
      labels = scales::label_number(accuracy = 0.1)
    ) +
    ggplot2::scale_x_continuous(
      name = "Year", breaks = pretty(country_data$year)
    ) +
    ggplot2::labs(
      title    = plot_title,
      subtitle = plot_subtitle,
      caption  = "Source: UNICEF, WHO & World Bank Joint Child Malnutrition Estimates"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position  = "right",
      legend.key.size  = grid::unit(1.1, "lines"),
      legend.title     = ggplot2::element_text(size = 11, face = "bold"),
      legend.text      = ggplot2::element_text(size = 10),
      plot.title       = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle    = ggplot2::element_text(size = 11),
      plot.caption     = ggplot2::element_text(size = 9, hjust = 0, margin = ggplot2::margin(t = 8)),
      plot.margin      = ggplot2::margin(t = 20, r = 15, b = 20, l = 15)
    ) +
    gganimate::transition_reveal(year)

  p
}

# ---------------------------------------------------------------------------
# Render country-level scatterplots: one "all countries" + per-region plots
#
# country_data     : full data frame from load_country_series
# indicator_label  : short indicator name for filenames, e.g. "stunting"
# y_axis_label     : y-axis text
# all_title        : plot title for the all-countries plot
# region_title_fn  : function(region_name) → plot title for regional plots
# output_dir       : destination folder
# label_top_n_all  : how many countries to label in the all-countries view
# max_countries_per_plot : if a region has more countries than this, only the
#                    top N by pop_affected are labelled (all are still plotted)
# ---------------------------------------------------------------------------
render_country_scatterplots <- function(country_data,
                                        indicator_label,
                                        y_axis_label,
                                        all_title,
                                        region_title_fn = function(r) paste0(r, ": country trends"),
                                        output_dir,
                                        label_top_n_all = 15,
                                        focus_top_n = 3,
                                        top_n_per_region = 10,
                                        color_by = NULL,
                                        y_limits = NULL,
                                        nframes  = 120,
                                        fps_gif  = 6,
                                        fps_mp4  = 10,
                                        plot_width  = 900,
                                        plot_height = 600) {

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  out_files <- character(0)

  # --- 1. All countries (top N per region by burden) --------------------
  latest_year_all <- max(country_data$year, na.rm = TRUE)
  top_isos_all <- country_data %>%
    dplyr::filter(year == latest_year_all) %>%
    dplyr::group_by(Region) %>%
    dplyr::slice_max(order_by = pop_affected, n = top_n_per_region,
                     with_ties = FALSE) %>%
    dplyr::ungroup() %>%
    dplyr::pull(REF_AREA)
  all_data <- country_data %>% dplyr::filter(REF_AREA %in% top_isos_all)

  message("  Building all-countries plot for ", indicator_label,
          " (top ", length(top_isos_all), " countries)")
  p_all <- build_country_scatterplot(
    all_data,
    y_axis_label = y_axis_label,
    plot_title   = all_title,
    label_top_n  = label_top_n_all,
    focus_top_n  = focus_top_n,
    color_by     = if (!is.null(color_by)) color_by else "region",
    y_limits     = y_limits,
    plot_width   = plot_width,
    plot_height  = plot_height
  )

  prefix_all <- paste0(indicator_label, "_countries_all")
  gif_all    <- file.path(output_dir, paste0(prefix_all, ".gif"))
  mp4_all    <- file.path(output_dir, paste0(prefix_all, ".mp4"))

  anim_all <- gganimate::animate(
    p_all, nframes = nframes, fps = fps_gif,
    start_pause = 10, end_pause = 10,
    width = plot_width, height = plot_height,
    renderer = gifski_renderer(), dev = "ragg_png", bg = "white"
  )
  gganimate::anim_save(gif_all, animation = anim_all)
  gganimate::animate(
    p_all, nframes = nframes, fps = fps_mp4,
    width = plot_width, height = plot_height,
    renderer = av_renderer(mp4_all), dev = "ragg_png", bg = "white"
  )
  out_files <- c(out_files, gif_all, mp4_all)
  message("  Saved: ", gif_all)

  # --- 2. Per-region ---------------------------------------------------
  latest_year <- max(country_data$year, na.rm = TRUE)
  regions <- sort(unique(country_data$Region))
  for (reg in regions) {
    reg_all <- country_data %>% dplyr::filter(Region == reg)
    n_total <- length(unique(reg_all$REF_AREA))

    # Keep only top N countries by burden in the latest year
    top_isos <- reg_all %>%
      dplyr::filter(year == latest_year) %>%
      dplyr::slice_max(order_by = pop_affected, n = top_n_per_region,
                       with_ties = FALSE) %>%
      dplyr::pull(REF_AREA)
    reg_data <- reg_all %>% dplyr::filter(REF_AREA %in% top_isos)
    n_countries <- length(unique(reg_data$REF_AREA))
    message("  Building ", reg, " (top ", n_countries, " of ", n_total, " countries)")

    p_reg <- build_country_scatterplot(
      reg_data,
      y_axis_label = y_axis_label,
      plot_title   = region_title_fn(reg),
      focus_top_n  = focus_top_n,
      color_by     = if (!is.null(color_by)) color_by else "country",
      y_limits     = y_limits,
      plot_width   = plot_width,
      plot_height  = plot_height
    )

    safe_name  <- tolower(gsub("[^A-Za-z0-9]+", "_", reg))
    prefix_reg <- paste0(indicator_label, "_countries_", safe_name)
    gif_reg    <- file.path(output_dir, paste0(prefix_reg, ".gif"))
    mp4_reg    <- file.path(output_dir, paste0(prefix_reg, ".mp4"))

    anim_reg <- gganimate::animate(
      p_reg, nframes = nframes, fps = fps_gif,
      start_pause = 10, end_pause = 10,
      width = plot_width, height = plot_height,
      renderer = gifski_renderer(), dev = "ragg_png", bg = "white"
    )
    gganimate::anim_save(gif_reg, animation = anim_reg)
    gganimate::animate(
      p_reg, nframes = nframes, fps = fps_mp4,
      width = plot_width, height = plot_height,
      renderer = av_renderer(mp4_reg), dev = "ragg_png", bg = "white"
    )
    out_files <- c(out_files, gif_reg, mp4_reg)
    message("  Saved: ", gif_reg)
  }

  invisible(out_files)
}

# Load crosswalk and population once (cached in calling environment)
load_crosswalk <- function() {
  readr::read_csv(
    file.path(interdir, "groups_for_agg.csv"),
    show_col_types = FALSE
  ) %>%
    dplyr::filter(!is.na(ISO3Code)) %>%
    dplyr::transmute(REF_AREA = ISO3Code, Classification = Regional_Grouping, Region) %>%
    dplyr::distinct()
}

load_population <- function() {
  readr::read_csv(
    file.path(inputdir, "base_population_1990_2030.csv"),
    show_col_types = FALSE
  ) %>%
    dplyr::transmute(
      REF_AREA = iso3_code,
      year     = as.integer(time),
      pop      = as.numeric(pop_month_0_59_value)
    )
}

# Read parquet series for one indicator and aggregate to UNICEF reporting regions
load_regional_series <- function(indicator_code, crosswalk, population,
                                 exclude_regions = c("Western Europe",
                                                     "Eastern Europe and Central Asia",
                                                     "Sub-Saharan Africa")) {
  series_raw <- arrow::open_dataset(
    file.path(analysisDatasetsInputDir, "cmrs2_series_accepted.parquet")
  ) %>%
    dplyr::filter(IndicatorCode == indicator_code, SEX == "_T") %>%
    dplyr::select(REF_AREA, TIME_PERIOD, r) %>%
    dplyr::collect() %>%
    dplyr::mutate(
      year       = as.integer(TIME_PERIOD),
      prevalence = as.numeric(r) * 100
    ) %>%
    dplyr::filter(!is.na(year), !is.na(prevalence), prevalence > 0)

  cw_regional <- crosswalk %>%
    dplyr::filter(Classification == "UNICEF_REP_REG_GLOBAL")

  series_raw %>%
    dplyr::inner_join(cw_regional, by = "REF_AREA",
                      relationship = "many-to-many") %>%
    dplyr::inner_join(population, by = c("REF_AREA", "year")) %>%
    dplyr::mutate(affected = prevalence / 100 * pop) %>%
    dplyr::group_by(Region, year) %>%
    dplyr::summarise(
      pop_affected = sum(affected, na.rm = TRUE),
      total_pop    = sum(pop, na.rm = TRUE),
      .groups      = "drop"
    ) %>%
    dplyr::mutate(prevalence = pop_affected / total_pop * 100) %>%
    dplyr::filter(!Region %in% exclude_regions) %>%
    dplyr::mutate(Region = factor(Region)) %>%
    dplyr::arrange(Region, year)
}

# Load pre-aggregated wasting regional series from the DW agg_domain CSV.
# Wasting data are produced separately and stored as already-aggregated
# regional estimates (not in the country-level parquet).
load_wasting_series <- function(csv_path, crosswalk, population,
                                indicator_code = "NT_ANT_WHZ_NE2",
                                exclude_regions = c("Western Europe",
                                                    "Eastern Europe and Central Asia",
                                                    "Sub-Saharan Africa")) {
  # Read the pre-aggregated CSV (columns: Classification, Region, INDICATOR,
  # SEX, OBS_VALUE, REF_AREA, TIME_PERIOD, OBS_FOOTNOTE)
  wst <- readr::read_csv(csv_path, show_col_types = FALSE) %>%
    dplyr::filter(
      Classification == "UNICEF Regions",
      INDICATOR      == indicator_code,
      SEX            == "_T"
    ) %>%
    dplyr::transmute(
      Region_csv = Region,
      year       = as.integer(TIME_PERIOD),
      prevalence = as.numeric(OBS_VALUE)
    ) %>%
    dplyr::filter(!is.na(year), !is.na(prevalence), prevalence > 0)

  # Harmonise CSV region names to the crosswalk names used elsewhere
  region_map <- c(
    "East Asia and the Pacific"   = "East Asia and Pacific",
    "Latin America and the Caribbean" = "Latin America and Caribbean",
    "East and Southern Africa"    = "Eastern and Southern Africa"
  )
  wst <- wst %>%
    dplyr::mutate(Region = dplyr::coalesce(region_map[Region_csv], Region_csv)) %>%
    dplyr::select(-Region_csv)

  # Compute regional population from country data so bubble sizes are available
  cw_regional <- crosswalk %>%
    dplyr::filter(Classification == "UNICEF_REP_REG_GLOBAL")

  reg_pop <- population %>%
    dplyr::inner_join(cw_regional, by = "REF_AREA",
                      relationship = "many-to-many") %>%
    dplyr::group_by(Region, year) %>%
    dplyr::summarise(total_pop = sum(pop, na.rm = TRUE), .groups = "drop")

  wst %>%
    dplyr::inner_join(reg_pop, by = c("Region", "year")) %>%
    dplyr::mutate(pop_affected = prevalence / 100 * total_pop) %>%
    dplyr::filter(!Region %in% exclude_regions) %>%
    dplyr::mutate(Region = factor(Region)) %>%
    dplyr::arrange(Region, year)
}

# Build the animated ggplot scatterplot
#
# focus_regions: character vector of region names to emphasize (bold labels,
#   stronger path/point alpha). Pass NULL or empty to treat all equally.
# focus_colors: optional named character vector of color overrides for focus
#   regions (e.g. c("South Asia" = "#0072B2")). Non-focus regions use Set2.
build_scatterplot <- function(reg_rep,
                              y_axis_label,
                              plot_title,
                              focus_regions = character(0),
                              focus_colors  = character(0),
                              y_limits      = NULL,
                              overlap_threshold = 1.5) {

  reg_rep <- reg_rep %>%
    dplyr::mutate(is_focus = Region %in% focus_regions)

  label_df <- reg_rep %>%
    dplyr::group_by(year) %>%
    dplyr::group_modify(~{
      df <- .x
      focus_idx <- which(df$is_focus)
      overlap_focus <- rep(FALSE, nrow(df))
      if (length(focus_idx) > 0) {
        for (i in seq_len(nrow(df))) {
          if (!df$is_focus[i]) {
            overlap_focus[i] <- any(
              abs(df$prevalence[i] - df$prevalence[focus_idx]) < overlap_threshold
            )
          }
        }
      }
      df$overlap_focus <- overlap_focus
      df
    }) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      label_alpha = dplyr::case_when(
        is_focus      ~ 1,
        overlap_focus ~ 0.1,
        TRUE          ~ 0.5
      )
    )

  focus_labels <- label_df %>% dplyr::filter(is_focus)
  other_labels <- label_df %>% dplyr::filter(!is_focus)

  # Color scheme — base palette then apply caller-supplied focus overrides
  region_levels <- levels(reg_rep$Region)
  n_regions     <- length(region_levels)
  base_cols <- RColorBrewer::brewer.pal(max(3, min(8, n_regions)), "Set2")[seq_len(n_regions)]
  names(base_cols) <- region_levels
  for (nm in names(focus_colors)) {
    if (nm %in% names(base_cols)) base_cols[nm] <- focus_colors[nm]
  }

  ggplot2::ggplot(
    reg_rep,
    ggplot2::aes(x = year, y = prevalence, size = pop_affected,
                 color = Region, group = Region)
  ) +
    ggplot2::geom_path(
      data = reg_rep %>% dplyr::filter(!is_focus),
      linewidth = 0.6, alpha = 0.4, show.legend = FALSE
    ) +
    ggplot2::geom_path(
      data = reg_rep %>% dplyr::filter(is_focus),
      linewidth = 0.8, alpha = 0.8, show.legend = FALSE
    ) +
    ggplot2::geom_point(
      data = label_df %>% dplyr::filter(!is_focus), alpha = 0.7
    ) +
    ggplot2::geom_point(
      data = label_df %>% dplyr::filter(is_focus), alpha = 0.95
    ) +
    ggrepel::geom_text_repel(
      data = other_labels,
      ggplot2::aes(label = Region, alpha = label_alpha),
      size               = 3.3,
      fontface           = "plain",
      color              = "black",
      point.padding      = 0.15,
      box.padding        = 0.2,
      force              = 0.3,
      force_pull         = 1.5,
      min.segment.length = 0.1,
      segment.color      = "grey60",
      segment.size       = 0.3,
      max.overlaps       = Inf,
      seed               = 42,
      show.legend        = FALSE
    ) +
    ggrepel::geom_text_repel(
      data = focus_labels,
      ggplot2::aes(label = Region),
      size               = 5,
      fontface           = "bold",
      color              = "black",
      point.padding      = 0.15,
      box.padding        = 0.2,
      force              = 0.3,
      force_pull         = 1.5,
      min.segment.length = 0.1,
      segment.color      = "grey60",
      segment.size       = 0.3,
      max.overlaps       = Inf,
      seed               = 42,
      show.legend        = FALSE
    ) +
    ggplot2::scale_alpha(range = c(0.1, 1), guide = "none") +
    ggplot2::scale_color_manual(values = base_cols) +
    ggplot2::scale_size_continuous(
      name   = "Population affected (children in 1000s)",
      range  = c(3, 20),
      labels = scales::label_number(accuracy = 1, big.mark = ",")
    ) +
    ggplot2::scale_y_continuous(
      name   = y_axis_label,
      limits = y_limits,
      labels = scales::label_number(accuracy = 0.1)
    ) +
    ggplot2::scale_x_continuous(
      name = "Year", breaks = pretty(reg_rep$year)
    ) +
    ggplot2::labs(
      title    = plot_title,
      subtitle = "Modeled estimates by UNICEF reporting regions \u2014 Year: {round(frame_along)}",
      caption  = "Source: UNICEF, WHO & World Bank Joint Child Malnutrition Estimates"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "right",
      legend.key.size = grid::unit(1.1, "lines"),
      legend.title    = ggplot2::element_text(size = 11, face = "bold"),
      legend.text     = ggplot2::element_text(size = 10),
      plot.title      = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle   = ggplot2::element_text(size = 11),
      plot.caption    = ggplot2::element_text(size = 9, hjust = 0, margin = ggplot2::margin(t = 8)),
      plot.margin     = ggplot2::margin(t = 20, r = 15, b = 20, l = 15)
    ) +
    gganimate::transition_reveal(year)
}

# Render base GIF and MP4
render_base_animations <- function(p, file_prefix, output_dir) {
  gif_path <- file.path(output_dir, paste0(file_prefix, "_regions_bubble.gif"))
  mp4_path <- file.path(output_dir, paste0(file_prefix, "_regions_bubble.mp4"))

  anim_obj <- gganimate::animate(
    p,
    nframes     = 120,
    fps         = 6,
    start_pause = 10,
    end_pause   = 10,
    width       = 900,
    height      = 600,
    renderer    = gifski_renderer(),
    dev         = "ragg_png",
    bg          = "white"
  )
  gganimate::anim_save(gif_path, animation = anim_obj)

  gganimate::animate(
    p,
    nframes  = 120,
    fps      = 10,
    width    = 900,
    height   = 600,
    renderer = av_renderer(mp4_path),
    dev      = "ragg_png",
    bg       = "white"
  )

  gif_path
}

# Add UNICEF-blue panel loops with headline/subline text overlays,
# then export looped GIF, frames, and MP4.
# Pass 1 is a clean loop (no panel) so the viewer can read the legend;
# panels with headlines appear from pass 2 onward.
render_looped_panel_version <- function(gif_path, file_prefix, output_dir,
                                        headlines, sublines) {
  n_messages <- length(headlines)
  stopifnot(length(sublines) == n_messages)
  total_loops <- n_messages + 1 # 1 clean pass + n_messages panel passes

  base <- magick::image_read(gif_path)
  frames_per_loop <- length(base)

  anim <- base
  for (i in 2:total_loops) {
    anim <- c(anim, base)
  }

  wrap_text <- function(x, width = 22) {
    paste(strwrap(x, width = width), collapse = "\n")
  }

  unicef_blue   <- "#1CABE2"
  panel_x_final <- 660
  panel_x_right <- 900
  slide_frames  <- 10

  # Panel overlays start on loop 2 (i.e. message index 1..n_messages)
  for (i in seq_len(n_messages)) {
    # Offset by 1 extra loop (the clean first pass)
    start <- i * frames_per_loop + 1
    end   <- (i + 1) * frames_per_loop

    visible_start <- start + floor(frames_per_loop * 0.20)
    visible_end   <- end

    hl  <- wrap_text(headlines[i], width = 20)
    sub <- wrap_text(sublines[i],  width = 22)

    headline_y  <- 140
    line_height <- 22
    n_lines_hl  <- length(strsplit(hl, "\n", fixed = TRUE)[[1]])
    subline_y   <- headline_y + n_lines_hl * line_height + 14

    # Slide-in panel
    for (f in seq_len(slide_frames)) {
      frame_index <- visible_start + f - 1
      if (frame_index > visible_end) break
      prog      <- f / slide_frames
      xleft_now <- panel_x_right - prog * (panel_x_right - panel_x_final)

      frame <- anim[frame_index]
      frame <- magick::image_draw(frame)
      rect(xleft = xleft_now, ybottom = 0, xright = panel_x_right, ytop = 600,
           col = unicef_blue, border = NA)
      dev.off()
      anim[frame_index] <- frame
    }

    # Static panel after slide
    static_start <- min(visible_start + slide_frames, visible_end)
    if (static_start <= visible_end) {
      for (frame_index in static_start:visible_end) {
        frame <- anim[frame_index]
        frame <- magick::image_draw(frame)
        rect(xleft = panel_x_final, ybottom = 0, xright = panel_x_right, ytop = 600,
             col = unicef_blue, border = NA)
        dev.off()
        anim[frame_index] <- frame
      }
    }

    # Headline text
    anim[visible_start:visible_end] <- magick::image_annotate(
      anim[visible_start:visible_end], hl,
      size = 18, gravity = "northwest",
      location = paste0("+", panel_x_final + 20, "+", headline_y),
      color = "white"
    )
    # Subline text
    anim[visible_start:visible_end] <- magick::image_annotate(
      anim[visible_start:visible_end], sub,
      size = 14, gravity = "northwest",
      location = paste0("+", panel_x_final + 20, "+", subline_y),
      color = "white"
    )
  }

  # Quantize and write looped GIF
  anim_small <- magick::image_quantize(anim, max = 256, dither = TRUE)
  magick::image_write(
    anim_small,
    file.path(output_dir, paste0(file_prefix, "_filler_loops_UNICEFblue_slide.gif"))
  )

  # Export individual frame PNGs and encode MP4
  frames_dir <- file.path(output_dir, paste0(file_prefix, "_frames_unicef"))
  dir.create(frames_dir, showWarnings = FALSE)

  for (i in seq_along(anim_small)) {
    magick::image_write(
      anim_small[i],
      path   = file.path(frames_dir, sprintf("frame_%03d.png", i)),
      format = "png"
    )
  }

  png_files <- sort(list.files(frames_dir, pattern = "^frame_\\d+\\.png$", full.names = TRUE))
  av::av_encode_video(
    png_files,
    output    = file.path(output_dir, paste0(file_prefix, "_filler_loops_UNICEFblue_slide.mp4")),
    framerate = 6
  )
}
