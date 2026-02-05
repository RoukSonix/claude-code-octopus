# OpenCode Configuration

This directory contains OpenCode CLI agents and commands, migrated from Claude Code format for compatibility with the [OpenCode](https://opencode.ai) multi-CLI toolkit.

## Directory Structure

```
.opencode/
├── agent/                    # All agents (flat structure)
│   ├── planning-*.md        # 10 planning agents
│   ├── *-reviewer.md        # 5 code review agents
│   └── *.md                 # 4 utility agents
├── command/                  # All commands (flat structure)
│   ├── agentic-*.md         # Multi-agent orchestration commands
│   ├── *-review.md          # Code review commands
│   └── *.md                 # Testing, research, utility commands
├── skills/                   # Skills with shell scripts
│   └── worktree/            # Git worktree skill
│       ├── SKILL.md         # Skill definition
│       └── scripts/         # Shell scripts
│           └── worktree.sh  # Main worktree script
├── migrate_from_claude.py   # Migration script
└── README.md                # This file
```

## Available Agents (19 total)

### Planning Agents (10)
- **planning-implementation** - Architecture design and implementation roadmaps with Context7
- **planning-quality-advisor** - Architecture patterns and code quality analysis
- **planning-security-architect** - Security design, authentication flows
- **planning-testing-strategist** - Test strategy and coverage planning
- **planning-ci-cd** - CI/CD pipeline analysis (Jenkins, GitHub Actions, GitLab)
- **planning-performance-architect** - Performance optimization strategies
- **planning-bug-prevention** - Edge case identification before implementation
- **planning-documentation** - Documentation planning for changes
- **planning-best-practices** - Post-implementation best practices review
- **codebase-analyzer** - Deep codebase structure analysis

### Code Review Agents (5)
- **code-quality-reviewer** - Best practices, maintainability, SOLID principles
- **bug-detector** - Bug detection, edge cases, logic errors
- **performance-reviewer** - Performance bottlenecks, optimization opportunities
- **security-reviewer** - Security vulnerabilities, secure coding practices
- **testing-reviewer** - Test coverage, test quality assessment

### Utility Agents (4)
- **confluence-searcher** - Atlassian Confluence search via MCP
- **pdf-analyzer** - PDF document analysis with memory persistence
- **memory-manager** - MCP memory operations and compilation
- **lint-type-checker** - Background linting and type checking

## Available Commands (21 total)

### Planning Commands
- **/jira-task-analyze** - Single-agent JIRA analysis
- **/agentic-jira-task-analyze** - Multi-agent JIRA analysis with codebase deep dive
- **/github-issue-analyze** - Single-agent GitHub Issue analysis using gh CLI
- **/agentic-github-issue-analyze** - Multi-agent GitHub Issue analysis with codebase deep dive
- **/agentic-plan-implementation** - Comprehensive planning with Context7 research

### Code Review Commands
- **/pr-review** - Multi-agent PR review (GitHub/Bitbucket)
- **/agentic-code-review** - Sequential specialized reviews for staged changes
- **/quality-code-review** - Best practices focused review
- **/commit-review-by-hash-id** - Review specific commits
- **/non-agentic-precommit-review** - Direct review without sub-agents

### Testing Commands
- **/test-app-playwright** - MCP Playwright integration for testing
- **/use-playwright-mcp** - Playwright best practices research
- **/use-chrome-devtools-mcp** - Chrome DevTools MCP research

### Research Commands
- **/use-context7** - Context7 integration for best practices
- **/find-solution** - Multi-source documentation research

### Utility Commands
- **/add-memory** - Store observations in MCP memory
- **/read-memory** - Retrieve stored knowledge
- **/analyze-docs** - PDF and Confluence document analysis
- **/create-commit** - Create git commits with staged changes
- **/quality-check-python** - Python code quality checks
- **/translate-jira-issue-english** - Translate JIRA issues to English

## Usage with OpenCode CLI

### Invoking Agents

Agents are invoked using `@` mention syntax:

```bash
@planning-implementation Create implementation plan for user authentication feature
```

### Running Commands

Commands are invoked with `/` prefix:

```bash
# Analyze JIRA task
/agentic-jira-task-analyze PROJ-123

# Analyze GitHub Issue (with issue number)
/github-issue-analyze 123

# Analyze GitHub Issue (with URL)
/agentic-github-issue-analyze https://github.com/owner/repo/issues/456

# Review pull request
/pr-review 456

# Use Context7 for research
/use-context7 FastAPI authentication
```

### Agent Orchestration

OpenCode commands use sequential agent execution (unlike Claude Code's parallel execution):

```bash
# This command will run agents one after another:
/agentic-jira-task-analyze PROJ-123
# 1. @codebase-analyzer runs first
# 2. @planning-implementation runs after codebase analysis completes
# 3. Optional agents run if needed
```

## Key Differences from Claude Code

### 1. Flat Directory Structure
- **Claude Code**: Nested structure (`.claude/agents/planning-agents/`)
- **OpenCode**: Flat structure (`.opencode/agent/`)

### 2. Command Naming
- **Claude Code**: Namespace-based (`/planning:jira-task-analyze`)
- **OpenCode**: Hyphenated (`/jira-task-analyze`)

### 3. Agent Invocation
- **Claude Code**: `Task(subagent_type="agent-name")`
- **OpenCode**: `@agent-name`

### 4. Execution Model
- **Claude Code**: Parallel agent execution supported
- **OpenCode**: Sequential execution only (performance impact: ~40-50% slower)

### 5. Permission Model
- **Claude Code**: Tool-based (`allowed-tools: Task, Read, Write`)
- **OpenCode**: Permission-based (tri-state: allow/ask/deny with bash granularity)

### 6. Tool Specification
- **Claude Code**: Array format (`tools: [Read, Write, Grep]`)
- **OpenCode**: Boolean map (`tools: {read: true, write: true, grep: true}`)

## Frontmatter Format

### Agent Frontmatter
```yaml
---
description: "Brief explanation of agent purpose"
mode: primary
tools:
  read: true
  write: true
  grep: true
  mcp__context7__*: true
permission:
  bash:
    "*": allow  # For agents that create artifacts
---
```

### Command Frontmatter
```yaml
---
description: "Command description"
permission:
  bash:
    "git *": allow
    "mkdir *": allow
    "*": ask
---
```

## Permission Strategy

### Agents with Write Permission (9 agents)
These agents create analysis artifacts and need write access:
- planning-implementation
- codebase-analyzer
- planning-quality-advisor
- planning-security-architect
- planning-testing-strategist
- planning-ci-cd
- planning-performance-architect
- planning-bug-prevention
- planning-documentation

**Permission**: `bash."*": allow` + `write: true`

### Other Agents (10 agents)
Review and analysis agents use conservative defaults:

**Permission**: `bash."*": ask`

## MCP Integration

All agents and commands support MCP (Model Context Protocol) tools:

- **Atlassian MCP** (`mcp__atlassian__*`): JIRA, Confluence integration
- **Context7 MCP** (`mcp__context7__*`): Documentation and best practices
- **Filesystem MCP** (`mcp__filesystem__*`): Deep codebase analysis
- **Memory MCP** (`mcp__memory__*`): Knowledge persistence
- **Playwright MCP** (`mcp__playwright__*`): Browser automation

## Migration from Claude Code

If you make changes to agents/commands in `.claude/` and want to sync to OpenCode:

```bash
# Run the migration script
python3 .opencode/migrate_from_claude.py
```

This will:
1. Read all agents from `.claude/agents/**/*.md`
2. Read all commands from `.claude/commands/**/*.md`
3. Transform frontmatter and content to OpenCode format
4. Write to `.opencode/agent/` and `.opencode/command/`

## Working with Context7

All agents are Context7-aware for up-to-date documentation:

```bash
@planning-implementation Research FastAPI best practices using Context7 before creating plan
```

The agent will:
1. Resolve library IDs using `mcp__context7__resolve-library-id`
2. Fetch 15000+ tokens of documentation using `mcp__context7__get-library-docs`
3. Apply current patterns and avoid deprecated approaches

## Testing

Before using in production:

1. **Test agent invocation**:
   ```bash
   @code-quality-reviewer Review this file: src/main.py
   ```

2. **Test command execution**:
   ```bash
   /use-context7 TypeScript async patterns
   ```

3. **Test multi-agent orchestration**:
   ```bash
   /agentic-jira-task-analyze TEST-123
   ```

## Troubleshooting

### Agent not found
- Verify file exists in `.opencode/agent/`
- Check filename matches agent name (e.g., `planning-implementation.md`)
- Ensure frontmatter has valid `description` field

### Command not found
- Verify file exists in `.opencode/command/`
- Check filename matches command name
- Ensure frontmatter has valid YAML syntax

### Permission denied errors
- Review `permission.bash` settings in frontmatter
- For write operations, ensure `bash."*": allow` is set
- Check file system permissions on target directories

### Sequential execution too slow
- Consider breaking down large tasks into smaller chunks
- Use caching strategies in commands
- Prioritize critical agents only

## Contributing

When adding new agents or commands:

1. Create in `.claude/` first (for consistency with project structure)
2. Test in Claude Code
3. Run migration script to sync to OpenCode
4. Test in OpenCode CLI
5. Document any OpenCode-specific limitations

## GitHub Issue Commands

Two new commands have been added to analyze GitHub Issues using the `gh` CLI instead of JIRA:

### `/github-issue-analyze`

Single-agent comprehensive analysis of GitHub Issues.

**Features:**
- Auto-detection of input format (issue number or full URL)
- Uses `gh` CLI for fetching issue data
- Context7 integration for best practices research
- Detailed implementation plan with architecture design
- Conditional deep-dive analysis for security/performance/testing

**Usage:**
```bash
# With issue number (uses current repository)
/github-issue-analyze 123

# With full URL
/github-issue-analyze https://github.com/owner/repo/issues/456
```

**Requirements:**
- `gh` CLI installed and authenticated (`gh auth login`)
- Read access to the repository and issue

**Output:**
```
working-docs/
└── analysis/
    └── issue-123/
        ├── github-issue.md
        └── IMPLEMENTATION-PLAN.md
```

### `/agentic-github-issue-analyze`

Multi-agent analysis with specialized agents for different aspects.

**Features:**
- Sequential execution of specialized agents:
  - `@codebase-analyzer` - Deep codebase structure analysis
  - `@planning-implementation` - Architecture and implementation plan
  - `@planning-testing-strategist` - Testing strategy (conditional)
  - `@planning-security-architect` - Security design (conditional)
- Context7 research integrated into all agents
- Comprehensive final plan compilation
- 30-50% faster than previous multi-group approach

**Usage:**
```bash
# With issue number
/agentic-github-issue-analyze 789

# With URL
/agentic-github-issue-analyze https://github.com/myorg/myrepo/issues/101
```

**Output:**
```
working-docs/
└── analysis/
    └── issue-789/
        ├── github-issue.md
        ├── codebase-analysis.md
        ├── implementation-draft.md
        ├── testing-strategy.md (optional)
        ├── security-architecture.md (optional)
        └── IMPLEMENTATION-PLAN.md
```

### Comparison: JIRA vs GitHub Commands

| Feature | JIRA Commands | GitHub Commands |
|---------|--------------|-----------------|
| **Data Source** | MCP Atlassian | `gh` CLI |
| **Input Format** | Issue key or URL | Issue number or URL |
| **Authentication** | MCP server config | `gh auth login` |
| **Path Structure** | `working-docs/analysis/PROJ-123/` | `working-docs/analysis/issue-123/` |
| **Issue Fields** | description, acceptance criteria | body (parsed for criteria) |
| **Labels** | JIRA labels | GitHub labels |
| **Assignees** | JIRA assignees | GitHub assignees |
| **Milestones** | JIRA sprint/epic | GitHub milestone |
| **Comments** | Can add to JIRA (optional) | Local files only |

### GitHub Issue Body Parsing

GitHub Issue commands parse the issue body to extract:

- **Description**: Full issue body content
- **Acceptance Criteria**: Detected from:
  - Checklist items (`- [ ]` / `- [x]`)
  - Sections marked with `## Acceptance Criteria`
  - Sections marked with `## Requirements`
- **Labels**: Used for categorization and complexity analysis
- **Milestone**: Target release/sprint information

### Error Handling

**Invalid reference:**
```
❌ Error: Invalid GitHub Issue reference.
Please provide a valid GitHub Issue URL or issue number (123).
```

**gh CLI not available:**
```
❌ Error: GitHub CLI (gh) is not available or not authenticated.
Please install gh CLI and authenticate: gh auth login
```

**Access denied:**
```
❌ Error: Access denied to GitHub Issue #123.
Please ensure you have read access to the repository.
```

### Testing GitHub Commands

```bash
# 1. Verify gh CLI is installed and authenticated
gh auth status

# 2. Test with a public repository issue
/github-issue-analyze https://github.com/facebook/react/issues/12345

# 3. Test with private repository (requires auth)
/agentic-github-issue-analyze 456

# 4. Review generated files
ls -la working-docs/analysis/issue-*/
```

## Skills

OpenCode supports skills - shell script-based automation that executes deterministically without model invocation.

### Available Skills

#### `/worktree` - Git Worktree with Config Sync

Create a git worktree and automatically copy important gitignored files (configs, .env, IDE settings).

**Usage:**
```bash
# Auto-generate both path and branch
/worktree

# Specify path only
/worktree ../my-feature

# Specify both path and branch
/worktree ../my-feature feature/new-auth
```

**What it does:**
1. Validates git repository
2. Creates worktree at specified path
3. Parses .gitignore to find files to sync
4. Copies config files (excludes node_modules, .venv, etc.)
5. Reports what was copied

**Copied files:** `.env*`, `.claude/settings.local.json`, `config/local.*`

**Excluded:** `node_modules/`, `.venv/`, `__pycache__/`, `dist/`, `build/`, etc.

### Skills Discovery

OpenCode discovers skills from multiple locations:
- `.opencode/skills/<name>/SKILL.md` (project-specific)
- `.claude/skills/<name>/SKILL.md` (auto-reads Claude skills!)
- `~/.config/opencode/skills/` (global)
- `~/.claude/skills/` (global, shared with Claude Code)

## Documentation

- **Claude Code Specific**: See `CLAUDE.md` in project root
- **Multi-CLI General**: See `AGENTS.md` in project root
- **OpenCode Docs**: https://opencode.ai/docs/
- **GitHub CLI Docs**: https://cli.github.com/manual/

## License

Same as parent project (Code Agent Octopus).
