# AI Agents Marketplace - Catalog

> Browse and install agents, commands, and skills for **Claude Code** and **Codex CLI**.

---

## Agents (19)

Sub-agents are autonomous specialists that run as background workers inside Claude Code. They handle complex reasoning tasks like architecture analysis, code review, and security auditing.

> **Note**: Agents are currently supported only in **Claude Code**. Codex CLI uses AGENTS.md and prompts instead.

### Planning & Architecture (10)

| Agent | Description | MCP Required | Install |
|-------|-------------|--------------|---------|
| **Implementation Planner** | Analyzes architecture, creates detailed implementation plans with Context7 | context7 | `--item agent-planning-implementation` |
| **Quality Advisor** | Analyzes existing patterns and designs high-quality architecture | context7 | `--item agent-planning-quality-advisor` |
| **Security Architect** | Designs secure implementations: auth, encryption, validation, compliance | context7 | `--item agent-planning-security-architect` |
| **Testing Strategist** | Designs comprehensive testing approaches: unit, integration, e2e | context7 | `--item agent-planning-testing-strategist` |
| **Bug Prevention Planner** | Identifies edge cases, error scenarios, and failure modes before implementation | context7 | `--item agent-planning-bug-prevention` |
| **Best Practices Reviewer** | Reviews solutions for best practices and breaking changes via Context7 | context7 | `--item agent-planning-best-practices` |
| **CI/CD Specialist** | Analyzes Jenkins, GitHub Actions, GitLab CI and plans improvements | context7 | `--item agent-planning-ci-cd` |
| **Performance Architect** | Designs high-performance solutions: algorithms, caching, scalability | context7 | `--item agent-planning-performance-architect` |
| **Documentation Planner** | Plans README updates, API docs, inline comments, and user guides | context7 | `--item agent-planning-documentation` |
| **Codebase Analyzer** | Deep codebase analysis: structure mapping, dependency analysis, integration points | filesystem | `--item agent-codebase-analyzer` |

### Code Review (5)

| Agent | Description | MCP Required | Install |
|-------|-------------|--------------|---------|
| **Bug Detector** | Identifies potential bugs, edge cases, and logic errors | context7 | `--item agent-bug-detector` |
| **Code Quality Reviewer** | Analyzes code quality, best practices, and maintainability | context7 | `--item agent-code-quality-reviewer` |
| **Performance Reviewer** | Identifies performance bottlenecks and suggests optimizations | context7 | `--item agent-performance-reviewer` |
| **Security Reviewer** | Identifies security vulnerabilities and secure coding practices | context7 | `--item agent-security-reviewer` |
| **Testing Reviewer** | Assesses test coverage, quality, and suggests improvements | — | `--item agent-testing-reviewer` |

### Utility (4)

| Agent | Description | MCP Required | Install |
|-------|-------------|--------------|---------|
| **Confluence Searcher** | Searches and extracts information from Confluence | atlassian, memory | `--item agent-confluence-searcher` |
| **Lint & Type Checker** | Background linting and type checking on code changes | — | `--item agent-lint-type-checker` |
| **Memory Manager** | Manages MCP memory operations and context persistence | memory, filesystem | `--item agent-memory-manager` |
| **PDF Analyzer** | Analyzes PDF documents and extracts structured information | filesystem, memory | `--item agent-pdf-analyzer` |

---

## Commands (20)

Slash commands are guided workflows invoked via `/command-name`. They orchestrate tools, agents, and MCP servers to complete specific tasks.

### Planning (4)

| Command | Claude Code | Codex | Description |
|---------|:-----------:|:-----:|-------------|
| **Agentic JIRA Analyzer** | `/planning:agentic-jira-task-analyze` | — | Multi-agent JIRA analysis with parallel codebase deep dive |
| **JIRA Task Analyzer** | `/planning:jira-task-analyze` | `/jira-task-analyze` | Single-agent JIRA analysis and implementation plan |
| **Agentic Implementation Planner** | `/planning:agentic-plan-implementation` | — | Context7-powered architecture + CI/CD planning |
| **JIRA Issue Translator** | `/translate-jira-issue-english` | `/translate-jira-issue-english` | Translate JIRA issue to English |

### Code Review (5)

| Command | Claude Code | Codex | Description |
|---------|:-----------:|:-----:|-------------|
| **PR Review** | `/code-review:pr-review` | — | Multi-agent PR review (GitHub/Bitbucket) |
| **Agentic Code Review** | `/code-review:agentic-code-review` | — | Parallel specialized code review |
| **Quality Code Review** | `/code-review:quality-code-review` | — | Best practices, optimization, maintainability |
| **Commit Review** | `/code-review:commit-review-by-hash-id` | — | Review specific commits by hash |
| **Precommit Review** | `/code-review:non-agentic-precommit-review` | `/non-agentic-precommit-review` | Lightweight review without sub-agents |

### Research (3)

| Command | Claude Code | Codex | Description |
|---------|:-----------:|:-----:|-------------|
| **Context7 Research** | `/research:use-context7` | — | Research best practices for any technology |
| **Find Solution** | `/research:find-solution` | — | Multi-source documentation research |
| **Document Analyzer** | `/analyze-docs` | — | PDF + Confluence analysis with memory |

### Testing (3)

| Command | Claude Code | Codex | Description |
|---------|:-----------:|:-----:|-------------|
| **Playwright Testing** | `/testing:test-app-playwright` | — | Browser automation testing via MCP |
| **Playwright Research** | `/testing:use-playwright-mcp` | — | Playwright best practices via MCP |
| **Chrome DevTools** | `/testing:use-chrome-devtools-mcp` | `/use-chrome-devtools-mcp` | Chrome DevTools research via MCP |

### Context & Memory (2)

| Command | Claude Code | Codex | Description |
|---------|:-----------:|:-----:|-------------|
| **Add Memory** | `/context-memory:add-memory` | — | Store information in MCP memory |
| **Read Memory** | `/context-memory:read-memory` | — | Retrieve stored knowledge |

### DevOps & Quality (3)

| Command | Claude Code | Codex | Description |
|---------|:-----------:|:-----:|-------------|
| **Create Commit** | `/create-commit` | `/create-commit` | Git commit with staged changes |
| **Python Quality Check** | `/quality-check-python` | `/quality-check-python` | Python linting and formatting |
| **Frontend Quality Check** | `/quality-check-frontend` | `/quality-check-frontend` | Frontend ESLint and Prettier |

---

## Skills (4)

Skills are reusable instruction sets that can run deterministic scripts or provide structured AI workflows. They work across both Claude Code and Codex CLI.

| Skill | Type | Claude Code | Codex | Description |
|-------|------|:-----------:|:-----:|-------------|
| **Git Worktree Manager** | Script | `/worktree` | `/worktree` | Create worktree with gitignored files sync |
| **JIRA Parallel Planner** | AI | `/jira-parallel-execution-planner` | `/jira-parallel-execution-planner` | Analyze Jira dependencies, plan parallel execution |
| **Protractor-Playwright Migrator** | AI | `/protractor-playwright-migrator` | `/protractor-playwright-migrator` | Migrate Protractor tests to Playwright |
| **Test All** | AI | `/test-all` | `/test-all` | Discover and run all test suites in monorepo |

---

## Compatibility Matrix

| Feature | Claude Code | Codex CLI |
|---------|:-----------:|:---------:|
| **Agents** | 19 | — |
| **Commands** | 20 | 8 |
| **Skills** | 4 | 4 |
| **Total** | **43** | **12** |
| MCP Support | Native | Via SDK |
| Multi-Agent | Parallel | — |
| Context7 | Native | Via MCP |

---

## Installation

Single Python installer for all platforms. Requires Python 3.7+, no dependencies.

```bash
# One-liner (macOS / Linux)
python3 <(curl -fsSL https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py) --all

# One-liner (Windows PowerShell)
Invoke-WebRequest https://raw.githubusercontent.com/rouksonix/claude-code-octopus/main/marketplace/install.py -OutFile install.py; python install.py --all

# From cloned repo
python3 marketplace/install.py --list
python3 marketplace/install.py --all --cli claude --target-dir ~/my-project
python3 marketplace/install.py --skills --target-dir ~/my-project
python3 marketplace/install.py --item agent-bug-detector --target-dir ~/my-project
python3 marketplace/install.py --info agent-bug-detector
```

---

## MCP Servers

Many items require MCP (Model Context Protocol) servers. Configure them in your project's `.claude/settings.json` or equivalent:

| MCP Server | Used By | Purpose |
|------------|---------|---------|
| **context7** | 15 agents, 5 commands | Documentation lookup, best practices |
| **atlassian** | 2 agents, 4 commands, 1 skill | JIRA/Confluence integration |
| **memory** | 3 agents, 2 commands | Knowledge persistence |
| **filesystem** | 3 agents, 1 command | Deep file system analysis |
| **playwright** | 2 commands | Browser automation |
| **chrome-devtools** | 1 command, 1 skill | Chrome debugging |

---

## Contributing

1. Add your agent/command/skill to the appropriate directory
2. Update `marketplace.json` with the item metadata
3. Test in both Claude Code and Codex CLI
4. Submit a pull request
