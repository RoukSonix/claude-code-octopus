---
name: jira-parallel-execution-planner
description: Analyze a Jira task from a link or issue key, collect all linked tasks, validate execution sequence and parallelization constraints, assess repository readiness for implementation, and produce both an implementation plan and a parallel subagent execution plan. Use when delivery planning depends on Jira dependencies and real codebase state.
argument-hint: "<JIRA-ISSUE-KEY or URL>"
license: MIT
compatibility: opencode
---

# Jira Parallel Execution Planner

## Goal

Turn a Jira issue and its dependency graph into an execution-ready delivery strategy grounded in the current repository state.

## Required Inputs

Collect before planning:

- Jira issue URL or issue key
- Target repository path and active branch (if relevant)
- Scope constraints (deadline, mandatory components, no-touch areas), if provided

If Jira access is unavailable, report the blocker and continue with a best-effort plan from available text only.

## Workflow

### 1. Analyze the primary Jira task

- Fetch issue summary, description, acceptance criteria, status, assignee, priority, labels, and sprint/release data.
- Extract explicit requirements and implicit constraints.
- Normalize requirements into clear deliverables with verification signals.

### 2. Collect all related tasks

- Fetch parent/epic links, subtasks, and issue links (`blocks`, `is blocked by`, `relates to`, duplicates, dependencies).
- Build a dependency map with issue key, relation type, and current status.
- Flag missing references when a description mentions tasks not linked in Jira.

### 3. Validate execution order and parallelization claims

- Derive an execution graph from link semantics and status.
- Compute a recommended order (topological where possible).
- Compare any sequence/parallel notes in Jira text against the actual dependency graph.
- Confirm parallel execution only when all checks pass:
  - No dependency edge violation
  - No shared irreversible step conflict (for example: same DB migration scope)
  - No high-risk file ownership overlap without a defined merge order
- Mark each claim as `valid`, `conditionally valid`, or `invalid`, and explain why.

### 4. Assess codebase readiness

- Map each requirement to existing modules, services, APIs, schemas, UI components, and tests.
- Identify reusable implementation points and integration seams.
- Identify missing pieces (new entities, migrations, endpoints, contracts, UI flows, tests, infra).
- Produce a readiness classification per requirement:
  - `ready`: implementation path is clear with existing foundations
  - `partial`: foundations exist but critical gaps remain
  - `blocked`: prerequisite architecture or dependency is missing

### 5. Build the implementation plan

- Split work into ordered phases with clear deliverables.
- Add acceptance checks and test strategy per phase.
- Include risk handling for dependencies and rollback-sensitive steps.

### 6. Build the parallel subagent plan

- Partition work into independent tracks with explicit ownership boundaries.
- Assign one owner per track (service or file-scope ownership).
- Define prerequisites, expected outputs, validation commands, and sync points.
- Define merge/integration order and conflict resolution checkpoints.

## Output Contract

Use `references/analysis-checklist.md` as the default output structure.

Always include:

- Dependency findings with concrete issue keys
- Validation of claimed execution order or parallel steps
- Codebase readiness matrix tied to requirements
- Final implementation plan
- Final subagent parallelization plan

## Jira Workflow Constraint

When asked to transition completed Jira tasks, move to `Acceptance` (transition ID `6`), not `Done`.
