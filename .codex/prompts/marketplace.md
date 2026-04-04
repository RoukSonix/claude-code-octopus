---
description: Browse, search, and install items from the AI Agents Marketplace
---

# AI Agents Marketplace

Browse, search, and install agents, commands, and skills from the marketplace.

## Context

The marketplace registry is at `marketplace.json` in the repository root. Read it to understand all available items.

The user's request: $ARGUMENTS

## Instructions

Parse $ARGUMENTS to determine the action:

### "list" or empty:
- Read `marketplace.json`
- Display all items grouped by type (agents, commands, skills)
- Show Codex compatibility for each item
- Show total counts

### "search <query>":
- Read `marketplace.json`
- Search items matching query in name, description, or tags
- Display matching items with details

### "install <item-id>":
- Read `marketplace.json` to find the item
- Check if item has Codex compatibility (look for `.codex/` path)
- Copy the file(s) to current project directory
- For skills: copy entire directory (SKILL.md + scripts/ + references/)
- For commands: copy the .md file to `.codex/prompts/`
- Preserve directory structure
- Report what was installed and any required MCP servers

### "install-all" / "install-commands" / "install-skills":
- Read `marketplace.json`
- Install all Codex-compatible items of the requested type
- Copy each to current project preserving structure
- Report summary

### "categories":
- Show all available categories

## Important

- Only install items that have `codex` compatibility marked as `supported: true`
- When an item doesn't have Codex support, tell the user it's Claude Code only
- Skills are directories, commands are single .md files
- Always report required MCP servers after installation
