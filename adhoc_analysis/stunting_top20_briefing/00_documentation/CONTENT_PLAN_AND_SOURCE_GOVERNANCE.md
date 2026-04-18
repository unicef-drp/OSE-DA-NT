# Stunting Top 20 Briefing - Content Plan And Source Governance

Last updated: 2026-04-18

## Purpose

This note sets the content-development plan for the stunting briefing and the
source-governance rules that must constrain future agent work.

The core problem is not slide design. The current pipeline already produces a
well-branded deck. The gap is analytical depth and evidentiary discipline:

- the current analysis is mostly three rankings plus narrative text generated
  from those rankings
- the current narrative can overstate programme implications that are not
  directly tested in the data
- the pipeline does not yet maintain a local registry for non-dataset source
  documents used for context or interpretation

This document fixes those gaps by defining:

1. what counts as an approved numeric source
2. what analytical questions the briefing should answer
3. what contextual documents agents may use for ideas and interpretation
4. how external document use must be stored and cited

## External Storage Rule

The source library for this workflow must live outside the GitHub repository.

Use this external Analysis Space location:

`C:/Users/jconkle/UNICEF/Data and Analytics Nutrition - Analysis Space/github/adhoc_analysis/stunting_top20_briefing/00_documentation/source_library`

GitHub should hold the workflow rules, not the working document collection.

## Pre-Production Content Agreement

Before producing a brief or PowerPoint, prepare a content-agreement note for
this workflow that covers:

1. audience and purpose
2. key questions the output must answer
3. approved datasets in scope
4. approved context documents in scope
5. proposed structure or slide list
6. claims to avoid unless separately approved
7. open questions requiring user confirmation

The briefing should not move straight from rankings to polished output without
this step.

Use the shared template in `00_ai/CONTENT_AGREEMENT_TEMPLATE.md` when starting
that agreement.

For review, use a paired `.review.md` file and the `>>>` comment convention so
comments can be added without overwriting the agreed draft text.

## Current State Assessment

The existing pipeline does these things well:

- pulls quantitative inputs from approved pipeline outputs rather than ad hoc
  spreadsheets
- filters to national totals for a consistent comparison set
- separates prevalence and burden views
- exports chart-ready Excel sheets alongside the PowerPoint

The existing pipeline is still analytically thin in these ways:

- it ranks countries but does not explain concentration, composition, or why the
  same countries do or do not appear across views
- it treats 10-year and 20-year endpoint changes as the main progress measure,
  but does not test whether results are robust to population growth, country
  eligibility, or overlap between prevalence and burden
- it does not report the size of the analytic universe, the eligibility rules,
  or coverage limitations for each comparison
- it generates narrative statements without a formal distinction between
  data-derived findings and document-derived context

## Approved Quantitative Sources

All numeric claims in the briefing must come from one of these source classes
unless the user explicitly approves an exception.

### Approved by default

1. `analysis_datasets` accepted parquet outputs produced in this repository.
2. `DW-Production` outputs already treated as in-scope downstream analytical
   inputs for this workflow.
3. Derived tables computed inside this pipeline directly from those approved
   datasets, with the transformation logic stored in repository code.

### Not approved by default

1. Numbers copied from PDFs, Word files, slide decks, websites, or emails.
2. Numbers quoted from methodological or policy documents.
3. Manually typed country totals or percentages that cannot be traced to a
   pipeline dataset.

### Exception rule

External numeric claims may only be used if the user explicitly approves them.
When that happens:

1. store the source document locally in
  the external Analysis Space source-library folder for this workflow
2. add a row to `source_registry.csv`
3. mark `approved_for_numeric_use = TRUE`
4. record who approved it and any scope limits in `approval_notes`

## Non-Numeric Context Sources

Narrative context, framing, definitions, and interpretive cautions may come
from documents, but only if they are handled as documented sources.

Allowed examples:

- indicator definitions
- methodology notes
- policy framing
- previously cleared talking points
- interpretation of why a pattern matters

These claims must:

1. cite a document in the local source library or an internal repo document
2. be clearly distinguishable from dataset-derived findings
3. avoid introducing uncited factual assertions

## Background Documents Agents Should Read First

These documents are the minimum briefing background set.

### Internal repo documents

- `README.md`
- `00_documentation/REPO_SCOPE_AND_BOUNDARIES.md`
- `00_documentation/ANALYSIS_DATASETS_RUNBOOK.md`
- `00_documentation/COMBINED_NUTRITION_DATABASE_SCHEMA.md`
- `00_documentation/UPSTREAM_SOURCE_DATA_FLAGS.md`
- `adhoc_analysis/stunting_top20_briefing/00_documentation/README.md`
- this document
- the external `source_registry.csv` stored in the Analysis Space source-library folder for this workflow

### Source-governance support docs

- `00_ai/instruction_nutrition-pipeline.md`
- `00_ai/analysis_datasets/BUILD_CONVENTIONS_SKILL.md`
- `00_ai/analysis_datasets/EFFICIENT_PARQUET_SKILL.md` when parquet logic is
  changed

### External contextual documents

Any external document used for interpretation must be copied into the local
source library before it is cited in slides or notes.

For child anthropometry content based on JME indicators, agents should start by
reviewing:

- https://data.unicef.org/topic/nutrition/malnutrition/
- https://data.unicef.org/resources/jme/

See also `JME_SOURCE_DISCOVERY_STARTER.md` in this folder for the current
high-priority source list.

Those pages should be used to identify the latest JME report, standard
methodology, current downloadable tables, and directly relevant anthropometry
guidance before drafting briefing narrative.

The following stored external documents are now explicitly in scope as context
sources for this workflow:

- `DOC-015` - SOFI 2025 FAO Knowledge Repository landing page
- `DOC-016` - SOFI 2025 PDF stored in the external source library
- `DOC-017` - UN SDG Report 2025 landing page
- `DOC-018` - UN Secretary-General SDG Report 2025 English PDF stored in the external source library

Word-based storyline documents saved in the external source-library folder are
also in scope as context sources for this workflow when they are registered in
`source_registry.csv`. These should be treated as editorial and interpretive
inputs unless the user explicitly approves numeric use.

These SOFI sources may be used for contextual framing, interpretation, and
cross-report narrative support, but they remain non-numeric sources unless the
user explicitly approves numeric use and the registry is updated accordingly.

The UN SDG Report sources follow the same rule: they may be used for context,
cross-report framing, and narrative support, but not as approved numeric
sources unless the user explicitly approves numeric use and the registry is
updated accordingly.

## Population Data Rule

For this briefing, narrative statements about global or regional under-five
population change must not be back-calculated from prevalence and burden when a
direct approved population source exists.

Use this approved workbook for regional and global population context:

`C:/Users/jconkle/UNICEF/Chief Statistician Office - Documents/060.DW-MASTER/01_dw_prep/011_rawdata/nt/output/inter/agg_indicator/Regional_Output_NT_ANT_HAZ_NE2_MOD.xlsx`

Use the `basepop_value` variable from that workbook for regional and global
population references in the two-pager narrative. This rule exists to avoid
rounding differences introduced by reverse-calculation from prevalence and
burden values.

If other scripts or systems are consulted for validation, treat them as
secondary checks unless the user explicitly approves them as a primary numeric
source.

## Content Improvement Plan

Future briefing content should be built around analytical questions rather than
around generic chart types.

### Module 1 - What is the current scale of the problem?

Required questions:

- Which countries have the highest latest-year prevalence?
- Which countries have the largest latest-year burden by number affected?
- How much overlap is there between the prevalence and burden top 20 lists?
- How concentrated is the burden across the top countries?

Recommended outputs:

- prevalence top 20
- burden top 20
- overlap table or quadrant view showing high prevalence vs high burden
- concentration summary using shares computed only from approved datasets

### Module 2 - Where is progress strongest or weakest?

Required questions:

- Which countries improved most over 10 years and 20 years in percentage points?
- Which countries improved most in absolute numbers?
- Which countries remain high-burden despite progress because child population
  growth offset prevalence reduction?

Recommended outputs:

- 10-year and 20-year prevalence reduction rankings
- burden reduction rankings
- a change decomposition view where feasible using approved population inputs

### Module 3 - How robust are the comparisons?

Required questions:

- How many countries are eligible for each ranking?
- Are countries excluded because they lack both endpoints?
- What is the latest year actually available in the accepted dataset?
- Are results being driven by endpoint choice alone?

Required methods notes in outputs:

- number of countries included in each ranking universe
- year window definition
- endpoint requirement rule
- confidentiality exclusion rule
- note that accepted parquets may include both preferred and non-preferred rows
  for some downstream uses, and that this briefing must document what was used

### Module 4 - What should leadership take away?

The briefing should stop at evidence-backed synthesis. It should not jump from
rankings to unsupported causal claims.

Preferred framing:

- countries with persistently high prevalence may require intensified attention
- countries with falling prevalence but rising burden may reflect population
  growth pressure
- countries with strong long-run improvement can be used as progress examples
  only if the statement is explicitly limited to the observed stunting trend

Avoid:

- causal explanations not tested in approved data
- programme recommendations presented as facts without cited source documents

## Recommended Slide Architecture

The briefing should evolve from a ranking deck into an evidence-led story.

Suggested structure:

1. What the deck answers and what data are in scope
2. Latest-year prevalence leaders
3. Latest-year burden leaders
4. Overlap between high prevalence and high burden
5. Biggest 10-year prevalence reductions
6. Biggest 20-year prevalence reductions
7. Burden change versus prevalence change
8. Countries with persistent high prevalence despite progress
9. Methods, eligibility, and coverage cautions
10. Implications and contextual notes with citations

Each title should state the finding, not only the topic.

## Minimum Method Metadata To Carry In Results Objects

Future ranking outputs should carry enough metadata for slides and QA to be
auditable. At minimum:

- dataset file names used
- indicator codes used
- latest year used
- baseline years used
- country eligibility counts per ranking
- confidentiality filters applied
- scale conversion notes
- whether number-based metrics came from direct dataset values or derived joins

## Citation Rules For Slides And Notes

Every briefing output should distinguish two source classes.

### Data source

Used for numbers, charts, rankings, and any stated counts or percentages.

Format example:

`Data source: OSE-DA-NT analysis_datasets cmrs2_series_accepted.parquet, indicator ANT_HAZ_NE2_MOD.`

### Context source

Used for methodology or narrative context only.

Format example:

`Context source: DOC-003.`

If a slide uses both, show both explicitly. Do not collapse them into one vague
"Source" label.

## Operating Rules For Future Agent Work

1. Numbers must come only from approved datasets unless the user approves an
   exception.
2. Every contextual claim from a document must have a stored source and a
   registry row.
3. If an agent cannot trace a number to dataset code or an approved document,
   the claim must be removed.
4. If a document is used only for ideas, that still counts as source use and it
   must be stored if it informs slide text.
5. Agents should prefer neutral formulations such as "may indicate" or
   "is consistent with" unless the source evidence directly supports a stronger
   claim.

## Implementation Priority

### Phase 1 - Governance and method transparency

- maintain this document
- maintain the external source library and registry
- add methods metadata to ranking outputs
- add explicit eligibility counts and source footers to slides

### Phase 2 - Analytical depth

- add overlap and concentration analyses
- add burden-versus-prevalence comparisons
- add population-growth-aware interpretation using approved DW inputs where
  needed

### Phase 3 - Reusable briefing framework

- generalize the content rules so other ad hoc nutrition briefings use the same
  numeric-source and citation workflow
