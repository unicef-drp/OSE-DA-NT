library(readxl)
library(dplyr)
library(ggplot2)
library(gganimate)
library(scales)
library(grid)
library(RColorBrewer)
library(av)
library(magick)

## 1. Read the regional Excel
reg <- read_excel(
  "C:/Users/jconkle/UNICEF/Chief Statistician Office - Documents/060.DW-MASTER/01_dw_prep/011_rawdata/nt/output/agg_indicator/Regional_Output_NT_ANT_HAZ_NE2_MOD.xlsx",
  sheet = "Sheet 1"
)

## 2. Filter + prepare
reg_rep <- reg %>%
  filter(
    Classification == "UNICEF_REP_REG_GLOBAL",
    SEX == "_T",
    !Region %in% c(
      "Western Europe",
      "Eastern Europe and Central Asia",
      "Sub-Saharan Africa"
    )
  ) %>%
  mutate(
    year         = as.integer(time),
    prevalence   = as.numeric(OBS_VALUE),
    pop_affected = as.numeric(regional_n),
    Region       = factor(Region)
  ) %>%
  filter(
    !is.na(year),
    !is.na(prevalence),
    !is.na(pop_affected)
  ) %>%
  arrange(Region, year)

## 3. Highlight + overlap logic for labels
focus_regions     <- c("South Asia", "East Asia and Pacific")
overlap_threshold <- 1.5

reg_rep <- reg_rep %>%
  mutate(is_focus = Region %in% focus_regions)

label_df <- reg_rep %>%
  group_by(year) %>%
  group_modify(~{
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
  ungroup() %>%
  mutate(
    label_alpha = case_when(
      is_focus      ~ 1,
      overlap_focus ~ 0.1,
      TRUE          ~ 0.5
    )
  )

focus_labels <- label_df %>% filter(is_focus)
other_labels <- label_df %>% filter(!is_focus)

## 4. Color scheme
region_levels <- levels(reg_rep$Region)
n_regions     <- length(region_levels)

base_cols <- brewer.pal(max(3, min(8, n_regions)), "Set2")[seq_len(n_regions)]
names(base_cols) <- region_levels

base_cols["South Asia"]            <- "#0072B2"
base_cols["East Asia and Pacific"] <- "#E69F00"

region_colors <- base_cols

## 5. Plot
p <- ggplot(
  reg_rep,
  aes(
    x     = year,
    y     = prevalence,
    size  = pop_affected,
    color = Region,
    group = Region
  )
) +
  geom_path(
    data        = reg_rep %>% filter(!is_focus),
    linewidth   = 0.6,
    alpha       = 0.4,
    show.legend = FALSE
  ) +
  geom_path(
    data        = reg_rep %>% filter(is_focus),
    linewidth   = 0.8,
    alpha       = 0.8,
    show.legend = FALSE
  ) +
  geom_point(
    data  = label_df %>% filter(!is_focus),
    alpha = 0.7
  ) +
  geom_point(
    data  = label_df %>% filter(is_focus),
    alpha = 0.95
  ) +
  geom_text(
    data = other_labels,
    aes(label = Region, alpha = label_alpha),
    size        = 3.3,
    nudge_y     = 1.2,
    color       = "black",
    show.legend = FALSE
  ) +
  geom_text(
    data = focus_labels,
    aes(label = Region),
    size        = 5,
    fontface    = "bold",
    nudge_y     = 1.3,
    color       = "black",
    show.legend = FALSE
  ) +
  scale_alpha(range = c(0.1, 1), guide = "none") +
  scale_color_manual(values = region_colors) +
  scale_y_continuous(
    name   = "Stunting prevalence (% <-2 height-for-age z-score",
    labels = label_number(accuracy = 0.1)
  ) +
  scale_x_continuous(
    name   = "Year",
    breaks = pretty(reg_rep$year)
  ) +
  scale_size_continuous(
    name   = "Population affected (children in 1000s)",
    range  = c(3, 20),
    labels = label_number(accuracy = 1, big.mark = ",")
  ) +
  labs(
    title    = "Child stunting: prevalence and number of children under 5 years who are too short-for-age",
    subtitle = "Modeled estimates by UNICEF reporting regions — Year: {round(frame_along)}",
    caption  = "Source: UNICEF, WHO & World Bank Joint Child Malnutrition Estimates"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "right",
    legend.key_size = unit(1.1, "lines"),
    legend.title    = element_text(size = 11, face = "bold"),
    legend.text     = element_text(size = 10),
    plot.title      = element_text(face = "bold", size = 14),
    plot.subtitle   = element_text(size = 11),
    plot.caption    = element_text(size = 9, hjust = 0, margin = margin(t = 8)),
    plot.margin     = margin(t = 20, r = 15, b = 20, l = 15)
  ) +
  transition_reveal(year)

## 6. Animate GIF
anim <- animate(
  p,
  nframes  = 120,
  fps      = 6,
  start_pause = 10,   # ← hold first frame for 20 frames (2 seconds at 10 fps)
  end_pause = 10,      # holds last frame for 20 extra frames = 2 seconds at 10 fps
  width    = 900,
  height   = 600,
  renderer = gifski_renderer(),
  dev      = "ragg_png",
  bg       = "white"
)

anim_save(
  "C:/Users/jconkle/Desktop/stunting_regions_bubble.gif",
  animation = anim
)

## 6b. MP4 version
animate(
  p,
  nframes  = 120,
  fps      = 10,
  width    = 900,
  height   = 600,
  renderer = av_renderer("C:/Users/jconkle/Desktop/stunting_regions_bubble.mp4"),
  dev      = "ragg_png",
  bg       = "white"
)


##########################################################
# Loop GIF with slide-in UNICEF-blue panel (no white boxes)
##########################################################

library(magick)

# Read GIF you already created (with legend on the right)
base <- image_read("C:/Users/jconkle/Desktop/stunting_regions_bubble.gif")

frames_per_loop <- length(base)   # this reflects nframes + pauses from gganimate
loops <- 3                        # 3 messages, 3 loops (change to 4 if needed)

# Repeat loops
anim <- base
for (i in 2:loops) {
  anim <- c(anim, base)
}

# Define messages: headline + subline
headlines <- c(
  "In 1990 there were more than 260 million stunted children globally",
  "More than 60% of children in South Asia were stunted in 1990",
  "In East Asia & Pacific stunting prevalence dropped from 39% to 13%"
)

sublines <- c(
  "By 2024 the number reduced to 150 million, with South Asia and East Asia & Pacific improving the most",
  "By 2024 stunting prevalence was nearly cut in half to 30% and the number of stunted children reduced from 103 million to 56 million",
  "The number of stunted children decreased from 78 million to 15 million"
)

stopifnot(length(headlines) == loops, length(sublines) == loops)

# Helper to wrap text to fit panel
wrap_text <- function(x, width = 22) {
  paste(strwrap(x, width = width), collapse = "\n")
}

unicef_blue   <- "#1CABE2"
panel_x_final <- 660    # final left edge of the panel (your choice)
panel_x_right <- 900    # frame width
slide_frames  <- 10     # how many frames to spend sliding in

for (i in seq_len(loops)) {
  start <- (i - 1) * frames_per_loop + 1
  end   <- i * frames_per_loop
  
  # Legend visible in first 20% of loop, panel+message from 20% → end
  visible_start <- start + floor(frames_per_loop * 0.20)
  visible_end   <- end   # keep panel + text until end
  
  # Wrap text once per loop
  hl  <- wrap_text(headlines[i], width = 20)
  sub <- wrap_text(sublines[i],   width = 22)
  
  # Vertical layout inside panel
  headline_y  <- 140
  line_height <- 22  # pixels per line at size=18
  n_lines_hl  <- length(strsplit(hl, "\n", fixed = TRUE)[[1]])
  subline_y   <- headline_y + n_lines_hl * line_height + 14
  
  # ---- 1) SLIDE-IN UNICEF BLUE PANEL ----
  for (f in seq_len(slide_frames)) {
    frame_index <- visible_start + f - 1
    if (frame_index > visible_end) break
    
    # xleft: start off-screen (900) → end at 660
    prog       <- f / slide_frames
    xleft_now  <- panel_x_right - prog * (panel_x_right - panel_x_final)
    
    frame <- anim[frame_index]
    frame <- image_draw(frame)
    
    rect(
      xleft   = xleft_now,
      ybottom = 0,
      xright  = panel_x_right,
      ytop    = 600,
      col     = unicef_blue,
      border  = NA
    )
    
    dev.off()
    anim[frame_index] <- frame
  }
  
  # ---- 2) STATIC PANEL AFTER SLIDE ----
  static_start <- min(visible_start + slide_frames, visible_end)
  if (static_start <= visible_end) {
    for (frame_index in static_start:visible_end) {
      frame <- anim[frame_index]
      frame <- image_draw(frame)
      
      rect(
        xleft   = panel_x_final,
        ybottom = 0,
        xright  = panel_x_right,
        ytop    = 600,
        col     = unicef_blue,
        border  = NA
      )
      
      dev.off()
      anim[frame_index] <- frame
    }
  }
  
  # ---- 3) ADD TEXT ON TOP OF PANEL (white) ----
  # Headline
  anim[visible_start:visible_end] <- image_annotate(
    anim[visible_start:visible_end],
    hl,
    size     = 18,                 # a bit smaller for better fit
    gravity  = "northwest",
    location = paste0("+", panel_x_final + 20, "+", headline_y),
    color    = "white"
  )
  
  # Subline
  anim[visible_start:visible_end] <- image_annotate(
    anim[visible_start:visible_end],
    sub,
    size     = 14,
    gravity  = "northwest",
    location = paste0("+", panel_x_final + 20, "+", subline_y),
    color    = "white"
  )
}

library(magick)
library(av)

# You already have:
# anim_small <- image_quantize(anim, max = 256, dither = TRUE)

# (Optional) keep the GIF
image_write(
  anim_small,
  "C:/Users/jconkle/Desktop/stunting_filler_loops_UNICEFblue_slide.gif"
)

# ---------- 1. Export frames as individual PNGs ----------
frames_dir <- "C:/Users/jconkle/Desktop/stunting_frames_unicef"
dir.create(frames_dir, showWarnings = FALSE)

# Write each frame explicitly: frame_001.png, frame_002.png, ...
for (i in seq_along(anim_small)) {
  image_write(
    anim_small[i],
    path   = file.path(frames_dir, sprintf("frame_%03d.png", i)),
    format = "png"
  )
}

# ---------- 2. Collect PNG filenames in order ----------
png_files <- list.files(
  frames_dir,
  pattern    = "^frame_\\d+\\.png$",
  full.names = TRUE
)
png_files <- sort(png_files)

# (Optional sanity check)
length(png_files)   # should be > 0, likely = length(anim_small)

# ---------- 3. Encode MP4 with av ----------
av::av_encode_video(
  png_files,
  output    = "C:/Users/jconkle/Desktop/stunting_filler_loops_UNICEFblue_slide.mp4",
  framerate = 6   # match your gganimate fps
)