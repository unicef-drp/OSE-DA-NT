# Session Learnings - 2026-04-17

This note captures the main workflow and content lessons established during the
stunting briefing session so they can be reused in later rounds.

## Document Workflow Learnings

- Markdown review works best with three files per reconciled round:
  - one clean accepted draft
  - one tracked version showing visible changes
  - one clean review copy for the next round
- Review files should preserve the full substantive document text.
- `>>>` comments should stay sparse and only appear where the user has a real
  comment to make.
- Direct edits in the review file should be interpreted as proposed
  replacements even if there is no explicit marker such as `PROPOSED:`.
- For tracked markdown, simple `<mark>` and `~~...~~` styling was not visually
  strong enough. A more Word-like pattern using green additions and red
  strikethrough deletions in HTML-rendered markdown is better.

## Source And Storage Learnings

- GitHub should not be used as storage for the briefing source library or other
  working support files.
- External contextual documents should be stored in the mirrored Analysis Space
  `github` folder and registered in `source_registry.csv` before being cited.
- Numeric claims should come only from approved datasets or code-derived
  outputs unless the user explicitly approves an exception.

## Content Development Learnings

- A content-agreement step is necessary before drafting a brief or PowerPoint.
- The content agreement and briefing content must account for the physical
  space available in the target output format from the very beginning. A
  two-page brief has roughly one page of usable text space once figures,
  headers, callouts, and margins are accounted for. Content plans that produce
  more narrative than can fit lead to painful cutting later and risk losing
  important material. Future content agreements should state the target format
  and approximate word/paragraph budget alongside the substantive outline.
- For multi-product outputs, the most comprehensive product should be settled
  first and should act as the source narrative for shorter derivative products.
- For this workflow, the preferred sequence was revised to: two-page narrative
  brief first, then 1-page brief, then PowerPoint. The earlier PPT-first
  approach was reversed because narrative documents are easier to review and
  edit than slide content.
- The briefing content needed to distinguish prevalence from burden rather than
  treating them as interchangeable views.
- The current outputs supported stronger narrative only after adding overlap,
  concentration, burden-reduction, and eligibility context.
- Where a broader-sounding number is used, the text should state exactly what
  universe it comes from. For example, the 149.2 million figure in the current
  draft is the total from the 162-country comparison universe in the approved
  output, not an independently approved external global total.
- PowerPoint content planning should align with the slide architecture already
  implemented in the pipeline code, including divider slides, section slides,
  bullet slides, chart slides, and speaker notes.

## Outstanding Analytical Gaps

- Region-based clustering still needs an approved tabulation if it will be used
  explicitly in the final brief.
- Burden-versus-population decomposition still needs additional approved
  computation before stronger claims on population growth pressure are made.
- Final external-facing country naming conventions still need confirmation for
  cases such as North Korea and the Democratic Republic of the Congo.
