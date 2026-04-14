# Presentation Design Instructions for AI Agent

Use this file as the presentation design policy for any agent that creates PowerPoint slides. These rules are mandatory unless the user explicitly overrides them.

## Goal

Create slides that are:
- clear
- visually balanced
- easy to understand in 5 to 10 seconds
- professional rather than decorative
- concise rather than text-heavy

The deck should feel intentional, consistent, and easy to present live.

---

## Core Principle

Each slide should communicate one main idea.

A good slide is not a document page. It is a visual communication unit. Do not try to fit everything onto one slide.

---

## Slide Types Allowed

Use one of these standard slide patterns:

1. **Title slide**
   - presentation title
   - subtitle only if useful
   - clean visual or plain background

2. **Section divider**
   - large section title
   - optional one-line context
   - minimal content

3. **Key message slide**
   - takeaway title
   - 2 to 4 short supporting bullets
   - optional visual

4. **Two-column comparison**
   - left and right comparison
   - short labels
   - balanced text length

5. **Process slide**
   - 3 to 5 steps
   - short step labels
   - simple sequence or timeline

6. **Data highlight slide**
   - one key number or chart
   - short interpretation
   - minimal supporting text

Do not mix too many structures on the same slide.

---

## Titles

Slide titles must communicate the takeaway, not just the topic.

### Good title examples
- Market demand is growing بسرعة
- AI reduces reporting time by 40%
- Three changes can improve delivery speed

### Bad title examples
- Market Analysis
- AI
- Results
- Discussion

### Title rules
- keep titles to one line whenever possible
- prefer statement titles over topic labels
- use sentence case unless the deck style requires otherwise
- avoid vague titles

---

## Font Rules

### Recommended sizes
- Title: **36 to 44 pt**
- Section divider: **40 to 52 pt**
- Body text: **20 to 28 pt**
- Labels / captions: **18 to 20 pt**
- Absolute minimum: **18 pt**

### Font guidance
- use one sans-serif font family throughout the deck when possible
- use weight for emphasis before using color
- do not use more than 2 font sizes for body content on the same slide
- avoid excessive bolding
- avoid italics except for rare emphasis
- do not use underlining unless it is a hyperlink

If content does not fit at readable size, reduce content instead of shrinking the font.

---

## Body Text Rules

- maximum **5 bullets per slide**
- maximum **8 words per bullet** in most cases
- prefer phrases, not full sentences
- avoid paragraphs
- avoid dense speaker-note style writing on slides
- each bullet should express one distinct point
- use parallel structure across bullets

### Good bullets
- Faster onboarding
- Lower operating costs
- Better data visibility
- Fewer manual errors

### Bad bullets
- The company can improve performance by implementing a number of changes across departments.
- We think this strategy will probably lead to better long-term outcomes in several areas.

---

## Layout Rules

### White space
Aim for approximately:
- **60% white space**
- **40% content**

Do not fill every part of the slide.

### Alignment
- prefer left alignment for most text
- center only when the slide is intentionally minimal
- keep text boxes aligned to a common grid
- keep margins generous and consistent

### Content density
- one idea per slide
- one visual focal point per slide
- no clutter
- no tiny elements scattered across the page

---

## Visual Hierarchy

Every slide should have this hierarchy:

1. **Title** — the takeaway
2. **Primary content** — bullets, numbers, comparison, or chart
3. **Secondary content** — brief context only if necessary

The viewer should immediately know:
- what the slide is about
- where to look first
- what conclusion to take away

---

## Color Rules

Use restrained color.

### Palette guidance
- 1 primary color
- 1 accent color
- neutral background and text colors

### Best practices
- dark text on light background, or light text on dark background
- use color to direct attention, not to decorate
- keep accent color usage limited and meaningful

### Avoid
- too many colors
- overly saturated combinations
- red and green contrasts for core meaning
- inconsistent color meanings across slides

---

## Visual Element Rules

Use visuals only when they improve understanding.

### Good uses of visuals
- icons for simple categories
- charts for meaningful quantitative comparisons
- timelines for sequences
- diagrams for relationships
- one relevant image when it supports the message

### Avoid
- decorative clip art
- crowded stock-photo collages
- irrelevant images
- charts with too many series
- 3D charts
- excessive shadows, gradients, or animation-like effects

---

## Charts and Data Slides

When presenting data:
- highlight the key message in the title
- simplify the chart
- label only what matters
- remove unnecessary gridlines and clutter
- emphasize the most important comparison or trend
- include only essential legend items

If a chart takes too long to understand, simplify it or replace it with a key metric plus one supporting graphic.

---

## Use of Emphasis

To emphasize something, use this priority order:

1. position
2. size
3. weight
4. color

Do not emphasize everything. If many elements are highlighted, nothing is highlighted.

---

## Consistency Rules

Across the whole deck:
- use the same font family
- use the same title style
- use the same bullet style
- use the same spacing logic
- use the same alignment system
- use the same color logic

Slides can vary in layout, but they should still feel like one presentation.

---

## Slide-by-Slide Quality Check

Before finalizing a slide, check:

- Does this slide communicate one main idea?
- Is the title a takeaway?
- Is the text readable from a distance?
- Is there enough white space?
- Are there too many bullets?
- Can any text be shortened?
- Would a visual communicate this better?
- Is the layout consistent with the rest of the deck?

If the answer is poor on any of these, revise the slide.

---

## What the Agent Must Avoid

Never:
- create paragraph-heavy slides
- shrink text below 18 pt to fit more content
- place more than 5 bullets on a slide unless explicitly requested
- use vague titles
- overload a slide with multiple ideas
- mix unrelated visuals
- use decorative elements that do not add meaning
- create inconsistent formatting across slides

---

## Narrative Flow Rules

The deck should feel like a story, not a collection of notes.

Use this flow when appropriate:
1. context
2. problem or opportunity
3. analysis or evidence
4. recommendation or solution
5. next steps

Each slide should logically lead to the next.

---

## Default Design Behavior

Unless the user asks otherwise, the agent should:
- prefer minimal, professional design
- keep slides clean and modern
- prioritize clarity over decoration
- reduce content rather than shrinking it
- convert dense content into multiple slides when needed

---

## Instruction for Slide Generation

When generating slides, the agent should first produce:
1. a short deck storyline
2. a slide-by-slide outline
3. the actual slide content

Do not jump directly into slide text without planning the flow.

---

## Optional Output Schema for Internal Agent Use

If your pipeline supports structured intermediate output, use this format:

```json
{
  "deck_title": "string",
  "theme": "minimal professional",
  "slides": [
    {
      "slide_type": "key_message",
      "title": "Takeaway title",
      "content": [
        "Short bullet 1",
        "Short bullet 2",
        "Short bullet 3"
      ],
      "visual_direction": "Optional note for chart, icon, comparison, or image"
    }
  ]
}
```

---

## Final Rule

When deciding between:
- more information
- better readability

always choose **better readability**.
