# ---------------------------------------------------------------------------
# Script:  5f_create_two_pager_v5.r
# Purpose: Build a UNICEF-branded two-page briefing document from the approved
#          v3 tables/figures content and the user-edited brief content markdown.
# Inputs:  03_outputs/stunting_rankings.rds
#          03_outputs/figures/fig1_highest_prevalence.png
#          03_outputs/figures/fig4_highest_burden.png
#          03_outputs/figures/fig8_before_after_prev_20yr.png
#          03_outputs/figures/fig10_before_after_burden_20yr.png
# Outputs: 03_outputs/stunting_top20_two_pager_v5.docx
# ---------------------------------------------------------------------------

# --- Paths -----------------------------------------------------------------
if (!exists("projectFolder", envir = .GlobalEnv)) {
  source(file.path(getwd(), "profile_OSE-DA-NT.R"))
}

adhoc_output_root <- file.path(githubOutputRoot, "adhoc_analysis",
                               "stunting_top20_briefing")
output_dir  <- file.path(adhoc_output_root, "03_outputs")
figures_dir <- file.path(output_dir, "figures")

rds_path <- file.path(output_dir, "stunting_rankings.rds")
if (!file.exists(rds_path)) stop("Rankings not found: ", rds_path)
results <- readRDS(rds_path)

# --- Brand colours ---------------------------------------------------------
ucol <- list(
  dark_blue  = "#374EA2",
  cyan       = "#00AEEF",
  teal       = "#00A79D",
  white      = "#FFFFFF",
  light_grey = "#F0F0F0",
  body_text  = "#1D1D1B",
  caption    = "#5A5A5A"
)

# --- Helper functions ------------------------------------------------------
fp_title <- officer::fp_text(
  font.size = 18, bold = TRUE, font.family = "Noto Sans", color = ucol$white
)
fp_subtitle <- officer::fp_text(
  font.size = 9, italic = TRUE, font.family = "Noto Sans", color = ucol$caption
)
fp_section <- officer::fp_text(
  font.size = 11, bold = TRUE, font.family = "Noto Sans", color = ucol$dark_blue
)
fp_body <- officer::fp_text(
  font.size = 9, font.family = "Noto Sans", color = ucol$body_text
)
fp_body_bold <- officer::fp_text(
  font.size = 9, bold = TRUE, font.family = "Noto Sans", color = ucol$body_text
)
fp_key_msg <- officer::fp_text(
  font.size = 9, font.family = "Noto Sans", color = ucol$dark_blue
)
fp_key_msg_bold <- officer::fp_text(
  font.size = 9, bold = TRUE, font.family = "Noto Sans", color = ucol$dark_blue
)
fp_source <- officer::fp_text(
  font.size = 7, italic = TRUE, font.family = "Noto Sans", color = ucol$caption
)
fp_fig_caption <- officer::fp_text(
  font.size = 8, bold = TRUE, font.family = "Noto Sans", color = ucol$dark_blue
)

add_title_bar <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(txt, fp_title),
    fp_p = officer::fp_par(
      text.align = "left",
      padding.top = 8, padding.bottom = 8,
      padding.left = 10, padding.right = 10,
      shading.color = ucol$dark_blue
    )
  ))
}

add_subtitle <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(txt, fp_subtitle),
    fp_p = officer::fp_par(padding.top = 2, padding.bottom = 6)
  ))
}

add_section_head <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(txt, fp_section),
    fp_p = officer::fp_par(
      padding.top = 6, padding.bottom = 2,
      border.bottom = officer::fp_border(color = ucol$cyan, width = 1.5)
    )
  ))
}

add_body_text <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(txt, fp_body),
    fp_p = officer::fp_par(line_spacing = 1.15, padding.bottom = 3)
  ))
}

add_key_bullet <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext("\u2022 ", fp_key_msg_bold),
    officer::ftext(txt, fp_key_msg),
    fp_p = officer::fp_par(line_spacing = 1.15, padding.bottom = 2, padding.left = 8)
  ))
}

add_fig_caption <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(txt, fp_fig_caption),
    fp_p = officer::fp_par(padding.top = 2, padding.bottom = 1)
  ))
}

add_source_footer <- function(doc, txt) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext(txt, fp_source),
    fp_p = officer::fp_par(
      padding.top = 4,
      border.top = officer::fp_border(color = ucol$cyan, width = 0.5)
    )
  ))
}

# --- Key messages callout box ----------------------------------------------
add_key_messages_box <- function(doc) {
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext("KEY MESSAGES", officer::fp_text(
      font.size = 10, bold = TRUE, font.family = "Noto Sans", color = ucol$dark_blue
    )),
    fp_p = officer::fp_par(
      padding.top = 6, padding.bottom = 2, padding.left = 8,
      shading.color = ucol$light_grey,
      border.left = officer::fp_border(color = ucol$cyan, width = 3)
    )
  ))
  bullets <- c(
    "An estimated 150.2 million children under 5 were stunted in 2024. The burden is highly concentrated: the top 20 countries account for over three quarters of the global total.",
    "The global number of stunted children fell by 51.7 million over the past two decades, and a single country \u2014 India \u2014 accounted for more than half of that reduction.",
    "The highest-prevalence countries are concentrated in Sub-Saharan Africa, while the highest-burden countries span both Sub-Saharan Africa and South Asia.",
    "Progress has been narrowly concentrated in a small number of populous countries."
  )
  for (b in bullets) {
    officer::body_add_fpar(doc, officer::fpar(
      officer::ftext("\u2022 ", fp_key_msg_bold),
      officer::ftext(b, fp_key_msg),
      fp_p = officer::fp_par(
        line_spacing = 1.1, padding.bottom = 1, padding.left = 14,
        shading.color = ucol$light_grey,
        border.left = officer::fp_border(color = ucol$cyan, width = 3)
      )
    ))
  }
  # Close box with a thin bottom padding paragraph
  officer::body_add_fpar(doc, officer::fpar(
    officer::ftext("", fp_body),
    fp_p = officer::fp_par(
      padding.top = 0, padding.bottom = 2,
      shading.color = ucol$light_grey,
      border.left = officer::fp_border(color = ucol$cyan, width = 3)
    )
  ))
}

# --- Compose the document --------------------------------------------------
doc <- officer::read_docx()

# Set narrow margins for a dense two-pager
doc <- officer::body_set_default_section(doc, officer::prop_section(
  page_size = officer::page_size(orient = "portrait",
                                  width = 8.27, height = 11.69),  # A4
  page_margins = officer::page_mar(
    top = 0.5, bottom = 0.5, left = 0.6, right = 0.6,
    header = 0.3, footer = 0.3
  )
))

# ========== PAGE 1 =========================================================
add_title_bar(doc, "Child Stunting: Where Levels Remain Highest and Where Progress Has Been Strongest")
add_subtitle(doc, "JME modeled estimates, 2024  |  Stunting (height-for-age < \u22122 SD), children under 5")

# Key messages box
add_key_messages_box(doc)

# --- Current Scale: Prevalence ---------------------------------------------
add_section_head(doc, "Current Scale: Prevalence")
add_body_text(doc, "Burundi had the highest modeled stunting prevalence in 2024 at 55.3%, followed by Niger, Eritrea, Angola, and Papua New Guinea. The highest-prevalence countries are concentrated in Sub-Saharan Africa, with one Pacific country in the top five.")
add_body_text(doc, "The prevalence and burden rankings overlap but are not identical. Eleven countries appear in both the top-20 highest-prevalence and top-20 highest-burden lists: Afghanistan, Angola, the Democratic Republic of the Congo, Ethiopia, Madagascar, Mozambique, Niger, Nigeria, Pakistan, Sudan, and Yemen.")

# Figure 1
fig1_path <- file.path(figures_dir, "fig1_highest_prevalence.png")
if (file.exists(fig1_path)) {
  add_fig_caption(doc, "Figure 1. Top 10 countries by stunting prevalence, 2024")
  officer::body_add_img(doc, src = fig1_path, width = 3.3, height = 2.2,
                        style = "Normal")
}

# --- Current Scale: Burden -------------------------------------------------
add_section_head(doc, "Current Scale: Burden")
add_body_text(doc, "India had the largest estimated number of stunted children in 2024 at 37.4 million \u2014 one in every four stunted children globally. The top five burden countries were India, Nigeria, Pakistan, the Democratic Republic of the Congo, and Ethiopia.")
add_body_text(doc, "The burden is highly concentrated. The top 5 countries accounted for 50.1% of the global total, the top 10 for 62.4%, and the top 20 for 76.8%.")

# Figure 4
fig4_path <- file.path(figures_dir, "fig4_highest_burden.png")
if (file.exists(fig4_path)) {
  add_fig_caption(doc, "Figure 4. Top 10 countries by number of stunted children, 2024")
  officer::body_add_img(doc, src = fig4_path, width = 3.3, height = 2.2,
                        style = "Normal")
}

# Source footer page 1
add_source_footer(doc, "Data source: 2025 Joint Child Malnutrition Estimates.")

# ========== PAGE BREAK =====================================================
doc <- officer::body_add_break(doc)

# ========== PAGE 2 =========================================================
add_section_head(doc, "Progress: Prevalence Reduction Over 20 Years")
add_body_text(doc, "North Korea showed the largest 20-year reduction in stunting prevalence, with a decline of 27.6 percentage points between 2004 and 2024. Several countries appear in both the 10-year and 20-year top-improver lists, suggesting sustained long-term progress. Among 10-year reducers, the fastest pace was about 1.4 percentage points per year.")
add_body_text(doc, "Countries that started from the highest prevalence levels tended to achieve the largest absolute reductions, though relative progress varied widely. Some countries that began above 40% prevalence have achieved reductions of 20 percentage points or more over two decades.")

# Figure 8
fig8_path <- file.path(figures_dir, "fig8_before_after_prev_20yr.png")
if (file.exists(fig8_path)) {
  add_fig_caption(doc, "Figure 8. Top 10 prevalence improvers, 2004 vs 2024")
  officer::body_add_img(doc, src = fig8_path, width = 3.3, height = 2.2,
                        style = "Normal")
}

# --- Burden Reduction and Concentration ------------------------------------
add_section_head(doc, "Progress: Burden Reduction and Its Concentration")
add_body_text(doc, "The global number of stunted children fell from 201.9 million in 2004 to 150.2 million in 2024 \u2014 a reduction of 51.7 million. India alone accounted for 27.5 million of that reduction, or 53.3% of the global total.")
add_body_text(doc, "This concentration is striking: the top 5 burden reducers accounted for 91.3% of the global reduction, and the top 10 for 100.9%. That the top-10 share exceeds 100% is not an error \u2014 it reflects the fact that burden increased in some countries over this period, particularly in African countries that had high population growth and little or no improvement in prevalence. The top 20 reducers accounted for 111.3%, reinforcing that progress has been driven by a small number of populous countries while burden grew elsewhere.")
add_body_text(doc, "India achieved the largest absolute burden reduction (27.5 million fewer stunted children over 20 years) yet remains the single largest-burden country, illustrating that even more progress is needed.")

# Figure 10
fig10_path <- file.path(figures_dir, "fig10_before_after_burden_20yr.png")
if (file.exists(fig10_path)) {
  add_fig_caption(doc, "Figure 10. Top 10 burden reducers, 2004 vs 2024")
  officer::body_add_img(doc, src = fig10_path, width = 3.3, height = 2.2,
                        style = "Normal")
}

# --- Limitations -----------------------------------------------------------
add_section_head(doc, "Limitations")
add_body_text(doc, "These rankings use JME modeled stunting estimates, which are appropriate for trend comparison but produce smoothed trajectories rather than direct annual observations.")
add_body_text(doc, "Acute shocks \u2014 including conflict, economic crisis, and food emergencies \u2014 may not be captured in real time by the modeled series. Estimates and rankings should not be over-interpreted.")

# Source footer page 2
add_source_footer(doc, "Data source: 2025 Joint Child Malnutrition Estimates.")

# --- Save ------------------------------------------------------------------
doc_path <- file.path(output_dir, "stunting_top20_two_pager_v5.docx")
print(doc, target = doc_path)
message("Saved: ", doc_path)
