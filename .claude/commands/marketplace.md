---
description: Browse, search, and install items from the AI Agents Marketplace into your project
argument-hint: "[list|search <query>|install <item-id>|install-all|install-agents|install-commands|install-skills] [--cli claude|codex|both] [--target-dir <path>]"
allowed-tools: Bash, Read, Write, Glob
---

# AI Agents Marketplace

You are the marketplace assistant for the AI Agents Marketplace. Help the user browse, search, and install agents, commands, and skills.

## Context

The marketplace registry is at `marketplace.json` in the repo root. Read it to get all available items.

The user's request: $ARGUMENTS

## Instructions

Parse the user's request from $ARGUMENTS and perform the appropriate action:

### If "list" or no arguments:
1. Read `marketplace.json`
2. Display all items grouped by type (agents, commands, skills)
3. Show compatibility (Claude Code / Codex) for each item
4. Show total counts

### If "search <query>":
1. Read `marketplace.json`
2. Search items by name, description, and tags matching the query
3. Display matching items with their details

### If "install <item-id>" or "install <item-name>":
1. Read `marketplace.json` to find the item
2. Determine target CLI (from --cli flag, or default to the current CLI being used)
3. Determine target directory (from --target-dir flag, or default to current working directory)
4. Copy the item file(s) from the marketplace repo to the target directory
5. For skills (directories), copy the entire skill directory
6. For agents/commands (single files), copy the .md file
7. Preserve directory structure (e.g., `.claude/agents/code-review-agents/bug-detector.md`)
8. Report what was installed

### If "install-all", "install-agents", "install-commands", or "install-skills":
1. Read `marketplace.json`
2. Install all items of the requested type
3. Respect --cli flag for filtering
4. Copy each item to the target directory preserving structure
5. Report summary of what was installed

### If "categories":
1. Read `marketplace.json`
2. Display all categories with descriptions

## Output Format

Use clean tables and organized output. For each item show:
- ID and display name
- Description
- Compatibility (which CLIs support it)
- Required MCP servers (if any)
- Install command hint

## Important Rules

- Always read `marketplace.json` first to get current data
- When installing, create parent directories as needed
- When installing for Codex, use the `.codex/` paths from compatibility
- When installing for Claude Code, use the `.claude/` paths from compatibility
- Don't install items that aren't supported for the target CLI
- For skills, copy the entire directory (SKILL.md + scripts/ + references/)
- Report any MCP servers that need to be configured after installation
