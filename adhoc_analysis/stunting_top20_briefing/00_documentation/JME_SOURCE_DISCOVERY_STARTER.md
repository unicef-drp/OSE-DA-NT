# JME Source Discovery Starter

Last updated: 2026-04-18

## Purpose

This note lists the first external sources agents should review when producing
content for modeled child anthropometry briefings, especially modeled stunting.

These are background and context sources. They do not automatically become
approved numeric sources for briefing claims.

## Primary Starting Pages

1. https://data.unicef.org/topic/nutrition/malnutrition/
2. https://data.unicef.org/resources/jme/
3. https://data.unicef.org/resources/jme-standard-methodology/

## High-Priority JME Sources

### 1. JME Levels and Trends 2025 edition

- Page: https://data.unicef.org/resources/jme/
- Type: primary JME report page
- Why it matters: main narrative and framing page for current JME levels and trends

### 2. JME standard methodology

- Page: https://data.unicef.org/resources/jme-standard-methodology/
- Type: methodology guidance
- Why it matters: explains data compilation, source review, inclusion criteria, modeled estimates for stunting and overweight, and regional and global trends

### 3. Child Malnutrition topic page

- Page: https://data.unicef.org/topic/nutrition/malnutrition/
- Type: topic landing page with current downloads
- Why it matters: surfaces current downloadable JME tables and related guidance

### 4. Recommendations for data collection, analysis and reporting on anthropometric indicators in children under 5 years of age

- Page: linked from the Child Malnutrition topic page
- Type: anthropometry guidance
- Why it matters: useful for framing methods and limitations in anthropometry briefing content

### 5. Anthropometry data quality research priorities

- Page: linked from the Child Malnutrition topic page
- Type: guidance
- Why it matters: useful for data quality framing and cautions

## Additional Context Sources Now In Scope

These are not replacements for JME sources. They are supporting context inputs
for narrative development and cross-report framing.

### 6. SOFI 2025

- Registry entries: `DOC-015`, `DOC-016`
- Why it matters: contextual framing on food insecurity and nutrition trends
- Use rule: context only unless numeric use is explicitly approved

### 7. UN SDG Report 2025

- Registry entries: `DOC-017`, `DOC-018`
- Why it matters: high-level global development framing and cross-report positioning
- Use rule: context only unless numeric use is explicitly approved

### 8. UNSD storyline Word documents

- Location: external source-library folder for this workflow
- Naming pattern: Word files with `storyline` in the file name
- Why they matter: recent editorial framing and storyline language aligned with current reporting workflows
- Use rule: register them in `source_registry.csv` if used, then treat them as context sources unless numeric use is explicitly approved

## Population Context Sources

For this briefing, regional and global under-five population context should be
drawn from an approved numeric workbook rather than reverse-calculated.

Primary approved source:

`C:/Users/jconkle/UNICEF/Chief Statistician Office - Documents/060.DW-MASTER/01_dw_prep/011_rawdata/nt/output/inter/agg_indicator/Regional_Output_NT_ANT_HAZ_NE2_MOD.xlsx`

Use the `basepop_value` variable for regional and global population references
in the two-pager brief.

Secondary validation source:

- the `animated_scatterplots` work in the further-transformation system may be consulted as a secondary check on population treatment, but it should not override the approved workbook without explicit approval

## How To Use These Sources

- Use approved datasets for numbers.
- Use JME pages and stored reports for methodology, definitions, framing, and cautions.
- Use storyline documents, SOFI, and UN SDG documents for narrative context and cross-report framing.
- Store any external documents actually used in the external Analysis Space source-library folder for the workflow.
- Register each external source used in the external `source_registry.csv`.
- Distinguish clearly between dataset-derived findings and document-derived context in product drafts.
