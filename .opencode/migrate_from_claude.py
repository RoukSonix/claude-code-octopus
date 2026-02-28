#!/usr/bin/env python3
"""
Migration script to convert Claude Code agents and commands to OpenCode format.

This script transforms:
1. Agents from .claude/agents/ to .opencode/agent/
2. Commands from .claude/commands/ to .opencode/command/

Key transformations:
- Flatten directory structure
- Transform YAML frontmatter format
- Convert tools array to boolean map
- Add OpenCode-specific fields (mode, permission)
- Adapt orchestration syntax (Task tool → @ mentions)
"""

import re
import yaml
from pathlib import Path
from typing import Dict, List, Any

# Agents that need Write permission (create analysis artifacts)
WRITE_AGENTS = {
    'planning-implementation',
    'codebase-analyzer',
    'planning-quality-advisor',
    'planning-security-architect',
    'planning-testing-strategist',
    'planning-ci-cd',
    'planning-performance-architect',
    'planning-bug-prevention',
    'planning-documentation',
}

def parse_frontmatter(content: str) -> tuple[Dict[str, Any], str]:
    """Extract YAML frontmatter and content from markdown file."""
    match = re.match(r'^---\n(.*?)\n---\n(.*)$', content, re.DOTALL)
    if not match:
        return {}, content

    frontmatter_str, body = match.groups()
    frontmatter = yaml.safe_load(frontmatter_str)
    return frontmatter, body

def tools_array_to_map(tools: List[str]) -> Dict[str, bool]:
    """Convert Claude Code tools array to OpenCode boolean map."""
    tools_map = {}
    for tool in tools:
        # Normalize tool name to lowercase
        tool_lower = tool.lower()
        tools_map[tool_lower] = True
    return tools_map

def transform_agent_frontmatter(frontmatter: Dict[str, Any], filename: str) -> Dict[str, Any]:
    """Transform Claude Code agent frontmatter to OpenCode format."""
    agent_name = frontmatter.get('name', filename.replace('.md', ''))

    opencode_fm = {
        'description': frontmatter.get('description', ''),
        'mode': 'primary',
    }

    # Transform tools
    if 'tools' in frontmatter:
        opencode_fm['tools'] = tools_array_to_map(frontmatter['tools'])

    # Add permissions based on whether agent needs Write access.
    # OpenCode uses two layers: tools (bool on/off) and permission (allow/ask/deny).
    # permission.edit controls all file modifications (write, patch, multiedit).
    # permission.bash controls shell command execution with glob patterns.
    if agent_name in WRITE_AGENTS:
        opencode_fm['permission'] = {
            'edit': 'allow',
            'bash': {'*': 'allow'},
        }
    else:
        opencode_fm['permission'] = {
            'edit': 'deny',
            'bash': {'*': 'ask'},
        }

    return opencode_fm

def transform_command_frontmatter(frontmatter: Dict[str, Any]) -> Dict[str, Any]:
    """Transform Claude Code command frontmatter to OpenCode format."""
    opencode_fm = {}

    # Keep description
    if 'description' in frontmatter:
        opencode_fm['description'] = frontmatter['description']

    # Keep model if specified
    if 'model' in frontmatter:
        opencode_fm['model'] = frontmatter['model']

    # Add default permissions for commands
    opencode_fm['permission'] = {
        'bash': {
            'git *': 'allow',
            'mkdir *': 'allow',
            '*': 'ask'
        }
    }

    return opencode_fm

def adapt_command_orchestration(body: str) -> str:
    """Adapt command body from Claude Code Task tool to OpenCode @ mentions."""
    # Replace Task tool calls with @ mention syntax
    # Pattern: Task tool with subagent_type="agent-name"
    # Replacement: @agent-name

    # Match various Task tool patterns
    patterns = [
        (r'Use Task tool with subagent_type="([^"]+)":', r'@\1'),
        (r'Task\(.*?subagent_type="([^"]+)".*?\)', r'@\1'),
        (r'subagent_type="([^"]+)"', r'@\1'),
    ]

    adapted = body
    for pattern, replacement in patterns:
        adapted = re.sub(pattern, replacement, adapted)

    # Update parallel execution notes
    adapted = adapted.replace(
        'Launch agents in parallel',
        'Launch agents sequentially (OpenCode limitation)'
    )
    adapted = adapted.replace(
        'run simultaneously',
        'run sequentially'
    )
    adapted = adapted.replace(
        'parallel execution',
        'sequential execution'
    )

    return adapted

def migrate_agent(source_path: Path, target_dir: Path):
    """Migrate a single agent file."""
    filename = source_path.name
    print(f"  Migrating agent: {filename}")

    with open(source_path, 'r', encoding='utf-8') as f:
        content = f.read()

    frontmatter, body = parse_frontmatter(content)
    new_frontmatter = transform_agent_frontmatter(frontmatter, filename)

    # Reconstruct file with new frontmatter
    new_content = f"---\n{yaml.dump(new_frontmatter, default_flow_style=False, allow_unicode=True)}---\n{body}"

    target_path = target_dir / filename
    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"    ✓ Saved to: {target_path}")

def migrate_command(source_path: Path, target_dir: Path):
    """Migrate a single command file."""
    filename = source_path.name
    print(f"  Migrating command: {filename}")

    with open(source_path, 'r', encoding='utf-8') as f:
        content = f.read()

    frontmatter, body = parse_frontmatter(content)
    new_frontmatter = transform_command_frontmatter(frontmatter)
    adapted_body = adapt_command_orchestration(body)

    # Reconstruct file with new frontmatter and adapted body
    new_content = f"---\n{yaml.dump(new_frontmatter, default_flow_style=False, allow_unicode=True)}---\n{adapted_body}"

    target_path = target_dir / filename
    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"    ✓ Saved to: {target_path}")

def main():
    """Main migration function."""
    print("=" * 60)
    print("Claude Code → OpenCode Migration Script")
    print("=" * 60)

    # Setup paths
    project_root = Path(__file__).parent.parent
    claude_agents_dir = project_root / '.claude' / 'agents'
    claude_commands_dir = project_root / '.claude' / 'commands'
    opencode_agent_dir = project_root / '.opencode' / 'agent'
    opencode_command_dir = project_root / '.opencode' / 'command'

    # Ensure target directories exist
    opencode_agent_dir.mkdir(parents=True, exist_ok=True)
    opencode_command_dir.mkdir(parents=True, exist_ok=True)

    # Migrate agents
    print("\n📦 Migrating Agents...")
    print("-" * 60)

    agent_count = 0
    for category_dir in claude_agents_dir.iterdir():
        if category_dir.is_dir():
            for agent_file in category_dir.glob('*.md'):
                migrate_agent(agent_file, opencode_agent_dir)
                agent_count += 1

    # Also migrate top-level agents
    for agent_file in claude_agents_dir.glob('*.md'):
        migrate_agent(agent_file, opencode_agent_dir)
        agent_count += 1

    print(f"\n✅ Migrated {agent_count} agents")

    # Migrate commands
    print("\n📦 Migrating Commands...")
    print("-" * 60)

    command_count = 0
    for namespace_dir in claude_commands_dir.iterdir():
        if namespace_dir.is_dir():
            for command_file in namespace_dir.glob('*.md'):
                migrate_command(command_file, opencode_command_dir)
                command_count += 1

    # Also migrate top-level commands
    for command_file in claude_commands_dir.glob('*.md'):
        migrate_command(command_file, opencode_command_dir)
        command_count += 1

    print(f"\n✅ Migrated {command_count} commands")

    # Summary
    print("\n" + "=" * 60)
    print("Migration Complete!")
    print("=" * 60)
    print(f"Total agents migrated:   {agent_count}")
    print(f"Total commands migrated: {command_count}")
    print(f"\nOutput directories:")
    print(f"  Agents:   {opencode_agent_dir}")
    print(f"  Commands: {opencode_command_dir}")
    print("\nNext steps:")
    print("  1. Review migrated files in .opencode/")
    print("  2. Test commands with OpenCode CLI")
    print("  3. Update documentation (CLAUDE.md, AGENTS.md)")
    print("=" * 60)

if __name__ == '__main__':
    main()
