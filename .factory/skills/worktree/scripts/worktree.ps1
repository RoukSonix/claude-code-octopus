#Requires -Version 5.1
<#
.SYNOPSIS
    Git Worktree with Gitignored Files Sync (Windows)

.DESCRIPTION
    Creates a git worktree and copies important gitignored files
    (configs, .env, IDE settings) while excluding heavy dependencies.

    Compatible with PowerShell 5.1+ (Windows built-in) and PowerShell 7+ (cross-platform).

.PARAMETER WorktreePath
    Path where the worktree will be created.
    Default: ..\worktrees\<repo-name>-<timestamp>

.PARAMETER Branch
    Branch name.
    Default: ai-worktree/<car-brand>-<timestamp>

.EXAMPLE
    .\worktree.ps1
    .\worktree.ps1 ..\my-feature
    .\worktree.ps1 ..\my-feature feature/new-auth
    .\worktree.ps1 C:\temp\worktree-test develop
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$WorktreePath = "",

    [Parameter(Position = 1)]
    [string]$Branch = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Constants
$MAX_FILE_SIZE_BYTES = 10485760  # 10MB

# Car brands for random branch naming
$CAR_BRANDS = @(
    "toyota", "honda", "ford", "chevrolet", "bmw", "mercedes", "audi", "volkswagen",
    "porsche", "ferrari", "lamborghini", "maserati", "jaguar", "lexus", "infiniti",
    "acura", "mazda", "subaru", "nissan", "hyundai", "kia", "volvo", "tesla", "rivian",
    "bentley", "rollsroyce", "aston", "mclaren", "bugatti", "pagani", "koenigsegg",
    "alpine", "lotus", "morgan", "mini", "fiat", "alfa", "lancia", "peugeot", "renault",
    "citroen", "skoda", "seat", "opel", "saab", "dacia", "suzuki", "mitsubishi"
)

# Blacklist of heavy directories (never copy these)
$BLACKLIST = @(
    "node_modules",
    ".venv",
    "venv",
    "__pycache__",
    ".cache",
    "dist",
    "build",
    ".git",
    ".tox",
    ".pytest_cache",
    ".mypy_cache",
    "coverage",
    ".next",
    ".nuxt",
    "vendor",
    ".terraform",
    "target",
    ".gradle",
    ".m2",
    "*.egg-info"
)

# Global tracking sets
$script:SeenFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$script:SeenDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Cleanup variable
$script:WorktreePathForCleanup = ""

# --- Helper Functions ---

function Write-ColorOutput {
    param(
        [string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::White
    )
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Message
    $Host.UI.RawUI.ForegroundColor = $prev
}

function Write-Info    { param([string]$Msg) Write-ColorOutput $Msg -Color Cyan }
function Write-Success { param([string]$Msg) Write-ColorOutput $Msg -Color Green }
function Write-Warn    { param([string]$Msg) Write-ColorOutput $Msg -Color Yellow }
function Write-Err     { param([string]$Msg) Write-ColorOutput $Msg -Color Red }

function Get-RandomCar {
    $index = Get-Random -Minimum 0 -Maximum $CAR_BRANDS.Count
    return $CAR_BRANDS[$index]
}

function Test-Blacklisted {
    param([string]$Name)
    foreach ($pattern in $BLACKLIST) {
        if ($Name -like $pattern) {
            return $true
        }
    }
    return $false
}

function Format-FileSize {
    param([long]$Size)
    if ($Size -lt 1024) {
        return "$Size B"
    }
    elseif ($Size -lt 1048576) {
        return "$([math]::Floor($Size / 1024)) KB"
    }
    else {
        return "$([math]::Floor($Size / 1048576)) MB"
    }
}

function Get-UnixTimestamp {
    return [long](([System.DateTimeOffset]::UtcNow).ToUnixTimeSeconds())
}

function Invoke-Cleanup {
    if ($script:WorktreePathForCleanup -and (Test-Path $script:WorktreePathForCleanup)) {
        Write-Warn "Cleaning up partial worktree at: $($script:WorktreePathForCleanup)"
        try {
            & git worktree remove --force $script:WorktreePathForCleanup 2>$null
        }
        catch {
            Remove-Item -Recurse -Force $script:WorktreePathForCleanup -ErrorAction SilentlyContinue
        }
    }
}

function Test-PathContainsBlacklisted {
    param([string]$RelativePath)

    $parts = $RelativePath -split '[/\\]'
    foreach ($part in $parts) {
        if ($part -and (Test-Blacklisted $part)) {
            return @{ Blocked = $true; DirName = $part }
        }
    }
    return @{ Blocked = $false; DirName = "" }
}

# --- Main Logic ---

function Main {
    # Handle --help
    if ($WorktreePath -eq "--help" -or $WorktreePath -eq "-h") {
        Write-Host "Usage: worktree.ps1 [worktree-path] [branch]"
        Write-Host ""
        Write-Host "Arguments:"
        Write-Host "  worktree-path  Path where the worktree will be created"
        Write-Host "                 Default: ..\worktrees\<repo-name>-<timestamp>"
        Write-Host "  branch         Branch name"
        Write-Host "                 Default: ai-worktree/<car-brand>-<timestamp>"
        Write-Host ""
        Write-Host "Example:"
        Write-Host "  .\worktree.ps1                                    # Auto-generate path and branch"
        Write-Host "  .\worktree.ps1 ..\my-feature                      # Auto-generate branch only"
        Write-Host "  .\worktree.ps1 ..\my-feature feature/auth         # Specify both"
        Write-Host "  .\worktree.ps1 C:\temp\worktree-test develop"
        return
    }

    # Step 1: Validate git repository
    $gitDir = & git rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Error: Not a git repository"
        exit 1
    }

    $sourceDir = (& git rev-parse --show-toplevel 2>&1).Trim()
    # Normalize to native path separators
    $sourceDir = [System.IO.Path]::GetFullPath($sourceDir)
    $repoName = Split-Path $sourceDir -Leaf
    $timestamp = Get-UnixTimestamp

    Write-Info "Source repository: $sourceDir"

    # Step 2: Generate default worktree path if not specified
    if (-not $WorktreePath) {
        $worktreesDir = Join-Path (Split-Path $sourceDir -Parent) "worktrees"
        $WorktreePath = Join-Path $worktreesDir "$repoName-$timestamp"
        Write-Warn "Using default path: $WorktreePath"
    }

    # Step 3: Generate default branch name if not specified
    if (-not $Branch) {
        $carBrand = Get-RandomCar
        $Branch = "ai-worktree/$carBrand-$timestamp"
        Write-Warn "Using generated branch: $Branch"
    }

    # Step 3.1: Validate branch name
    & git check-ref-format --branch $Branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Error: Invalid branch name: $Branch"
        Write-Warn "Branch names cannot contain spaces, ~, ^, :, ?, *, [, or \"
        exit 1
    }

    Write-Info "Branch: $Branch"

    # Step 4: Resolve worktree path to absolute
    if (-not [System.IO.Path]::IsPathRooted($WorktreePath)) {
        $WorktreePath = Join-Path (Get-Location).Path $WorktreePath
    }
    $WorktreePath = [System.IO.Path]::GetFullPath($WorktreePath)
    Write-Info "Worktree path: $WorktreePath"

    # Step 5: Check if path exists
    if (Test-Path $WorktreePath) {
        Write-Err "Error: Path already exists: $WorktreePath"
        Write-Warn "Suggestion: Try a different path like ${WorktreePath}-2"
        exit 1
    }

    # Set up cleanup
    $script:WorktreePathForCleanup = $WorktreePath

    # Step 6: Check if branch exists
    $branchExists = $false
    & git show-ref --verify --quiet "refs/heads/$Branch" 2>$null
    if ($LASTEXITCODE -eq 0) {
        $branchExists = $true
    }
    else {
        & git show-ref --verify --quiet "refs/remotes/origin/$Branch" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $branchExists = $true
        }
    }

    # Step 7: Create worktree
    Write-Host ""
    Write-Info "Creating git worktree..."

    try {
        if ($branchExists) {
            $output = & git worktree add $WorktreePath $Branch 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Error: Failed to create worktree"
                Write-Host $output
                Invoke-Cleanup
                exit 1
            }
            Write-Host $output
        }
        else {
            Write-Warn "Branch '$Branch' does not exist. Creating new branch..."
            $output = & git worktree add -b $Branch $WorktreePath 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Error: Failed to create worktree with new branch"
                Write-Host $output
                Invoke-Cleanup
                exit 1
            }
            Write-Host $output
        }
    }
    catch {
        Write-Err "Error: Failed to create worktree - $_"
        Invoke-Cleanup
        exit 1
    }

    Write-Success "Worktree created successfully"

    # Step 8: Parse .gitignore and find files to copy
    $gitignoreFile = Join-Path $sourceDir ".gitignore"
    $filesToCopy = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $skippedDirs = [System.Collections.Generic.List[string]]::new()
    [long]$totalSize = 0

    if (Test-Path $gitignoreFile) {
        Write-Host ""
        Write-Info "Scanning gitignored files..."

        $patterns = Get-Content $gitignoreFile -ErrorAction SilentlyContinue | ForEach-Object {
            $line = $_.Trim()
            # Skip comments, empty lines, negation patterns
            if (-not $line -or $line.StartsWith('#') -or $line.StartsWith('!')) { return }
            # Remove trailing slash
            $line = $line.TrimEnd('/')
            $line
        } | Where-Object { $_ }

        foreach ($pattern in $patterns) {
            # Find matching files using Get-ChildItem with wildcard
            $foundFiles = @()
            try {
                # Search recursively, excluding blacklisted directories
                $foundFiles = Get-ChildItem -Path $sourceDir -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object {
                        $relPath = $_.FullName.Substring($sourceDir.Length + 1)
                        $check = Test-PathContainsBlacklisted $relPath
                        if ($check.Blocked -and $check.DirName) {
                            if (-not $script:SeenDirs.Contains($check.DirName)) {
                                $skippedDirs.Add($check.DirName)
                                [void]$script:SeenDirs.Add($check.DirName)
                            }
                            return $false
                        }
                        return $true
                    }
            }
            catch {
                # Silently skip patterns that cause errors
                continue
            }

            foreach ($file in $foundFiles) {
                # Skip if already seen
                if ($script:SeenFiles.Contains($file.FullName)) { continue }
                [void]$script:SeenFiles.Add($file.FullName)

                # Skip files larger than MAX_FILE_SIZE_BYTES
                if ($file.Length -gt $MAX_FILE_SIZE_BYTES) {
                    $relPath = $file.FullName.Substring($sourceDir.Length + 1)
                    Write-Warn "  Skipping large file: $relPath ($(Format-FileSize $file.Length))"
                    continue
                }

                $filesToCopy.Add($file)
                $totalSize += $file.Length
            }
        }

        # Also explicitly look for common config files
        $commonConfigs = @(
            ".env",
            ".env.local",
            ".env.development",
            ".env.development.local",
            ".env.test",
            ".env.test.local",
            ".env.production.local",
            ".claude\settings.local.json",
            "config\local.yaml",
            "config\local.yml",
            "config\local.json"
        )

        foreach ($config in $commonConfigs) {
            $configPath = Join-Path $sourceDir $config
            if (Test-Path $configPath -PathType Leaf) {
                $fullPath = (Get-Item $configPath).FullName
                if ($script:SeenFiles.Contains($fullPath)) { continue }
                [void]$script:SeenFiles.Add($fullPath)

                $fileInfo = Get-Item $configPath
                $filesToCopy.Add($fileInfo)
                $totalSize += $fileInfo.Length
            }
        }
    }
    else {
        Write-Warn "No .gitignore found, skipping file sync"
    }

    # Step 9: Copy files
    $copiedCount = 0
    if ($filesToCopy.Count -gt 0) {
        Write-Host ""
        Write-Info "Copying gitignored files..."

        foreach ($file in $filesToCopy) {
            $relPath = $file.FullName.Substring($sourceDir.Length + 1)
            $destPath = Join-Path $WorktreePath $relPath
            $destDir = Split-Path $destPath -Parent

            # Create parent directory
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            # Copy file
            try {
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                $fileSize = $file.Length
                Write-Host "  " -NoNewline
                Write-ColorOutput "+ $relPath ($(Format-FileSize $fileSize))" -Color Green
                $copiedCount++
            }
            catch {
                Write-Host "  " -NoNewline
                Write-ColorOutput "x Failed to copy: $relPath" -Color Red
            }
        }
    }

    # Clear cleanup on success
    $script:WorktreePathForCleanup = ""

    # Step 10: Generate report
    Write-Host ""
    Write-Success "========================================"
    Write-Success "Git Worktree Created Successfully"
    Write-Success "========================================"
    Write-Host ""
    Write-Info "Worktree Details:"
    Write-Host "  Path:   $WorktreePath"
    Write-Host "  Branch: $Branch"
    Write-Host "  Source: $sourceDir"
    Write-Host ""

    if ($copiedCount -gt 0) {
        Write-Info "Copied Files:"
        Write-Host "  Total: $copiedCount files, $(Format-FileSize $totalSize)"
    }
    else {
        Write-Warn "No gitignored files were copied"
    }

    if ($skippedDirs.Count -gt 0) {
        Write-Host ""
        Write-Info "Excluded (heavy directories):"
        foreach ($dir in $skippedDirs) {
            Write-Host "  - $dir/ (skipped)"
        }
    }

    Write-Host ""
    Write-Info "Next Steps:"
    Write-Host "  1. cd $WorktreePath"
    Write-Host "  2. Install dependencies if needed:"
    Write-Host "     - Node.js: npm install / yarn / pnpm install"
    Write-Host "     - Python: pip install -r requirements.txt / poetry install"
    Write-Host "     - .NET: dotnet restore"
    Write-Host "     - Go: go mod download"
    Write-Host "  3. Start working on your changes"
}

# Run main with cleanup trap
try {
    Main
}
catch {
    Write-Err "Error: $_"
    Invoke-Cleanup
    exit 1
}
