# hs-ap

Source of the seminar *Us and them: Identity and polarization in contemporary democracies*
(Hauptseminar, B.A. Politikwissenschaft, University of Mannheim).

The site has three pages: **About**, **Syllabus** and **Schedule**.

- **`course.yml`** is the single source of truth for everything term-level: dates, module
  entries, thresholds, the block structure, and the per-session topic, goals and readings.
  Change a value there, never in a page.
- **`STYLE.md`** is the authoring style for every `.qmd` and `.md` here.
- **`website/references.bib`** is the bibliography, copied from the CSAP research project.

Values that are not settled yet read `PLACEHOLDER` in `course.yml` and render as
"to be announced", so the site is always publishable.

## Render

```powershell
cd website
quarto render
```

Output goes to `website/_site/` and is git-ignored.

## Publishing

`main` holds the sources.
The `gh-pages` branch holds only the rendered site, force-pushed there by Quarto.
The site is live at <https://dertristan.github.io/hs-ap/>.

```powershell
./automation/publish-site.ps1 -DryRun   # render only, publish nothing
./automation/publish-site.ps1           # render and publish
```

The script refuses to publish from a dirty working tree, so the live site always maps to a
commit.
