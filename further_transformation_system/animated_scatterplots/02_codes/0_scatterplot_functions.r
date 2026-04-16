# =============================================================================
# Shared functions for animated scatterplot pipeline
# Sourced by 1_execute.r before indicator-specific scripts
# =============================================================================

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
