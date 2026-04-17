# Stunting Top 20 Briefing Content Skill

Last updated: 2026-04-17

## Purpose

Guide AI agents working on the stunting briefing so they improve analytical
content without breaking source discipline.

This skill exists because the briefing pipeline already has strong PowerPoint
design infrastructure, but still needs tighter rules for:

- analytical depth
- dataset-only numeric sourcing
- document storage and citation for non-dataset claims

## Trigger

Apply this skill when:

- extending `adhoc_analysis/stunting_top20_briefing/`
- adding new analyses, charts, slide text, or methods notes
- using any external document to shape briefing content
- reviewing whether a slide claim is adequately supported

## Required Reading Before Editing

Read these files before changing the briefing content:

1. `adhoc_analysis/stunting_top20_briefing/00_documentation/README.md`
2. `adhoc_analysis/stunting_top20_briefing/00_documentation/CONTENT_PLAN_AND_SOURCE_GOVERNANCE.md`
3. the external source-library README for this workflow in the Analysis Space `github` folder
4. the external `source_registry.csv` for this workflow in the Analysis Space `github` folder
5. `00_documentation/ANALYSIS_DATASETS_RUNBOOK.md`
6. `00_ai/analysis_datasets/BUILD_CONVENTIONS_SKILL.md`
7. `00_ai/skill_PPTX_GENERATION.md` when editing slide-generation code
8. https://data.unicef.org/topic/nutrition/malnutrition/ for current JME-linked resources
9. https://data.unicef.org/resources/jme/ for the current JME report page

## Hard Source Rules

### Rule 1 - Numbers come from approved datasets

Numeric claims must come only from:

- `analysis_datasets` outputs in this repository
- approved `DW-Production` outputs already in scope for the workflow
- transformations derived in code directly from those datasets

Do not pull numbers from:

- PDFs
- Word files
- emails
- websites
- prior slide decks

unless the user explicitly approves that exception.

### Rule 2 - Documents may support context, not default numbers

Documents can support:

- definitions
- methodology notes
- framing
- interpretation
- cautions

Documents cannot supply numeric claims by default.

### Rule 3 - Every document-derived claim must be traceable

If a slide, speaker note, or summary uses a document-derived claim:

1. the document must be stored locally if it is external to the repo
2. the document must have a `source_id` in `source_registry.csv`
3. the output must cite that `source_id`

For this workflow, external documents must be stored in the mirrored Analysis
Space source-library folder, not in the repository.

### Rule 4 - Untraceable claims must be removed

If a claim cannot be traced to dataset code or a registered source document,
remove it rather than paraphrasing it more confidently.

## Analytical Expectations

Do not stop at simple rankings. The briefing should answer a small set of
decision-relevant questions.

Minimum expected content areas:

1. latest-year prevalence
2. latest-year burden by number affected
3. progress over 10-year and 20-year windows
4. overlap between high prevalence and high burden
5. eligibility and coverage limitations of the ranking universe

Preferred extensions when supported by approved data:

- concentration of burden across top countries
- burden change versus prevalence change
- population-growth-aware interpretation
- persistent high-prevalence country profiles

## Interpretation Rules

Use cautious language unless the data directly support a stronger statement.

Preferred wording:

- `may indicate`
- `is consistent with`
- `remains among the highest`
- `shows a large absolute reduction`

Avoid:

- unsupported causal claims
- policy recommendations presented as data findings
- vague statements such as `these countries carry a large share of the global burden`
  unless the share is actually calculated from approved data

## Required Method Transparency

Whenever rankings are produced, capture and present:

- indicator code used
- dataset file used
- latest year and baseline years
- country eligibility count
- filtering rules for confidentiality and dimensional scope
- whether values were read as proportions and converted to percent

## Slide Source Formatting

Where possible, distinguish:

- `Data source:` for chart numbers and rankings
- `Context source:` for methodology or narrative notes

Do not use a single ambiguous `Source:` label when both are present.

## External Document Workflow

When an external document is needed for ideas or context:

1. copy it into
   the external Analysis Space source-library folder for this workflow
2. add a registry row with a new `source_id`
3. mark numeric approval status explicitly
4. cite the `source_id` anywhere the document informs output text

## JME Background Requirement

Because this briefing uses modeled stunting, agents should review current UNICEF
JME background material before drafting narrative content.

Minimum source-discovery starting points:

- https://data.unicef.org/topic/nutrition/malnutrition/
- https://data.unicef.org/resources/jme/

At minimum, identify the latest JME report, latest downloadable tables, and the
relevant methodology or guidance pages before drafting interpretive text.


## Definition Of Done

This skill is satisfied only when:

1. every numeric statement is traceable to approved datasets or an explicitly
   approved exception
2. every document-derived contextual statement is traceable to a registered
   source
3. the deck includes method transparency on ranking eligibility and windows
4. the narrative says no more than the evidence supports
