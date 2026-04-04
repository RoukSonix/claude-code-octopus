#Requires -Version 5.1
<#
.SYNOPSIS
    AI Agents Marketplace - Windows PowerShell Installer

.DESCRIPTION
    Installs agents, commands, and skills from the AI Agents Marketplace
    into your project for Claude Code and Codex CLI.

.PARAMETER Action
    Action to perform: Install, List, Search, ListCategories

.PARAMETER All
    Install all items (agents + commands + skills)

.PARAMETER Agents
    Install all agents

.PARAMETER Commands
    Install all commands

.PARAMETER Skills
    Install all skills

.PARAMETER Item
    Install a specific item by marketplace ID

.PARAMETER Category
    Install all items in a category

.PARAMETER Cli
    Target CLI: claude, codex, or both (default: both)

.PARAMETER TargetDir
    Target project directory (default: current directory)

.PARAMETER SearchQuery
    Search query for --search action

.PARAMETER DryRun
    Preview what would be installed without copying

.EXAMPLE
    .\marketplace\install.ps1 -List
    .\marketplace\install.ps1 -All -Cli claude -TargetDir C:\Projects\my-project
    .\marketplace\install.ps1 -Item agent-bug-detector
    .\marketplace\install.ps1 -Search security
    .\marketplace\install.ps1 -All -DryRun

.EXAMPLE
    # One-liner remote install
    irm https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.ps1 | iex
#>

[CmdletBinding(DefaultParameterSetName = 'Help')]
param(
    [Parameter(ParameterSetName = 'InstallAll')]
    [switch]$All,

    [Parameter(ParameterSetName = 'InstallAgents')]
    [switch]$Agents,

    [Parameter(ParameterSetName = 'InstallCommands')]
    [switch]$Commands,

    [Parameter(ParameterSetName = 'InstallSkills')]
    [switch]$Skills,

    [Parameter(ParameterSetName = 'InstallItem')]
    [string]$Item,

    [Parameter(ParameterSetName = 'InstallCategory')]
    [string]$Category,

    [Parameter(ParameterSetName = 'List')]
    [switch]$List,

    [Parameter(ParameterSetName = 'ListCategories')]
    [switch]$ListCategories,

    [Parameter(ParameterSetName = 'Search')]
    [string]$Search,

    [ValidateSet('claude', 'codex', 'both')]
    [string]$Cli = 'both',

    [string]$TargetDir = '.',

    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Help')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$Version = '1.0.0'

# ── Helpers ─────────────────────────────────────────────────────────────────

function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "[i] $msg" -ForegroundColor Blue }

function Write-Header {
    Write-Host ""
    Write-Host "=== AI Agents Marketplace ===" -ForegroundColor Cyan
    Write-Host ""
}

# ── Find Marketplace Data ──────────────────────────────────────────────────

function Find-MarketplaceJson {
    $scriptDir = $PSScriptRoot
    $candidates = @(
        (Join-Path $scriptDir 'marketplace.json'),
        (Join-Path (Split-Path $scriptDir) 'marketplace.json'),
        (Join-Path (Get-Location) 'marketplace.json')
    )

    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }

    # Download from GitHub
    Write-Info "marketplace.json not found locally, downloading..."
    $url = 'https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace.json'
    $tmp = Join-Path $env:TEMP 'marketplace.json'
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    return $tmp
}

function Find-RepoRoot {
    $scriptDir = $PSScriptRoot
    $candidates = @(
        (Split-Path $scriptDir),
        $scriptDir,
        (Get-Location).Path
    )

    foreach ($p in $candidates) {
        if ((Test-Path (Join-Path $p '.claude')) -and (Test-Path (Join-Path $p 'marketplace.json'))) {
            return $p
        }
    }

    # Clone the repo
    Write-Info "Repo not found locally, cloning from GitHub..."
    $tmp = Join-Path $env:TEMP "claude-code-octopus-$(Get-Random)"

    try {
        git clone --depth=1 'https://github.com/rouksonix/claude-code-octopus.git' $tmp 2>$null
        if ($LASTEXITCODE -eq 0) { return $tmp }
    } catch {}

    # Fallback: download zip
    Write-Info "git not available, downloading ZIP..."
    $zipUrl = 'https://github.com/rouksonix/claude-code-octopus/archive/refs/heads/main.zip'
    $zipPath = Join-Path $env:TEMP 'repo.zip'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
    $extracted = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like 'claude-code-octopus*' } | Select-Object -First 1
    return $extracted.FullName
}

# ── Actions ─────────────────────────────────────────────────────────────────

function Show-Items($data) {
    Write-Header
    Write-Host "Available Items:" -ForegroundColor White
    Write-Host ""

    foreach ($entry in @(
        @{ Type = 'agent';   Label = 'Agents' },
        @{ Type = 'command'; Label = 'Commands' },
        @{ Type = 'skill';   Label = 'Skills' }
    )) {
        $items = $data.items | Where-Object { $_.type -eq $entry.Type }
        $count = ($items | Measure-Object).Count
        Write-Host "$($entry.Label) ($count)" -ForegroundColor Cyan
        Write-Host ('-' * 60)
        foreach ($item in $items) {
            $support = @()
            if ($item.compatibility.'claude-code'.supported) { $support += 'CC' }
            if ($item.compatibility.codex.supported) { $support += 'Codex' }
            $supportStr = $support -join ', '
            Write-Host ("  {0,-45} [{1}]" -f $item.id, $supportStr)
            Write-Host "    $($item.description)" -ForegroundColor Gray
        }
        Write-Host ""
    }

    Write-Host "Total: $($data.stats.total) items" -ForegroundColor White
    Write-Host "  Claude Code: $($data.stats.claude_code_supported) supported"
    Write-Host "  Codex CLI:   $($data.stats.codex_supported) supported"
}

function Search-Items($data, $query) {
    Write-Header
    Write-Host "Search results for: $query"
    Write-Host ""

    $q = $query.ToLower()
    $found = 0

    foreach ($item in $data.items) {
        $nameMatch = $item.name.ToLower().Contains($q)
        $descMatch = $item.description.ToLower().Contains($q)
        $tagMatch  = ($item.tags | Where-Object { $_.ToLower().Contains($q) } | Measure-Object).Count -gt 0

        if ($nameMatch -or $descMatch -or $tagMatch) {
            $found++
            Write-Host "  [$($item.type)] $($item.id)" -ForegroundColor White
            Write-Host "    $($item.description)" -ForegroundColor Gray
            Write-Host "    Tags: $($item.tags -join ', ')" -ForegroundColor DarkGray
            Write-Host ""
        }
    }

    if ($found -eq 0) { Write-Warn "No items found matching '$query'" }
}

function Show-Categories($data) {
    Write-Header
    Write-Host "Categories:" -ForegroundColor White
    Write-Host ""
    foreach ($section in @('agents', 'commands', 'skills')) {
        Write-Host $section.Substring(0,1).ToUpper() + $section.Substring(1) -ForegroundColor Cyan
        $cats = $data.categories.$section
        foreach ($prop in $cats.PSObject.Properties) {
            $val = $prop.Value
            Write-Host ("  {0,-25} {1} {2}: {3}" -f $prop.Name, $val.icon, $val.label, $val.description)
        }
        Write-Host ""
    }
}

function Copy-MarketplaceItem($repoRoot, $src, $dst, $name, [bool]$dryRun) {
    $srcPath = Join-Path $repoRoot $src

    if ($dryRun) {
        Write-Info "[DRY RUN] Would copy: $src -> $dst"
        return $true
    }

    $dstDir = Split-Path $dst
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if (Test-Path $srcPath -PathType Container) {
        if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
        Copy-Item -Path $srcPath -Destination $dst -Recurse -Force
        Write-Ok "Installed $name -> $dst"
        return $true
    }
    elseif (Test-Path $srcPath -PathType Leaf) {
        Copy-Item -Path $srcPath -Destination $dst -Force
        Write-Ok "Installed $name -> $dst"
        return $true
    }
    else {
        Write-Err "Source not found: $srcPath"
        return $false
    }
}

function Install-MarketplaceItem($data, $repoRoot, $itemId, $targetCli, $targetDir, [bool]$dryRun) {
    $item = $data.items | Where-Object { $_.id -eq $itemId } | Select-Object -First 1
    if (-not $item) {
        Write-Err "Item not found: $itemId"
        return $false
    }

    $display = if ($item.displayName) { $item.displayName } else { $item.name }
    $installed = $false

    foreach ($entry in @(
        @{ Key = 'claude-code'; Short = 'claude' },
        @{ Key = 'codex';       Short = 'codex' }
    )) {
        if ($targetCli -ne 'both' -and $targetCli -ne $entry.Short) { continue }

        $compat = $item.compatibility.($entry.Key)
        if (-not $compat.supported) {
            if ($targetCli -ne 'both') { Write-Warn "$display is not supported for $($entry.Key)" }
            continue
        }

        $path = $compat.path
        if (-not $path) { continue }

        $dst = Join-Path $targetDir $path
        if (Copy-MarketplaceItem $repoRoot $path $dst "$display ($($entry.Key))" $dryRun) {
            $installed = $true
        }
    }

    return $installed
}

function Install-ByType($data, $repoRoot, $itemType, $targetCli, $targetDir, [bool]$dryRun) {
    $items = $data.items | Where-Object { $_.type -eq $itemType }
    $count = 0
    foreach ($item in $items) {
        if (Install-MarketplaceItem $data $repoRoot $item.id $targetCli $targetDir $dryRun) {
            $count++
        }
    }
    Write-Info "Installed $count $($itemType)(s)"
}

function Install-AllItems($data, $repoRoot, $targetCli, $targetDir, [bool]$dryRun) {
    Write-Header
    Write-Host "Installing all items for: $targetCli" -ForegroundColor White
    Write-Host "Target directory: $targetDir" -ForegroundColor White
    Write-Host ""

    foreach ($t in @('agent', 'command', 'skill')) {
        Install-ByType $data $repoRoot $t $targetCli $targetDir $dryRun
    }

    Write-Host ""
    Write-Ok "Installation complete!"
}

function Show-Help {
    Write-Header
    @"
AI Agents Marketplace Installer v$Version (PowerShell)

USAGE:
  .\marketplace\install.ps1 [options]

ACTIONS:
  -List              List all available items
  -ListCategories    List categories
  -Search <query>    Search items by name, tag, or description
  -All               Install everything
  -Agents            Install all agents
  -Commands          Install all commands
  -Skills            Install all skills
  -Item <id>         Install specific item
  -Category <name>   Install items in a category

OPTIONS:
  -Cli <target>      Target CLI: claude, codex, or both (default: both)
  -TargetDir <path>  Target directory (default: current directory)
  -DryRun            Preview without installing

EXAMPLES:
  .\marketplace\install.ps1 -List
  .\marketplace\install.ps1 -All -Cli claude -TargetDir C:\Projects\myapp
  .\marketplace\install.ps1 -Item agent-bug-detector
  .\marketplace\install.ps1 -Search security
  .\marketplace\install.ps1 -All -DryRun

ONE-LINER REMOTE INSTALL:
  irm https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.ps1 | iex
"@ | Write-Host
}

# ── Main ────────────────────────────────────────────────────────────────────

$marketplaceJson = Find-MarketplaceJson
$data = Get-Content $marketplaceJson -Raw | ConvertFrom-Json

if ($List)           { Show-Items $data; return }
if ($ListCategories) { Show-Categories $data; return }
if ($Search)         { Search-Items $data $Search; return }
if ($Help -or $PSCmdlet.ParameterSetName -eq 'Help') { Show-Help; return }

# Install actions need repo root
$repoRoot = Find-RepoRoot
$resolvedTarget = (Resolve-Path $TargetDir -ErrorAction SilentlyContinue) ?? $TargetDir

if ($All) {
    Install-AllItems $data $repoRoot $Cli $resolvedTarget $DryRun.IsPresent
}
elseif ($Agents) {
    Write-Header; Install-ByType $data $repoRoot 'agent' $Cli $resolvedTarget $DryRun.IsPresent
}
elseif ($Commands) {
    Write-Header; Install-ByType $data $repoRoot 'command' $Cli $resolvedTarget $DryRun.IsPresent
}
elseif ($Skills) {
    Write-Header; Install-ByType $data $repoRoot 'skill' $Cli $resolvedTarget $DryRun.IsPresent
}
elseif ($Item) {
    Write-Header; Install-MarketplaceItem $data $repoRoot $Item $Cli $resolvedTarget $DryRun.IsPresent
}
elseif ($Category) {
    Write-Header
    $items = $data.items | Where-Object { $_.category -eq $Category }
    if (-not $items) { Write-Err "No items in category: $Category"; return }
    Write-Host "Installing category: $Category" -ForegroundColor White
    $count = 0
    foreach ($i in $items) {
        if (Install-MarketplaceItem $data $repoRoot $i.id $Cli $resolvedTarget $DryRun.IsPresent) { $count++ }
    }
    Write-Info "Installed $count item(s) from '$Category'"
}
