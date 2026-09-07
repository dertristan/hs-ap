<#
.SYNOPSIS
  Render the Quarto website and publish it to GitHub Pages.
.DESCRIPTION
  main holds the sources; the gh-pages branch holds only rendered output. Run from anywhere
  in the repo: this renders website/ and force-pushes the built _site to this repo's own
  gh-pages branch, which Pages serves at $SiteUrl. Nothing else moves.

  The script is idempotent. On the first run it also creates the gh-pages branch and points
  the repo's Pages source at it.
.PARAMETER DryRun
  Render only; do not publish.
.EXAMPLE
  ./automation/publish-site.ps1 -DryRun
  ./automation/publish-site.ps1
#>
param(
  [string]$SiteDir = "website",
  [string]$Owner   = "dertristan",
  [string]$Repo    = "hs-ap",
  [string]$SiteUrl = "https://dertristan.github.io/hs-ap/",
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$site = Join-Path $root $SiteDir

# --- native-command helpers -------------------------------------------------------------
# Windows PowerShell 5.1 turns a native command's stderr into a NativeCommandError while
# $ErrorActionPreference is 'Stop', and redirecting it (2>$null) does NOT prevent that. So a
# plain "does this branch exist?" probe would abort the script instead of returning false.
# Each helper drops the preference to 'Continue' for the duration of one call.

# Run a command that is EXPECTED to fail sometimes; return whether it exited 0.
function Test-NativeOk {
  param([Parameter(Mandatory)][scriptblock]$Command)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Command 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
  } finally { $ErrorActionPreference = $prev }
}

# Run a command whose failure is harmless and whose exit code we do not care about.
function Invoke-NativeQuiet {
  param([Parameter(Mandatory)][scriptblock]$Command)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Command 2>&1 | Out-Null } finally { $ErrorActionPreference = $prev }
}

# Run a command and return its stdout, or $null when it failed.
function Get-NativeOutput {
  param([Parameter(Mandatory)][scriptblock]$Command)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & $Command 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($out -join "`n").Trim()
  } finally { $ErrorActionPreference = $prev }
}

# --- guard: publishing from a dirty tree makes the live site untraceable to a commit ---
Push-Location $root
try {
  $dirty = @(git status --porcelain)
  if ($dirty -and -not $DryRun) {
    Write-Host "Uncommitted changes in the working tree:" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" }
    throw "Commit (or stash) before publishing, so the live site maps to a commit."
  }
} finally { Pop-Location }

# --- one-time bootstrap: `quarto publish gh-pages --no-prompt` refuses to CREATE the branch ---
# It only pushes to a gh-pages branch that already exists on origin. Create an empty orphan
# commit for it the first time (4b825dc... is git's well-known empty-tree object).
if (-not $DryRun) {
  Push-Location $root
  try {
    if (-not (Test-NativeOk { git ls-remote --exit-code --heads origin gh-pages })) {
      Write-Host "No gh-pages branch on origin - creating it ..." -ForegroundColor Cyan
      $empty  = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
      $commit = (git commit-tree $empty -m "Initialize gh-pages").Trim()
      git push origin "${commit}:refs/heads/gh-pages"
      if ($LASTEXITCODE -ne 0) { throw "Could not create the gh-pages branch on origin." }
    }

    # Pages is off by default on a project repo, so the first run switches it on.
    $slug   = "$($Owner)/$($Repo)"
    $branch = Get-NativeOutput { gh api "repos/$slug/pages" --jq '.source.branch' }
    if ($branch -ne "gh-pages") {
      Write-Host "Pointing GitHub Pages at gh-pages / ..." -ForegroundColor Cyan
      $body = '{"source":{"branch":"gh-pages","path":"/"}}'
      # POST creates a Pages site that does not exist yet; PUT updates an existing one.
      if (-not (Test-NativeOk { $body | gh api -X POST "repos/$slug/pages" --input - })) {
        Invoke-NativeQuiet { $body | gh api -X PUT "repos/$slug/pages" --input - }
      }
    }
  } finally { Pop-Location }
}

Write-Host "Rendering $site ..." -ForegroundColor Cyan
Push-Location $site
try {
  # A cached render is silent, but as soon as an R chunk actually re-executes, R writes to
  # stderr and PS 5.1 turns that into a NativeCommandError that aborts the publish mid-flight.
  # Drop to 'Continue' for the native call and keep the explicit exit-code checks below,
  # which are what actually decide success.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'

  if ($DryRun) {
    quarto render
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($rc -ne 0) { throw "quarto render failed (exit $rc)." }
    Write-Host "[DryRun] Rendered only. Would publish _site to the gh-pages branch -> $SiteUrl" -ForegroundColor Yellow
  } else {
    # Renders, then force-pushes _site to gh-pages of this repo's origin.
    quarto publish gh-pages --no-prompt --no-browser
    # A native command's failure does NOT stop PowerShell, not even under
    # $ErrorActionPreference='Stop' - without this check the script cheerfully reports
    # success over a failed publish.
    $rc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($rc -ne 0) { throw "quarto publish failed (exit $rc) - nothing was published." }
    Write-Host "Published. Live (after Pages rebuilds, ~1 min): $SiteUrl" -ForegroundColor Green
  }
} finally { Pop-Location }
