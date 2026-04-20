library(xml2)
source("profile_OSE-DA-NT.R")

brand_root <- file.path(nutritionRoot, "github", "documentation", "unicef_brand")
tpl_orig <- file.path(brand_root, "UNICEF Branded Presentation Template 2026.pptx")
# Use a short local path to avoid long-path issues with file.copy / unzip
tpl <- "C:/Temp/tpl_icons.pptx"
dir.create("C:/Temp", showWarnings = FALSE)
if (!file.copy(tpl_orig, tpl, overwrite = TRUE)) {
  # Fallback: robocopy handles long source paths
  system2("robocopy", c(shQuote(normalizePath(dirname(tpl_orig))),
    "C:\\Temp", shQuote(basename(tpl_orig)), "/NFL /NDL /NJH /NJS /NC /NS"),
    stdout = FALSE, stderr = FALSE)
  file.rename("C:/Temp/UNICEF Branded Presentation Template 2026.pptx", tpl)
}
stopifnot(file.exists(tpl))

extract_dir <- "C:/Temp/tpl_icons_extract"
unlink(extract_dir, TRUE)
dir.create(extract_dir)
utils::unzip(tpl, exdir = extract_dir)

# Nutrition-related icons are on slide 65 (well-labelled with descr attributes)
# Target icons by their descr text
nutrition_keywords <- c(
  "Nutrition", "Breastfeeding", "Food Security",
  "Infant", "Mother and Baby", "Baby", "Children"
)

slide_file <- file.path(extract_dir, "ppt", "slides", "slide65.xml")
rels_file  <- file.path(extract_dir, "ppt", "slides", "_rels", "slide65.xml.rels")

sx <- read_xml(slide_file)
ns <- xml_ns(sx)
rx <- read_xml(rels_file)

# Build rId -> image file map from rels
rels <- xml_find_all(rx, ".//d1:Relationship", xml_ns(rx))
rid_map <- setNames(
  sapply(rels, function(r) xml_attr(r, "Target")),
  sapply(rels, function(r) xml_attr(r, "Id"))
)

# Find all pic shapes
pics <- xml_find_all(sx, ".//p:pic", ns)

results <- list()
for (pic in pics) {
  nvPr <- xml_find_first(pic, ".//p:cNvPr", ns)
  descr <- xml_attr(nvPr, "descr")
  name  <- xml_attr(nvPr, "name")
  
  if (is.na(descr)) next
  
  # Check if this icon matches any nutrition keyword
  matched <- sapply(nutrition_keywords, function(kw) grepl(kw, descr, ignore.case = TRUE))
  if (!any(matched)) next
  
  # Get the blip rId (try both direct and inside grpSp)
  blip <- xml_find_first(pic, ".//a:blip", ns)
  r_embed <- xml_attr(blip, "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed")
  
  if (is.na(r_embed)) next
  
  target <- rid_map[r_embed]
  img_file <- file.path(extract_dir, "ppt", sub("^\\.\\./", "", target))
  
  cat(sprintf("%-30s  rId=%-6s  file=%s  exists=%s\n",
              descr, r_embed, basename(img_file), file.exists(img_file)))
  
  results[[descr]] <- list(
    descr = descr,
    name = name,
    rId = r_embed,
    img_file = img_file
  )
}

# Copy matched icons to a staging folder
out_dir <- file.path(getwd(), "adhoc_analysis", "stunting_top20_briefing", "01_inputs", "icons")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for (item in results) {
  # Clean filename from descr
  clean_name <- gsub("[^a-zA-Z0-9_]", "_", tolower(trimws(item$descr)))
  clean_name <- gsub("_+", "_", clean_name)
  clean_name <- gsub("_icon_?$", "", clean_name)
  clean_name <- gsub("_$", "", clean_name)
  dest <- file.path(out_dir, paste0(clean_name, ".png"))
  file.copy(item$img_file, dest, overwrite = TRUE)
  cat(sprintf("  -> Saved: %s\n", dest))
}

unlink(extract_dir, TRUE)
cat("\nDone. Icons saved to:", out_dir, "\n")
