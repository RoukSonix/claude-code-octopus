# Migration Plan Template

## 1. Inputs

- Source directory: `<ARGUMENT-1>`
- Target directory: `<ARGUMENT-2>`
- Scope mode: `<plan-only|plan-and-implement>`

## 2. Inventory Summary

- Total files:
- Specs:
- Pages:
- Elements:
- Data:
- Utils:
- Other/manual:

## 3. Source to Target Mapping

| Source file | Category | Target file | Notes |
|---|---|---|---|

## 4. Business Logic Parity Matrix (required)

| Protractor test/spec | Business intent (why test exists) | Live flow observed via mcp chrome-devtools | Critical actions/data transitions | Original assertions | Playwright coverage (spec + assertions) | Parity status (full/partial/missing) |
|---|---|---|---|---|---|---|

## 5. Application Reconnaissance Summary (required)

- Subagents used for reconnaissance:
- Scope of flows reproduced in Creatio:
- Role/user assumptions:
- Key UI markers/controls and behavior notes:
- Evidence references (screenshots/step logs):
- Blockers (if any):

## 6. TestKit Compliance Checklist

- Page base classes selected correctly.
- `schemaName()`/page selector/navigation rules defined.
- TestKit elements used instead of raw locators.
- Fixtures and auth strategy align with TestKit best practices.
- Assertions use auto-retrying matchers.
- Hardcoded waits/timeouts removed.

## 7. Gap Analysis (Missing in TestKit)

| Gap | Why TestKit is insufficient | Planned implementation | Target location |
|---|---|---|---|

## 8. Phased Migration Plan

### Phase 1: Foundation

- Normalize directories and file naming.
- Build base page objects.
- Prepare shared/custom elements.

### Phase 2: Spec migration

- Migrate specs by priority.
- Replace Protractor-specific API with Playwright/TestKit API.
- Add/adjust fixtures and test data setup.

### Phase 3: Stabilization

- Resolve flaky selectors and waits.
- Add or improve assertions.
- Refactor duplicate helpers.

### Phase 4: Quality gates

- `npx tsc --noEmit`
- `npm run eslint-check`
- Run affected Playwright specs (desktop/mobile as needed)

## 9. Verification Plan (mcp chrome-devtools)

For each migrated spec group:

1. Run affected tests with artifacts enabled (`npx playwright test <affected-specs> --trace on`).
2. Open target page in Creatio and verify initial render.
3. Execute migrated user flow (core action).
4. Validate expected UI outcome and persisted state.
5. Capture screenshot evidence.
6. Record pass/fail and blockers.

Include:

- exact Playwright command(s) used,
- artifact locations in `test-results/` and `playwright-report/`.

## 10. Failure Debug Plan (required when validation fails)

1. Reproduce the failing business flow in Creatio with `mcp chrome-devtools` first (primary method).
2. Use subagents to explore multiple failing flows in parallel when needed.
3. Collect failing test artifacts from `test-results/` (trace, screenshot, video, error logs).
4. Review run summary and stack details in `playwright-report/`.
5. Correlate artifact evidence with live UI/network behavior and identify probable root cause.
6. Define minimal fix actions and re-check steps in application before re-running full tests.

## 11. Risks and Mitigations

- 7.x/extJs pages mixed with 8.x pages.
- Missing TestKit element abstractions.
- Grid column/dataSource mismatches.
- Environment-specific data dependencies.

## 12. Used References

1. `node_modules/@creatio/playwright-testkit/dist/docs/<file>.md`
2. `docs/ai-migration/migration-patterns.md`
3. Additional local sources (if needed)
