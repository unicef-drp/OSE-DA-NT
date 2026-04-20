# Two-Pager Markdown Render Spec

Last updated: 2026-04-20

## Purpose

This note documents the markdown conventions currently supported by the Word
brief generators:

- `02_codes/4_create_two_pager.r`

It exists so content editing and script behavior stay aligned.

## Active Content File

The active content source for the Word brief pipeline is currently:

`00_documentation/TWO_PAGER_BRIEF_CONTENT_V6.md`

Future content versions should keep this same marker pattern unless the render
scripts are updated in parallel.

The active on-disk renderer is currently:

`02_codes/4_create_two_pager.r`

## Figure Label Convention

The V6 content and renderer support compound figure labels:

- `Figure 1a` / `Figure 1b` for the page-1 pair (prevalence + burden)
- `Figure 2a` / `Figure 2b` for the page-2 pair (prevalence improvers + burden reducers)

The figure-path resolver in `4_create_two_pager.r` maps these labels to PNG
filenames via a lookup that also accepts the legacy numeric-only labels (1, 4,
8, 10) for backward compatibility.

## Supported Markers

### Title block markers

- `[[KICKER: ...]]`
- `[[SUBTITLE: ...]]`
- `[[PAGE2_KICKER: ...]]`

These markers are parsed explicitly by the Word brief scripts and should not be
treated as ordinary body text.

### Footnote markers

- `[[FOOTNOTE: ...]]`

These markers are parsed as editable figure footnotes. They should be placed in
the section where the footnotes are intended to render.

## Supported Structural Elements

The scripts currently support:

- one `#` title
- `##` section headings
- plain paragraphs
- markdown bullets using `-`
- figure placeholders in the form `**[Figure X: ...]**`
- data source lines in the form `**Data source:** ...`
- optional `>>>` editorial notes, which are ignored by the renderer

## Current Section Assumptions

The current Word brief scripts assume these main sections exist:

- `Key Messages`
- `Current Scale: Prevalence & Burden`
- `Progress: Reduction in Prevalence and Number of Affected Children Over 20 Years`

Optional supported section:

- `Interpreting the Results`

If an explicit `Limitations` section exists, it will render as its own section.
If it does not exist, the script may render limitation bullets from the most
relevant page-2 section instead.

## Figure Placement Rules

The scripts build side-by-side figure panels rather than placing figures one by
one.

Current page behavior:

- page 1 uses the figure placeholders found in `Current Scale: Prevalence & Burden`
- page 2 uses the figure placeholders found in `Progress...` and, if needed, also `Interpreting the Results`

Placement behavior:

- if page-2 figure placeholders appear in the `Progress...` section, the panel is rendered immediately after the progress text
- if page-2 figure placeholders are absent from `Progress...` but present later, the panel is rendered after the later page-2 content block

This means moving figure placeholder lines inside the markdown changes figure
placement in the rendered DOCX.

## Footnote Rendering Rules

For the current two-pager:

- page 1 expects two figure footnotes:
  - `11-20 prevalence, 2024`
  - `11-20 number of stunted children, 2024`
- page 2 expects two figure footnotes:
  - `11-20 reduction in prevalence, 2004-2024`
  - `11-20 reduction in stunted children, 2004-2024`

If `[[FOOTNOTE: ...]]` markers are present in the relevant section, the scripts
render those exact strings.

If no footnote markers are present, the scripts fall back to auto-generated
footnotes from `stunting_rankings.rds`.

## Source Rendering Rules

Data source lines written in markdown as:

`**Data source:** ...`

are parsed and rendered as source footers in the Word document.

The scripts currently use section-level source placement:

- page 1 uses the source tied to the current-scale section
- page 2 prefers the source tied to the progress section

## Editing Guidance

When updating the content markdown:

- keep markers on their own lines
- keep figure placeholders on their own lines
- keep source lines in the `**Data source:** ...` form
- place `[[FOOTNOTE: ...]]` lines directly under the figure block they belong to
- use `>>>` lines for editorial comments only during review stages

If you change section names or introduce new structural markers, update the
Word brief scripts in the same session.
