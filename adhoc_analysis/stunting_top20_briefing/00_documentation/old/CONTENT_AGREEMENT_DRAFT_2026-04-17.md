# Content Agreement Draft - Stunting Top 20 Briefing

Date: 2026-04-17

## Output

- Working title: Stunting top 20 briefing
- Audience: Executive Director and senior leadership
- Decision or use case: rapid leadership briefing on where modeled stunting
  levels remain highest, where progress has been strongest, and what caveats are
  required before interpreting the results
- Requested format: briefing note and PowerPoint after content agreement

## Questions To Answer

1. Which countries currently have the highest modeled stunting prevalence and
   the highest burden by number of children affected?
2. Which countries show the largest 10-year and 20-year reductions, and how do
   those changes compare with burden change and population growth pressure?
3. What are the key limitations, eligibility rules, and JME methodological
   cautions that leadership should see before drawing conclusions?

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

## Numeric Claims Allowed

- country rankings, values, and changes calculated from approved datasets
- eligibility counts and overlap metrics calculated from approved datasets
- burden concentration measures calculated from approved datasets
- any population-linked interpretation only when computed from approved DW or
  OSE datasets already in scope

## Numeric Claims Not Yet Approved

- numbers quoted from JME PDFs or UNICEF web pages when those same values are
  not derived in the pipeline datasets
- any external statistics not already represented in approved datasets
- any manually inserted figures from previous slide decks or briefing notes

## Proposed Structure

1. Scope and methods: what data are included, what indicator is used, and what
   comparisons are valid
2. Current scale: latest prevalence leaders, latest burden leaders, overlap, and
   concentration
3. Progress: 10-year and 20-year reductions in prevalence and burden, plus any
   population-growth-aware interpretation that can be derived from approved data
4. Cautions and implications: eligibility limits, data coverage, JME method
   cautions, and tightly bounded leadership takeaways

## Methods And Caveats To Surface

- JME modeled stunting is appropriate for trend analysis; any narrative should
  respect JME methodology and indicator definitions
- the deck must distinguish data-derived findings from context-derived
  methodology notes
- rankings should report how many countries were eligible for each comparison
- endpoint-based improvement rankings may exclude countries lacking both years
- any interpretation of burden change should separate prevalence reduction from
  child population growth where the approved data support that distinction

## Open Questions For User Confirmation

- Should this first content-agreement version limit context sources to JME and
  anthropometry methodology documents only, or should broader UNICEF nutrition
  guidance also be considered in scope?
- Do you want the first briefing to stay fully country-focused, or should it add
  a short regional concentration view if it is derived from approved datasets?
- Should programme implications remain descriptive only in this version, unless
  separately approved with additional source documents?

## Agreement Status

- Status: ready for review
- Approved by:
- Date: