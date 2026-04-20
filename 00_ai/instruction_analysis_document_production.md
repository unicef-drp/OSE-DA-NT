---
applyTo: "**/*"
---

# Analysis And Document Production Instructions

These instructions apply to AI work that produces analytical outputs or
documents from repository data, including briefs, slide decks, notes, and
supporting narrative.

## Core Rule

Do not move directly from available data to a finished brief or PowerPoint.
First define and agree the analytical content.

## Required Pre-Production Content Agreement

Before producing a brief, slide deck, or polished narrative output, create or
update a content-agreement note that covers:

1. objective and audience
2. questions the output must answer
3. approved datasets in scope
4. approved contextual documents in scope
5. numeric claims that are allowed
6. claims that are explicitly out of scope or unapproved
7. proposed structure or slide outline
8. open decisions requiring user confirmation

If the user is actively iterating on content, this agreement can be lightweight,
but it must exist before final production.

Template:

- `00_ai/CONTENT_AGREEMENT_TEMPLATE.md`

If the document is being actively reviewed in markdown:

- keep one clean current draft in the main `.md` file
- use a paired `.review.md` file for comments and direct text edits
- when reconciling a round, create a clean next version, a visible `.tracked.md`
	version, and a fresh clean `.review.md` file for the next round

## Source Rules

### Numbers

Numeric claims must come from approved datasets or code-derived outputs that are
traceable to approved datasets.

Do not use numbers copied from:

- websites
- PDFs
- Word files
- prior briefings
- emails

unless the user explicitly approves that use.

### Contextual Documents

Documents may support framing, definitions, methods notes, and interpretation,
but they do not become approved numeric sources by default.

Any external document that informs output content must be stored in the
appropriate Analysis Space subfolder and registered in a local source registry.

## Storage Rule

GitHub is not a storage space for working documents, asset libraries, source
packets, or large briefing reference files.

Use the external Analysis Space `github` folder for:

- source-document libraries
- working output files
- large reference assets
- briefing support materials not suited for version control

Keep GitHub limited to:

- scripts
- runbooks
- instructions
- code modules
- small reference tables required by code

## Citation Rule

Any contextual claim drawn from a document must be traceable to a stored source
document or to a repository document.

Outputs should distinguish between:

- `Data source:` for quantitative claims and charts
- `Context source:` for narrative, methods, or framing documents

## Markdown Review Rule

When the user wants tracked changes in markdown, prefer a Word-like visual
scheme in Markdown Preview:

- additions in green
- deletions in red with strikethrough
- a short legend at the top of the tracked file

Do not rely only on plain `<mark>` and `~~...~~` if the user says the changes
are hard to see.


## Anthropometry Requirement

When working on child anthropometry content, agents should review current UNICEF
JME sources before drafting narrative or briefing content.

Minimum starting points:

- https://data.unicef.org/topic/nutrition/malnutrition/
- https://data.unicef.org/resources/jme/

For JME-related anthropometry outputs, agents should identify the latest
relevant JME report, methodology page, downloadable tables, and any directly
relevant guidance documents before drafting content.
