# Markdown Review And Tracked Changes Skill

Last updated: 2026-04-17

## Purpose

Guide AI agents through iterative document review in markdown when a user wants
to:

1. comment directly on a working draft
2. propose edits by rewriting text in place
3. see a visible tracked-change version before accepting the next round

This skill is designed for briefs, content agreements, analytical notes, and
other markdown-first drafting workflows in this repository.

## Trigger

Apply this skill when:

- the user wants to review or comment on a markdown draft
- the user prefers direct text edits instead of comment-only review
- the user wants a tracked version of changes between rounds
- the user wants a clean next-round review file after reconciliation

## Core File Pattern

Use three files for each reconciled round.

### Current accepted draft

- `name.md`

This is the clean accepted version for the current round.

### Review copy

- `name.review.md`

This is the user-editable review file.

### Tracked copy

- `name.tracked.md`

This is the visual diff file showing how the new clean version differs from the
previous accepted version.

## Review Convention

In the `.review.md` file:

- `>>>` at the top of the file means a document-level comment
- `>>>` immediately below copied text means the comment applies to the text
  above
- changed text in the review file indicates a proposed replacement even if no
  explicit marker is added

Do not add placeholder comment lines under every paragraph. Keep the review copy
sparse and preserve the real document text.

## Reconciliation Workflow

When a review round is complete:

1. compare the accepted draft and the review file
2. interpret direct text edits as proposed replacements
3. interpret `>>>` lines as comments on the text above or on the whole document
4. produce a new clean accepted draft
5. produce a tracked file showing the changes from the prior accepted draft
6. produce a fresh clean review file for the next round

## Tracked File Rendering Pattern

For markdown tracked files, prefer HTML styling that renders clearly in
Markdown Preview.

Use:

- additions: `<ins style="color:#166534; background-color:#dcfce7; text-decoration:none; font-weight:600;">...</ins>`
- deletions: `<del style="color:#b91c1c; background-color:#fee2e2; text-decoration:line-through;">...</del>`

Recommended legend:

- added or revised text in green
- deleted text in red with strikethrough
- replacements shown as deleted text followed immediately by added text
- new sections shown entirely as additions

Include a short note telling the user to open the file in Markdown Preview for
the clearest rendering.

## Naming Pattern For Later Rounds

When version labels are being used, prefer:

- `NAME_V2_date.md`
- `NAME_V2_date.tracked.md`
- `NAME_V2_date.review.md`

Then repeat the same pattern for later rounds.

## Definition Of Done

This skill is satisfied only when:

1. the review file preserves the full substantive content of the current draft
2. the user can add sparse `>>>` comments without template clutter
3. the reconciled round includes a clean draft, tracked draft, and clean next
   review file
4. the tracked file uses a visually clear add/delete scheme in Markdown Preview
