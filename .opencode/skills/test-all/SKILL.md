---
name: test-all
description: Detect modified services in a monorepo, discover all test types (unit, integration, component, e2e, performance), validate environment readiness, run tests, and produce a structured report. Use when you need to run all applicable tests after code changes.
argument-hint: "[service-path or --all] [--base-branch=main]"
license: MIT
compatibility: opencode
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
# Untracked files (new files not yet staged)
git ls-files --others --exclude-standard
```

Combine all changed file paths (including untracked). Map each changed file to its parent service directory. A service directory is identified by the presence of a project manifest at its root:

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
| `pytest.ini` / `pyproject.toml` with `[tool.pytest.ini_options]` / `conftest.py` | pytest | unit |
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

#### 2b. Discover Project-Specific Test Scripts

Before falling back to standard runner commands, search each service for custom test scripts that the team may have configured. These take priority over generic commands because they often include project-specific flags, environment setup, or multi-step workflows.

Search locations (in priority order):

1. **Makefile / Taskfile.yml / justfile** -- look for targets like `test`, `test-unit`, `test-integration`, `test-e2e`, `test-perf`, `test-all`, `check`, `ci-test`
2. **Shell scripts** -- `scripts/test*.sh`, `bin/test*`, `run-tests.sh`, `ci/*.sh`
3. **package.json scripts** (Node.js) -- `test`, `test:unit`, `test:integration`, `test:e2e`, `test:perf`, `test:all`
4. **pyproject.toml / tox.ini / noxfile.py** (Python) -- `[tool.tox]` envs, nox sessions like `tests`, `integration`, `e2e`
5. **Docker Compose test services** -- `docker-compose.test.yml`, services named `*-test*`
6. **CI config files** -- `.github/workflows/test*.yml`, `Jenkinsfile`, `.gitlab-ci.yml` -- extract test commands from CI steps as hints for local execution

For each discovered script, map it to a test type (unit / integration / e2e / performance) based on name or content.

**Command resolution priority** for each test type in a service:

1. Project-specific script (Makefile target, shell script, tox env, etc.)
2. Named `package.json` script (e.g., `test:e2e`)
3. Standard runner command from the table in Step 4d

Record the chosen command source in the execution queue (e.g., `Makefile:test-e2e` vs `npx playwright test`).

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

#### 4a. Build Execution Queue

From the Step 2 discovery matrix, build an execution queue listing every service + test-type combination. Output it to the user before running anything:

```
EXECUTION QUEUE (N entries):
[ ] unit        - services/api (npm test:unit via package.json), services/worker (make test-unit via Makefile)
[ ] integration - services/worker (python -m pytest tests/integration/ --cov, standard)
[ ] e2e         - services/web (scripts/run-e2e.sh via shell script)
[ ] performance - services/api (k6 run ..., standard)
```

This queue is a binding contract. Every entry MUST be executed before generating the report.

Execution order by type (fastest first):

| Type | Timeout per service |
|---|---|
| unit | 5 minutes |
| integration | 10 minutes |
| component | 10 minutes |
| e2e | 15 minutes |
| performance | 10 minutes |

#### 4b. Execute Queue (checkpoint loop)

Process entries one by one. After completing each entry:

1. Run the test command for this entry
2. Record exit code, stdout/stderr, duration, coverage
3. Mark entry as done with result (PASSED / FAILED / ERROR / TIMEOUT)
4. Output checkpoint showing remaining queue:

```
CHECKPOINT: 2/4 complete, 2 remaining:
[x] unit        - PASSED (42 passed, 0 failed)
[x] integration - FAILED (8 passed, 3 failed)
[ ] e2e         - pending
[ ] performance - pending
>>> Continuing with: e2e
```

5. Continue to next entry. NEVER stop the loop early.

**CRITICAL**: do NOT generate the final report (Step 6) until ALL queue entries show `[x]`. If a test type fails, mark it as FAILED and move to the next entry. The loop ends only when every entry has been processed.

#### 4c. Execution Rules

- Within a service, run test types sequentially in the order above
- Capture full stdout/stderr for each test run
- If a test suite fails, continue with remaining suites in that service and other services
- Pass `--no-color` or equivalent flag when available for clean output parsing
- Use `--coverage` or equivalent when the runner supports it

#### 4d. Common Run Commands

| Runner | Command |
|---|---|
| Jest | `npx jest --ci --coverage --no-color` |
| Vitest | `npx vitest run --coverage --reporter=verbose` |
| pytest | `python -m pytest -v --tb=short --no-header` (add `--cov` only if pytest-cov is installed) |
| Playwright | `npx playwright test --reporter=list` |
| Cypress | `npx cypress run --reporter spec` |
| Mocha | `npx mocha --reporter spec --no-color` |
| go test | `go test -v -count=1 ./...` |
| Maven | `./mvnw test -B` |
| Gradle | `./gradlew test` |
| k6 | `k6 run --summary-trend-stats="avg,p(95),p(99)" <script>` |
| Locust | `locust --headless -u 1 -r 1 --run-time 30s` |
| dotnet test | `dotnet test --no-build --verbosity normal` |

Note: `--no-header` requires pytest >= 7.0. For older versions, remove this flag. To check if pytest-cov is available, run `python -m pytest --co -q --cov 2>&1 | head -1` -- if it errors with "unrecognized arguments", omit `--cov`.

Use the command resolution priority from Step 2b: project-specific scripts first, then named package.json scripts, then standard runner commands from the table above.

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

Verify completeness before proceeding to Step 6:

- Every entry from the Step 4a execution queue must have a result (PASSED / FAILED / ERROR / TIMEOUT)
- If any entry is missing a result, go back and execute it now
- Output the final completed queue as confirmation:

```
ALL QUEUE ENTRIES PROCESSED (4/4):
[x] unit        - PASSED
[x] integration - FAILED
[x] e2e         - PASSED
[x] performance - PASSED
>>> Proceeding to report generation
```

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

- Execute services sequentially (OpenCode does not support parallel subagent execution)
- Within each service, run test types sequentially in priority order
- Collect all results and assemble the final report after all services complete

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
