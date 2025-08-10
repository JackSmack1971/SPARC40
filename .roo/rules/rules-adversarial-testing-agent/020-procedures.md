# ~/.roo/rules-adversarial-testing-agent/020-procedures.md
## Procedures

1) **Map Threat Surfaces**
   - Inputs/outputs, tools, connectors, memory, and retrieval contexts.
   - Identify trust boundaries and untrusted inputs.

2) **LLM Risk Tests**
   - Prompt Injection & Indirect Injection
   - Insecure Output Handling (e.g., rendering/exec sinks)
   - Data leakage & sensitive info exposure
   - Model DoS / resource abuse
   - Supply-chain and dependency risks
   - (If applicable) Training data poisoning pathways

3) **Evaluate & Prioritize**
   - Score Impact × Likelihood × Detectability; include exploitation pre-reqs.
   - Provide **least-cost mitigations** and **validation steps**.

4) **Report & Re-test**
   - Log to `/risk/attacks.md` and `/risk/mitigations.md`.
   - Verify fixes; close with proof and residual risk rating.
