# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

The website for the seminar *Us and them: Identity and polarization in contemporary
democracies* (Hauptseminar, B.A. Politikwissenschaft, University of Mannheim, 13 sessions).
It is a **reading seminar, not a methods course**: no homework, no code, no models.
Sessions do have a slide deck each, which is a short framing of the reading rather than a lecture.

## Scope: three pages plus the decks

`website/index.qmd` (About), `website/syllabus.qmd`, `website/schedule.qmd`, and the decks in
`website/slides/`. That is the whole site. Do not add a glossary, an installation guide or a
resources directory. The skeleton was deliberately cut down from
`C:/R/teaching/qmir-2026-fall`, which has all of those and needs them.

A deck is `website/slides/weekNN.qmd`, zero padded, copied from
`website/slides/_deck-template.qmd`. Its YAML carries `title:` and nothing else, because the
shared revealjs block lives in `website/slides/_metadata.yml`. The schedule's Slides column is
gated on the file existing, so a deck publishes itself and there is no `slides:` key in
`course.yml` to keep in sync.

## Rules

- **`course.yml` is the single source of truth.** The syllabus and the schedule are *built*
  from it by R chunks using `website/_course-helpers.R`. Never type a date, a topic, a
  threshold or a reading into a page: put it in `course.yml` and let the page read it.
- **Read `STYLE.md` before authoring any `.qmd`.** One sentence per line, no em dashes, no
  semicolons, sentence case headings, a `#sec-` label on every heading.
- **Do not invent facts.** Anything not yet settled is `PLACEHOLDER` in `course.yml` and prints
  as "to be announced" via `shown()`. Module facts come from the two PDFs in `C:/R/teaching/`:
  `Modulkatolog_Politikwissenschaft_Bachelor_2023.pdf` (this HS is on p. 31 and again on p. 38,
  it is offered in both modules) and `PO_BA_Powi_HWS2023_neu2024-1.pdf` (section 13a lists the
  permissible assessment forms, section 13b permits Mitarbeit as coursework). **Attendance
  thresholds are deliberately not published on this site**, and there is no attendance
  requirement in this seminar. Do not reintroduce the 80% or 60% figures, in either direction:
  saying the rule does not apply still puts the number on the page. What is required is active
  participation, the mandatory core reading, and the term paper idea presentation.
- **Readings are BibTeX keys** in `course.yml`, resolved against `website/references.bib`.
  Check a key exists before adding it.
- **No student names** in `course.yml` or any tracked file. There are no session leads in this
  seminar, so nothing in `course.yml` is waiting for a student name.

## Render

```powershell
cd website
quarto render
```
