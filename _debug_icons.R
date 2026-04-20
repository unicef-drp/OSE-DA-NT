library(xml2)
source("profile_OSE-DA-NT.R")

# Template already copied to C:/Temp by PowerShell
tpl <- "C:/Temp/tpl_icons.pptx"
stopifnot(file.exists(tpl))
extract_dir <- "C:/Temp/tpl_icons_extract"
unlink(extract_dir, TRUE)
dir.create(extract_dir)
utils::unzip(tpl, exdir = extract_dir)

slide_file <- file.path(extract_dir, "ppt", "slides", "slide65.xml")
rels_file  <- file.path(extract_dir, "ppt", "slides", "_rels", "slide65.xml.rels")

sx <- read_xml(slide_file)
ns <- xml_ns(sx)
rx <- read_xml(rels_file)

# Build rId -> image file map
rels <- xml_find_all(rx, ".//d1:Relationship", xml_ns(rx))
rid_map <- setNames(
  sapply(rels, function(r) xml_attr(r, "Target")),
  sapply(rels, function(r) xml_attr(r, "Id"))
)

# Find ALL pic shapes (including inside grpSp)
pics <- xml_find_all(sx, ".//p:pic", ns)
cat("Total pics found:", length(pics), "\n")

nutrition_keywords <- c("Nutrition", "Breastfeeding", "Food Security",
                        "Infant", "Mother and Baby", "Baby icon", "Children icon")

for (pic in pics) {
  # cNvPr can be at different levels depending on grouping
  nvPr <- xml_find_first(pic, ".//p:cNvPr", ns)
  if (is.null(nvPr) || length(nvPr) == 0) next
  descr <- xml_attr(nvPr, "descr")
  name  <- xml_attr(nvPr, "name")
  
  if (is.na(descr) || !nchar(descr)) next
  
  matched <- sapply(nutrition_keywords, function(kw) grepl(kw, descr, ignore.case = TRUE))
  if (!any(matched)) next
  
  # Get blip - try namespace-aware approach
  blip <- xml_find_first(pic, ".//a:blip", ns)
  if (length(blip) == 0) {
    cat(sprintf("  SKIP (no blip): %s\n", descr))
    next
  }
  
  # Try various ways to get the embed attribute
  r_embed <- xml_attr(blip, "embed")
  if (is.na(r_embed)) {
    # Try with namespace prefix
    all_attrs <- xml_attrs(blip)
    cat(sprintf("  Blip attrs for '%s': %s\n", descr, paste(names(all_attrs), all_attrs, sep="=", collapse=", ")))
    # Look for r:embed
    r_embed <- all_attrs[grepl("embed", names(all_attrs))]
    if (length(r_embed) > 0) r_embed <- r_embed[1] else r_embed <- NA
  }
  
  if (is.na(r_embed)) {
    cat(sprintf("  SKIP (no embed): %s\n", descr))
    next
  }
  
  target <- rid_map[r_embed]
  if (is.na(target)) {
    cat(sprintf("  SKIP (rId not in rels): %s  rId=%s\n", descr, r_embed))
    next
  }
  
  img_file <- file.path(extract_dir, "ppt", sub("^\\.\\./", "", target))
  cat(sprintf("MATCH: %-30s  rId=%-6s  file=%-20s  exists=%s  size=%s\n",
              descr, r_embed, basename(img_file), file.exists(img_file),
              if (file.exists(img_file)) file.size(img_file) else "?"))
}
