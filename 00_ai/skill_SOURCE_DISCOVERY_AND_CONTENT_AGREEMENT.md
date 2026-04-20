# Source Discovery And Content Agreement Skill

Last updated: 2026-04-17

## Purpose

Guide AI agents through two tasks that should happen before document production:

1. finding the right background sources
2. agreeing the analytical content before drafting a brief or PowerPoint

This skill is meant for cross-cutting use across ad hoc analyses and document
production workflows in this repository.

## Trigger

Apply this skill when:

- preparing a briefing, note, or PowerPoint
- drafting narrative from analytical results
- using external documents for context or framing
- starting a new analysis request that will end in a document

## Step 1 - Define The Output Before Writing It

Before building the document, prepare a content-agreement note covering:

1. audience
2. objective
3. decisions the document should support
4. core analytical questions
5. approved data sources
6. approved contextual sources
7. prohibited or unapproved claims
8. proposed structure or slide list
9. unresolved questions for the user

Do not draft a polished brief or deck before this step is complete.

Template:

- `00_ai/CONTENT_AGREEMENT_TEMPLATE.md`

Review pattern:

- keep the current agreement in the main `.md` file
- capture comments and proposed edits in a paired `.review.md` file
- use `>>>` comment lines only where comments are needed
- if text in the review file differs from the main file, treat that as a
  proposed edit even without any explicit marker
- when reconciling a review round, produce:
  - a new clean accepted version
  - a `.tracked.md` file showing visible changes from the prior accepted version
  - a fresh clean `.review.md` file for the next round

Interpretation rule:

- `>>>` at the top of the file means a document-level comment
- `>>>` directly below copied text means the comment applies to the text above
- changed text in the review file indicates a proposed replacement for the
  corresponding text in the main file

Tracked-file convention:

- prefer HTML-based markdown styling for tracked changes when the user wants a
  Word-like visual review
- additions should render in green
- deletions should render in red with strikethrough
- include a short legend and tell the user Markdown Preview gives the clearest
  rendering

## Step 2 - Separate Data Sources From Context Sources

Treat source classes differently.

### Data sources

Use for:

- charts
- rankings
- percentages
- counts
- derived statistical summaries

### Context sources

Use for:

- methodology notes
- indicator definitions
- interpretation boundaries
- policy framing

Documents are not approved numeric sources unless the user explicitly approves
them.

## Step 3 - Store External Documents Outside GitHub

Store working source documents in the relevant Analysis Space subfolder, not in
the repository.

GitHub should contain only code, documentation, and small reference tables.

For every external document used:

1. store the file in the relevant external source-library folder
2. add a row to the local source registry
3. record whether numeric use is approved
4. cite the source identifier in outputs

## Step 4 - Anthropometry Source Discovery Workflow

For child anthropometry work, start with these UNICEF JME pages:

1. https://data.unicef.org/topic/nutrition/malnutrition/
2. https://data.unicef.org/resources/jme/

At minimum, identify and review:

- the latest JME levels and trends page
- the latest standard methodology page
- current downloadable country or regional tables
- any directly relevant guidance on anthropometric indicators or data quality

As of 2026-04-17, these pages surface at least the following high-priority
starting points for modeled stunting work:

- JME Levels and Trends 2025 edition
- JME standard methodology
- current downloadable JME country estimates tables on the malnutrition topic page
- anthropometry guidance and data quality resources listed on the malnutrition topic page

## Recommended Pattern

For AI workflow, use a skill rather than a code function.

Why a skill is the better default:

- source discovery is judgment-heavy, not deterministic
- the relevant pages and latest documents can change over time
- the task includes workflow decisions, not only file retrieval
- the agent needs to decide what is background, what is citable, and what is
  still unapproved for numeric use

Use a code function only if a stable, repetitive need emerges later, for
example downloading and indexing known document types from fixed URLs.

## Definition Of Done

This skill is satisfied only when:

1. the analytical content is defined before document drafting
2. approved data sources are explicit
3. contextual documents are identified and stored externally if needed
4. numeric-use approvals are explicit
5. outputs can distinguish data sources from context sources
