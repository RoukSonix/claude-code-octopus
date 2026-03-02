# Test Run Report

Use this structure for the final output.

## 1. Summary

| Metric | Value |
|---|---|
| Services tested | N |
| Test suites run | N |
| Total tests | N |
| Passed | N |
| Failed | N |
| Skipped | N |
| Total duration | Nm Ns |
| Overall status | PASS / FAIL |

## 2. Changed Services

| Service | Path | Changed Files | Detection Method |
|---|---|---|---|
| api-service | `services/api/` | 12 | git diff vs main |
| web-app | `services/web/` | 5 | git diff vs main |

Detection method values:
- `git diff vs <branch>`
- `explicit path`
- `--all flag`

## 3. Environment Readiness

| Service | Status | Issues | Fix Commands |
|---|---|---|---|
| api-service | ready | - | - |
| web-app | needs-setup | node_modules missing | `cd services/web && npm install` |

Status values:
- `ready` - all prerequisites met
- `needs-setup` - fixable issues with listed commands
- `blocked` - critical dependency missing

## 4. Test Results Matrix

| Service | Unit | Integration | Component | E2E | Performance |
|---|---|---|---|---|---|
| api-service | 45/45 pass | 12/14 pass | - | - | - |
| web-app | 89/90 pass | - | 15/15 pass | 8/8 pass | - |

Cell format: `passed/total status` or `-` if test type not present.

## 5. Failure Details

### Service: `<service-name>`

#### Test Type: `<type>`

**Runner:** `<runner-name>` | **Command:** `<command-used>`

| # | Test | File | Error |
|---|---|---|---|
| 1 | should validate email format | `src/validators/__tests__/email.test.ts:42` | Expected "valid" but received "invalid" |
| 2 | should handle timeout | `src/api/__tests__/client.test.ts:88` | Timeout of 5000ms exceeded |

<details>
<summary>Full error output for test #N</summary>

```
Paste relevant error output here (first 20 lines).
```

</details>

Repeat for each failing test type and service.

## 6. Coverage Summary

| Service | Lines | Branches | Functions | Statements |
|---|---|---|---|---|
| api-service | 78.5% | 65.2% | 82.1% | 79.0% |
| web-app | 91.2% | 87.4% | 93.5% | 90.8% |

Note: coverage data is only available when the test runner supports it and `--coverage` flag was used.
If coverage is not available for a service, note "N/A" and explain why.

## 7. Recommendations

List actionable items based on the test run results:

- **Missing test types**: services without integration/e2e tests
- **Low coverage areas**: files or modules below threshold
- **Flaky tests**: tests that show intermittent behavior (if detected)
- **Environment improvements**: CI configuration suggestions
- **New test suggestions**: uncovered code paths in changed files

Format each recommendation as:

| Priority | Service | Recommendation | Rationale |
|---|---|---|---|
| high | api-service | Add integration tests for new endpoint | Endpoint `/api/v2/users` has no integration coverage |
| medium | web-app | Fix flaky timeout test | `client.test.ts:88` failed with timeout |
| low | web-app | Increase branch coverage | Branch coverage 65.2% is below 80% threshold |

Priority values: `critical`, `high`, `medium`, `low`.
