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
  `apply_title_text()`, `add_bullet_slides()`) and keeps helper
  functions private (`.prefixed`).

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

## 6. New Module Checklist

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

### Layout: "Title and Content" (slideLayout31.xml, master UNICEF)

Split layout used by `add_section_slide()` for overview and section breaks.
Design matches template slides 30–31.
- Left ~55%: "Title 1" + "Content Placeholder 2" (body text).
- Right ~45%: "Picture Placeholder 2" (empty — user inserts own photo).
- Footer: "Date Placeholder 3".
- Variant "2_Title and Content" (slideLayout19) is visually identical.
- This is an add-from-layout slide: no embedded assets to retain.
