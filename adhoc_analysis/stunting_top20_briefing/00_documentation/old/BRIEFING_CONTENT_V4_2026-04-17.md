# Stunting Top 20 Briefing - Two-Page Brief V4

Date: 2026-04-17

Status: v4 drafted from completed v3 review

Purpose: this two-page narrative brief is the master content document.
The 1-page brief and PowerPoint are derived from it once the content,
numbers, and caveats are settled here.

## Guardrails

- All numeric statements below were drawn from approved briefing outputs derived
  from `cmrs2_series_accepted.parquet` through `stunting_modeled.parquet`,
  `stunting_numbers.parquet`, and `stunting_rankings.rds/csv`.
- Contextual and methodological cautions were limited to registered Joint Child
  Malnutrition Estimates (JME) and anthropometry background sources.
- Where a stronger statement would have required additional computation, the
  text stayed descriptive rather than inferring beyond the current outputs.

## Working Headline

Child Stunting: Level and Trends Over Two Decades

## Proposed Figures And Tables

- Figure 1: horizontal bar chart of highest stunting prevalence countries
- Figure 2: horizontal bar chart of highest burden countries
- Table 1: countries appearing on both top-20 lists
- Figure 3: 10-year prevalence reduction chart
- Figure 4: 20-year prevalence reduction chart
- Figure 5: 10-year reduction in number of stunted children
- Figure 6: 20-year reduction in number of stunted children

## Section 0 - Executive Summary

The 2024 Joint Child Malnutrition Estimates showed that child stunting remained
severe in several countries and highly concentrated in a relatively small set
of high-burden countries. Countries with the highest prevalence were not
identical to those with the highest number of stunted children, so severity and
scale should be interpreted together.

Progress over both the 10-year and 20-year windows showed that substantial
reductions in prevalence and in the number of stunted children were possible.
At the same time, several countries remained among the highest-burden settings
in 2024 despite major declines.

Using the global estimate of 150.2 million stunted children in 2024 as the
denominator, the top five burden countries in this briefing accounted for
75.2 million children, or about half of the global total.

## Section 1 - What The 2024 Data Showed

This briefing used modeled national stunting estimates for children under 5.
The latest year available was 2024.

On prevalence, the highest-ranked countries were Burundi (55.3 per cent),
Niger (48.3 per cent), Eritrea (48.0 per cent), Angola (47.7 per cent), and
Papua New Guinea (47.6 per cent). Four of these five countries were in
sub-Saharan Africa, with one in the Pacific.

On burden, or the number of children affected by stunting, the picture shifted
toward larger-population countries. India had the largest estimated number of
stunted children (37.4 million), followed by Nigeria (11.4 million), Pakistan
(10.7 million), the Democratic Republic of the Congo (8.7 million), and
Ethiopia (6.9 million). This top-burden group was concentrated in South Asia
and sub-Saharan Africa.

The overlap between these two views was substantial but not complete. Eleven
countries appeared in both top-20 lists: Niger, Angola, Yemen, the Democratic
Republic of the Congo, Afghanistan, Madagascar, Mozambique, Ethiopia, Sudan,
Nigeria, and Pakistan. Most of these overlap countries were in sub-Saharan
Africa, with additional countries in South or West Asia.

Targeting these overlap countries can enable an equity-focused approach while
also targeting settings where absolute impact can be largest.

The burden was also concentrated. Of the 150.2 million children affected by
stunting globally in 2024, the top five burden countries represented about
50.1 per cent. The top 20 burden countries represented approximately
76.8 per cent of the global total.

## Section 2 - Where Progress Was Strongest

The strongest 10-year prevalence reductions (2014-2024) were in Libya
(13.9 percentage points), Comoros (11.1 percentage points), and Nepal
(11.0 percentage points).

The strongest 20-year prevalence reductions (2004-2024) were in North Korea
(27.6 percentage points), Nepal (25.3 percentage points), and Tajikistan
(24.9 percentage points).

At the upper end of the observed distribution, these results were equivalent to
an average annual reduction pace of about 1.4 percentage points per year.
Because this metric is in percentage points, the relative per-year percent
reduction depends on each country's starting prevalence. For example, a decline
of 14 percentage points over a decade corresponds to a 28 per cent relative
reduction from a 50 per cent baseline, but a 47 per cent relative reduction
from a 30 per cent baseline.

Progress in burden was also substantial. Over 2014-2024, the largest reductions
in the estimated number of stunted children were in India (12.6 million),
China (3.6 million), Indonesia (2.9 million), Pakistan (2.4 million), and
Bangladesh (1.3 million).

Over 2004-2024, the largest burden reductions were in India (27.5 million),
China (9.5 million), Bangladesh (5.0 million), Indonesia (3.9 million), and the
Philippines (1.3 million).

These top burden reductions were concentrated in South and East Asia. By
contrast, many sub-Saharan African countries remained prominent in the highest-
burden 2024 rankings, indicating that prevalence improvements were often offset
by child population growth or slower declines in prevalence.

India recorded the largest burden reduction in both windows, yet remained the
largest-burden country in 2024. This indicates that very large gains were
possible while absolute burden could still remain high in populous settings.

## Section 3 - Data Considerations

Modeled stunting data are suitable for trend interpretation, but should not be
read as a direct year-by-year record of change. Rapid shocks, including
conflict and war, may not be reflected immediately in the modeled series
because data were often unavailable from those contexts.

The ranking universes in the prepared inputs included 162 countries for the
latest-year, 10-year, and 20-year comparisons used here. The current output was
well suited to describing relative ranking, overlap, concentration, and
measured change over the selected windows. It did not yet support stronger
claims about the causes of progress, the role of conflict in specific country
movements, or the extent to which child population growth offset prevalence
reductions unless those relationships were computed explicitly.

## Section 4 - Key Messages

- Severity and scale should be interpreted together: the highest-prevalence and
  highest-burden country lists overlap, but they are not identical.
- Burden remained concentrated: the top five burden countries represented about
  half of the 2024 global estimate of stunted children, and the top 20
  represented about three quarters.
- The observed upper-end pace of prevalence reduction was about
  1.4 percentage points per year, and large burden reductions were possible at
  scale.
- Regional patterns differed: highest burden and largest burden reductions were
  concentrated in South and East Asia, while many sub-Saharan African countries
  remained prominent in the highest-burden rankings.

## Section 5 - Closing

Child stunting should be assessed through both prevalence and absolute burden.
Prevalence rankings identify where modeled rates remained most severe, while
burden rankings identify where the largest numbers of children were affected.

For policy and programming, this means balancing equity-focused action in the
highest-prevalence settings with scale-oriented action in the highest-burden
settings. The current results also show that substantial long-run progress was
possible, including in countries with very large affected populations.

## Items To Tighten Before Final Production

- Add a short region-by-region tabulation alongside each top-20 list to make
  clustering patterns explicit in the final brief tables.
- Add a burden-versus-population decomposition if the final brief needs a
  stronger statement on population growth pressure.
- Confirm country naming conventions directly from the parquet source fields for
  final external-facing text.

## Source Notes

Data source: OSE-DA-NT stunting briefing outputs derived from
`cmrs2_series_accepted.parquet` through `2_prepare_inputs.r` and
`3_stunting_rankings.r`; files used here included `stunting_modeled.parquet`,
`stunting_numbers.parquet`, and `stunting_rankings.rds/csv`.

Context source: DOC-008, DOC-012, DOC-009, DOC-013, DOC-010, DOC-014.
