# Content Agreement V2 - Stunting Top 20 Briefing

Legend:

- `<mark>...</mark>` = added or revised text in version 2
- `~~...~~` = removed text from the prior draft

Date: 2026-04-17

## Output

- Working title: ~~Stunting top 20 briefing~~ <mark>Child Stunting: Current Levels and Trends Over Two Decades</mark>
- Audience: ~~Executive Director and senior leadership~~ <mark>Executive Director and senior leadership of UNICEF</mark>
- Decision or use case: rapid leadership briefing on where modeled stunting
  levels remain highest, where progress has been strongest, <mark>what regional
  patterns should be highlighted, and</mark> what cautions are required before
  interpreting the results
- Requested format: ~~briefing note and PowerPoint~~ <mark>1-page briefing note, 2-page briefing note, and PowerPoint</mark> after content agreement

<mark>## Document Production Requirements</mark>

- <mark>Briefing note should be scannable in under a minute, with key messages and core objectives on the first page where possible</mark>
- <mark>Use clear, non-technical language and concise bullets rather than dense prose</mark>
- <mark>Briefing note should remain within 1-2 pages, with any additional detail moved to backup slides, annex material, or source notes</mark>
- ~~Talking points should stay specific and actionable; sensitive issues or topics to avoid should be surfaced explicitly when relevant~~

## Questions To Answer

1. Which countries currently have the highest modeled stunting prevalence and
   the highest burden by number of children affected<mark>, and what regional patterns
   are visible across those countries</mark>?
2. Which countries show the largest 10-year and 20-year reductions, and how do
   those changes compare with burden change and population growth pressure?
3. What ~~are the key limitations, eligibility rules, and JME methodological
   cautions that leadership should see before drawing conclusions~~ <mark>eligibility limits, comparability constraints, and JME methodological cautions
   must leadership see before drawing conclusions from the rankings</mark>?

## Approved Data Sources

- `analysis_datasets/cmrs2_series_accepted.parquet` for modeled stunting
  prevalence series
- `analysis_datasets` stunting number indicator values available through the
  accepted series parquet when present
- in-scope `DW-Production` outputs already used by this workflow where needed
  for population or aggregation context
- code-derived tables calculated directly from the approved datasets above

## Approved Context Sources

- DOC-006 and DOC-011: JME Levels and Trends 2025 page and stored PDF
- DOC-008 and DOC-012: JME standard methodology page and stored PDF
- DOC-009 and DOC-013: anthropometric indicators guidance page and stored PDF
- DOC-010 and DOC-014: anthropometry data quality research priorities page and
  stored PDF
- internal repo documentation already listed in
  `CONTENT_PLAN_AND_SOURCE_GOVERNANCE.md`
- <mark>relevant documents from `https://www.unicef.org/nutrition` when they are directly relevant to child stunting framing, stored externally, and registered in the source registry</mark>

## Numeric Claims Allowed

- country rankings, values, and changes calculated from approved datasets
- eligibility counts and overlap metrics calculated from approved datasets
- burden concentration measures calculated from approved datasets
- <mark>region-related summaries or clustering statements when calculated directly from approved datasets</mark>
- any population-linked interpretation only when computed from approved DW or
  OSE datasets already in scope

## Numeric Claims Not Yet Approved

- numbers quoted from JME PDFs or UNICEF web pages when those same values are
  not derived in the pipeline datasets
- any external statistics not already represented in approved datasets
- any manually inserted figures from previous slide decks or briefing notes

## Proposed Structure

1. ~~Scope and methods: what data are included, what indicator is used, and what
   comparisons are valid~~ <mark>Executive summary: headline findings, intended use, and key cautions</mark>
2. ~~Current scale: latest prevalence leaders, latest burden leaders, overlap, and
   concentration~~ <mark>Scope and methods: what data are included, what indicator is used, what comparisons are valid, and how country eligibility is defined</mark>
3. ~~Progress: 10-year and 20-year reductions in prevalence and burden, plus any
   population-growth-aware interpretation that can be derived from approved data~~ <mark>Current scale: latest prevalence leaders, latest burden leaders, overlap, concentration, and regional clustering of those countries</mark>
4. ~~Cautions and implications: eligibility limits, data coverage, JME method
   cautions, and tightly bounded leadership takeaways~~ <mark>Progress: 10-year and 20-year reductions in prevalence and burden, plus any population-growth-aware interpretation that can be derived from approved data</mark>
5. <mark>Leadership considerations: broad findings, communications cautions, and general programme implications stated in non-operational language</mark>
6. <mark>Sensitive issues, source notes, and next steps: topics to handle carefully, citation rules, and any follow-up outputs or decisions</mark>

## Methods And Caveats To Surface

- JME modeled stunting is appropriate for trend analysis; any narrative should
  respect JME methodology and indicator definitions
- <mark>The model produces smoothed estimates and should not be treated as a direct year-by-year observation series for sudden changes</mark>
- <mark>Acute shocks or rapid disruptions, including conflict and war, may not be captured in real time by the modeled series and should not be over-interpreted from rank changes alone</mark>
- ~~the~~ <mark>The</mark> deck must distinguish data-derived findings from context-derived
  methodology notes
- ~~rankings~~ <mark>Rankings</mark> should report how many countries were eligible for each comparison
- ~~endpoint-based~~ <mark>Endpoint-based</mark> improvement rankings may exclude countries lacking ~~both years~~ <mark>sufficient data</mark>
- ~~any~~ <mark>Any</mark> interpretation of burden change should separate prevalence reduction from
  child population growth where the approved data support that distinction
- <mark>Programme implications, where included, should remain broad and general rather than detailed operational recommendations</mark>

~~## Open Questions For User Confirmation~~

<mark>## Working Decisions Confirmed For Version 2</mark>

- ~~Should this first content-agreement version limit context sources to JME and anthropometry methodology documents only, or should broader UNICEF nutrition guidance also be considered in scope?~~ <mark>Context sources may include relevant UNICEF nutrition programme website documents once they are stored externally and registered</mark>
- ~~Do you want the first briefing to stay fully country-focused, or should it add a short regional concentration view if it is derived from approved datasets?~~ <mark>The briefing should remain country-focused, while noting regional clustering or concentration where analytically useful</mark>
- ~~Should programme implications remain descriptive only in this version, unless separately approved with additional source documents?~~ <mark>Programme implications may be included only in broad general language consistent with a Data & Analytics framing</mark>

## Agreement Status

- Status: ~~ready for review~~ <mark>finalized for zero draft drafting</mark>
- Approved by:
- Date:
