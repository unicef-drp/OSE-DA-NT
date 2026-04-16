library(xml2)

extract_dir <- "C:/Temp/tpl_icons_extract"
slide_file <- file.path(extract_dir, "ppt", "slides", "slide65.xml")
rels_file  <- file.path(extract_dir, "ppt", "slides", "_rels", "slide65.xml.rels")

sx <- read_xml(slide_file)
ns <- xml_ns(sx)
rx <- read_xml(rels_file)

rels <- xml_find_all(rx, ".//d1:Relationship", xml_ns(rx))
rid_map <- setNames(
  sapply(rels, function(r) xml_attr(r, "Target")),
  sapply(rels, function(r) xml_attr(r, "Id"))
)

pics <- xml_find_all(sx, ".//p:pic", ns)

nutrition_keywords <- c("Nutrition", "Breastfeeding", "Food Security",
                        "Infant", "Mother and Baby", "Baby icon", "Children icon")

out_dir <- "C:/Users/joelc/Documents/GitHub/OSE-DA-NT/adhoc_analysis/stunting_top20_briefing/01_inputs/icons"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for (pic in pics) {
  nvPr <- xml_find_first(pic, ".//p:cNvPr", ns)
  descr <- xml_attr(nvPr, "descr")
  if (is.na(descr) || !nchar(descr)) next
  
  matched <- sapply(nutrition_keywords, function(kw) grepl(kw, descr, ignore.case = TRUE))
  if (!any(matched)) next
  
  blip <- xml_find_first(pic, ".//a:blip", ns)
  all_attrs <- xml_attrs(blip)
  r_embed <- all_attrs[grepl("embed", names(all_attrs))]
  if (length(r_embed) == 0) next
  r_embed <- r_embed[1]
  
  target <- rid_map[r_embed]
  if (is.na(target)) next
  img_file <- file.path(extract_dir, "ppt", sub("^\\.\\./", "", target))
  
  clean_name <- gsub("[^a-zA-Z0-9_]", "_", tolower(trimws(descr)))
  clean_name <- gsub("_+", "_", clean_name)
  clean_name <- gsub("_icon_*$", "", clean_name)
  clean_name <- gsub("_$", "", clean_name)
  dest <- file.path(out_dir, paste0(clean_name, ".png"))
  file.copy(img_file, dest, overwrite = TRUE)
  cat(sprintf("Saved: %s (%d bytes)\n", basename(dest), file.size(dest)))
}

cat("\nIcons saved to:", out_dir, "\n")
cat("Files:", paste(list.files(out_dir), collapse = ", "), "\n")
