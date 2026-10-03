# AI-Assisted Advanced Bug Debugging — Product Requirements Document (PRD)

**Document status:** Implementation-ready  
**Version:** 1.0  
**Date:** 2026-10-03  
**Primary source:** `AI-Assisted Advanced Bug Debugging.pdf`  
**External verification:** WorkOS logic-vulnerability pipeline, Meta ACH/LLM mutation-testing research, Anthropic agent-evaluation guidance, Agentless, SAILOR, Agentic-PBT, LLMORPH, DiffSpec, and SWE-Bench Pro materials.

---

## 1. Product Definition

### 1.1 Product name
**AI-Assisted Advanced Bug Debugging (AADB)**

### 1.2 One-line definition
AADB is a repository-aware, evidence-driven engineering platform that uses deterministic orchestration and LLM reasoning to discover, reproduce, validate, explain, test, and safely repair complex logic bugs that ordinary unit tests, coverage metrics, fuzzers, and static scanners may miss.

### 1.3 Core thesis
The system must treat software correctness as more than crash detection. Traditional automated testing is strong at mechanical failures, but complex semantic/business-logic defects can execute successfully while violating product intent. The PDF calls this the **coverage illusion**: high line/branch coverage can coexist with important semantic failures because tests do not understand domain intent.

The product therefore uses AI as a semantic reasoning layer while preserving deterministic control, executable evidence, and independent validation.

### 1.4 Primary design rule
**Never treat an LLM assertion as proof of a bug.**

Every candidate finding must move through a validation chain:

`Context -> Hypothesis -> Test -> Execution -> Evidence -> Independent Validation -> Classification`

Only validated findings may enter the confirmed-issue workflow.

---

# 2. Problem Statement

Modern software systems contain bugs that are difficult for conventional tooling to detect because the failure is not a crash, syntax error, memory fault, or obvious API misuse.

Examples include:

- authorization checks present in one flow but missing in a legacy flow;
- a resource ownership rule enforced during creation but not during redemption;
- temporal/business rules that fail only at exact boundaries;
- concurrent requests that violate a state invariant;
- incorrect arithmetic or comparison logic that still returns a valid result;
- cross-module assumptions that diverge;
- semantic regressions introduced by an otherwise valid refactor;
- privacy/compliance rules violated in an edge case;
- a patch that fixes one path while breaking a distant dependency.

The PDF identifies the following limitations:

1. Traditional fuzzing is highly effective for absolute mechanical failures but structurally blind to many semantic/domain bugs.
2. High branch or line coverage does not imply correctness.
3. LLMs can reason about intent but are probabilistic and can hallucinate findings.
4. Long codebase context can degrade model attention.
5. AI-generated fixes may introduce secondary bugs or security weaknesses.
6. Therefore an enterprise solution must separate target selection, hypothesis generation, independent validation, repair, and continuous evaluation.

---

# 3. Product Vision

Build a debugging system that behaves like a disciplined software-research team:

- a **Scan Director** systematically covers the repository;
- a **Context Builder** maps architecture, flows, invariants, and trust boundaries;
- a **Scanner** generates a small number of deep, grounded hypotheses;
- specialized **Testing Agents** turn hypotheses into executable checks;
- an isolated **Validator** reproduces the suspected defect and measures its capability/business impact;
- an **APR Agent** proposes the smallest safe patch;
- the **Verification Engine** proves that the patch resolves the bug without introducing regressions;
- an **Evaluation Harness** measures the quality of the whole pipeline;
- a persistent **Learning/Knowledge Layer** turns confirmed corrections and dismissed findings into reusable context.

---

# 4. Goals

## 4.1 Primary goals

1. Detect deep semantic and domain-specific logic bugs.
2. Reduce false positives through independent reproduction.
3. Systematically cover an entire repository instead of repeatedly scanning the same easy code.
4. Generate executable tests from natural-language product intent.
5. Support multiple complementary testing methodologies:
   - Agentic Property-Based Testing
   - Metamorphic Testing
   - Differential Testing
   - Static-Analysis-Guided Symbolic Execution
   - Mutation-Guided Test Generation
   - Conventional unit/integration/fuzz testing
6. Safely repair validated bugs.
7. Prevent regressions by preserving every confirmed bug as a regression asset.
8. Measure the quality of the AI system using objective outcome-based evaluation.
9. Keep humans in control of production changes and architectural modifications.
10. Remain model-provider-agnostic.

## 4.2 Secondary goals

- Prioritize changed and previously unscanned code.
- Use cheaper models for routine tasks and stronger models for difficult reasoning.
- Preserve complete evidence trails.
- Support CI/CD and scheduled scans.
- Support repository-level rather than single-file reasoning.
- Provide developer-readable reports and machine-readable artifacts.

---

# 5. Non-Goals

The initial product does not attempt to:

- replace all conventional static analysis or fuzzing;
- guarantee absence of all software bugs;
- autonomously deploy arbitrary patches to production;
- infer undocumented business policy as fact;
- fabricate missing requirements;
- operate as an offensive exploitation platform against systems the user does not own or authorize;
- optimize only for benchmark scores;
- make model selection dependent on a single vendor.

---

# 6. Design Principles

1. **Evidence over confidence.**
2. **Source-of-truth over model intuition.**
3. **Deterministic orchestration around probabilistic reasoning.**
4. **Independent validation of independent analysis.**
5. **Minimal patches before complex rewrites.**
6. **Reproducibility before remediation.**
7. **Changed-code and blind-spot coverage before repetitive rescans.**
8. **Every confirmed bug creates a regression asset.**
9. **Every false positive becomes a calibration signal.**
10. **No "fixed" claim without an executable verification result.**
11. **Use model reasoning as an orchestrator and synthesizer, not as the sole oracle.**
12. **Minimize context to relevant slices while retaining enough architectural context to avoid local fixes that break global invariants.**

---

# 7. Target Users

## 7.1 Developer
Needs fast diagnosis, root cause, reproduction, regression tests, and a minimal patch.

## 7.2 QA/Automation Engineer
Needs generated properties, metamorphic relations, mutation tests, test coverage evidence, and reproducible failures.

## 7.3 Security Engineer
Needs trust-boundary reasoning, attacker hypotheses, preconditions, capability delta, and reproducible evidence.

## 7.4 Tech Lead/Architect
Needs system-level impact analysis and assurance that a local fix does not violate architectural invariants.

## 7.5 Engineering Manager
Needs scan coverage, signal/noise ratios, regression trends, repair rates, and evaluation metrics.

## 7.6 CI/CD Platform
Needs deterministic APIs, machine-readable findings, pass/fail gates, and artifact retention.

---

# 8. Core User Journeys

## Journey A — Repository onboarding

1. User connects a repository.
2. System identifies language(s), build system, tests, package managers, services, databases, and CI configuration.
3. System builds a repository catalog.
4. System extracts products/features/modules.
5. System records trust boundaries and critical flows.
6. System runs baseline tests.
7. System stores baseline hashes and environment information.
8. Repository becomes eligible for scheduled scanning.

## Journey B — Deep logic scan

1. Scan Director selects an unexamined or recently changed target.
2. Context Builder assembles a bounded code/context packet.
3. Scanner maps flow and invariants.
4. Scanner creates a few high-value hypotheses.
5. Each hypothesis becomes one or more executable checks.
6. Validator independently re-reads source.
7. Validator reproduces the behavior in a disposable environment.
8. System classifies the result as:
   - confirmed bug,
   - mitigated,
   - invalid,
   - insufficient evidence,
   - test-generation defect,
   - environment failure.
9. Confirmed bugs receive standardized reports.

## Journey C — Automated repair

1. Repair agent localizes the cause.
2. Baseline failure is frozen.
3. Minimal patch is proposed.
4. Patch is applied in a sandbox/worktree.
5. Regression suite runs.
6. Targeted new test runs.
7. Mutation/safety checks run when applicable.
8. Static/security analysis runs.
9. If all gates pass, patch becomes "verified candidate."
10. Human review remains required for protected branches/architectural changes.

## Journey D — Continuous learning

1. Findings are reviewed.
2. Confirmed/dismissed outcomes are stored.
3. Product context and severity calibration are updated.
4. Prompts and rules are versioned.
5. Evaluation suite reruns to detect regressions in the AI system itself.

---

# 9. Functional Requirements

## FR-001 Repository Intake

The system shall:

- accept a repository via local path, mounted workspace, git checkout, or CI workspace;
- detect project language(s) and build systems;
- discover tests and test runners;
- identify executable entry points;
- detect configuration files;
- identify services and external dependencies;
- record repository commit/ref;
- support monorepos;
- support repository snapshots for reproducibility.

**Acceptance criteria**
- A newly connected repository produces a machine-readable repository catalog.
- Baseline commands can be executed reproducibly.
- Unknown build/test configuration is reported as unknown, not invented.

---

## FR-002 Repository Catalog / Scan Director

The Scan Director shall maintain:

- feature/module catalog;
- scan history;
- code ownership or component ownership when available;
- changed-code map;
- previously tested flows;
- previously dismissed findings;
- threat-model coverage;
- test-method coverage;
- stale/unscanned targets.

Priority order should generally favor:

1. newly changed critical code;
2. previously unexamined critical flows;
3. security-sensitive/trust-boundary flows;
4. previously weakly covered business-critical areas;
5. stale recurring scans;
6. lower-risk baseline coverage.

The scheduler must avoid repeatedly scanning the same target with identical context.

---

## FR-003 Context Builder

The Context Builder shall produce a structured context packet containing, when available:

- feature purpose;
- public/internal entry points;
- relevant files;
- function/class signatures;
- data flow;
- state transitions;
- external calls;
- trust boundaries;
- authentication/authorization relationships;
- tenant/resource relationships;
- persistent state changes;
- invariants;
- error-handling paths;
- concurrency considerations;
- time/date assumptions;
- related tests;
- related historical bugs;
- build/test commands;
- known accepted risks.

The packet should be small enough to preserve model attention but rich enough for system-level reasoning.

---

## FR-004 Domain Intent Extraction

The system shall derive testable intent from:

- requirements;
- documentation;
- API schemas;
- comments;
- test cases;
- configuration;
- historical issues;
- product context supplied by the user;
- observed runtime behavior.

Each extracted rule shall include:

- rule identifier;
- statement;
- source;
- confidence;
- affected components;
- invariants;
- examples;
- boundary conditions.

Unverified inferred rules must be explicitly labeled as inferred.

---

## FR-005 Scanner

The Scanner shall implement a five-phase reasoning sequence:

1. **Context Building**
2. **Threat Modeling**
3. **Attacker/Failure Hypotheses**
4. **Hypothesis Testing**
5. **Finding Validation**

The scanner should prioritize a small number of deep, plausible hypotheses over long lists of shallow issues.

For security-sensitive flows it should reason across:

`credentials -> tenant/org -> session -> actor -> resource -> state transition -> sensitive operation`

and look for broken links in that relationship chain.

---

## FR-006 Hypothesis Model

Each hypothesis shall include:

- hypothesis ID;
- target flow;
- premise;
- expected invariant;
- preconditions;
- mutation/perturbation;
- expected behavior;
- suspected bad behavior;
- impact;
- evidence required;
- confidence before validation;
- validation status.

The scanner is forbidden from converting a hypothesis into a confirmed finding without executable evidence or a formally equivalent proof.

---

## FR-007 Agentic Property-Based Testing

The system shall support generated properties/invariants and executable property-based tests.

Pipeline:

`target function/flow -> inferred domain -> candidate invariants -> generator -> property test -> execution -> counterexample -> analysis`

The agent must distinguish:

- genuine application failure;
- invalid property;
- invalid input generator;
- environment issue;
- flaky execution.

The system shall retain generated properties for later mutation/regression evaluation.

---

## FR-008 Metamorphic Testing

The system shall support relationships between source input and transformed input.

Examples of generic transformations:

- permutation that should preserve semantic output;
- addition of irrelevant data;
- equivalent identifier representation;
- time shift that should preserve a duration-based rule;
- duplicated idempotent action;
- commutative input reordering;
- case normalization where semantics are defined as insensitive;
- equivalent serialization/deserialization.

Every metamorphic test must specify:

- source input;
- transformation;
- expected relationship;
- observed outputs;
- violation;
- whether the relation is supported by a documented/inferred rule.

---

## FR-009 Differential Testing

Where multiple implementations or execution paths exist, the system shall compare:

- implementation A vs B;
- old version vs candidate version;
- independent parser/validator implementations;
- reference implementation vs optimized implementation;
- API layer vs domain-service behavior.

A divergence shall not automatically become a bug; the system must determine which behavior is authoritative.

---

## FR-010 Static Analysis and Symbolic Execution

The system shall support an adapter architecture for static analysis tools.

Static analysis can identify:

- suspicious data-flow locations;
- security-relevant sinks;
- candidate vulnerable functions;
- state relationships;
- dependency facts.

For supported codebases, an LLM may synthesize symbolic-execution harnesses, assertions, stubs, and drivers.

Symbolic findings must be concretely replayed against the unmodified project source when feasible.

---

## FR-011 Conventional Fuzzing Integration

The platform shall preserve conventional fuzzing for mechanical failures.

Fuzzing should complement rather than replace semantic testing.

The system shall ingest fuzzing results into the common finding/evidence model.

---

## FR-012 Validator Agent

Validator is an independent stage and must not simply accept Scanner output.

Validator shall:

- re-read full relevant source;
- inspect the product context;
- inspect trust boundaries;
- verify mitigations;
- inspect accepted risks;
- build a concrete reproduction;
- execute the reproduction;
- measure actual capability or business impact;
- classify the candidate;
- explain dismissal reasons.

Dynamic reproduction should occur in a disposable sandbox whenever possible.

---

## FR-013 Capability Delta

For relevant security/business-logic findings, the report shall record:

- attacker/user starting state;
- required privileges;
- final achieved state;
- resources affected;
- cross-tenant/cross-user impact;
- authorization boundary crossed;
- data/state accessed or modified;
- practical business impact.

This prevents severity inflation when the actor already possesses the capability being claimed.

---

## FR-014 Evidence Model

A confirmed issue shall contain evidence such as:

- exact repository version;
- relevant files and locations;
- requirement/rule violated;
- minimal reproduction;
- commands executed;
- stdout/stderr;
- input/fixture;
- expected result;
- actual result;
- patch hash;
- post-fix result;
- regression results;
- static analysis results;
- mutation results where applicable.

---

## FR-015 Bug Classification

Supported classifications:

- syntax/build failure;
- unit-test failure;
- integration failure;
- semantic logic bug;
- state-transition bug;
- concurrency/race logic bug;
- authorization/business-rule bug;
- data-validation bug;
- numerical precision bug;
- temporal/boundary bug;
- parser/protocol divergence;
- privacy/compliance regression;
- regression introduced by patch;
- flaky/indeterminate;
- false positive;
- insufficient evidence.

---

## FR-016 Severity

Severity must be calculated from explicit dimensions rather than model tone:

- affected asset;
- preconditions;
- attacker/user capabilities;
- exploit/reproduction reliability;
- scope of impact;
- data/business impact;
- authorization boundary crossed;
- available mitigations;
- detectability;
- reversibility.

The system shall retain the raw dimensions and the final classification rationale.

---

## FR-017 Automated Program Repair

Repair shall follow:

`Localize -> Understand -> Hypothesize Root Cause -> Patch -> Test -> Refine -> Verify`

Rules:

- freeze baseline reproduction first;
- prefer smallest viable patch;
- avoid unrelated refactoring;
- preserve public interfaces unless required;
- add or update regression tests;
- re-run all relevant tests;
- re-run security/static analysis;
- run targeted mutation tests for the repaired invariant when possible;
- stop after a configured retry/step budget;
- never silently widen scope.

---

## FR-018 Patch Safety

All AI-generated patches shall be treated as untrusted until verified.

Required gates:

1. formatting/lint/build;
2. targeted regression;
3. affected test suite;
4. repository-wide tests where practical;
5. static/security analysis;
6. mutation or invariant checks when applicable;
7. diff review;
8. architectural compatibility checks for multi-module changes.

Production merges require human approval unless explicitly configured otherwise.

---

## FR-019 Mutation-Guided Hardening

The system shall support business-meaningful mutants, including examples such as:

- invert a comparison;
- remove an authorization check;
- alter a boundary from inclusive to exclusive;
- skip a state transition check;
- remove a validation branch;
- change an ownership predicate;
- alter a default value;
- change a temporal window;
- reorder a sensitive operation when order is meaningful.

For a meaningful mutant, the system shall generate a test that kills the mutant.

Equivalent mutants must be identified and excluded from false confidence calculations when feasible.

---

## FR-020 Evaluation Harness

The platform shall evaluate its own AI components.

Each evaluation trial shall record:

- task ID;
- repository state;
- model;
- prompt version;
- tools available;
- environment;
- tool calls;
- intermediate artifacts;
- final patch/finding;
- actual environment outcome;
- grader outputs;
- failure reason.

Grading should include:

- code-based graders;
- model-based graders;
- human review for selected high-impact samples.

Outcome verification must take precedence over claims inside the transcript.

---

## FR-021 Learning and Calibration

The system shall store:

- validated findings;
- dismissed findings;
- accepted mitigations;
- severity corrections;
- successful patches;
- failed patches;
- recurring reasoning errors;
- prompt versions;
- product context versions;
- useful test templates.

Corrections must improve future runs globally rather than remain isolated in one ticket.

---

## FR-022 Reporting

Reports must be human-readable and machine-readable.

Human report sections:

1. Executive summary
2. Affected flow
3. Violated rule/invariant
4. Preconditions
5. Reproduction
6. Root cause
7. Capability/business delta
8. Evidence
9. Recommended fix
10. Patch status
11. Regression status
12. Confidence and validation status
13. Limitations

Machine output shall support JSON/JSONL.

---

## FR-023 CI/CD Integration

The system shall expose gates for:

- pull request scanning;
- changed-file scanning;
- nightly scans;
- release scans;
- scheduled deep scans;
- post-merge regression scans.

Example gate policies:

- block on newly confirmed high-impact validated issues;
- warn on unvalidated hypotheses;
- fail on regression tests;
- require human approval for architecture/security-sensitive changes.

---

## FR-024 Access Control

At minimum support roles:

- Administrator
- Security Engineer
- Developer
- QA Engineer
- Reviewer
- Read-only Auditor

Sensitive repository credentials, secrets, and logs must have least-privilege access.

---

# 10. Non-Functional Requirements

## NFR-001 Reliability
Deterministic orchestration must be reproducible for the same snapshot, environment, and configuration wherever model nondeterminism does not materially affect the run.

## NFR-002 Safety
Execution of generated tests and candidate exploits must use isolated disposable environments.

## NFR-003 Auditability
All findings and patches must be traceable to exact repository states and tool outputs.

## NFR-004 Extensibility
Testing methods, model providers, static analyzers, test runners, and sandboxes must be replaceable through adapters.

## NFR-005 Performance
The platform should support parallel scans at the worker layer without sacrificing artifact traceability.

## NFR-006 Cost Control
Use model routing by task complexity and cache deterministic context artifacts.

## NFR-007 Privacy
Repository data and secrets must not be sent to an external model provider unless explicitly configured and authorized.

## NFR-008 Reproducibility
Every confirmed bug should be reproducible from a stored fixture, command, environment definition, and repository snapshot whenever feasible.

---

# 11. Proposed System Architecture

```text
                    +----------------------+
                    |      Web / CLI / CI  |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    | API / Job Controller  |
                    +----------+-----------+
                               |
                               v
                  +-------------------------+
                  | Deterministic Orchestrator|
                  +-----------+-------------+
                              |
         +--------------------+---------------------+
         |                    |                     |
         v                    v                     v
+----------------+   +----------------+   +----------------+
|  Scan Director |   | Context Builder|   | Eval Harness   |
+-------+--------+   +--------+-------+   +-------+--------+
        |                     |                   |
        +---------------------+-------------------+
                              |
                              v
                    +----------------------+
                    |    Scanner Agents    |
                    | logic/security/QA    |
                    +----------+-----------+
                               |
             +-----------------+------------------+
             |                 |                  |
             v                 v                  v
      +-----------+     +-----------+      +-------------+
      | PBT Agent |     | MT Agent  |      | Diff Agent  |
      +-----------+     +-----------+      +-------------+
             |                 |                  |
             +-----------------+------------------+
                               |
                      +--------v--------+
                      | Validator Agent |
                      +--------+--------+
                               |
                      +--------v--------+
                      | Disposable      |
                      | Execution Lab   |
                      +--------+--------+
                               |
               +---------------+----------------+
               |               |                |
               v               v                v
        +-------------+  +-----------+  +--------------+
        | Static/CodeQL|  | Symbolic  |  | Mutation     |
        | adapters     |  | execution |  | hardening    |
        +-------------+  +-----------+  +--------------+
                               |
                               v
                     +-------------------+
                     | Repair Agent / APR|
                     +---------+---------+
                               |
                               v
                    +---------------------+
                    | Verification Gates   |
                    +----------+----------+
                               |
                               v
                    +---------------------+
                    | Finding/PR/Evidence  |
                    | Store + Knowledge    |
                    +---------------------+
```

---

# 12. Suggested Reference Implementation Stack

The architecture must remain stack-agnostic. For a greenfield implementation, a practical reference stack is:

### Control plane
- Python 3.12+
- FastAPI
- Pydantic
- PostgreSQL
- Redis
- background worker system

### Execution
- Docker-based disposable sandboxes
- optional stronger isolation such as gVisor/Firecracker for high-risk workloads
- artifact storage compatible with S3-like object stores

### UI
- React/Next.js or an equivalent web stack

### AI layer
- model-provider abstraction
- structured output validation
- prompt registry/versioning
- routing by task complexity

### Testing adapters
- pytest/Hypothesis for Python where applicable
- language-native test runners
- fuzzers such as Atheris/libFuzzer adapters where applicable
- static analyzers such as CodeQL/Semgrep adapters
- symbolic execution adapters such as KLEE for supported languages
- mutation-testing adapters

This stack is a recommendation, not a hard requirement. Existing repository conventions should take precedence.

---

# 13. Data Model

## 13.1 Repository
Fields:

- id
- name
- source
- commit/ref
- language profile
- build profile
- test profile
- environment profile
- catalog version
- created_at
- updated_at

## 13.2 Flow
- id
- repository_id
- feature
- entry_point
- trust_boundaries
- sensitive_operations
- state_transitions
- covered_methods
- last_scanned_at

## 13.3 Rule / Invariant
- id
- source_type
- source_reference
- statement
- confidence
- affected_flows
- examples
- boundaries
- active

## 13.4 Hypothesis
- id
- scan_id
- flow_id
- statement
- preconditions
- expected_relation
- proposed_test
- status

## 13.5 Test Artifact
- id
- hypothesis_id
- methodology
- source
- generated_code
- fixtures
- commands
- result
- evidence_hash

## 13.6 Finding
- id
- severity
- category
- title
- description
- violated_rule
- preconditions
- capability_delta
- reproduction
- evidence
- validation_status
- root_cause
- remediation
- first_seen
- last_seen

## 13.7 Patch Attempt
- id
- finding_id
- base_revision
- patch
- attempt_number
- test_result
- static_result
- mutation_result
- verification_status

## 13.8 Evaluation Trial
- id
- task_id
- model
- prompt_version
- environment
- transcript_reference
- tool_trace
- outcome
- grader_results

---

# 14. API Requirements

The exact transport may be REST, GraphQL, RPC, or event-driven, but equivalent capabilities are required.

### Required operations

- `POST /repositories`
- `POST /repositories/{id}/catalog`
- `POST /scans`
- `GET /scans/{id}`
- `POST /hypotheses/{id}/validate`
- `POST /findings/{id}/reproduce`
- `POST /findings/{id}/repair`
- `POST /patches/{id}/verify`
- `POST /evaluations/run`
- `GET /findings`
- `GET /evidence/{id}`
- `POST /knowledge/rules`
- `GET /metrics`

Support event callbacks/webhooks for:

- scan_started
- scan_completed
- finding_candidate
- finding_validated
- patch_created
- patch_verified
- evaluation_completed

---

# 15. UI Requirements

## Dashboard
Show:

- repositories;
- scan coverage;
- active scans;
- validated findings;
- false-positive rate;
- mean validation time;
- repair success rate;
- mutation score;
- regression rate;
- model/prompt versions.

## Scan detail
Show:

- target flow;
- context packet;
- hypotheses;
- generated tests;
- tool traces;
- validator evidence;
- execution logs.

## Finding detail
Show:

- severity dimensions;
- source locations;
- violated invariant;
- reproduction;
- capability delta;
- evidence timeline;
- patch attempts;
- regression results.

## Evaluation detail
Show:

- task;
- model;
- prompt;
- tool trace;
- actual end state;
- grader outcomes;
- failure classification.

---

# 16. Security Requirements

1. Secrets must be redacted from prompts and logs.
2. Repository permissions must be least privilege.
3. Sandboxes must have bounded CPU, memory, disk, network, and process counts.
4. Network access should be deny-by-default for generated tests.
5. Destructive operations must be prevented or isolated.
6. Patch generation must not directly deploy to production.
7. All AI outputs must be treated as untrusted input.
8. Tool invocation must use allowlists.
9. Commands must be parsed/validated before execution when practical.
10. Findings must preserve evidence integrity.
11. Sensitive source material must not be retained longer than configured.
12. External model calls must be explicitly controlled by project policy.

---

# 17. Observability

Each run must emit structured telemetry:

- run ID;
- repository commit;
- scan target;
- prompt version;
- model;
- tool;
- start/end time;
- token/cost data if available;
- test result;
- validator classification;
- patch result;
- failure reason.

The system should support correlation across:

`scan -> hypothesis -> test -> execution -> finding -> patch -> regression -> evaluation`

---

# 18. Success Metrics

## Product metrics

- validated finding rate;
- false-positive rate after validation;
- mean time to reproducible bug;
- mean time to verified patch;
- mutation score on critical invariants;
- regression escape rate;
- changed-code scan latency;
- recurring coverage of critical flows;
- percentage of findings with executable reproduction.

## AI metrics

- hypothesis validity rate;
- test usefulness rate;
- finding precision after validator;
- repair pass rate;
- patch minimality;
- regression-free repair rate;
- evaluator agreement;
- hallucinated-tool/API rate.

## Coverage metrics

Do not report line/branch coverage alone.

Track:

- flow coverage;
- invariant coverage;
- threat-model coverage;
- methodology coverage;
- changed-code coverage;
- mutation coverage;
- validated reproduction coverage.

---

# 19. Acceptance Criteria

The system is considered MVP-complete when all are true:

1. A repository can be onboarded and catalogued.
2. Scan Director can select a bounded target.
3. Context Builder can produce a structured code/intent packet.
4. Scanner can produce grounded hypotheses.
5. At least one semantic testing method is executable.
6. Validator can independently reproduce or reject a candidate.
7. Confirmed findings have reproducible evidence.
8. Repair agent can produce a patch for at least one supported bug class.
9. Regression verification runs automatically.
10. Findings and patches are persisted.
11. AI runs are traceable.
12. Human review is required before protected-branch production changes.
13. Evaluation tasks can be executed against a known test corpus.
14. The system can report why a candidate was rejected.
15. A failed agent run never gets labeled "fixed" solely because the agent says it is fixed.

---

# 20. MVP Scope

### MVP-1: Foundation
- repository onboarding
- catalog
- test/build discovery
- scan Director
- context Builder
- structured evidence store

### MVP-2: Semantic Scanner
- five-phase scanner
- invariant extraction
- hypothesis engine
- conventional test generation
- validator + sandbox

### MVP-3: Advanced Testing
- PBT
- metamorphic testing
- mutation-guided hardening
- static-analysis adapter
- differential testing where applicable

### MVP-4: Repair
- bug localization
- minimal patch generation
- regression verification
- patch safety gates

### MVP-5: Enterprise Evaluation
- eval harness
- historical replay
- model/prompt comparisons
- calibration memory
- CI integration
- dashboards

---

# 21. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Hallucinated bugs | Independent validation + dynamic reproduction |
| False severity | Capability delta + explicit severity dimensions |
| Context degradation | Targeted context packets + summaries + architectural map |
| Bad patches | Zero-trust patching + complete regression gates |
| Repetitive scans | Scan history + deterministic distribution |
| Test generator errors | Validator distinguishes app bugs from test bugs |
| Equivalent mutants | Equivalence checks |
| Sandbox escape | Strong isolation + resource limits |
| Vendor lock-in | Model/tool adapters |
| Benchmark gaming | Internal outcome-based eval corpus |
| Eval defects | Audit test cases and verify harness integrity |
| Long-running scans | Job queue + checkpoints + resumability |
| Noisy reports | Single high-value finding per scan slice + independent filtering |

---

# 22. Source-to-Requirement Traceability

The PDF explicitly supports:

- coverage illusion and semantic defects;
- CRAFT prompt structure;
- five-phase attacker/researcher reasoning;
- BDD/Gherkin constraints;
- boundary/equivalence testing;
- exploratory paths;
- Agentic PBT;
- metamorphic testing;
- differential testing;
- symbolic execution orchestrated by AI;
- Scan Director / Scanner / Validator pipeline;
- capability delta;
- mutation-guided compliance hardening;
- automated program repair;
- localization -> hypothesis -> patch -> execution feedback;
- the need for strict validation, evaluation harnesses, and human oversight.

These principles are implemented above as product requirements rather than treated as optional documentation.

---

# 23. Definition of Done for Any Feature

A feature is not done until:

- implementation is complete;
- automated tests exist;
- edge cases are tested;
- relevant invariants are encoded;
- failure modes are documented;
- logs and evidence are captured;
- the feature passes static/security checks;
- no known regression is introduced;
- the change is evaluated under the project's AI/automation policy.

---

# 24. Final Product Principle

**AADB is successful when it turns AI from a bug-guessing assistant into a disciplined evidence-producing engineering system.**

The product must continuously answer four questions:

1. What rule or invariant should hold?
2. What concrete behavior violates it?
3. Can the violation be reproduced independently?
4. Did the fix remove the violation without damaging anything else?

Anything less is a hypothesis, not a verified bug fix.
