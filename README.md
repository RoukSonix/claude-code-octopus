# AI Agents Marketplace

Open marketplace of production-ready **agents**, **commands**, and **skills** for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Codex CLI](https://developers.openai.com/codex/cli).

**43 items** | **19 agents** | **20 commands** | **4 skills** | **2 CLIs supported**

---

## What's Inside

| Type | Claude Code | Codex CLI | Description |
|------|:-----------:|:---------:|-------------|
| **Agents** | 19 | — | Autonomous specialists: planning, code review, security, analysis |
| **Commands** | 20 | 8 | Guided workflows: JIRA analysis, PR review, testing, research |
| **Skills** | 4 | 4 | Reusable scripts and AI workflows: worktree, test runner, migration |

## Quick Install

```bash
# Clone the marketplace
git clone https://github.com/rouksonix/claude-code-octopus.git
cd claude-code-octopus

# Install everything into your project
./marketplace/install.sh --all --target-dir ~/my-project

# Or install selectively
./marketplace/install.sh --agents --cli claude --target-dir ~/my-project
./marketplace/install.sh --skills --target-dir ~/my-project
./marketplace/install.sh --item agent-bug-detector --target-dir ~/my-project
```

Or copy manually:

```bash
# Copy a single agent
cp .claude/agents/code-review-agents/bug-detector.md ~/my-project/.claude/agents/code-review-agents/

# Copy a skill
cp -r .claude/skills/worktree/ ~/my-project/.claude/skills/worktree/
```

## Browse the Catalog

**[Full Catalog](marketplace/catalog.md)** | **[marketplace.json](marketplace.json)**

### Planning & Architecture Agents

Build implementation plans, analyze codebases, design secure architectures.

| Agent | What it does |
|-------|-------------|
| **Implementation Planner** | Architecture analysis + detailed implementation roadmaps with Context7 |
| **Codebase Analyzer** | Deep project structure mapping, dependency analysis, integration points |
| **Security Architect** | Auth flows, encryption, validation, compliance design |
| **Performance Architect** | Algorithms, caching strategies, scalability patterns |
| **Testing Strategist** | Unit, integration, e2e test strategy design |
| **CI/CD Specialist** | Jenkins, GitHub Actions, GitLab CI pipeline planning |
| **Quality Advisor** | Architecture patterns and code quality analysis |
| **Bug Prevention** | Edge case identification before implementation |
| **Best Practices** | Post-implementation review against current standards |
| **Documentation Planner** | README, API docs, user guides planning |

### Code Review Agents

Run them individually or orchestrate all 5 in parallel with `/code-review:agentic-code-review`.

| Agent | What it does |
|-------|-------------|
| **Bug Detector** | Pattern analysis for bugs, edge cases, and logic errors |
| **Code Quality** | Best practices, SOLID principles, maintainability |
| **Performance** | Bottleneck identification and optimization suggestions |
| **Security** | OWASP vulnerabilities, secure coding practices |
| **Testing** | Test coverage assessment and improvement suggestions |

### Commands

| Command | Claude Code | Codex | Category |
|---------|:-----------:|:-----:|----------|
| Agentic JIRA Analyzer | `/planning:agentic-jira-task-analyze` | — | Planning |
| JIRA Task Analyzer | `/planning:jira-task-analyze` | `/jira-task-analyze` | Planning |
| PR Review (Multi-Agent) | `/code-review:pr-review` | — | Review |
| Agentic Code Review | `/code-review:agentic-code-review` | — | Review |
| Precommit Review | `/code-review:non-agentic-precommit-review` | `/non-agentic-precommit-review` | Review |
| Context7 Research | `/research:use-context7` | — | Research |
| Playwright Testing | `/testing:test-app-playwright` | — | Testing |
| Create Commit | `/create-commit` | `/create-commit` | DevOps |
| Python Quality Check | `/quality-check-python` | `/quality-check-python` | DevOps |
| Frontend Quality Check | `/quality-check-frontend` | `/quality-check-frontend` | DevOps |

[See all 20 commands in the catalog](marketplace/catalog.md#commands-20)

### Skills

| Skill | Type | Both CLIs | Description |
|-------|------|:---------:|-------------|
| **Git Worktree** | Script | Yes | Create worktree with gitignored files sync |
| **JIRA Parallel Planner** | AI | Yes | Analyze dependencies, plan parallel delivery |
| **Protractor-Playwright** | AI | Yes | Migrate Protractor e2e tests to Playwright |
| **Test All** | AI | Yes | Discover and run all test suites in monorepo |

## How It Works

### For Claude Code

Agents, commands, and skills are loaded from `.claude/` directory:

```
your-project/
├── .claude/
│   ├── agents/                # Sub-agents (auto-discovered)
│   │   ├── planning-agents/   # Planning specialists
│   │   └── code-review-agents/# Review specialists
│   ├── commands/              # Slash commands
│   │   ├── planning/          # /planning:*
│   │   ├── code-review/       # /code-review:*
│   │   ├── research/          # /research:*
│   │   └── testing/           # /testing:*
│   └── skills/                # Reusable skills
│       ├── worktree/
│       └── test-all/
```

```bash
# Verify installation
claude
/agents      # List installed agents
/commands    # List available commands
```

### For Codex CLI

Commands are loaded from `.codex/prompts/` and skills from `.codex/skills/`:

```
your-project/
├── .codex/
│   ├── prompts/               # Slash commands
│   └── skills/                # Reusable skills
│       ├── worktree/
│       └── test-all/
```

## MCP Servers

Many items integrate with [MCP servers](https://docs.anthropic.com/en/docs/claude-code/mcp) for enhanced capabilities:

| Server | Items Using | Purpose |
|--------|:-----------:|---------|
| **context7** | 20 | Documentation lookup, best practices research |
| **atlassian** | 7 | JIRA issues, Confluence search |
| **memory** | 5 | Knowledge persistence across sessions |
| **filesystem** | 4 | Deep file system analysis |
| **playwright** | 2 | Browser automation testing |
| **chrome-devtools** | 2 | Chrome debugging and verification |

## Repository Structure

```
claude-code-octopus/
├── marketplace.json           # Machine-readable registry (43 items)
├── marketplace/
│   ├── install.sh             # CLI installer
│   └── catalog.md             # Browsable catalog
├── .claude/                   # Claude Code items (source)
│   ├── agents/                # 19 sub-agents
│   ├── commands/              # 20 slash commands
│   └── skills/                # 4 skills
├── .codex/                    # Codex CLI items
│   ├── prompts/               # 8 commands
│   └── skills/                # 4 skills
├── .factory/                  # Canonical templates (source of truth)
│   ├── droids/                # Agent templates
│   ├── commands/              # Command templates
│   └── skills/                # Skill templates
├── CLAUDE.md                  # Claude Code configuration
├── AGENTS.md                  # Vendor-neutral configuration
└── docs/                      # Guides and documentation
```

## Contributing

1. Create your agent/command/skill in the appropriate `.claude/` or `.codex/` directory
2. Add entry to `marketplace.json` with metadata, tags, and compatibility info
3. Update the canonical template in `.factory/` if applicable
4. Test in both Claude Code and Codex CLI
5. Submit a pull request

See [CLAUDE.md](CLAUDE.md) for detailed architecture and file format specifications.

## Search & Discovery

```bash
# Search by keyword
./marketplace/install.sh --search security

# List categories
./marketplace/install.sh --list-categories

# Browse programmatically
jq '.items[] | select(.tags | index("testing"))' marketplace.json
```

## Documentation

- **[Full Catalog](marketplace/catalog.md)** - Browse all items with descriptions and compatibility
- **[CLAUDE.md](CLAUDE.md)** - Claude Code architecture, agent/command file formats
- **[AGENTS.md](AGENTS.md)** - Vendor-neutral conventions for Codex and other CLIs
- **[Custom Slash Commands](docs/claude-code/custom-slash-commands.md)** - How to create commands
- **[Sub-Agents Guide](docs/claude-code/sub-agents-guide.md)** - Designing autonomous agents
- **[Hooks Guide](docs/claude-code/hooks-guide.md)** - Event-driven automation

## License

[MIT](LICENSE)
