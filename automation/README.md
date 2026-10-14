# automation/

Scripts that check the site rather than build it.
Run them from the repo root.

| Script | Does |
|---|---|
| `check-decks.ps1` | Render every `website/slides/weekNN.qmd` (or one, with `-Week NN`) and measure each slide against the 1050x700 canvas. `-NoRender` measures the current `_site` output. Exits 1 if any deck has a finding. |
| `check-slide-fit.R` | The measurement itself, on one rendered deck: `Rscript automation/check-slide-fit.R website/_site/slides/week06.html`. Ported from `qmir-2026-fall/automation/check-slide-fit.R` and extended. |

Prereqs: `quarto`, R with the `chromote` package, and Chrome or Edge.
Without R, `chromote` or a browser the check prints a skip notice and exits 0.

## What it reports

Every fragment is revealed before measuring, because a slide only overflows once its last beat is shown.

| Finding | Meaning | Fix, in this order |
|---|---|---|
| `OVERFLOW` | Content taller than the canvas | Under about 8%: wrap the densest block in the next ladder step (STYLE.md §5). Above that: split the slide. Never invent a font size. |
| `TOO WIDE` | Content wider than the canvas, usually a long formula or table | Wrap the wide block in `.small` or `.xsmall`, break the formula, or split. |
| `UNDER LOGO` | Text, an image or a formula drawn under the Mannheim logo | Shorten the title, or open the slide with a full-width line so a right-hand column or a table caption starts below the logo. |
| `OVER FOOTER` | Content reaching the footer text or slide number, which sit inside the 700px canvas | Treat as overflow. A lone figure is the usual cause, see below. |
| `COLLAPSED` | A loaded image drawn at zero height | Give the figure an explicit `height=`. |
| `EXEMPT (scrollable)` | A `.scrollable` slide taller than the canvas | Nothing. Only the reference slide may be scrollable. |

The logo check uses the logo's opaque pixels, not its image box, because the PNG has wide transparent margins.
Text is tested by its glyph lines rather than by the full-width block it sits in.

**Size a lone figure with `height=`, not `width=`.**
Quarto auto-stretches a figure that is alone on a slide to fill the free space, which pushes the text below it into the footer.
An explicit height switches the stretch off.

## Why this exists

The QMIR check measures height only, and it measures images before they are loaded.
Reveal lazy-loads images (`data-src`) near the current slide only, so a deck measured cold counts most figures at zero height.
This version loads every image first, and on the hs-ap decks that alone surfaced a stacked pair of figures running into the footer (week 04, "Results: merit") and four stretched figures pushing text into the footer (weeks 03, 05 and 06).
It also found a formula cut off at the right edge (week 05, "Wagner: spread of scores"), and 33 slides drawn under the logo, which is why the deck logo is 3em here rather than QMIR's 4em.

## Keep the scripts ASCII-only

Windows PowerShell 5.1 reads a `.ps1` in the system ANSI codepage unless it carries a BOM, so a stray em dash or curly quote can break the parse far from the real line.
Typography belongs in the Markdown and Quarto files.
