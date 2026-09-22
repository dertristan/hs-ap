# -----------------------------------------------------------------------------
# Shared helpers for the site pages. Sourced by index.qmd, syllabus.qmd and
# schedule.qmd:
#
#     here::i_am("website/<page>.qmd")
#     source(here("website", "_course-helpers.R"))
#
# The leading underscore keeps Quarto from treating this as a render target.
#
# Everything term-level comes from course.yml. Nothing here holds a date, a
# threshold or a block name of its own: this file only does arithmetic and
# formatting on what course.yml says.
#
# Carried over from qmir-2026-fall/website/_course-helpers.R, minus the homework,
# exam and workload helpers, plus tolerance for values still set to PLACEHOLDER.
# -----------------------------------------------------------------------------

# Read course.yml. Callers must have set here::i_am() first, because website/
# is itself a Quarto project root and a bare here() would stop there.
read_course <- function() {
  yaml::read_yaml(here::here("course.yml"))
}

# TRUE for any course.yml value that has not been filled in yet. A missing key and
# a key still reading PLACEHOLDER are the same statement, so they get one test.
unset <- function(x) {
  is.null(x) || !nzchar(as.character(x)[1]) || identical(as.character(x)[1], "PLACEHOLDER")
}

# A PLACEHOLDER in course.yml prints as an honest "to be announced", never as the
# literal word.
shown <- function(x, fallback = "to be announced") {
  if (unset(x)) fallback else x
}

pad <- function(i) sprintf("%02d", i)

# --- the term calendar -------------------------------------------------------
# THE definition of when session N happens. The weekly grid starts at
# first_session, every date in skip_dates is removed, and what is left is taken in
# order until `count` sessions are found. So a cancelled date pushes every later
# session back by a week rather than silently renumbering the term.
#
# With first_session unset, every date is NA and the pages print "to be announced"
# rather than failing to render.
session_dates <- function(cfg) {
  n <- cfg$sessions$count
  if (unset(cfg$sessions$first_session)) {
    return(rep(as.Date(NA), n))
  }
  first <- as.Date(cfg$sessions$first_session)
  skips <- as.Date(unlist(cfg$sessions$skip_dates %||% list()))
  # Generate a generous grid, then drop the skipped dates and take the first n.
  grid <- first + seq(0, by = 7, length.out = n + length(skips))
  keep <- grid[!grid %in% skips]
  keep[seq_len(n)]
}

# One printable date, or "to be announced" while the calendar is unset.
session_date_label <- function(dates, i, fmt = "%d %b") {
  if (is.na(dates[i])) "to be announced" else format(dates[i], fmt)
}

# The skipped dates that actually fall inside the term, with the session they sit
# between, so the schedule can print an explained "no session" row.
skipped_sessions <- function(cfg) {
  empty <- data.frame(date = as.Date(character()), after_week = integer())
  skips <- as.Date(unlist(cfg$sessions$skip_dates %||% list()))
  if (length(skips) == 0 || unset(cfg$sessions$first_session)) {
    return(empty)
  }
  dates <- session_dates(cfg)
  skips <- sort(skips[skips >= min(dates) & skips <= max(dates)])
  if (length(skips) == 0) {
    return(empty)
  }
  data.frame(
    date = skips,
    after_week = vapply(skips, function(d) sum(dates < d), integer(1))
  )
}

# --- blocks ------------------------------------------------------------------
# Which teaching block a session belongs to. Named ONCE in course.yml, so the
# schedule and the syllabus cannot drift apart.
block_index_of <- function(cfg, i) {
  for (k in seq_along(cfg$blocks)) {
    b <- cfg$blocks[[k]]
    if (i >= b$from && i <= b$to) {
      return(k)
    }
  }
  NA_integer_ # session 1 sits outside the blocks
}

block_name_of <- function(cfg, i) {
  k <- block_index_of(cfg, i)
  if (is.na(k)) NA_character_ else cfg$blocks[[k]]$name
}

# Roman numerals for the block headings.
block_numeral <- function(k) c("I", "II", "III", "IV", "V")[k]

# --- the planned session entry -----------------------------------------------
# Compared with `==`, not identical(): callers pass session numbers that are
# sometimes integer (seq_len) and sometimes double (a literal 1), and identical()
# calls those different.
week_entry <- function(cfg, i) {
  hit <- Filter(function(w) isTRUE(w$week == i), cfg$weeks)
  if (length(hit) == 0) NULL else hit[[1]]
}

# The session's readings, normalised. `which` is "core" or "optional". A reading in
# course.yml is either a bare BibTeX key or a mapping carrying `key` and an optional
# `note` ("chapters 1, 2 and 3"), and both spellings may sit in the same list, so
# this is where the two are flattened into one shape: a list of list(key, note),
# with note NULL when there is none. Always a list, empty when there are no
# readings, so callers never have to test for NULL.
reading_entries <- function(cfg, i, which = c("core", "optional")) {
  which <- match.arg(which)
  w <- week_entry(cfg, i)
  if (is.null(w) || is.null(w$readings)) {
    return(list())
  }
  raw <- w$readings[[which]] %||% list()
  lapply(raw, function(r) {
    if (is.list(r)) {
      list(key = as.character(r$key), note = if (unset(r$note)) NULL else as.character(r$note))
    } else {
      list(key = as.character(r), note = NULL)
    }
  })
}

# Just the BibTeX keys, for callers that only count or link them.
readings_of <- function(cfg, i, which = c("core", "optional")) {
  vapply(reading_entries(cfg, i, which), function(e) e$key, character(1))
}

`%||%` <- function(x, y) if (is.null(x)) y else x
