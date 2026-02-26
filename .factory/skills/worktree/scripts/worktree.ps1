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

# Disable PS 7.4+ behavior where native command failures become terminating errors
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

# Constants (readonly)
Set-Variable -Name MAX_FILE_SIZE_BYTES -Value 10485760 -Option ReadOnly -Scope Script  # 10MB

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
    Write-Host $Message -ForegroundColor $Color
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
    # Compatible with .NET Framework 4.5+ (PowerShell 5.1 on older Windows)
    $epoch = [datetime]::new(1970, 1, 1, 0, 0, 0, [System.DateTimeKind]::Utc)
    return [long][math]::Floor(([datetime]::UtcNow - $epoch).TotalSeconds)
}

function Invoke-GitCommand {
    <#
    .SYNOPSIS
        Runs a git command safely, preventing stderr from becoming a terminating error.
    .DESCRIPTION
        PowerShell wraps stderr lines as ErrorRecord objects. With ErrorActionPreference=Stop,
        git's informational stderr messages (e.g. "Preparing worktree...") would throw exceptions
        before LASTEXITCODE can be checked. This helper temporarily sets Continue to avoid that.
    #>
    param([string[]]$Arguments)

    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $rawOutput = & git @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        # Convert ErrorRecord objects to strings
        $output = $rawOutput | ForEach-Object { $_.ToString() }
        return @{ Output = $output; ExitCode = $exitCode }
    }
    finally {
        $ErrorActionPreference = $prevEAP
    }
}

function Invoke-Cleanup {
    $pathToClean = $script:WorktreePathForCleanup
    $script:WorktreePathForCleanup = ""  # Prevent double cleanup

    if (-not $pathToClean) { return }
    if ($pathToClean.Length -lt 5) { return }  # Safety: prevent root deletion
    if (-not (Test-Path -LiteralPath $pathToClean)) { return }

    Write-Warn "Cleaning up partial worktree at: $pathToClean"
    try {
        $null = Invoke-GitCommand @("worktree", "remove", "--force", $pathToClean)
    }
    catch {}

    if (Test-Path -LiteralPath $pathToClean -PathType Container) {
        try { Remove-Item -LiteralPath $pathToClean -Recurse -Force -ErrorAction Stop }
        catch { Write-Warn "Warning: Could not fully clean up: $pathToClean" }
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

function Get-RelativePath {
    <#
    .SYNOPSIS
        Extracts a relative path from a full path given a base directory.
        Handles drive roots and trailing separators safely.
    #>
    param(
        [string]$FullPath,
        [string]$BaseDir
    )
    $normalizedBase = $BaseDir.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    return $FullPath.Substring($normalizedBase.Length)
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
    $result = Invoke-GitCommand @("rev-parse", "--git-dir")
    if ($result.ExitCode -ne 0) {
        throw "Not a git repository"
    }

    $result = Invoke-GitCommand @("rev-parse", "--show-toplevel")
    $sourceDir = ($result.Output | Select-Object -First 1).Trim()
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
    $result = Invoke-GitCommand @("check-ref-format", "--branch", $Branch)
    if ($result.ExitCode -ne 0) {
        throw "Invalid branch name: $Branch. Branch names cannot contain spaces, ~, ^, :, ?, *, [, or \"
    }

    Write-Info "Branch: $Branch"

    # Step 4: Resolve worktree path to absolute
    if (-not [System.IO.Path]::IsPathRooted($WorktreePath)) {
        $WorktreePath = Join-Path (Get-Location).Path $WorktreePath
    }
    $WorktreePath = [System.IO.Path]::GetFullPath($WorktreePath)
    Write-Info "Worktree path: $WorktreePath"

    # Step 5: Check if path exists
    if (Test-Path -LiteralPath $WorktreePath) {
        throw "Path already exists: $WorktreePath. Try a different path like ${WorktreePath}-2"
    }

    # Set up cleanup
    $script:WorktreePathForCleanup = $WorktreePath

    # Step 6: Check if branch exists
    $branchExists = $false
    $result = Invoke-GitCommand @("show-ref", "--verify", "--quiet", "refs/heads/$Branch")
    if ($result.ExitCode -eq 0) {
        $branchExists = $true
    }
    else {
        $result = Invoke-GitCommand @("show-ref", "--verify", "--quiet", "refs/remotes/origin/$Branch")
        if ($result.ExitCode -eq 0) {
            $branchExists = $true
        }
    }

    # Step 7: Create worktree
    Write-Host ""
    Write-Info "Creating git worktree..."

    if ($branchExists) {
        $result = Invoke-GitCommand @("worktree", "add", $WorktreePath, $Branch)
        if ($result.ExitCode -ne 0) {
            throw "Failed to create worktree: $($result.Output -join "`n")"
        }
        if ($result.Output) { $result.Output | ForEach-Object { Write-Host $_ } }
    }
    else {
        Write-Warn "Branch '$Branch' does not exist. Creating new branch..."
        $result = Invoke-GitCommand @("worktree", "add", "-b", $Branch, $WorktreePath)
        if ($result.ExitCode -ne 0) {
            throw "Failed to create worktree with new branch: $($result.Output -join "`n")"
        }
        if ($result.Output) { $result.Output | ForEach-Object { Write-Host $_ } }
    }

    Write-Success "Worktree created successfully"

    # Step 8: Parse .gitignore and find files to copy
    $gitignoreFile = Join-Path $sourceDir ".gitignore"
    $filesToCopy = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $skippedDirs = [System.Collections.Generic.List[string]]::new()
    [long]$totalSize = 0

    if (Test-Path -LiteralPath $gitignoreFile) {
        Write-Host ""
        Write-Info "Scanning gitignored files..."

        $patterns = Get-Content -LiteralPath $gitignoreFile -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
            $line = $_.Trim()
            # Skip comments, empty lines, negation patterns
            if (-not $line -or $line.StartsWith('#') -or $line.StartsWith('!')) { return }
            # Remove trailing slash
            $line = $line.TrimEnd('/')
            # Skip path patterns (contain / or \) — not supported by -Filter
            if ($line -match '[/\\]') { return }
            # Skip double-star patterns
            if ($line.Contains('**')) { return }
            # Strip leading / (root anchor — we search recursively anyway)
            $line = $line.TrimStart('/')
            $line
        } | Where-Object { $_ }

        foreach ($pattern in $patterns) {
            # Find matching files using Get-ChildItem with -Filter
            $foundFiles = @()
            try {
                # Search recursively, excluding blacklisted directories
                $foundFiles = Get-ChildItem -LiteralPath $sourceDir -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object {
                        $relPath = Get-RelativePath -FullPath $_.FullName -BaseDir $sourceDir
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
                if ($file.Length -gt $script:MAX_FILE_SIZE_BYTES) {
                    $relPath = Get-RelativePath -FullPath $file.FullName -BaseDir $sourceDir
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
            (Join-Path ".claude" "settings.local.json"),
            (Join-Path "config" "local.yaml"),
            (Join-Path "config" "local.yml"),
            (Join-Path "config" "local.json")
        )

        foreach ($config in $commonConfigs) {
            $configPath = Join-Path $sourceDir $config
            if (Test-Path -LiteralPath $configPath -PathType Leaf) {
                $fullPath = (Get-Item -LiteralPath $configPath).FullName
                if ($script:SeenFiles.Contains($fullPath)) { continue }
                [void]$script:SeenFiles.Add($fullPath)

                $fileInfo = Get-Item -LiteralPath $configPath
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
            $relPath = Get-RelativePath -FullPath $file.FullName -BaseDir $sourceDir
            $destPath = Join-Path $WorktreePath $relPath
            $destDir = Split-Path $destPath -Parent

            # Create parent directory
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }

            # Copy file and preserve timestamps
            try {
                Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
                # Preserve original timestamps (match bash cp -p behavior)
                $destItem = Get-Item -LiteralPath $destPath
                $destItem.LastWriteTime = $file.LastWriteTime
                $destItem.CreationTime = $file.CreationTime

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

# Run main with cleanup on any failure
# Main uses throw instead of exit 1, so all errors are caught here
try {
    Main
}
catch {
    Write-Err "Error: $_"
    Invoke-Cleanup
    exit 1
}
