---
name: test-all
description: Detect modified services in a monorepo, discover all test types (unit, integration, component, e2e, performance), validate environment readiness, run tests, and produce a structured report. Use when you need to run all applicable tests after code changes.
argument-hint: "[service-path or --all] [--base-branch=main]"
allowed-tools: Task, Bash, Read, Write, Grep, Glob
---

# Test All

## Goal

Automatically detect changed services, discover all available test suites, validate environment readiness, execute tests, and produce a structured report.

## Required Inputs

Collect before execution:

- Repository root path (default: current working directory)
- Base branch for diff comparison (default: `main`, override with `--base-branch=<branch>`)
- Scope: auto-detect from git changes, explicit service paths, or `--all` for full run

If `$ARGUMENTS` contains paths, use those as explicit service targets.
If `$ARGUMENTS` contains `--all`, scan every service in the monorepo.
Otherwise, auto-detect affected services from git changes.

## Workflow

### 1. Detect Changed Services

Identify which services have been modified:

```bash
# All changes in current branch vs base
git diff --name-only <base-branch>...HEAD 2>/dev/null || true
# Unstaged changes
git diff --name-only
# Staged changes
git diff --name-only --cached
```

Combine all changed file paths. Map each changed file to its parent service directory. A service directory is identified by the presence of a project manifest at its root:

- `package.json` (Node.js / frontend)
- `pyproject.toml` or `setup.py` or `setup.cfg` (Python)
- `go.mod` (Go)
- `pom.xml` or `build.gradle` or `build.gradle.kts` (Java/Kotlin)
- `Cargo.toml` (Rust)
- `Gemfile` (Ruby)
- `composer.json` (PHP)
- `*.csproj` or `*.sln` (.NET / C#)
- `Makefile` with test targets (generic)

If the repository root itself is a single-service project (manifest at root level), treat the entire repo as one service.

Report the list of affected services with the count of changed files per service.

### 2. Discover Test Configurations

For each affected service, scan for test runner configurations and classify test types:

| Marker | Runner | Default Type |
|---|---|---|
| `jest.config.*` or `jest` key in package.json | Jest | unit |
| `vitest.config.*` | Vitest | unit |
| `pytest.ini` / `pyproject.toml` with `[tool.pytest]` / `conftest.py` | pytest | unit |
| `playwright.config.*` | Playwright | e2e |
| `cypress.config.*` or `cypress/` directory | Cypress | e2e |
| `.mocharc.*` or `mocha` key in package.json | Mocha | unit |
| `*_test.go` files | go test | unit |
| `src/test/` + `pom.xml` | Maven (JUnit) | unit |
| `src/test/` + `build.gradle*` | Gradle (JUnit) | unit |
| `k6/` scripts or `*.k6.js` | k6 | performance |
| `locustfile.py` or `locust/` | Locust | performance |
| `artillery.yml` or `.artillery/` | Artillery | performance |
| `*.csproj` + `*Tests` project | dotnet test | unit |

Additionally, check `package.json` scripts for named test commands:

- `test` or `test:unit` -> unit
- `test:integration` or `test:int` -> integration
- `test:component` -> component
- `test:e2e` or `test:playwright` or `test:cypress` -> e2e
- `test:perf` or `test:performance` or `test:load` -> performance
- `test:all` -> all types

For Python projects, check for directory conventions:

- `tests/unit/` or `tests/test_*.py` at root -> unit
- `tests/integration/` -> integration
- `tests/e2e/` -> e2e
- `tests/performance/` or `tests/load/` -> performance

For Go projects, check for:

- `*_test.go` in source directories -> unit
- `tests/integration/` or `_integration_test.go` suffix -> integration
- `tests/e2e/` -> e2e

Produce a matrix: service x test-type with runner commands.

### 3. Validate Environment Readiness

For each service, check prerequisites:

**Node.js services:**
- `node_modules/` exists -> if not, suggest `npm install` / `yarn install` / `pnpm install` / `bun install`
- Check for lockfile to determine package manager (package-lock.json / yarn.lock / pnpm-lock.yaml / bun.lock)
- `.env` or `.env.test` exists if referenced in configs

**Python services:**
- Virtual environment exists (`.venv/`, `venv/`, or active conda env)
- Dependencies installed (check for `requirements.txt`, `pyproject.toml` with deps)
- Test dependencies present (pytest in installed packages)

**Go services:**
- `go.sum` exists (modules downloaded)
- Source valid (`go vet ./...`)

**Java/Kotlin services:**
- Build tool wrapper exists (`mvnw`, `gradlew`)
- Dependencies cached (`~/.m2/repository` or `.gradle/`)

**.NET services:**
- .NET SDK installed (`dotnet --version`)
- Dependencies restored (`dotnet restore` if `obj/` missing)

**Integration/E2E prerequisites:**
- Docker running (if docker-compose.yml or Dockerfile present in test config)
- Test database available (check env vars like DATABASE_URL, TEST_DATABASE_URL)
- Required services running (check ports or health endpoints if configured)

Classify each service:

- `ready` - all prerequisites met, tests can run immediately
- `needs-setup` - missing prerequisites with specific fix commands
- `blocked` - critical dependency missing that cannot be auto-resolved

If a service is `needs-setup`, ask the user whether to run setup commands before continuing.

### 4. Run Tests

Execute tests in priority order (fastest first):

1. **Unit tests** - timeout 5 minutes per service
2. **Integration tests** - timeout 10 minutes per service
3. **Component tests** - timeout 10 minutes per service
4. **E2E tests** - timeout 15 minutes per service
5. **Performance tests** - timeout 10 minutes per service

Execution rules:

- For independent services, use Task tool to launch parallel subagents (one per service)
- Within a service, run test types sequentially in the order above
- Capture full stdout/stderr for each test run
- Record exit code, duration, and any coverage output
- If a test suite fails, continue with remaining suites in that service and other services
- Pass `--no-color` or equivalent flag when available for clean output parsing
- Use `--coverage` or equivalent when the runner supports it

Common run commands by runner:

| Runner | Command |
|---|---|
| Jest | `npx jest --ci --coverage --no-color` |
| Vitest | `npx vitest run --coverage --reporter=verbose` |
| pytest | `python -m pytest -v --tb=short --no-header --cov` |
| Playwright | `npx playwright test --reporter=list` |
| Cypress | `npx cypress run --reporter spec` |
| Mocha | `npx mocha --reporter spec --no-color` |
| go test | `go test -v -count=1 ./...` |
| Maven | `./mvnw test -B` |
| Gradle | `./gradlew test` |
| k6 | `k6 run --summary-trend-stats="avg,p(95),p(99)" <script>` |
| Locust | `locust --headless -u 1 -r 1 --run-time 30s` |
| dotnet test | `dotnet test --no-build --verbosity normal` |

Note: `--no-header` requires pytest >= 7.0. For older versions, remove this flag from the command.

If `package.json` has specific named scripts (e.g., `test:unit`, `test:e2e`), prefer those over generic runner commands as they may include project-specific configuration.

### 5. Collect and Parse Results

For each test run, extract:

- Total tests: passed / failed / skipped / errored
- Duration in seconds
- Coverage percentage (line, branch, function) if available
- List of failed tests with:
  - Test file path
  - Test name / describe block
  - Error message (first 10 lines)
  - Stack trace hint (file:line of assertion failure)

Aggregate results:

- Per service: total pass/fail/skip across all test types
- Per test type: total pass/fail/skip across all services
- Overall: grand totals

### 6. Generate Report

Write the report to stdout using `references/test-report-template.md` as the structure.

Include:

- Executive summary with overall pass/fail status
- Per-service breakdown
- Failure details with actionable context
- Environment issues encountered
- Recommendations for improving test coverage

## Parallel Execution Strategy

When multiple services are affected:

- Spawn one Task subagent per service for independent test execution
- Each subagent runs all discovered test types for its assigned service
- Main process collects results and assembles the final report
- If only one service is affected, run sequentially without subagents

## Error Handling

| Situation | Behavior |
|---|---|
| No git repository | Error: report and exit |
| No changed files detected | Info: suggest `--all` flag or explicit paths |
| No tests found in service | Warning: report service as "no tests configured" |
| Test runner not installed | `needs-setup`: suggest install command |
| Test timeout exceeded | Kill process, report as timeout failure |
| Environment variable missing | `needs-setup`: list required vars |
| Docker not running | `blocked` for integration/e2e that need it |

## Output Contract

Always produce a report using `references/test-report-template.md` structure containing:

- Changed services detection summary
- Environment readiness matrix
- Test results matrix (service x test-type)
- Failure details with file paths and error messages
- Coverage summary per service (when available)
- Actionable recommendations

## Prompt Template

Invoke the skill with optional arguments:

```text
/test-all $ARGUMENTS
```

Where `$ARGUMENTS` can be:

- Empty: auto-detect changed services from git, use `main` as base branch
- `--all`: run tests for all services
- `--base-branch=develop`: use `develop` as comparison branch
- `services/api services/web`: explicit service paths
- Combinations: `services/api --base-branch=develop`

Default user prompt after parsing arguments:

```text
Run all applicable tests for modified services in this monorepo.
Detect which services changed, discover test types, validate the environment, execute tests, and produce a structured report.
```
