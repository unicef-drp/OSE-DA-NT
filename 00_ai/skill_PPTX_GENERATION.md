# PowerPoint Generation Skill

Last updated: 2026-04-16

## Purpose

Guide AI agents through creating and extending UNICEF-branded PowerPoint
slide modules using the `officer` + `xml2` approach established in this
repository. Covers OOXML pitfalls, the modular slide-function pattern,
design token usage, and integration into orchestrator scripts.

---

## Trigger

Apply this skill when:
- Building a new slide-type module (chart slide, divider, narrative, etc.).
- Editing an existing `00_pptx_*.r` module.
- Debugging text that does not appear in the generated PPTX.
- Adjusting text-box dimensions, vertical spacing, or font properties.
- Adding new colour or typography tokens.

---

## 1. Architecture Overview

```
02_codes/
  00_pptx_design_tokens.r   ← shared brand constants (unicef_tokens)
  00_pptx_title_slide.r     ← title slide module (retain-and-replace)
  00_pptx_bullet_slide.r    ← bullet slide module (add-from-layout)
  00_pptx_section_slide.r   ← section/overview slide module
  00_pptx_stat_slide.r      ← statistic callout slide module (1/2/4 stats)
  00_pptx_photo_stat_slide.r ← full-bleed photo stat (retain-and-replace)
  00_pptx_chart_slide.r     ← chart slide module (full-width + chart+bullets)
  00_pptx_<type>_slide.r    ← future modules follow same pattern
  4_create_ppt.r            ← orchestrator: sources modules, builds deck
```

- **Design tokens** (`unicef_tokens` list) hold colours, fonts, and
  text-box constraints. Every slide module sources this file and reads
  from the shared list — never hardcode hex colours or font names.
- **Slide modules** are `00_`-prefixed utility scripts. They are never
  called by the conductor (`1_execute_conductor.r`); instead the
  orchestrator step (`4_create_ppt.r`) sources them directly.
- Each module exposes a public API (e.g. `make_title_slide()`,
  `apply_title_text()`, `add_bullet_slides()`, `add_chart_slide()`,
  `add_chart_bullet_slide()`) and keeps helper functions private
  (`.prefixed`).

### Slide Construction Strategy

Choose the approach based on whether the template slide carries embedded
assets (pictures, decorative shapes) or relies only on the slide layout:

| Approach | When to use | Example |
|----------|-------------|---------|
| **Retain & replace** | Template slide has embedded images or decorative shapes that are not part of the layout. Keep the slide in `keep_slides`, then mutate its XML to replace placeholder text. | Title slides (1–11): each has a unique background photo embedded in the slide itself. |
| **Add from layout** | The layout alone defines the full visual design (placeholders, colours, numbering). No per-slide assets to preserve. Use `add_slide(layout, master)` and populate with `ph_with()`. | Bullet slides: "8_Title and Content" layout provides everything including `buAutoNum`. |

Do not mix the two approaches on a single slide type. If a slide has
embedded assets, retain it; if the layout is sufficient, add fresh.

---

## 2. OOXML Critical Rules

### 2a. Element ordering inside `<a:p>`

The `<a:endParaRPr>` element **must be the last child** of every `<a:p>`.
If an `<a:r>` (text run) appears after it, PowerPoint silently ignores
the run and the text is invisible.

**Correct insertion pattern:**
```r
xml2::xml_add_sibling(end_rpr, run_node, .where = "before")
```

**Anti-pattern (causes invisible text):**
```r
xml2::xml_add_child(p_node, run_node)
# ↑ Appends AFTER <a:endParaRPr> → text disappears
```

### 2b. Empty placeholders

UNICEF template title slides (1–11) have placeholders with **zero `<a:r>`
nodes** — only `<a:endParaRPr>` inside `<a:p>`. You must:

1. Clone font properties from `<a:endParaRPr>` into a new `<a:rPr>`.
2. Build an `<a:r>` containing that `<a:rPr>` and `<a:t>` with the text.
3. Insert the `<a:r>` before `<a:endParaRPr>`.

The `.replace_shape_text()` helper in the title slide module demonstrates
this pattern.

### 2c. Multi-line text

To produce multiple lines in a single shape, create one `<a:p>` element
per line. Do **not** use `&#10;` or `<a:br/>`— separate `<a:p>` elements
give the most reliable cross-platform result.

Split input on `\n`, remove all existing `<a:p>` nodes, then append new
ones preserving the original `<a:endParaRPr>` in each.

### 2d. XML escaping

Always escape `&`, `<`, `>` in text content before inserting into XML
strings. The `.replace_shape_text()` helper does this automatically.

### 2e. Element ordering inside `<a:pPr>`

The OOXML schema enforces a strict child-element order within `<a:pPr>`.
Key ordering constraints:

```
<a:pPr>  →  a:spcBef  →  a:spcAft  →  a:buAutoNum / a:buChar / a:buNone  →  …
```

If `<a:spcAft>` is inserted **after** `<a:buAutoNum>`, PowerPoint silently
ignores the spacing. Always inject spacing elements before bullet elements.

### 2f. Layout-inherited numbering (`buAutoNum`)

Some layouts (e.g. "8_Title and Content" / slideLayout22.xml) define
`<a:buAutoNum type="arabicPeriod"/>` at the **shape default-text level**
(inside `<a:lstStyle>`), not inside individual `<a:pPr>` elements.

Consequences:
- `ph_with()` + `unordered_list()` produce paragraphs whose `<a:pPr>` is
  empty or has only `lvl="1"` — no `<a:buAutoNum>` to modify.
- Searching for `<a:buAutoNum>` inside `<a:pPr>` will always fail.
- Numbering inherited from the layout always restarts at 1 on each slide.

**Fix for continued numbering across slides:**
Inject an explicit `<a:buAutoNum type="arabicPeriod" startAt="N"/>` into
**every** level-0 paragraph's `<a:pPr>` on continuation slides. Setting it
only on the first paragraph is insufficient — subsequent paragraphs fall back
to the layout default and restart at 1.

```r
bu_xml <- xml2::read_xml(paste0(
  '<a:buAutoNum xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"',
  ' type="arabicPeriod" startAt="', start_val, '"/>'
))
xml2::xml_add_child(pPr, bu_xml)
```

### 2g. `move_slide()` is non-functional

`officer::move_slide()` is a no-op in the currently installed version —
slides remain in their original position regardless of arguments. This was
verified by testing every combination of `index`/`to`, save-and-reopen
cycles, and direct R6 private-field manipulation.

**Workaround:** After saving the PPTX with `print()`, post-process the
zip file by reordering `<p:sldId>` entries inside the `<p:sldIdLst>`
element in `ppt/presentation.xml`. PowerPoint reads slide order from this
list. The `.reorder_pptx_slides(pptx_path, new_order)` helper in
`4_create_ppt.r` implements this: extract zip → regex-reorder sldIdLst →
re-zip with `zip::zip()`. The `new_order` argument is an integer vector
mapping desired positions to current positions (same semantics as R
vector indexing).

### 2h. `ph_with()` strips `ph_type`

`officer::ph_with()` removes the `ph_type` attribute from the shape after
populating it. This means post-processing code cannot use `<p:ph type="body">`
to locate the content shape. Instead, find the shape by its **name** attribute
(e.g. `"Content Placeholder 2"`) via `<p:cNvPr name="...">` on the `<p:sp>`.

### 2i. `buNone` and `buChar` are mutually exclusive

officer emits `<a:buNone/>` in `<a:pPr>` by default. Adding `<a:buChar>`
alongside it violates the OOXML schema (CT_TextNoBullet vs CT_TextCharBullet
in a choice group). PowerPoint will show a repair dialog and strip the
offending elements. Always remove `<a:buNone/>` before injecting any
`buChar`/`buAutoNum`/`buFont`/`buClr` elements.

### 2j. Freeform text boxes do not render OOXML bullets

Text boxes created with `ph_location()` (not layout placeholders) lack
`<a:lstStyle>` shape-level bullet inheritance. Even with correct
`<a:buChar>`, `marL="342900"`, `indent="-342900"`, and `buNone` removal,
bullets remain invisible. Use literal Unicode bullet characters (`\u2022`)
as `ftext()` runs instead — see Section 6 (Chart Slide Module).

### 2k. officer's in-memory XML and R6 references

officer keeps slide XML in-memory as R6 objects with reference semantics.
To mutate the XML of a specific slide in place:

```r
xml_doc <- pptx$slide$get_slide(sl_idx)$get()   # live reference
# mutations here persist when officer writes the PPTX via print()
```

Writing to disk via `xml2::write_xml()` does NOT work — officer rebuilds
from its in-memory R6 objects, discarding any disk changes.

---

## 3. Text-Box Manipulation

### Auto-shrink (normAutofit)

After replacing text, inject `<a:normAutofit/>` inside `<a:bodyPr>` so
PowerPoint auto-shrinks long text instead of overflowing:

```r
fit_node <- xml2::read_xml(
  '<a:normAutofit xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"/>'
)
xml2::xml_add_child(body_pr, fit_node)
```

### Runtime widening

Template text boxes may be narrower than needed. Widen by setting the
`cx` attribute on `<a:xfrm><a:ext>`:

```r
xml2::xml_set_attr(ext_node, "cx", as.character(as.integer(width_in * 914400)))
```

The conversion factor is 914400 EMU per inch.

### Vertical position nudging

Adjust `y` on `<a:xfrm><a:off>` to add or remove vertical space between
shapes. Positive delta moves down; negative moves up.

---

## 4. Long-Path Workaround

R's `zip::unzip` and some `file.copy` calls fail when the PPTX template
path exceeds ~200 characters (common with OneDrive sync folders). Copy the
template to `tempdir()` first:

```r
if (nchar(template_path) > 200) {
  tmp <- file.path(tempdir(), "unicef_template_tmp.pptx")
  file.copy(template_path, tmp, overwrite = TRUE)
  template_path <- tmp
}
```

---

## 5. Design Token Conventions

- Colours: 12-entry hex palette in `unicef_tokens$colour`.
- Fonts: all sizes in `unicef_tokens$font` (points).
- Text-box limits: per slide type, auto-computed by `.estimate_max_chars()`
  using a `char_width_factor` of 0.38 and 1.2× line spacing.
- Truncation: `.fit_text()` allows 150% of the estimated max before
  truncating with an ellipsis — PowerPoint auto-fit handles mild overflow.

When adding a new slide type, add its box dimensions and limits to
`unicef_tokens` in `00_pptx_design_tokens.r`. Do not create a second
tokens file.

---

## 6. Chart Slide Module

The chart slide module (`00_pptx_chart_slide.r`) provides two variants:

| Function | Layout | Description |
|----------|--------|-------------|
| `add_chart_slide()` | Full-width | Chart at (0.5, 1.7, 12.0×5.1), title 20pt bold, source footer, speaker notes |
| `add_chart_bullet_slide()` | Chart + bullets | Chart left (0.5, 1.7, 8.0×5.1), bullet panel right (8.8, 1.8, 3.8×4.8) |

Both use "Title Only" layout (master "UNICEF") with absolute positioning.

### Bullet rendering in freeform text boxes

officer's `block_list` placed into a freeform text box (`ph_location()`) does
not inherit layout-level bullet formatting. OOXML `<a:buChar>` injection into
the in-memory XML was tested extensively but does **not** render reliably:

- officer emits `<a:buNone/>` by default; removing it and injecting `buChar`
  with correct `marL`/`indent` still produced invisible bullets.
- Root cause: freeform text boxes lack the `<a:lstStyle>` shape-level
  bullet inheritance that layout placeholders provide.

**Working approach:** Use literal Unicode bullet characters (`\u2022`) as a
separate `ftext()` run with desired colour, followed by the text run:

```r
fpar(
  ftext("\u2022  ", prop = bullet_marker_style),
  ftext(text, prop = bullet_text_style),
  fp_p = fp_par(padding.bottom = 12, text.align = "left")
)
```

This is plain text content — it renders reliably in any text box without
XML post-processing.

### Colour awareness

The "Title Only" layout on the UNICEF template has a **blue background**.
Bullet text must use white (`#FFFFFF`) or another high-contrast colour.
Do not use dark blue or cyan — they are invisible on the blue background.

### ggplot integration

- Charts are wrapped in `dml(ggobj = chart)` for editable vector graphics.
- Remove ggplot titles/subtitles/captions when the slide already has a title:
  `labs(title = NULL, subtitle = NULL, caption = NULL)`.
- Set `theme_unicef` to blank out title elements:
  `plot.title = element_blank(), plot.subtitle = element_blank(), plot.caption = element_blank()`.
- Title font size at 20pt bold prevents wrapping and overlap with the chart.

### Speaker notes

`.add_speaker_notes()` splits on `\n`, builds a `block_list` of 12pt Noto Sans
paragraphs, and calls `set_notes()` with `notes_location_type()`.

---

## 7. New Module Checklist

When creating a new slide module (`00_pptx_<type>_slide.r`):

1. **Header block** — Module name, purpose, dependencies, public API.
2. **Auto-source tokens** — Guard with `if (!exists("unicef_tokens"))`.
3. **Public functions** — `make_<type>_slide()` and/or `apply_<type>_text()`.
4. **Private helpers** — `.prefixed()` names.
5. **Integrate** — Add `source()` call in `4_create_ppt.r`.
6. **Add constraints** — Add text-box dimensions to `00_pptx_design_tokens.r`.
7. **Document** — Update the Slide Modules table in the briefing README.

For modules that post-process XML (spacing, numbering), follow the pattern
in `00_pptx_bullet_slide.r`: locate the content shape by name (not ph_type),
inject spacing elements before bullet elements, and re-fetch `<a:pPr>`
references after any XML modification.

---

## 7. Template Structure Reference

UNICEF Branded Presentation Template (2025 & 2026, identical):
- 76 slides total.
- Slides 1–11: title variants (Number slide layout). Slide 9 excluded
  (older child, not under-5).
- Slide 17: branded photo divider (used as full-bleed cover when placed
  before the title slide — a "screensaver" for the audience filing in).
- Slides 71–76: thank-you / closing variants.
- Placeholder names: "Title 1", "Text Placeholder 3" (subtitle),
  "Text Placeholder 4" (section), "Text Placeholder 5" (date).
- Title slides use `<p:ph type="title">` and `<p:ph type="body">`.
  Distinguish body placeholders by shape name, not placeholder index.

### Layout: "8_Title and Content" (slideLayout22.xml, master UNICEF)

Full-width bullet layout used by `add_bullet_slides()`.
- Placeholders: "Title 1", "Content Placeholder 2", "Date Placeholder 3" (footer).
- Has `<a:buAutoNum type="arabicPeriod"/>` at shape `lstStyle` level (inherited, not per-paragraph).
- `unordered_list()` content works with this layout; numbering is automatic but must be overridden via XML injection for continuation numbering across slides.

### Layout: "Picture with Caption" (master UNICEF)

Split layout used by `add_section_slide()` for overview and section breaks.
- Left  ~36%: "Title 1" (offx=0.92, cx=4.30) + "Text Placeholder 3" (body text, cx=4.30)
- Right ~56%: "Picture Placeholder 2" — accepts an optional `icon_path` PNG
- Footer: "Footer Placeholder 5"
- Section number is prepended to the title as "Section N | title".
- This is an add-from-layout slide: no embedded assets to retain.
- **Icon support**: Pass `icon_path = "path/to/icon.png"` to `add_section_slide()`
  to insert a branded icon into Picture Placeholder 2. If NULL, the
  placeholder remains empty for user photos.

### Statistic callout slides (`add_stat_slide()`)

Module `00_pptx_stat_slide.r` creates number-emphasis slides inspired by
template slides 53–60 and the `N_Number slide` layouts. Uses "Title Only"
layout with absolutely-positioned `block_list` stat blocks for full control.

| Stats | Layout | Value font | Description |
|-------|--------|-----------|-------------|
| 1 | Centred, full-width | 60pt bold | Single hero stat |
| 2 | Side-by-side columns | 52pt bold | Comparison pair |
| 4 | 2×2 grid | 44pt bold | Dashboard summary |

Each stat is a `list(value, label, color)`:
- `value`: displayed large (e.g. "55.3%", "37.4M")
- `label`: description below the value (supports `\n`)
- `color`: optional hex colour (default UNICEF cyan)

```r
add_stat_slide(pptx,
  stats = list(
    list(value = "55.3%", label = "Highest prevalence\nBurundi (2024)",
         color = "#00AEEF"),
    list(value = "13.9pp", label = "Largest 10-year reduction\nLibya",
         color = "#00833D")
  ),
  title = "At a Glance",
  source_text = "Source: UNICEF/WHO/World Bank JME")
```

Positioning uses `.stat_positions()` with fixed coordinates (inches):
- 1-stat: left=2.0, top=2.0, width=9.3
- 2-stat: columns at left=0.8 and left=7.0, width=5.5 each
- 4-stat: same columns, rows at top=1.6 and top=4.1

### Template Number slide layouts (reference)

The template defines `1_Number slide` through `4_Number slide` layouts
(master UNICEF). These provide photo placeholder backgrounds and branded
chrome but use different placeholder positioning strategies per variant:

| Layout | Title position | Placeholders | Notes |
|--------|---------------|--------------|-------|
| `1_Number slide` | (0.76, 0.89) top | Title + idx 11/12/13 | Full-width, top-aligned |
| `2_Number slide` | (0.76, 0.94) top-left | Title + idx 11/12/13 | Left-half only; right stat manual |
| `3_Number slide` | (0.76, 4.62) lower | Title + idx 11/13 | Title at bottom half |
| `4_Number slide` | (0.76, 5.04) bottom | Title + idx 11 | Title near bottom; all stats manual |

Template sample slides 53–55 use slideLayout25 (not a Number layout) with
manually placed textboxes. Slides 56–59 use "UNICEF Photo slide" layout.
The `add_stat_slide()` module bypasses these layouts in favour of absolute
positioning for reliable automation.

### Template Icon Library (slides 65–70)

The UNICEF Branded Presentation Template contains ~200 programme icons on
slides 65–70 as individual `p:pic` shapes with descriptive `descr` alt-text.
Seven nutrition-related icons have been extracted to `01_inputs/icons/`:

| File | Alt-text | Description |
|------|----------|-------------|
| `nutrition.png` | Nutrition icon | Smiling face with spoon |
| `children.png` | Children icon | Two children figures |
| `infant.png` | Infant icon | Baby figure |
| `breastfeeding.png` | Breastfeeding icon | Mother breastfeeding |
| `food_security.png` | Food Security icon | Bowl with wheat |
| `mother_and_baby.png` | Mother and Baby icon | Mother holding baby |
| `baby.png` | Baby icon | Crawling baby |

All icons are UNICEF-blue line art in dotted circular frames (~5–6 KB PNGs).
To extract additional icons, unzip the template and match `p:pic` shapes on
slides 65–70 by their `descr` attribute, then look up the corresponding
`rId` → `ppt/media/imageNN.png` mapping.

### Layout: "Title and Content" (slideLayout31.xml, master UNICEF)

Full-width layout used by template slides 30–31 (which add their own
embedded picture shapes). NOT used for section slides — use
"Picture with Caption" instead for the native split design.
