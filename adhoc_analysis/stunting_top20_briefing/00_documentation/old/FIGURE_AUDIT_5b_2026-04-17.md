# Figure Audit — 5b_create_two_pager_styled.r

Date: 2026-04-17

## Purpose

Check (1) no figures are repeated in the styled two-pager, and (2) figure
titles match the data they display. Cross-reference against the V4 content
document's proposed figure list.

## V4 Proposed Figures And Tables

| V4 ID    | Description                                        |
|----------|----------------------------------------------------|
| Figure 1 | Horizontal bar chart of highest stunting prevalence |
| Figure 2 | Horizontal bar chart of highest burden countries    |
| Table 1  | Countries appearing on both top-20 lists            |
| Figure 3 | 10-year prevalence reduction chart                  |
| Figure 4 | 20-year prevalence reduction chart                  |
| Figure 5 | 10-year reduction in number of stunted children     |
| Figure 6 | 20-year reduction in number of stunted children     |

## Figures Actually in 5b Styled Brief

| Brief position | Object | Title in script                                                        | Data source                          |
|----------------|--------|------------------------------------------------------------------------|--------------------------------------|
| Page 1         | p1     | "Figure 1. Highest stunting prevalence (Top 10, {latest_year})"        | `results$highest` — prevalence col   |
| Page 2         | p2     | "Figure 2. Largest 10-year reduction in stunted numbers (Top 10, …)"   | `results$improve_10yr_number` — burden change |

## Check 1 — Repetition

- p1 is inserted once (Page 1, after "What the 2024 data showed").
- p2 is inserted once (Page 2, after "Where progress was strongest").
- **No figures are repeated. PASS.**

## Check 2 — Title-to-Data Alignment

| Figure | Title says                                   | Data actually shows                  | Match? |
|--------|----------------------------------------------|--------------------------------------|--------|
| p1     | Highest stunting prevalence (Top 10)         | `results$highest` ranked by prevalence | YES    |
| p2     | Largest 10-year reduction in stunted numbers | `results$improve_10yr_number` (burden change) | YES    |

- **Both figure titles accurately describe the data they display. PASS.**

## Check 3 — Numbering Consistency with V4 Content

| Brief figure | Brief title calls it | V4 content equivalent | V4 number | MISMATCH? |
|--------------|----------------------|-----------------------|-----------|-----------|
| p1           | Figure 1             | Highest prevalence    | Figure 1  | No        |
| p2           | Figure 2             | 10-year burden reduction | Figure 5 | **YES**   |

**ISSUE:** The brief labels the burden-reduction chart "Figure 2", but V4's
proposed figure list assigns that content to Figure 5. V4's "Figure 2" is
supposed to be a highest-burden-countries chart, which is **not in the brief**.

## Items Omitted from the Brief (Space Constraints)

The following V4 proposed figures/tables are not in the styled two-pager:

| V4 ID    | Description                              | Status in brief                        |
|----------|------------------------------------------|----------------------------------------|
| Figure 2 | Highest burden countries bar chart        | Omitted (burden discussed in text only)|
| Table 1  | Overlap countries table                   | Rendered as inline text, not a table   |
| Figure 3 | 10-year prevalence reduction chart        | Omitted                                |
| Figure 4 | 20-year prevalence reduction chart        | Omitted                                |
| Figure 6 | 20-year reduction in number of children   | Omitted                                |

## Recommended Actions

1. **Renumber the brief figures** to be self-consistent (Figure 1 and Figure 2
   within the brief are fine as a standalone numbering sequence), but update the
   V4 content document's proposed figure list to reflect what actually fits in
   the two-pager versus what is available for longer products.
2. **Decide whether V4's Figure 2 (highest burden bar chart) should replace the
   current Figure 2 (burden reduction).** The text on Page 1 discusses burden
   levels in detail but has no accompanying chart, while Page 2 discusses
   burden reduction and has a chart. Swapping or adding a burden-level chart to
   Page 1 would better match the narrative flow, but would require either
   smaller figures or less text.
3. **Update the V4 proposed figure list** to distinguish between "full figure
   set available from the data" and "figures selected for the two-pager."
