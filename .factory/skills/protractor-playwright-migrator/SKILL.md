---
name: protractor-playwright-migrator
description: Migrate Creatio end-to-end tests from legacy Protractor sources into Playwright TestKit-compliant feature folders, or build a full migration plan before implementation. Use when invoked as $protractor-playwright-migrator [protractor-tests-location] [playwright-tests-destination], or when a request includes source and target paths and requires business-logic preservation per test, TestKit-first patterns, gap analysis for missing TestKit components, verification on Creatio via mcp chrome-devtools, and failure debugging using mcp chrome-devtools plus Playwright artifacts from test-results and playwright-report.
argument-hint: "[protractor-tests-location] [playwright-tests-destination]"
---

# Protractor to Playwright Migrator

## Goal

Produce a migration plan (and optionally migration changes) from Protractor to Playwright that matches this repository rules and TestKit conventions.

## Required Inputs

Collect these values from the user request:

- Source directory (Protractor): `ARGUMENT-1`
- Target directory (Playwright): `ARGUMENT-2`
- Scope mode: `plan-only` or `plan-and-implement` (default `plan-only`)

If any input is missing, derive from context and state assumptions explicitly.

## Non-Negotiable Lookup Order

Follow this order every time:

1. Check TestKit docs first at `node_modules/@creatio/playwright-testkit/dist/docs`.
2. Check migration rules at `docs/ai-migration/migration-patterns.md`.
3. Check repository code and `external-source/protractor` only after steps 1-2.

If TestKit docs are missing/unreadable, stop and report blocker. Recommend `git pull` and `npm install`, then wait for user approval to continue without TestKit docs.

## Required Subagent Orchestration

Use subagents for non-trivial scope.

- Spawn `explorer` 1: TestKit conventions extractor (pages, elements, fixtures, auth, waits).
- Spawn `explorer` 2: Source inventory and path mapping analyzer for `ARGUMENT-1`.
- Spawn `explorer` 3: Plan synthesizer that builds phased migration work and verification checkpoints.
- Spawn `explorer` 4: Business-flow reconnaissance agent that reproduces target user flows in Creatio via `mcp chrome-devtools` and captures behavior notes/evidence.

For large scopes (more than 10 spec files), split implementation by feature area and assign `worker` subagents with explicit file ownership.

## Workflow

1. Validate paths.
- Confirm `ARGUMENT-1` and `ARGUMENT-2` exist or create `ARGUMENT-2` when implementation mode requires it.

2. Build source inventory.
- Resolve the inventory script path relative to the skill root (do not assume repository `scripts/` and do not require `CODEX_HOME`):
  - Preferred from skill root: `scripts/build_migration_inventory.py`
  - Fallback: locate the script in the active CLI's skills directory
  - If needed, discover dynamically: `find . -path '*/skills/protractor-playwright-migrator/scripts/build_migration_inventory.py' -print -quit`
- Run `<resolved-script-path> --source <ARGUMENT-1> --target <ARGUMENT-2>`.
- Do not fail migration planning if `<repo>/scripts/build_migration_inventory.py` is missing; it is not expected to exist there.
- Group files into `specs`, `pages`, `elements`, `data`, `utils`, `other`.

3. Define target mapping.
- Place migrated assets under `tests/_migrated/features/<feature>/...`.
- Keep import boundary: no imports from `tests/_migrated` into `tests/features`.

4. Analyze business logic of every migrated test before translation.
- Run subagent-driven business-flow reconnaissance in parallel for test groups:
  - assign `explorer` subagents to reproduce real user flows in Creatio with `mcp chrome-devtools`,
  - capture screen/state transitions, important controls/markers, role constraints, and expected outcomes,
  - attach concise evidence references (screenshots or step logs).
- For each Protractor spec/test case, extract test intent and protected behavior from both code and live app behavior:
  - business scenario and user role/context,
  - critical actions and data transitions,
  - assertions that protect business value.
- Correlate Protractor assertions with observed application behavior from `mcp chrome-devtools` and resolve mismatches before planning.
- Build a parity checklist per test: `original intent -> migrated coverage`.
- Do not drop business assertions during migration; if UI details change, preserve intent with equivalent Playwright/TestKit assertions.
- If reconnaissance cannot be completed (environment/auth/data blockers), stop and report blockers explicitly with assumptions that require user confirmation.

5. Apply TestKit-first migration rules.
- Use appropriate base pages (`BaseListPage`, `BaseFormPage`, `Base8xPage`, `Base7xPage`, `BaseSystemDesignerPage`).
- Prefer TestKit elements and `ElementProps` (`marker` first, then `ariaLabel`, then stable attributes).
- Use fixture-based auth (`test.use({ userType })`) and avoid routine manual login.
- Use auto-retrying expectations and avoid hardcoded waits.

6. Perform gap analysis.
- Identify features not covered by TestKit.
- Plan implementation of missing custom elements/helpers as part of migration under `elements/` or `utils/`.
- Prefer reusable abstractions over one-off locators.

7. Build phased migration plan.
- Include per-file migration actions.
- Include risk/complexity flags (7.x/extJs, dynamic grids, unsupported elements, brittle selectors).
- Include required tests and lint/type checks.

8. Define mandatory verification on real app with `mcp chrome-devtools`.
- Execute affected migrated tests to produce artifacts before deep debug:
  - `npx playwright test <affected-specs> --trace on`
- Open Creatio and navigate migrated flow.
- Validate key user path per migrated spec (open page, perform action, assert visible outcomes).
- Capture evidence (screenshots and concise pass/fail notes).

9. Debug failed validation runs.
- If migrated tests fail or are unstable, start with live app exploration in Creatio via `mcp chrome-devtools` as the primary debugging method.
- Use subagents to reproduce failing flows in parallel when scope is large (split by failing spec group).
- During debugging, prioritize understanding real runtime behavior first, then correlate with test artifacts.
- Inspect Playwright artifacts produced after each run:
  - `test-results/` for traces, screenshots, videos, and per-test artifacts.
  - `playwright-report/` for HTML run summary and error context.
- Correlate artifact failures with live UI behavior in `mcp chrome-devtools` and produce:
  - validated root-cause hypothesis,
  - minimal fix actions,
  - re-check steps in application before re-running full tests.

## Output Contract

Always return:

- Inventory summary with counts by category.
- File mapping table: `source -> target`.
- Application reconnaissance summary from `mcp chrome-devtools` (observed flow steps, markers/controls, role constraints, evidence links).
- Business-logic parity matrix for every migrated test (`Protractor intent -> Playwright assertions`).
- TestKit compliance checklist.
- Gap analysis for missing TestKit coverage and implementation tasks.
- Phased migration plan with execution order and parallel tracks.
- Verification plan using `mcp chrome-devtools` with explicit steps and expected results.
- Validation execution summary with exact Playwright command(s) and artifact locations.
- Failure-debug plan that uses `mcp chrome-devtools` and Playwright artifacts from `test-results/` and `playwright-report/`.
- Used references list where the first item is a TestKit docs path.

Use `references/migration-plan-template.md` as the default response format.

## Prompt Template

Invoke the skill with positional arguments:

```text
$protractor-playwright-migrator $ARGUMENTS
```

Where:

- `$ARGUMENTS` = `[protractor-tests-location] [playwright-tests-destination]`
- argument 1 = source directory (Protractor)
- argument 2 = target directory (Playwright)

Default user prompt after parsing arguments:

```text
I need to migrate tests from Protractor to Playwright.
Source directory: ARGUMENT-1
Target directory: ARGUMENT-2
Create a migration plan for all tests in this directory.
If something is not provided by testkit it should be implemented as part of the migration.
The plan must include verification of migrated tests in Creatio using mcp chrome-devtools.
```

## Context7 Rule

When querying external docs for coding details, use Context7 and append `use context7` to the query text.
