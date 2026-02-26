# Analysis Checklist

Use this structure for final outputs.

## 1. Primary Jira Task Summary

- Issue key:
- URL:
- Summary:
- Status:
- Priority:
- Assignee:
- Acceptance criteria (normalized):

## 2. Linked Issues and Dependency Map

| Issue | Relation | Direction | Status | Planning Impact |
|---|---|---|---|---|
| CY-123 | blocks | outbound | In Progress | Must finish before CY-456 |

Add notes for missing links explicitly referenced in descriptions.

## 3. Sequence and Parallelization Validation

| Claim Source | Claim | Validation | Reason |
|---|---|---|---|
| CY-456 description | "Frontend and API can run in parallel" | conditionally valid | Shared contract update requires sync checkpoint |

Validation values:

- `valid`
- `conditionally valid`
- `invalid`

## 4. Codebase Readiness Matrix

| Requirement | Existing Code | Gaps | Readiness | Notes |
|---|---|---|---|---|
| Add endpoint X | `cimetry-api/app/api/endpoints/...` | Missing schema + tests | partial | Reuse service Y |

Readiness values:

- `ready`
- `partial`
- `blocked`

## 5. Implementation Plan

| Phase | Scope | Dependencies | Deliverables | Validation |
|---|---|---|---|---|
| 1 | Contract and schema changes | None | Updated schemas + migration | Unit tests + migration check |

## 6. Parallel Subagent Plan

| Track | Agent Scope | Owned Paths | Prerequisites | Deliverables | Sync Point |
|---|---|---|---|---|---|
| API track | Backend API updates | `cimetry-api/app/api/...` | Contract approved | Endpoints + tests | Before frontend wiring |

Rules:

- Avoid overlapping file ownership across tracks.
- Define explicit handoff points for shared contracts.
- Include one integration stage after parallel tracks.
