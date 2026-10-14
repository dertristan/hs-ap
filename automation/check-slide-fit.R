# ─────────────────────────────────────────────────────────────────────────────
# Measure whether every slide of a rendered RevealJS deck fits the canvas.
#
# Ported from qmir-2026-fall/automation/check-slide-fit.R and extended. Called by
# automation/check-decks.ps1. Standalone use:
#
#     Rscript automation/check-slide-fit.R website/_site/slides/week06.html
#
# Why a browser. Slide overflow is a layout property. It depends on the theme,
# the font, the rendered figure sizes and how many fragments a slide reveals, so
# counting source lines cannot answer it.
#
# Three checks, every fragment revealed:
#
#   OVERFLOW    content taller than the canvas (the QMIR check, unchanged)
#   TOO WIDE    content wider than the canvas
#   UNDER LOGO  text, an image or a formula drawn under the Mannheim logo, which
#               sits top right outside the slide container (theme.scss
#               .slide-logo) and so is invisible to the two size checks
#
# A slide with class .scrollable is the reference slide (STYLE.md §5) and is
# reported as exempt from OVERFLOW rather than failing.
#
# Exit codes: 0 = every slide fits, or the check could not run (a missing browser
# must not fail the build). 1 = at least one finding.
# ─────────────────────────────────────────────────────────────────────────────

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("usage: check-slide-fit.R <rendered-deck.html> [canvas_width] [canvas_height]")
}

html <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
canvas_w <- if (length(args) >= 2) as.numeric(args[2]) else 1050
canvas_h <- if (length(args) >= 3) as.numeric(args[3]) else 700

# Tolerance in px. Reveal's own layout rounds, and a slide one or two pixels over
# is not something a human would ever notice on a projector.
tol <- 6

# Overlap in px before a box counts as under the logo. The logo PNG has a little
# transparent margin, so a glancing touch is not a collision.
logo_tol <- 3

skip <- function(msg) {
  cat("  [skip]", msg, "\n")
  cat("  [skip] Install with: install.packages(\"chromote\")\n")
  quit(status = 0)
}

if (!requireNamespace("chromote", quietly = TRUE)) {
  skip("the chromote package is not installed.")
}

# chromote::find_chrome() looks for Chrome, Chromium and Brave but not Edge, which is
# the browser present on a stock Windows install. Fall back to it explicitly.
find_browser <- function() {
  # find_chrome() writes a "Google Chrome was not found" notice to stderr before
  # returning NULL. That is not an error here, because Edge is the fallback.
  found <- suppressMessages(suppressWarnings(
    tryCatch(chromote::find_chrome(), error = function(e) NULL)
  ))
  if (!is.null(found) && nzchar(found)) {
    return(found)
  }
  candidates <- c(
    file.path(Sys.getenv("ProgramFiles(x86)"), "Microsoft/Edge/Application/msedge.exe"),
    file.path(Sys.getenv("ProgramFiles"), "Microsoft/Edge/Application/msedge.exe"),
    file.path(Sys.getenv("LOCALAPPDATA"), "Microsoft/Edge/Application/msedge.exe")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit)) hit[1] else NULL
}

chrome <- find_browser()
if (is.null(chrome)) {
  skip("no Chrome, Chromium or Edge installation found.")
}
Sys.setenv(CHROMOTE_CHROME = chrome)

b <- tryCatch(
  chromote::ChromoteSession$new(width = canvas_w, height = canvas_h),
  error = function(e) NULL
)
if (is.null(b)) skip("could not start a headless browser session.")

on.exit(try(b$close(), silent = TRUE), add = TRUE)

url <- paste0("file:///", sub("^/", "", html))

invisible(b$Page$navigate(url, wait_ = TRUE))
invisible(b$Page$loadEventFired(wait_ = TRUE, timeout_ = 60))

eval_js <- function(js) {
  tryCatch(
    b$Runtime$evaluate(js, returnByValue = TRUE)$result$value,
    error = function(e) NULL
  )
}

# Reveal builds its layout asynchronously after load. Poll rather than sleeping a
# fixed amount, so a slow deck is not measured half-built.
js_ready <- "(window.Reveal && Reveal.isReady && Reveal.isReady()) ? document.querySelectorAll('.reveal .slides section').length : 0"
n_sections <- 0
for (i in seq_len(60)) {
  Sys.sleep(0.25)
  n_sections <- eval_js(js_ready)
  if (is.numeric(n_sections) && n_sections > 0 && i > 4) break
}
if (!is.numeric(n_sections) || n_sections == 0) {
  skip("the deck produced no slides.")
}
# MathJax typesets after Reveal is ready, and formulas change the layout.
for (i in seq_len(40)) {
  done <- eval_js("!window.MathJax || !MathJax.startup || !MathJax.startup.promise ? true : (window.__mjDone === true)")
  if (isTRUE(done)) break
  eval_js("if (window.MathJax && MathJax.startup) MathJax.startup.promise.then(() => { window.__mjDone = true })")
  Sys.sleep(0.25)
}

# Reveal lazy-loads images (data-src) only near the current slide. An unloaded image
# has no height, so a deck measured cold undercounts every figure slide. Load them
# all and wait, which is what the QMIR check missed.
invisible(eval_js("document.querySelectorAll('img[data-src]').forEach(m => { m.src = m.getAttribute('data-src'); m.removeAttribute('data-src'); })"))
for (i in seq_len(60)) {
  pending <- eval_js("[...document.querySelectorAll('.reveal .slides img')].filter(m => !m.complete).length")
  if (is.numeric(pending) && pending == 0) break
  Sys.sleep(0.25)
}

# ── Checks 1 to 3: logo, footer, collapsed images, in the presentation layout ─
#
# The logo and the footer are positioned against the viewport, outside the scaled
# slide container, so these checks run before the size checks dismantle reveal's
# layout. Each slide is shown in turn with every fragment visible. Text is tested
# by its line boxes (Range.getClientRects), which follow the glyphs rather than the
# full-width block, so a short line beside the logo is not a false hit. Images, SVG
# and MathJax output are tested by their boxes. Speaker notes are skipped.
#
# UNDER LOGO   content meets the logo's opaque pixels
# OVER FOOTER  content reaches below the top of the footer text or slide number,
#              which sit inside the 700px canvas and so pass the height check
# COLLAPSED    a loaded image drawn at zero height, which is what Quarto's
#              auto-stretch does to a lone figure when the rest of the slide
#              leaves it no room
js_logo <- sprintf("
(() => {
  const T = %f;
  Reveal.configure({ transition: 'none', backgroundTransition: 'none' });
  const logo = document.querySelector('.reveal .slide-logo');
  if (!logo) return JSON.stringify([]);
  // The PNG carries wide transparent margins, so its box is far larger than the
  // artwork. Find the opaque pixels once and test against those instead.
  const nw = logo.naturalWidth, nh = logo.naturalHeight;
  const cv = document.createElement('canvas');
  cv.width = nw; cv.height = nh;
  const cx = cv.getContext('2d');
  cx.drawImage(logo, 0, 0);
  const px = cx.getImageData(0, 0, nw, nh).data;
  let x0 = nw, y0 = nh, x1 = -1, y1 = -1;
  for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
    if (px[(y * nw + x) * 4 + 3] > 32) {
      if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) { x0 = 0; y0 = 0; x1 = nw; y1 = nh; }
  const opaque = () => {
    const B = logo.getBoundingClientRect();
    return { left: B.left + B.width * x0 / nw, right: B.left + B.width * (x1 + 1) / nw,
             top: B.top + B.height * y0 / nh, bottom: B.top + B.height * (y1 + 1) / nh,
             width: B.width };
  };
  const hit = (r, L) =>
    Math.min(r.right, L.right) - Math.max(r.left, L.left) > T &&
    Math.min(r.bottom, L.bottom) - Math.max(r.top, L.top) > T;
  // A text line box includes the leading above and below the glyphs.
  const glyphs = r => ({ left: r.left, right: r.right,
    top: r.top + 0.15 * r.height, bottom: r.bottom - 0.15 * r.height });
  // The top of the footer band: the highest glyph of the footer or slide number.
  const footerTop = () => {
    let top = Infinity;
    document.querySelectorAll('.reveal .footer, .reveal .slide-number').forEach(f => {
      if (getComputedStyle(f).display === 'none') return;
      const w = document.createTreeWalker(f, NodeFilter.SHOW_TEXT);
      let t;
      while ((t = w.nextNode())) {
        if (!t.textContent.trim()) continue;
        const rg = document.createRange();
        rg.selectNodeContents(t);
        for (const r of rg.getClientRects()) top = Math.min(top, glyphs(r).top);
      }
    });
    return top;
  };
  const out = { logo: [], footer: [], collapsed: [] };
  const push = (list, k, title, found) => {
    if (found.length) list.push({ i: k + 1, title: title, what: found[0], n: found.length });
  };
  const slides = Reveal.getSlides();
  slides.forEach((s, k) => {
    const ix = Reveal.getIndices(s);
    Reveal.slide(ix.h, ix.v, Number.MAX_SAFE_INTEGER);
    s.querySelectorAll('.fragment').forEach(f => f.classList.add('visible'));
    Reveal.layout();
    const L = opaque();
    const logoOn = L.width > 0 && getComputedStyle(logo).display !== 'none';
    const F = footerTop();
    const head = s.querySelector('h1, h2, h3');
    const title = s.id === 'title-slide' ? '(title slide)'
      : head ? head.textContent.trim().slice(0, 40) : '(no heading)';
    const underLogo = [], overFooter = [], collapsed = [];
    const walker = document.createTreeWalker(s, NodeFilter.SHOW_TEXT);
    let n;
    while ((n = walker.nextNode())) {
      const txt = n.textContent.trim();
      if (!txt) continue;
      const el = n.parentElement;
      if (!el || el.closest('aside.notes, .notes, mjx-assistive-mml, script, style')) continue;
      const cs = getComputedStyle(el);
      if (cs.visibility === 'hidden' || cs.display === 'none') continue;
      const range = document.createRange();
      range.selectNodeContents(n);
      const rs = [...range.getClientRects()].map(glyphs);
      if (logoOn && rs.some(r => hit(r, L))) underLogo.push(txt.slice(0, 40));
      if (rs.some(r => r.bottom > F + T)) overFooter.push(txt.slice(0, 40));
    }
    s.querySelectorAll('img, svg, mjx-container, video, canvas').forEach(e => {
      if (e.closest('aside.notes, .notes')) return;
      if (e.closest('mjx-container') && e.tagName !== 'MJX-CONTAINER') return;
      const r = e.getBoundingClientRect();
      const label = '<' + e.tagName.toLowerCase() + '> ' + (e.getAttribute('alt') || '').slice(0, 30);
      if (e.tagName === 'IMG' && e.naturalWidth > 0 && r.height < 2 &&
          getComputedStyle(e).display !== 'none') {
        collapsed.push(label);
        return;
      }
      if (r.height < 2) return;
      if (logoOn && hit(r, L)) underLogo.push(label);
      if (r.bottom > F + T) overFooter.push(label);
    });
    push(out.logo, k, title, underLogo);
    push(out.footer, k, title, overFooter);
    push(out.collapsed, k, title, collapsed);
  });
  return JSON.stringify(out);
})()
", logo_tol)

empty_hits <- data.frame(i = integer(0), title = character(0), what = character(0), n = integer(0))
as_hits <- function(x) if (is.null(x) || length(x) == 0) empty_hits else as.data.frame(x)

view_res <- eval_js(js_logo)
if (is.null(view_res)) cat("  [warn] the logo and footer checks did not return a result.\n")
view <- if (is.null(view_res)) list() else jsonlite::fromJSON(view_res, simplifyDataFrame = TRUE)
logo_hits <- as_hits(view$logo)
footer_hits <- as_hits(view$footer)
collapsed_hits <- as_hits(view$collapsed)

# ── Checks 2 and 3: height and width, in a static layout ─────────────────────
#
# Reveal displays one slide at a time and fits the deck to the viewport with a CSS
# transform, so neither the rendered box nor a print-pdf page tells you how big a
# slide's CONTENT is: both report the fixed canvas box. So we neutralise reveal's
# layout for the measurement, laying every slide out statically at the true canvas
# WIDTH with height:auto, and read the natural content size back. That number is
# directly comparable to the canvas because reveal scales by transform and never
# changes the font size, so the unscaled coordinate system is 1050x700.
#
# Every fragment is forced visible first: a slide only overflows once its last beat
# is revealed. Sections containing another section are vertical-stack wrappers, not
# slides, so they are skipped. The index matches Reveal.getSlides() order.
js_measure <- sprintf("
(() => {
  const W = %f;
  const css = document.createElement('style');
  css.textContent = `
    .reveal .slides { position: static !important; transform: none !important;
      left: 0 !important; top: 0 !important; margin: 0 !important;
      width: ${W}px !important; height: auto !important; zoom: 1 !important; }
    .reveal .slides > section,
    .reveal .slides > section > section {
      display: block !important; position: static !important;
      height: auto !important; min-height: 0 !important;
      visibility: visible !important; opacity: 1 !important;
      transform: none !important; top: auto !important; }
    .reveal .fragment { opacity: 1 !important; visibility: visible !important; }
    .reveal .slides section .fragment:not(.visible) { opacity: 1 !important; }
  `;
  document.head.appendChild(css);
  document.querySelectorAll('.reveal .fragment').forEach(f => {
    f.classList.add('visible', 'current-fragment');
  });

  const out = [];
  let idx = 0;
  document.querySelectorAll('.reveal .slides section').forEach(s => {
    if (s.querySelector(':scope > section')) return;
    idx += 1;
    const head = s.querySelector('h1, h2, h3');
    const isTitle = s.id === 'title-slide';
    out.push({
      i: idx,
      title: isTitle ? '(title slide)'
            : head ? head.textContent.trim().slice(0, 40)
            : '(no heading)',
      h: Math.round(Math.max(s.scrollHeight, s.offsetHeight)),
      w: Math.round(s.scrollWidth),
      scrollable: s.classList.contains('scrollable')
    });
  });
  return JSON.stringify(out);
})()
", canvas_w)

res <- eval_js(js_measure)
if (is.null(res)) skip("measurement script did not return a result.")

slides <- tryCatch(
  jsonlite::fromJSON(res, simplifyDataFrame = TRUE),
  error = function(e) NULL
)
if (is.null(slides) || length(slides) == 0 || nrow(slides) == 0) {
  skip("no measurable slides in the deck.")
}

slides$over <- slides$h - canvas_h
slides$pct <- 100 * slides$over / canvas_h
tall <- slides[slides$over > tol, , drop = FALSE]
exempt <- tall[tall$scrollable, , drop = FALSE]
tall <- tall[!tall$scrollable, , drop = FALSE]
wide <- slides[slides$w > canvas_w + tol, , drop = FALSE]
# The reference slide scrolls, so its runs past the footer are by design.
scroll_i <- slides$i[slides$scrollable]
footer_hits <- footer_hits[!footer_hits$i %in% scroll_i, , drop = FALSE]

remedy <- function(pct) {
  if (pct <= 8) {
    "wrap the dense block in .small"
  } else if (pct <= 20) {
    "wrap the dense block in .xsmall, or split"
  } else {
    "split the slide"
  }
}

report_hits <- function(hits, heading, advice) {
  if (nrow(hits) == 0) return(invisible())
  cat("\n ", heading, "\n")
  for (k in seq_len(nrow(hits))) {
    cat(sprintf(
      "    slide %2d  %-42s \"%s\"%s\n",
      hits$i[k], hits$title[k], hits$what[k],
      if (hits$n[k] > 1) sprintf(" (+%d more)", hits$n[k] - 1) else ""
    ))
  }
  cat("    ->", advice, "\n")
}

cat(sprintf("  canvas %.0fx%.0f, %d slide(s) measured\n", canvas_w, canvas_h, nrow(slides)))

if (nrow(tall) > 0) {
  cat("\n  OVERFLOW\n")
  for (k in seq_len(nrow(tall))) {
    cat(sprintf(
      "    slide %2d  %-42s %4dpx  (+%.1f%%)  -> %s\n",
      tall$i[k], tall$title[k], tall$h[k], tall$pct[k], remedy(tall$pct[k])
    ))
  }
}

if (nrow(wide) > 0) {
  cat("\n  TOO WIDE\n")
  for (k in seq_len(nrow(wide))) {
    cat(sprintf(
      "    slide %2d  %-42s %4dpx  -> shrink the wide block with the ladder, or split\n",
      wide$i[k], wide$title[k], wide$w[k]
    ))
  }
}

report_hits(logo_hits, "UNDER LOGO", "shorten the title, or start the slide with a full-width line")
report_hits(footer_hits, "OVER FOOTER", "treat as overflow: take the next ladder step, or split")
report_hits(collapsed_hits, "COLLAPSED", "give the figure an explicit height, which stops Quarto's auto-stretch")

if (nrow(exempt) > 0) {
  cat("\n  EXEMPT (scrollable)\n")
  for (k in seq_len(nrow(exempt))) {
    cat(sprintf("    slide %2d  %-42s %4dpx\n", exempt$i[k], exempt$title[k], exempt$h[k]))
  }
}

bad <- unique(c(tall$i, wide$i, logo_hits$i, footer_hits$i, collapsed_hits$i))
if (length(bad) == 0) {
  cat(sprintf("\n  all %d slides fit.\n", nrow(slides)))
  quit(status = 0)
}
cat(sprintf("\n  %d of %d slides fit. See STYLE.md section 5 for the ladder.\n",
            nrow(slides) - length(bad), nrow(slides)))
quit(status = 1)
