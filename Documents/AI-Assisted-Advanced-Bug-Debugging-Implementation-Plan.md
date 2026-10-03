# AI-Assisted Advanced Bug Debugging — Implementation Plan

**Version:** 1.0  
**Date:** 2026-10-03  
**Implementation style:** phased, test-driven, repository-first, model-agnostic

---

## 0. Implementation Strategy

Build the platform as a deterministic control system around probabilistic AI workers.

The implementation order matters:

1. establish reproducibility and repository understanding;
2. build deterministic scheduling and artifact storage;
3. add semantic reasoning;
4. add independent validation;
5. add advanced testing methods;
6. add automated repair;
7. add continuous evaluation and learning;
8. integrate with CI/CD.

Do not start by building a general autonomous agent that can freely modify repositories. First build the evidence pipeline.

---

# Phase 0 — Project Bootstrap

## Objectives
Create the repository structure, coding standards, environment, CI, logging, configuration, and security boundaries.

## Deliverables

```text
/aadb
  /apps
    /api
    /worker
    /web
  /core
    /domain
    /orchestrator
    /policies
    /artifacts
  /agents
    /scanner
    /validator
    /repair
    /testing
  /adapters
    /models
    /runners
    /static_analysis
    /symbolic
    /mutation
    /vcs
  /sandbox
  /evals
  /prompts
  /knowledge
  /tests
  /docs
```

## Required outputs

- reproducible local development environment;
- CI pipeline;
- typed configuration;
- structured logging;
- database migrations;
- basic artifact storage;
- test harness.

## Definition of done
A clean checkout can be built, started, tested, and stopped using documented commands.

---

# Phase 1 — Repository Intake and Catalog

## Goal
Understand any repository before asking an AI to reason about it.

## Tasks

### 1.1 Repository scanner
Detect:

- languages;
- package managers;
- build files;
- test frameworks;
- source roots;
- generated files;
- configuration;
- CI files;
- Docker/container files;
- API specifications;
- database migrations;
- service boundaries.

### 1.2 Baseline executor
Run:

- build;
- tests;
- static analysis where available.

Record:

- commands;
- exit codes;
- logs;
- timing;
- artifact hashes.

### 1.3 Repository catalog
Create machine-readable catalog.

### 1.4 Change detector
Compute changed files relative to:

- previous commit;
- branch base;
- last successful scan.

## Acceptance test
Create a fixture repository with at least two languages and verify catalog correctness.

---

# Phase 2 — Context Builder

## Goal
Transform a repository into structured reasoning context.

## Tasks

1. Parse repository tree.
2. Detect entry points.
3. Build dependency relationships.
4. Extract symbols.
5. Map test references.
6. Identify sensitive operations.
7. Identify state transitions.
8. Extract trust boundaries.
9. Extract business rules.
10. Link requirements/documentation/tests to code.
11. Build compact context packets.

## Context packet schema

```json
{
  "repository": "...",
  "commit": "...",
  "feature": "...",
  "entry_points": [],
  "files": [],
  "symbols": [],
  "data_flows": [],
  "state_transitions": [],
  "trust_boundaries": [],
  "sensitive_operations": [],
  "invariants": [],
  "existing_tests": [],
  "known_mitigations": [],
  "unknowns": []
}
```

## Acceptance test
Given a fixture feature, the system should identify the correct entry point, state transition, and invariant.

---

# Phase 3 — Deterministic Scan Director

## Goal
Ensure the AI sees the right part of the repository at the right time.

## Tasks

- feature catalog;
- scan queue;
- priority model;
- historical dispersion;
- change-aware scheduling;
- blind-spot detection;
- stale target scheduling;
- threat-model coverage tracking;
- scan budget;
- resumable jobs.

## Suggested priority formula

Use an explainable weighted score:

```text
priority =
  change_weight
+ criticality_weight
+ trust_boundary_weight
+ untested_weight
+ stale_weight
+ historical_failure_weight
- recent_scan_penalty
```

Do not make priority dependent only on an LLM-generated label.

## Acceptance test
Repeated scan requests must not produce identical target selection until the coverage rules justify it.

---

# Phase 4 — Scanner Agent

## Goal
Implement deep semantic reasoning without allowing the LLM to declare victory.

## Required flow

### Step 1 — Context Building
Map the target flow end-to-end.

### Step 2 — Threat/Failure Modeling
Define what must never happen.

### Step 3 — Hypothesis Generation
Create a small set of high-value "what-if" scenarios.

### Step 4 — Hypothesis Testing
Compare each hypothesis against actual code.

### Step 5 — Finding Validation
Prepare the hypothesis for independent validation.

## Scanner constraints

- never invent APIs;
- never invent requirements;
- never invent files;
- distinguish facts from inferences;
- cite source locations;
- keep hypothesis count bounded;
- prioritize deep issues;
- produce structured output.

---

# Phase 5 — Test Generation Engine

Implement pluggable methods.

## 5A. Property-Based Testing

### Build
- property templates;
- input domain extraction;
- generator synthesis;
- shrinking/counterexample storage;
- invalid-property detection.

### Test
- pure functions;
- parsing;
- validation;
- state transitions;
- business rules;
- numerical logic.

---

## 5B. Metamorphic Testing

### Build
- relation library;
- transformation engine;
- source/follow-up test generator;
- relation verification.

### Initial relation templates

- permutation;
- duplication;
- normalization;
- irrelevant-field insertion;
- equivalent encoding;
- time-preserving shift;
- idempotence;
- commutativity.

---

## 5C. Differential Testing

### Build
- multiple runner targets;
- output canonicalization;
- comparison engine;
- authoritative-source policy.

### Test targets

- old vs new;
- implementation A vs B;
- API vs domain service;
- optimized vs reference implementation.

---

## 5D. Static-Analysis Adapter

Create generic interfaces:

```text
analyze(repository, target)
  -> candidate_locations
  -> data_flow
  -> diagnostics
```

Start with one widely useful analyzer, then add adapters.

---

## 5E. Symbolic Execution Adapter

Requirements:

- harness generation;
- driver/stub generation;
- assertion synthesis;
- iterative compile feedback;
- symbolic run;
- concrete replay.

Do not require symbolic execution for every repository.

---

# Phase 6 — Sandbox / Execution Lab

## Goal
Provide the source of truth for dynamic validation.

## Requirements

- disposable worktree/container;
- reproducible dependency installation;
- restricted network;
- CPU/memory/time quotas;
- command allowlist;
- filesystem isolation;
- secret redaction;
- artifact capture;
- process tree capture;
- deterministic environment metadata.

## Execution types

- unit;
- integration;
- property;
- fuzz;
- metamorphic;
- differential;
- symbolic replay;
- mutation;
- regression.

## Acceptance test
Run a malicious or runaway fixture and verify the sandbox terminates it without affecting the host environment.

---

# Phase 7 — Validator Agent

## Goal
Independently decide whether a candidate is real.

## Steps

1. Load full context.
2. Ignore scanner conclusion initially.
3. Reconstruct the flow.
4. Identify the exact rule.
5. Challenge the hypothesis.
6. Search for mitigations.
7. Build minimal reproduction.
8. Execute reproduction.
9. Measure actual impact.
10. Classify.

## Output statuses

```text
CONFIRMED
MITIGATED
INVALID
INSUFFICIENT_EVIDENCE
TEST_GENERATOR_DEFECT
ENVIRONMENT_FAILURE
```

## Critical rule
No execution result -> no "confirmed" label unless a formally equivalent proof is available.

---

# Phase 8 — Evidence Store

Build immutable evidence artifacts.

Each evidence bundle should contain:

```text
repository commit
context hash
prompt version
model
tool versions
commands
inputs
outputs
logs
test source
patch
result
timestamp
```

Use content-addressable storage where practical.

---

# Phase 9 — Finding Management

Implement the finding lifecycle:

```text
CANDIDATE
  -> VALIDATING
  -> CONFIRMED
  -> PATCHING
  -> VERIFYING
  -> VERIFIED
  -> HUMAN_REVIEW
  -> CLOSED
```

Alternate terminal states:

```text
DISMISSED
MITIGATED
BLOCKED
UNRESOLVED
```

---

# Phase 10 — Automated Program Repair

## 10.1 Localization

Combine:

- failing test;
- stack trace;
- static analyzer location;
- search;
- repository history;
- dependency mapping.

## 10.2 Root-cause hypothesis

Before editing, require the agent to explain:

- what invariant is violated;
- why the current code violates it;
- which smallest change should restore it.

## 10.3 Patch generation

Strategy:

1. one-file minimal patch;
2. minimal multi-file patch;
3. structural patch only if necessary.

## 10.4 Validation loop

```text
patch
 -> targeted test
 -> regression suite
 -> static analysis
 -> mutation/invariant check
 -> review diff
```

On failure:

```text
capture failure
 -> update hypothesis
 -> generate next patch
```

Stop at configured budget.

---

# Phase 11 — Mutation-Guided Hardening

## Goal
Turn confirmed logic bugs into permanent protection.

For each verified bug:

1. define the invariant;
2. synthesize a meaningful mutant;
3. verify the mutant changes behavior;
4. generate a catching test;
5. confirm test kills mutant;
6. keep the test in regression suite.

Examples:

- remove owner check;
- invert boundary;
- bypass state transition;
- alter date window;
- skip privacy filter;
- change arithmetic relation.

---

# Phase 12 — Knowledge and Calibration

Implement a versioned knowledge base.

## Knowledge types

- product context;
- accepted risks;
- invariants;
- severity rules;
- dismissed patterns;
- common mitigations;
- historical bugs;
- repair recipes;
- test relations;
- benchmark tasks.

## Update flow

```text
human correction
    -> structured correction
    -> knowledge entry
    -> prompt/rule version
    -> evaluation
```

Never let the system silently rewrite policy from a single model response.

---

# Phase 13 — Evaluation Harness

## Core requirement
Evaluate actual environment outcomes, not only text.

## Trial structure

```text
task
 -> baseline
 -> agent run
 -> environment state
 -> tests
 -> graders
 -> final outcome
```

## Graders

### Code-based
- tests;
- build;
- static analysis;
- mutation score;
- file/diff constraints.

### Model-based
- reasoning quality;
- evidence completeness;
- report quality.

### Human
- high-impact sample review;
- ambiguous findings;
- severity calibration.

## Evaluation datasets

Create internal tiers:

1. known bugs;
2. synthetic seeded logic bugs;
3. mutation-derived bugs;
4. historical production bugs;
5. adversarial edge cases;
6. negative controls (valid code that should not trigger findings).

---

# Phase 14 — CI/CD Integration

Implement:

- pull request gate;
- changed-code scan;
- nightly deep scan;
- release scan;
- post-fix regression scan.

Recommended policy:

```text
validated high-impact bug -> block
unvalidated hypothesis     -> warn
environment failure        -> mark inconclusive
test regression            -> block
AI patch                   -> require review
```

---

# Phase 15 — Web UI

## Screen 1 — Dashboard
- scan coverage;
- validated bugs;
- active jobs;
- repair status;
- test hardening;
- eval health.

## Screen 2 — Repository
- catalog;
- features;
- last scan;
- risk map;
- coverage.

## Screen 3 — Scan
- target;
- context;
- hypotheses;
- tests;
- tool activity.

## Screen 4 — Finding
- issue;
- evidence;
- reproduction;
- capability delta;
- patch;
- verification.

## Screen 5 — Evaluation
- task;
- run;
- transcript;
- environment outcome;
- grader score;
- failure analysis.

---

# Phase 16 — Production Hardening

Before release:

- secret scanning;
- sandbox escape tests;
- dependency scanning;
- prompt-injection tests;
- malformed-tool-output tests;
- model timeout tests;
- partial-worker failure tests;
- database recovery tests;
- queue retry/idempotency tests;
- audit-log integrity tests.

---

# Phase 17 — Launch Readiness

## Must pass

### Correctness
- confirmed finding reproducibility;
- patch verification;
- regression suite.

### Safety
- isolation;
- no unapproved production changes;
- least privilege.

### Quality
- low false-positive rate after validation;
- meaningful evidence;
- stable reports.

### Operations
- resumable jobs;
- metrics;
- alerting;
- backup/recovery.

### AI quality
- prompt versioning;
- trace capture;
- eval suite;
- calibration loop.

---

# 18. Recommended Milestones

| Milestone | Outcome |
|---|---|
| M0 | Project builds and CI works |
| M1 | Repository catalog + baseline |
| M2 | Context Builder + Scan Director |
| M3 | Scanner + hypothesis engine |
| M4 | Sandbox + Validator |
| M5 | PBT + metamorphic testing |
| M6 | Differential + static-analysis adapters |
| M7 | Mutation hardening |
| M8 | Automated repair |
| M9 | Evaluation harness |
| M10 | CI/UI integration |
| M11 | Security hardening |
| M12 | Production readiness |

---

# 19. Engineering Rules for the Implementing AI

1. Read existing code before creating abstractions.
2. Preserve working behavior unless change is necessary.
3. Build small vertical slices.
4. After every significant change, run the smallest relevant test first.
5. Then run the broader regression suite.
6. Never hide failing tests.
7. Never fabricate an available command.
8. Never assume a dependency exists without checking.
9. Keep interfaces explicit.
10. Keep generated artifacts deterministic where possible.
11. Make every AI decision traceable.
12. Use feature flags for experimental methodologies.
13. Prefer adapters over hard-coded vendor integrations.
14. Treat model output as untrusted input.
15. Treat "done" as an execution result, not a narrative claim.

---

# 20. Technical Backlog Template

For every implementation task use:

```text
Task ID:
Title:
Goal:
Inputs:
Preconditions:
Files/Modules:
Implementation:
Tests:
Security considerations:
Observability:
Acceptance criteria:
Rollback:
Dependencies:
```

---

# 21. Final Implementation Gate

No phase may be considered complete until:

- the implementation exists;
- tests exist;
- tests pass;
- logs exist;
- failure cases are handled;
- the phase output is reusable by the next phase;
- documentation is updated;
- no known unresolved blocker is hidden.

The overall project must be implemented as an evidence-producing pipeline, not merely a chat interface over a codebase.
