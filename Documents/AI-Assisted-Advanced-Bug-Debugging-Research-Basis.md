# Research and Source Basis

## Primary project source
**AI-Assisted Advanced Bug Debugging.pdf** — 14-page research report supplied for this project.

Key source sections used:
- Coverage illusion and semantic logic bugs
- CRAFT prompt structure
- Five-phase vulnerability-analysis reasoning
- Agentic Property-Based Testing
- Metamorphic Testing
- Differential Testing
- Static-analysis-guided symbolic execution
- Scan Director / Scanner / Validator architecture
- Capability delta
- Mutation-Guided Automated Compliance Hardening
- Automated Program Repair
- SWE-bench evaluation limitations
- Hallucination/false-positive risk
- Dynamic verification and evaluation harnesses

## External research consulted

1. **WorkOS — A prompt that finds deep logic bugs, and the pipeline we built around it**
   - Confirms the five-phase deep-logic workflow and three-stage Scan Director / Scanner / Validator architecture.
   - Useful design lessons: coverage distribution, explicit severity calibration, independent validation, reusable validation infrastructure, and feedback-driven improvement.

2. **Meta Engineering — LLM-powered bug catchers / Automated Compliance Hardening**
   - Confirms mutation-guided, LLM-assisted test generation and the practice of generating tests that target meaningful logic/compliance failures.

3. **Anthropic — Demystifying evals for AI agents**
   - Supports outcome-based evaluation, evaluation harnesses, code/model/human graders, and transcript inspection.

4. **Agentless — Demystifying LLM-based Software Engineering Agents**
   - Supports the simpler localization -> repair -> validation decomposition and the value of focused context.

5. **SAILOR — Guiding Symbolic Execution with Static Analysis and LLMs**
   - Supports static-analysis candidate localization, LLM-generated symbolic harnesses, iterative synthesis, symbolic execution, and concrete replay.

6. **Agentic Property-Based Testing**
   - Supports automated inference and execution of properties with LLM assistance, while also demonstrating the importance of validating generated findings.

7. **LLMORPH**
   - Supports automated metamorphic testing as a way to detect inconsistencies without requiring expensive labeled ground truth.

8. **DiffSpec**
   - Supports differential testing driven by natural-language specifications and targeted LLM-generated tests.

9. **SWE-bench Pro**
   - Supports evaluating long-horizon software-engineering repair capabilities.
   - Important caution: recent audits found significant benchmark/task-quality problems, reinforcing the requirement that the product maintain its own verified evaluation harness.

10. **OpenAI evaluation guidance**
   - Used only as additional current reference for outcome-based and trace-based agent evaluation patterns; the architecture remains vendor-neutral.

## Source handling rule

The PDF is the project’s primary source. External sources are used to verify, strengthen, and modernize implementation details. Where external material differs from the PDF, the project should preserve the PDF’s core principles while clearly marking the newer evidence as external guidance rather than rewriting the source’s claims.
