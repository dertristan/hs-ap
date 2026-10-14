<#
.SYNOPSIS
  Render the session decks and measure every slide against the 1050x700 canvas.

.DESCRIPTION
  The slide-fit stage of qmir-2026-fall/automation/check-authoring.ps1 (-Fit), ported to
  this repo. For each website/slides/weekNN.qmd in scope it renders the deck with quarto,
  then runs automation/check-slide-fit.R on website/_site/slides/weekNN.html, which drives
  headless Chrome or Edge through R's chromote and reports three kinds of finding:
  OVERFLOW (too tall), TOO WIDE, and UNDER LOGO (content drawn under the Mannheim logo).
  Skips cleanly, without failing, when R, chromote or a browser is unavailable.

.PARAMETER Week
  Check one deck, by session number. Without it, every weekNN.qmd is checked.

.PARAMETER NoRender
  Measure the current _site output instead of rendering first.

.EXAMPLE
  .\automation\check-decks.ps1
  .\automation\check-decks.ps1 -Week 06
  .\automation\check-decks.ps1 -NoRender

  Keep this file ASCII-only (see automation/README.md).
#>
param(
  [int]$Week,
  [switch]$NoRender
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

# R is routinely installed without being on PATH. Same lookup as qmir-2026-fall/automation/_common.ps1.
function Get-RscriptPath {
  $onPath = Get-Command Rscript -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }

  $roots = @(
    "$env:ProgramFiles\R",
    "${env:ProgramFiles(x86)}\R",
    "$env:LOCALAPPDATA\Programs\R"
  ) | Where-Object { $_ -and (Test-Path $_) }

  $candidates = foreach ($root in $roots) {
    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Join-Path $_.FullName "bin\Rscript.exe" } |
      Where-Object { Test-Path $_ }
  }
  if (-not $candidates) { return $null }

  # Newest first, by the R-x.y.z directory name parsed as a version.
  $candidates |
    Sort-Object {
      $name = Split-Path (Split-Path $_ -Parent) -Parent | Split-Path -Leaf
      try { [version]($name -replace '^R-', '') } catch { [version]'0.0.0' }
    } -Descending |
    Select-Object -First 1
}

function Test-SlideFit {
  param([string]$DeckQmd, [string]$Rscript)

  $deckName = [System.IO.Path]::GetFileNameWithoutExtension($DeckQmd)
  $siteDir = Join-Path $RepoRoot "website"
  $html = Join-Path $siteDir "_site\slides\$deckName.html"

  if (-not $NoRender) {
    Write-Host "  rendering $deckName ..." -ForegroundColor DarkGray
    Push-Location $siteDir
    try {
      # A native command writing to stderr aborts under "Stop", even when redirected.
      $prev = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      & quarto render "slides/$deckName.qmd" --quiet 2>&1 | Out-Null
      $rc = $LASTEXITCODE
      $ErrorActionPreference = $prev
    } finally { Pop-Location }

    if ($rc -ne 0) {
      Write-Host "  [fail] quarto render failed for $deckName." -ForegroundColor Red
      return $false
    }
  }

  if (-not (Test-Path $html)) {
    Write-Host "  [fail] no rendered deck at website/_site/slides/$deckName.html." -ForegroundColor Red
    return $false
  }

  $checker = Join-Path $PSScriptRoot "check-slide-fit.R"
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  # Write-Host, not bare output: anything a function emits to the pipeline becomes part
  # of its return value, so the report would vanish into the boolean.
  & $Rscript --vanilla $checker $html 2>&1 | ForEach-Object { Write-Host $_ }
  $rc = $LASTEXITCODE
  $ErrorActionPreference = $prev
  return ($rc -eq 0)
}

$rscript = Get-RscriptPath
if (-not $rscript) {
  Write-Host "[skip] R not found, cannot run the slide-fit check." -ForegroundColor DarkYellow
  exit 0
}

$slidesDir = Join-Path $RepoRoot "website\slides"
if ($Week) {
  $pad = "{0:d2}" -f $Week
  $deck = Join-Path $slidesDir "week$pad.qmd"
  if (-not (Test-Path $deck)) { throw "No deck at website/slides/week$pad.qmd" }
  $decks = @(Get-Item $deck)
} else {
  $decks = @(Get-ChildItem $slidesDir -Filter "week*.qmd" -File |
    Where-Object { $_.Name -match '^week\d{2}\.qmd$' } |
    Sort-Object Name)
}

if (-not $decks) {
  Write-Host "No decks found under website/slides/." -ForegroundColor DarkYellow
  exit 0
}

$failed = @()
foreach ($d in $decks) {
  Write-Host "-- slide fit: $($d.Name) --" -ForegroundColor Cyan
  if (-not (Test-SlideFit -DeckQmd $d.FullName -Rscript $rscript)) { $failed += $d.Name }
}

Write-Host ""
if ($failed.Count -gt 0) {
  Write-Host ("{0} of {1} deck(s) with findings: {2}" -f $failed.Count, $decks.Count, ($failed -join ", ")) -ForegroundColor Red
  exit 1
}
Write-Host ("All {0} deck(s) fit." -f $decks.Count) -ForegroundColor Green
exit 0
