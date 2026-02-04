---
name: worktree
description: Create git worktree with automatic sync of gitignored files (configs, .env, IDE settings). Use when setting up parallel development environments or working on multiple branches simultaneously.
argument-hint: "<worktree-path> [branch]"
allowed-tools: Bash(bash *), Bash(git *), Read, Glob
disable-model-invocation: true
---

# Git Worktree with Gitignored Files Sync

Create a git worktree and automatically copy important gitignored files (configs, .env, IDE settings) while excluding heavy dependencies like node_modules.

## Usage

Run the worktree script:

```bash
bash ~/.claude/skills/worktree/scripts/worktree.sh $ARGUMENTS
```

Or if installed in project:

```bash
bash .claude/skills/worktree/scripts/worktree.sh $ARGUMENTS
```

## What This Skill Does

1. **Validates** the current directory is a git repository
2. **Creates** a new git worktree at the specified path
3. **Parses** .gitignore to find files that should be synced
4. **Copies** important config files while excluding heavy directories
5. **Reports** what was copied and provides next steps

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

- `worktree-path` (required): Path where the worktree will be created
- `branch` (optional): Branch name. Defaults to current branch. Creates new branch if doesn't exist.

## Examples

```bash
# Create worktree for a feature branch
/worktree ../my-repo-feature feature/new-auth

# Create worktree using current branch
/worktree ../my-repo-bugfix

# Create worktree with absolute path
/worktree /tmp/worktree-test develop

# Create worktree with new branch (auto-created)
/worktree ../experiment experiment/new-idea
```

## Output Example

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

## Error Handling

| Situation | Behavior |
|-----------|----------|
| Not a git repository | Error message, exit |
| Path already exists | Error with suggestion for alternative path |
| Branch doesn't exist | Automatically creates new branch |
| No .gitignore | Creates worktree without file sync |
| File copy fails | Warning, continues with other files |
| File > 10MB | Skipped with warning |
