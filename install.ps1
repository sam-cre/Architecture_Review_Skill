<#
.SYNOPSIS
    Installs the architecture-review skill into ~/.claude/skills so it is
    available in every project, in Claude Code and in the Claude desktop app.

.DESCRIPTION
    Copies (default) or symlinks (-Link) skill/architecture-review into
    $HOME/.claude/skills/architecture-review.

    Copy mode is the safe default and works everywhere.
    Link mode makes edits to this repo take effect immediately, but requires
    Windows Developer Mode or an elevated shell.

.PARAMETER Link
    Create a directory symlink instead of copying. Best if you plan to keep
    editing the skill.

.PARAMETER Force
    Overwrite an existing installation without prompting.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Link
    .\install.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Link,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$Source    = Join-Path $RepoRoot 'skill\architecture-review'
$SkillsDir = Join-Path $HOME '.claude\skills'
$Target    = Join-Path $SkillsDir 'architecture-review'

Write-Host ''
Write-Host 'Architecture Review Skill - installer' -ForegroundColor Cyan
Write-Host ''

# --- Validate source -------------------------------------------------------
if (-not (Test-Path $Source)) {
    Write-Host "ERROR: source not found at $Source" -ForegroundColor Red
    Write-Host 'Run this script from the repository root.'
    exit 1
}
$Manifest = Join-Path $Source 'SKILL.md'
if (-not (Test-Path $Manifest)) {
    Write-Host "ERROR: SKILL.md missing from $Source" -ForegroundColor Red
    exit 1
}

# --- Handle existing install ----------------------------------------------
if (Test-Path $Target) {
    $item      = Get-Item $Target -Force
    $isSymlink = $item.LinkType -eq 'SymbolicLink'
    $kind      = if ($isSymlink) { 'symlink' } else { 'directory' }

    if (-not $Force) {
        Write-Host "An installation already exists ($kind):" -ForegroundColor Yellow
        Write-Host "  $Target"
        $reply = Read-Host 'Replace it? [y/N]'
        if ($reply -notmatch '^[Yy]') {
            Write-Host 'Cancelled. Nothing changed.'
            exit 0
        }
    }

    # Remove the link itself, never its contents.
    if ($isSymlink) {
        [System.IO.Directory]::Delete($Target, $false)
    } else {
        Remove-Item $Target -Recurse -Force
    }
    Write-Host 'Removed previous installation.' -ForegroundColor DarkGray
}

if (-not (Test-Path $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
}

# --- Install ---------------------------------------------------------------
$mode = 'copied'
if ($Link) {
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        $mode = 'symlinked'
    } catch {
        Write-Host 'Symlink failed (needs Developer Mode or an elevated shell).' -ForegroundColor Yellow
        Write-Host 'Falling back to copy.' -ForegroundColor Yellow
        Copy-Item -Path $Source -Destination $Target -Recurse -Force
    }
} else {
    Copy-Item -Path $Source -Destination $Target -Recurse -Force
}

# --- Verify ----------------------------------------------------------------
$checks = @(
    'SKILL.md'
    'references\rules.md'
    'references\differential-protocol.md'
    'references\parallel-review.md'
    'references\phases\phase-0-recon.md'
    'references\phases\phase-7-report.md'
    'references\domains\backend-service.md'
    'references\domains\frontend-app.md'
    'references\tooling\git-history.md'
    'references\templates\findings-schema.json'
)

$missing = @()
foreach ($c in $checks) {
    if (-not (Test-Path (Join-Path $Target $c))) { $missing += $c }
}

if ($missing.Count -gt 0) {
    Write-Host 'ERROR: installation incomplete. Missing:' -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

$fileCount   = (Get-ChildItem $Target -Recurse -File).Count
$phaseCount  = (Get-ChildItem (Join-Path $Target 'references\phases')   -File).Count
$domainCount = (Get-ChildItem (Join-Path $Target 'references\domains')  -File).Count

Write-Host ''
Write-Host "Installed ($mode)." -ForegroundColor Green
Write-Host "  Location : $Target"
Write-Host "  Files    : $fileCount  ($phaseCount phases, $domainCount domain guides)"
Write-Host ''
Write-Host 'Usage - from any project directory:' -ForegroundColor Cyan
Write-Host '  /architecture-review           full design review (standard)'
Write-Host '  /architecture-review quick     structural triage - graph, cycles, hotspots'
Write-Host '  /architecture-review deep      wider evidence sweep, more change scenarios'
Write-Host '  /architecture-review pr        review the design of a diff'
Write-Host '  /architecture-review diff      re-review; did the debt move?'
Write-Host ''
Write-Host 'It also triggers on plain requests such as "is this overengineered"'
Write-Host 'or "why is this so hard to change".'
Write-Host ''
Write-Host 'Output goes to .architecture-review/ in the reviewed project.'
Write-Host 'The skill never modifies the project under review.' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Restart Claude Code or the Claude desktop app to pick it up.' -ForegroundColor Yellow
Write-Host ''
