# hs-ap authoring conventions

The house style for every `.qmd` and `.md` in this repo.
Carried over from the QMIR course (`C:/R/teaching/qmir-2026-fall/STYLE.md`), cut to the sections
that apply to a site with three prose pages, a deck per session, and no homework and no models.

The `E0NN` codes are kept so the two repos speak the same language.
There is **no checker script here**, so they are conventions rather than enforced rules.

---

## 1. Prose and typography

The site is written in English throughout. The voice is encouraging, clear and non-dogmatic,
pitched at 4th and 5th semester bachelor students with no statistics background beyond
descriptives.

**No em dashes or en dashes in prose** (`E001`). Use a comma, a colon, parentheses, or recast
the sentence. Where a dash genuinely reads better, write a literal double hyphen: Pandoc renders
it as an en dash and it survives every output format.

```markdown
Bad:   The website is the source of truth — if it is not linked, it does not exist.
Good:  The website is the source of truth. If it is not linked, it does not exist.
Good:  QMIR -- Week 3 -- Priors
```

**No semicolons in prose** (`E002`). A semicolon almost always marks two sentences pretending to
be one. Split them.

The rule is about *prose*. Code, YAML mechanics, SCSS, URLs, file paths and the box-drawing
banners in comments are all exempt, and the checker strips fenced code blocks, inline code spans,
raw HTML and math before it looks.

**One sentence per line.** Diffs stay readable, and a reworded sentence shows up as one changed
line instead of a reflowed paragraph.

Other prose rules:

- Sentence case for headings, not Title Case.
- Package and function names in backticks: `brms`, `pp_check()`.
- The feedback-policy banner (CLAUDE.md §2) is reproduced **verbatim** wherever it appears. Do
  not reword it. Consistency is the entire point of it.

---

## 2. Cross-references

Every figure, table, equation and heading is labelled with Quarto crossref syntax and referenced
by label. Never write "the figure below" or "the table above". A label survives reordering and a
positional phrase does not.

**Figures** (`E020`). A chunk needs the label *and* the caption. A `fig-` label without a
`fig-cap` is not a cross-reference, and Quarto warns about it.

````markdown
```{r}
#| label: fig-prior-predictive
#| fig-cap: "Prior predictive draws for turnout. The N(0, 10) prior on the intercept implies
#|   turnout rates far outside the unit interval, which is the signal that it is too wide."
#| fig-height: 4
#| dpi: 500
```
````

**Tables** (`E021`). The same pairing, a `tbl-` label plus a `tbl-cap`. For a static Markdown
table, put the caption on the line below it:

```markdown
: Packages installed in week 1 and what each is for. {#tbl-packages}
```

**Equations** (`E022`). Display math takes a label, with a blank line after the opening `$$` and
before the closing one. Inline math uses single `$`.

```markdown
$$
p(\theta \mid Y) \propto L(Y \mid \theta) \times p(\theta)
$$ {#eq-bayes-core}
```

**Headings** (`E023`). Every `##` and `###` carries a section label so it can be referenced and
linked. Kebab-case, topical, prefixed `sec-`.

```markdown
## Prior predictive checks {#sec-prior-predictive .smaller}
```

Attribute order is fixed: **id first, then classes**. The previous course iteration used both
orderings, which made the decks harder to grep than they needed to be.

**Captions must be self-sufficient.** A reader who sees only the figure and its caption should
understand what is plotted and what the point is. This is graded on the exam, so the course
materials have to model it.

Reference with `@fig-x`, `@tbl-x`, `@eq-x`, `@sec-x`.

---

## 3. Callouts

Exactly four types, each with one job (`E030`). `callout-caution` is not used.

| Type | Use it for |
|---|---|
| `note` | Additional context, background, deeper or further information. The default. |
| `warning` | Frequently occurring errors, mistakes and pitfalls to avoid. |
| `important` | What students MUST keep in mind to avoid getting lost or making a fundamental error. The harder variant of `warning`. |
| `tip` | Useful advice, tips, best practice. |

Shape: a bold lead sentence on its own line, then one to three explanation lines, one sentence
per line.

```markdown
::: {.callout-warning}
**`brm()` silently accepts a flat prior.**
If you omit `prior =`, brms picks improper flat priors for the population-level effects.
The model still samples, so nothing warns you that you skipped step 3.
:::
```

On slides, size a callout with the ladder classes from §5, never with an inline style.

---

## 4. R code

The R here does one job: build the syllabus and schedule pages from `course.yml`.
There are no models and no data analysis, so this section is short.

**Paths.** `here()` for every path, always (`E013`).

::: {.callout-warning}
**A bare `here()` stops at `website/`, not at the repo root.**
`_quarto.yml` is itself a project-root marker, so inside the site project `here()` resolves to
`website/`.
Anchor it explicitly with `here::i_am("website/schedule.qmd")` once at the top of the setup
chunk, and `here()` is correct from then on.
:::

**Tidyverse, native pipe.** `|>`, never `%>%` (`E010`). `snake_case` throughout.

**Chunk options** are `#|` YAML comments only, never the legacy in-header knitr form.
Every chunk carries a `#| label:`.

**Setup chunk.** One `library()` call per line, each with a short trailing comment saying what
it is for (`E014`).

```r
library(here) # project-root-relative paths
library(yaml) # read course.yml
```

**Other R rules.**

- `case_match()`, not the deprecated `recode()` (`E012`).
- Comments are one to three words. The explanation belongs in the surrounding prose, which is
  the entire reason for writing in Quarto.
- Minimal new packages. Ask and justify before adding one.
- Run the Air formatter (built into Positron) before committing.

---

## 5. Slide decks

One deck per session, at `website/slides/weekNN.qmd`, zero padded. Copy
`website/slides/_deck-template.qmd`, which is the worked example of everything below.

**The YAML carries `title:` and nothing else** (`E041`). The shared revealjs block, the theme, the
logo and the title-slide background live in `website/slides/_metadata.yml`. A deck that declares
its own `format:` will drift from the other twelve, which is what happened in the QMIR course
before the block was centralised.

The title reads `Session NN: <topic>`. The schedule takes its Topic column from `course.yml`
rather than from the deck, so nothing parses this string, but keeping the shape makes the decks
sortable and greppable.

**Every heading takes a `#sec-` label**, the same rule as the prose pages (§2). One sentence per
line, no em dashes, no semicolons (§1).

**The size ladder** (`E040`). A slide that does not fit is fixed in this order, and never with an
inline `style="font-size: ..."`:

1. `{.smaller}` on the slide. This is the default for a content slide.
2. `.small` on the one dense block, not on the whole slide.
3. `.xsmall` on that block.
4. Split the slide.

`.reveal .small` and `.reveal .xsmall` are defined in `website/slides/theme.scss`. The site
stylesheet does not carry them, because only the decks use them.

**Revealed beats.** `. . .` separates them, and a beat is three to six short lines. Instructor
cues go in a `::: notes` block as terse imperatives, never as prose.

**Images.** `website/slides/images/` holds the two University of Mannheim assets that
`_metadata.yml` references, and `images/COPYRIGHTS.md` states their terms. Anything added there
gets a line in that file.
