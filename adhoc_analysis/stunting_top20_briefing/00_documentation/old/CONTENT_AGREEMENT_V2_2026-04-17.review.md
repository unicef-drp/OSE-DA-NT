>>> General: Add document-level comments at the top of this file using `>>>`.
>>> General: To comment on a specific line or paragraph, copy that text here and put one or more `>>>` lines directly below it.
>>> General: If you want to propose edits, just change the copied text in this review file. The agent should compare this file against the main draft.

# Review File - Content Agreement V2 - Stunting Top 20 Briefing

Use this file to review:

- `CONTENT_AGREEMENT_V2_2026-04-17.md`

Review syntax:

- document-level comments start with `>>>` at the top of the file
- copied text from the main file can be followed by `>>>` comment lines
- edited text in this file counts as a proposed change

---

Date: 2026-04-17

## Output

- Working title: Child Stunting: Current Levels and Trends Over Two Decades
- Audience: Executive Director and senior leadership of UNICEF
- Decision or use case: rapid leadership briefing on where modeled stunting
  levels remain highest, where progress has been strongest, what regional
  patterns should be highlighted, and what cautions are required before
  interpreting the results
- Requested format: 1-page briefing note, 2-page briefing note, and PowerPoint
  after content agreement

## Document Production Requirements

- Briefing note should be scannable in under a minute, with key messages and
  core objectives on the first page where possible
- Use clear, non-technical language and concise bullets rather than dense prose
- Briefing note should remain within 1-2 pages, with any additional detail
  moved to backup slides, annex material, or source notes

>>> Removed talking points because it is not a brief for a specific meeting

## Questions To Answer

1. Which countries currently have the highest modeled stunting prevalence and
   the highest burden by number of children affected, and what regional patterns
   are visible across those countries?
2. Which countries show the largest 10-year and 20-year reductions, and how do
   those changes compare with burden change and population growth pressure?
3. What eligibility limits, comparability constraints, and JME methodological
   cautions must leadership see before drawing conclusions from the rankings?

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
- relevant documents from `https://www.unicef.org/nutrition` when they are
  directly relevant to child stunting framing, stored externally, and registered
  in the source registry

## Numeric Claims Allowed

- country rankings, values, and changes calculated from approved datasets
- eligibility counts and overlap metrics calculated from approved datasets
- burden concentration measures calculated from approved datasets
- region-related summaries or clustering statements when calculated directly
  from approved datasets
- any population-linked interpretation only when computed from approved DW or
  OSE datasets already in scope

## Numeric Claims Not Yet Approved

- numbers quoted from JME PDFs or UNICEF web pages when those same values are
  not derived in the pipeline datasets
- any external statistics not already represented in approved datasets
- any manually inserted figures from previous slide decks or briefing notes

## Proposed Structure

1. Executive summary: headline findings, intended use, and key cautions
2. Scope and methods: what data are included, what indicator is used, what
   comparisons are valid, and how country eligibility is defined
3. Current scale: latest prevalence leaders, latest burden leaders, overlap,
   concentration, and regional clustering of those countries
4. Progress: 10-year and 20-year reductions in prevalence and burden, plus any
   population-growth-aware interpretation that can be derived from approved data
5. Leadership considerations: broad findings, communications cautions, and
   general programme implications stated in non-operational language
6. Sensitive issues, source notes, and next steps: topics to handle carefully,
   citation rules, and any follow-up outputs or decisions

## Methods And Caveats To Surface

- JME modeled stunting is appropriate for trend analysis; any narrative should
  respect JME methodology and indicator definitions
- The model produces smoothed estimates and should not be treated as a direct
  year-by-year observation series for sudden changes
- Acute shocks or rapid disruptions, including conflict and war, may not be
  captured in real time by the modeled series and should not be over-interpreted
  from rank changes alone
- The deck must distinguish data-derived findings from context-derived
  methodology notes
- Rankings should report how many countries were eligible for each comparison
- Endpoint-based improvement rankings may exclude countries lacking sufficient data
- Any interpretation of burden change should separate prevalence reduction from
  child population growth where the approved data support that distinction
- Programme implications, where included, should remain broad and general rather
  than detailed operational recommendations

## Working Decisions Confirmed For Version 2

- Context sources may include relevant UNICEF nutrition programme website
  documents once they are stored externally and registered
- The briefing should remain country-focused, while noting regional clustering
  or concentration where analytically useful
- Programme implications may be included only in broad general language
  consistent with a Data & Analytics framing

## Agreement Status

- Status: ready for review
- Approved by:
- Date: