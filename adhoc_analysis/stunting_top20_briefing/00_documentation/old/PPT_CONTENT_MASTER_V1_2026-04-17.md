# Stunting Top 20 Briefing - PPT Content Master V1

Date: 2026-04-17

Status: primary document for review

Purpose: slide-level content reference for the PowerPoint. The two-page
narrative brief is the primary review and editing document; the 1-page brief
and PowerPoint are derived from it.

## Sequencing Rule

Document development for this workflow should proceed in this order:

1. Two-page narrative brief (primary review and editing document)
2. One-page brief derived from the settled two-page brief
3. PowerPoint derived from the settled two-page brief

Narrative documents are easier to review and edit than slide-structured
content. Settling the analytical story in prose first avoids drift across
products and ensures the PPT inherits agreed content rather than driving it.

## Guardrails

- All numeric statements below were drawn from approved briefing outputs derived
  from `cmrs2_series_accepted.parquet` through `stunting_modeled.parquet`,
  `stunting_numbers.parquet`, and `stunting_rankings.rds/csv`.
- Contextual and methodological cautions were limited to registered JME and
  anthropometry background sources.
- Where a stronger statement would have required additional computation, the
  text stayed descriptive rather than inferring beyond the current outputs.

## What The Two-Page Brief Must Settle

- the analytical story arc (severity, scale, progress, caveats)
- core claims and approved numbers
- chart or table requirements
- methods cautions and source attributions
- what content flows into the 1-pager and what maps onto PPT slides

## Downstream Product Plan

### One-Page Brief

The one-page brief should be drafted only after the two-page brief is stable.
It should:

- use the same approved numbers and caveats
- compress to headline findings only
- remove supporting detail that is already settled in the two-page brief

### PowerPoint

The PowerPoint should be built only after the two-page brief is stable.
It should:

- map the settled narrative sections onto slides
- use approved numbers, caveats, and chart specifications from the brief
- add speaker notes derived from the brief prose
- not introduce new analytical claims beyond what the brief contains

## Working Headline

Modeled stunting was highly concentrated in a relatively small set of
countries, but the countries with the highest prevalence were not identical to
those carrying the largest burden.

## PowerPoint Content Master

### Slide 1 - Branded Divider

- Slide type: retained template divider slide
- Role in story: branded opening only
- On-slide text: template-managed
- Speaker notes: brief verbal opener only; no substantive analytical text
- Chart/table: none

### Slide 2 - Title

- Slide type: title slide variant from `00_pptx_title_slide.r`
- Role in story: define the topic and audience
- On-slide text:
  Child Stunting: Current Levels and Trends Over Two Decades

  Executive Director briefing
- Speaker notes:
  This deck reviewed where modeled stunting remained highest, where the largest
  numbers of children were affected, and where the strongest reductions had
  been recorded over the last 10 and 20 years.
- Chart/table: none

### Slide 3 - Overview

- Slide type: section slide from `00_pptx_section_slide.r`
- Role in story: orient the audience to the structure of the deck
- On-slide text:
  Overview

  What this briefing showed
  Stunting prevalence: highest rates and fastest reductions
  Stunting burden: number of children affected
  Key findings and programme implications
- Speaker notes:
  The deck was structured to separate prevalence, burden, progress, and methods
  cautions so that scale and severity were not collapsed into one message.
- Chart/table: none

### Slide 4 - What This Briefing Showed

- Slide type: bullet slide from `00_pptx_bullet_slide.r`
- Role in story: establish the core claims early
- On-slide text:
  1. Burundi had the highest modeled stunting prevalence in 2024 at
     55.3 per cent.
  2. India had the largest estimated number of stunted children in 2024 at
     37.4 million.
  3. The strongest observed reductions reached about 1.4 percentage points per
     year in the highest-performing country-year windows.
  4. Large reductions in the number of stunted children were recorded in India,
     China, Indonesia, Pakistan, and Bangladesh over 2014-2024.
- Speaker notes:
  This opening summary should set up the dual message of severity and scale,
  and it should flag early that the observed upper-end pace of reduction was
  substantial in some settings represented in the dataset.
- Chart/table: none

### Slide 5 - Stunting Prevalence Section

- Slide type: section slide from `00_pptx_section_slide.r`
- Role in story: shift into the prevalence part of the deck
- On-slide text:
  Stunting prevalence

  Countries with the highest rates and fastest reductions
- Speaker notes:
  This section focused on prevalence rather than the number of affected
  children.
- Chart/table: none

### Slide 6 - Highest Prevalence Countries

- Slide type: title-only chart slide
- Role in story: show where severity of stunting rates remained highest
- On-slide text:
  Highest modeled stunting prevalence in 2024
- Speaker notes:
  Burundi, Niger, Eritrea, Angola, and Papua New Guinea ranked highest in the
  current modeled prevalence output. This chart should be interpreted as a rate
  comparison, not as a statement about the largest absolute burden.
- Chart/table:
  Horizontal bar chart of the top 15 countries by modeled prevalence in 2024

Proposed figure:

- Chart type: horizontal bar chart
- Visual purpose: show the countries with the highest modeled stunting rates in
  2024
- Sorting: descending by prevalence
- Preview values:

| Country | Prevalence (%) |
|---|---:|
| Burundi | 55.3 |
| Niger | 48.3 |
| Eritrea | 48.0 |
| Angola | 47.7 |
| Papua New Guinea | 47.6 |

### Slide 7 - Strongest 10-Year Prevalence Reductions

- Slide type: title-only chart slide
- Role in story: show shorter-run prevalence progress
- On-slide text:
  Biggest reduction in stunting: 2014-2024
- Speaker notes:
  Libya, Comoros, and Nepal recorded the largest 10-year prevalence reductions.
  The top observed decline over this window was 13.9 percentage points, or
  about 1.4 percentage points per year.
- Chart/table:
  Horizontal bar chart of the top 15 countries by absolute reduction in
  prevalence, 2014-2024

Proposed figure:

- Chart type: horizontal bar chart
- Visual purpose: show the largest absolute 10-year prevalence reductions
- Sorting: descending by absolute percentage-point reduction
- Preview values:

| Country | 2014 (%) | 2024 (%) | Reduction (pp) |
|---|---:|---:|---:|
| Libya | 23.1 | 9.2 | 13.9 |
| Comoros | 28.5 | 17.4 | 11.1 |
| Nepal | 37.0 | 26.0 | 11.0 |
| Bangladesh | 35.6 | 25.1 | 10.5 |
| Tajikistan | 22.9 | 13.1 | 9.8 |

### Slide 8 - 10-Year Before-And-After Comparison

- Slide type: title-only chart slide
- Role in story: show movement from baseline to current values
- On-slide text:
  Stunting prevalence: before and after, 2014 vs 2024
- Speaker notes:
  This figure should show that countries with the strongest reductions still
  started from very different baselines. The slide was intended to show the
  size of movement, not only the ranking order.
- Chart/table:
  Before-and-after dot plot for the top 15 countries in the 10-year reduction
  ranking

Proposed figure:

- Chart type: before-and-after dot plot
- Visual purpose: show baseline and latest values for the strongest 10-year
  improvers
- Sorting: ascending by latest-year prevalence in the plotted set
- Preview values:

| Country | 2014 (%) | 2024 (%) |
|---|---:|---:|
| Libya | 23.1 | 9.2 |
| Tajikistan | 22.9 | 13.1 |
| Comoros | 28.5 | 17.4 |
| Bangladesh | 35.6 | 25.1 |
| Nepal | 37.0 | 26.0 |

### Slide 9 - Strongest 20-Year Prevalence Reductions

- Slide type: title-only chart slide
- Role in story: show long-run prevalence progress
- On-slide text:
  Biggest reduction in stunting: 2004-2024
- Speaker notes:
  North Korea, Nepal, and Tajikistan recorded the largest 20-year prevalence
  reductions. The strongest 20-year decline was 27.6 percentage points, again
  roughly 1.4 percentage points per year on average.
- Chart/table:
  Horizontal bar chart of the top 15 countries by absolute reduction in
  prevalence, 2004-2024

Proposed figure:

- Chart type: horizontal bar chart
- Visual purpose: show the largest absolute 20-year prevalence reductions
- Sorting: descending by absolute percentage-point reduction
- Preview values:

| Country | 2004 (%) | 2024 (%) | Reduction (pp) |
|---|---:|---:|---:|
| North Korea | 44.2 | 16.6 | 27.6 |
| Nepal | 51.4 | 26.0 | 25.3 |
| Tajikistan | 38.0 | 13.1 | 24.9 |
| Bangladesh | 50.0 | 25.1 | 24.9 |
| Comoros | 42.0 | 17.4 | 24.6 |

### Slide 10 - Stunting Burden Section

- Slide type: section slide from `00_pptx_section_slide.r`
- Role in story: shift from severity to scale
- On-slide text:
  Stunting burden: number of children affected

  Countries with the highest absolute numbers and largest reductions
- Speaker notes:
  This section shifted from rate to scale and should make clear that the burden
  ranking answered a different question from the prevalence ranking.
- Chart/table: none

### Slide 11 - Highest Burden Countries

- Slide type: title-only chart slide
- Role in story: show where the largest numbers of children were affected
- On-slide text:
  Highest number of stunted children in 2024
- Speaker notes:
  India, Nigeria, Pakistan, the Democratic Republic of the Congo, and Ethiopia
  accounted for 75.2 million of the 149.2 million children represented in the
  full 2024 comparison universe. That was just over half of the total burden in
  the current output.
- Chart/table:
  Horizontal bar chart of the top 15 countries by number of stunted children in
  2024

Proposed figure:

- Chart type: horizontal bar chart
- Visual purpose: show where the largest absolute numbers of stunted children
  were located in 2024
- Sorting: descending by number of stunted children
- Preview values:

| Country | Stunted children (millions) |
|---|---:|
| India | 37.4 |
| Nigeria | 11.4 |
| Pakistan | 10.7 |
| Congo - Kinshasa | 8.7 |
| Ethiopia | 6.9 |

### Slide 12 - Strongest 10-Year Burden Reductions

- Slide type: title-only chart slide
- Role in story: show shorter-run burden progress
- On-slide text:
  Biggest reduction in stunted numbers: 2014-2024
- Speaker notes:
  India, China, Indonesia, Pakistan, and Bangladesh recorded the largest
  10-year reductions in the number of stunted children. India alone recorded a
  decline of 12.6 million over this window.
- Chart/table:
  Horizontal bar chart of the top 15 countries by reduction in the number of
  stunted children, 2014-2024

Proposed figure:

- Chart type: horizontal bar chart
- Visual purpose: show the largest absolute 10-year reductions in the number of
  stunted children
- Sorting: descending by absolute reduction in millions
- Preview values:

| Country | 2014 (millions) | 2024 (millions) | Reduction (millions) |
|---|---:|---:|---:|
| India | 50.0 | 37.4 | 12.6 |
| China | 6.0 | 2.4 | 3.6 |
| Indonesia | 7.9 | 5.0 | 2.9 |
| Pakistan | 13.1 | 10.7 | 2.4 |
| Bangladesh | 5.5 | 4.2 | 1.3 |

### Slide 13 - Strongest 20-Year Burden Reductions

- Slide type: title-only chart slide
- Role in story: show long-run burden progress
- On-slide text:
  Biggest reduction in stunted numbers: 2004-2024
- Speaker notes:
  India, China, Bangladesh, Indonesia, and the Philippines recorded the largest
  20-year reductions in the number of stunted children. This slide should show
  that large burden declines were possible over long periods, while also making
  clear that some countries still remained among the highest-burden settings.
- Chart/table:
  Horizontal bar chart of the top 15 countries by reduction in the number of
  stunted children, 2004-2024

Proposed figure:

- Chart type: horizontal bar chart
- Visual purpose: show the largest absolute 20-year reductions in the number of
  stunted children
- Sorting: descending by absolute reduction in millions
- Preview values:

| Country | 2004 (millions) | 2024 (millions) | Reduction (millions) |
|---|---:|---:|---:|
| India | 64.9 | 37.4 | 27.5 |
| China | 11.8 | 2.4 | 9.5 |
| Bangladesh | 9.2 | 4.2 | 5.0 |
| Indonesia | 8.9 | 5.0 | 3.9 |
| Philippines | 3.9 | 2.5 | 1.3 |

### Slide 14 - Key Findings And Programme Implications

- Slide type: bullet slide from `00_pptx_bullet_slide.r`
- Role in story: synthesize the evidence and set the boundaries of the message
- On-slide text:
  1. Severity and scale did not point to exactly the same country set.
  2. Eleven countries appeared on both the prevalence and burden top-20 lists.
  3. The strongest observed prevalence reductions reached about 1.4 percentage
     points per year.
  4. Large burden reductions were possible, but some countries still remained
     among the highest-burden settings in 2024.
- Speaker notes:
  Child stunting had to be viewed through both severity and scale. Equity-
  focused approaches were needed to address the highest-prevalence settings,
  but high-burden countries also mattered when the objective was impact at
  scale. These implications should stay broad and should not be presented as a
  causal claim.
- Chart/table:
  Optional companion table in notes or annex listing the 11 overlap countries

Optional companion table preview:

| Overlap countries |
|---|
| Niger |
| Angola |
| Yemen |
| Congo - Kinshasa |
| Afghanistan |
| Madagascar |
| Mozambique |
| Ethiopia |
| Sudan |
| Nigeria |
| Pakistan |

### Slide 15 - Thank You

- Slide type: retained template closing slide
- Role in story: close the presentation
- On-slide text: template-managed
- Speaker notes: none
- Chart/table: none

## Open Questions To Resolve In PPT Review

- Should the deck add a dedicated overlap slide or keep overlap only in the key
  findings slide and notes?
- Should the burden section add a concentration callout beyond the current top
  five share statement?
- Should a methods slide be inserted before the closing findings slide, or are
  the speaker notes sufficient for the current briefing purpose?
- Which country naming convention should be used in final external-facing text
  for cases such as North Korea and the Democratic Republic of the Congo?

## What Gets Deferred Until After PPT Approval

- drafting the two-page brief in prose
- drafting the one-page brief in compressed executive form
- final compression decisions about which caveats remain visible in shorter
  products and which move to notes or annexes

## Source Notes

Data source: OSE-DA-NT stunting briefing outputs derived from
`cmrs2_series_accepted.parquet` through `2_prepare_inputs.r` and
`3_stunting_rankings.r`; files used here included `stunting_modeled.parquet`,
`stunting_numbers.parquet`, and `stunting_rankings.rds/csv`.

Context source: DOC-008, DOC-012, DOC-009, DOC-013, DOC-010, DOC-014.
