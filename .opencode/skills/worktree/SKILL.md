---
name: worktree
description: Create git worktree with automatic sync of gitignored files (configs, .env, IDE settings). Use when setting up parallel development environments or working on multiple branches simultaneously.
argument-hint: "[worktree-path] [branch]"
license: MIT
compatibility: opencode
---

# Git Worktree with Gitignored Files Sync

Create a git worktree and automatically copy important gitignored files (configs, .env, IDE settings) while excluding heavy dependencies like node_modules.

## Platform Support

This skill works on **macOS**, **Linux**, and **Windows**:

| OS | Script | Shell |
|----|--------|-------|
| macOS / Linux | `worktree.sh` | Bash 3.2+ |
| Windows | `worktree.ps1` | PowerShell 5.1+ |

## Usage

### macOS / Linux

```bash
bash .opencode/skills/worktree/scripts/worktree.sh $ARGUMENTS
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy RemoteSigned -File .opencode\skills\worktree\scripts\worktree.ps1 $ARGUMENTS
```

## What This Skill Does

1. **Validates** the current directory is a git repository
2. **Generates** default path and branch if not specified
3. **Creates** a new git worktree at the specified path
4. **Parses** .gitignore to find files that should be synced
5. **Copies** important config files while excluding heavy directories
6. **Reports** what was copied and provides next steps

## Copied Files (from .gitignore)

The script copies gitignored files that are typically needed for local development:
- `.env`, `.env.local`, `.env.development`, etc.
- `.claude/settings.local.json`
- Local config files (`config/local.*`, `*.local.*`)
- IDE local settings

## Excluded (Never Copied)

Heavy directories are always excluded:
- `node_modules/`
- `.venv/`, `venv/`
- `__pycache__/`
- `dist/`, `build/`
- `.cache/`, `.pytest_cache/`, `.mypy_cache/`
- `.next/`, `.nuxt/`
- `vendor/`, `target/`
- Files larger than 10MB

## Arguments

- `worktree-path` (optional): Path where the worktree will be created
  - Default: `../worktrees/<repo-name>-<unix-timestamp>`
- `branch` (optional): Branch name
  - Default: `ai-worktree/<random-car-brand>-<unix-timestamp>`
  - Creates new branch if doesn't exist

## Examples

```bash
# Auto-generate both path and branch (simplest usage)
/worktree
# Creates: ../worktrees/my-project-1738680000
# Branch: ai-worktree/ferrari-1738680000

# Specify path only, auto-generate branch
/worktree ../my-feature
# Creates: ../my-feature
# Branch: ai-worktree/toyota-1738680000

# Specify both path and branch
/worktree ../my-repo-feature feature/new-auth

# Absolute path with specific branch
/worktree /tmp/worktree-test develop
```

## Output Example (macOS/Linux)

```
Source repository: /Users/dev/my-project
Branch: feature/auth
Worktree path: /Users/dev/my-project-feature

Creating git worktree...
Worktree created successfully

Scanning gitignored files...
Copying gitignored files...
  + .env (234 B)
  + .env.local (128 B)
  + .claude/settings.local.json (1 KB)

========================================
Git Worktree Created Successfully
========================================

Worktree Details:
  Path:   /Users/dev/my-project-feature
  Branch: feature/auth
  Source: /Users/dev/my-project

Copied Files:
  Total: 3 files, 1 KB

Excluded (heavy directories):
  - node_modules/ (skipped)
  - .venv/ (skipped)

Next Steps:
  1. cd /Users/dev/my-project-feature
  2. Install dependencies if needed
  3. Start working on your changes
```

## Output Example (Windows)

```
Source repository: C:\Users\dev\my-project
Branch: feature/auth
Worktree path: C:\Users\dev\my-project-feature

Creating git worktree...
Worktree created successfully

Scanning gitignored files...
Copying gitignored files...
  + .env (234 B)
  + .env.local (128 B)
  + .claude\settings.local.json (1 KB)

========================================
Git Worktree Created Successfully
========================================

Worktree Details:
  Path:   C:\Users\dev\my-project-feature
  Branch: feature/auth
  Source: C:\Users\dev\my-project

Copied Files:
  Total: 3 files, 1 KB

Next Steps:
  1. cd C:\Users\dev\my-project-feature
  2. Install dependencies if needed
  3. Start working on your changes
```

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Not a git repository | Error message, exit |
| Path already exists | Error with suggestion for alternative path |
| Branch doesn't exist | Automatically creates new branch |
| No .gitignore | Creates worktree without file sync |
| File copy fails | Warning, continues with other files |
| File > 10MB | Skipped with warning |
