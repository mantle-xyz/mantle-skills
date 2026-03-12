---
name: mantle-smart-contract-developer
description: Use when a Mantle project needs contract requirements, architecture, access control, upgradeability, dependencies, or deployment-readiness decisions before authoring or deployment.
---

# Mantle Smart Contract Developer

## Overview

Guide Mantle-specific contract development decisions and fail closed when requirements are incomplete. This skill owns architecture, dependency selection, readiness checks, and deployment handoff, but actual contract-writing guidance must go through OpenZeppelin MCP.

## Workflow

1. Capture the development target:
   - contract purpose and user flows
   - target environment (`mainnet` or `testnet`)
   - token/asset assumptions
   - admin, ownership, and upgradeability requirements
   - external dependencies and trusted addresses
2. Run `references/development-checklist.md`.
3. If the user needs contract code, inheritance, library usage, upgrade patterns, or Solidity implementation help, route that work through `references/openzeppelin-mcp-handoff.md`.
4. Reconcile Mantle-specific decisions:
   - MNT gas and operational assumptions
   - environment-correct protocol/system addresses
   - deployment roles and initialization values
   - integration points needed by frontends or offchain services
5. Produce a development brief with:
   - contract inventory and responsibilities
   - dependency and inheritance choices
   - constructor / initializer inputs
   - test and security review requirements
   - deployment prerequisites
6. When the brief is complete, hand off to `$mantle-smart-contract-deployer`.

## Guardrails

- Mantle-specific only: if the request is generic Solidity with no Mantle context, ask to scope it to Mantle.
- For contract authoring, do not rely on memory when OpenZeppelin MCP should be consulted.
- Never recommend proxy, admin, or ownership patterns without stating the operational trade-off.
- Never mix `mainnet` and `testnet` dependencies or addresses.
- Never mark code as audited, production-ready, or deploy-safe without explicit evidence.
- If requirements, permissions, or upgrade intent are ambiguous, stop and clarify before producing a final brief.

## Output Format

```text
Mantle Contract Development Brief
- project_goal:
- environment:
- contract_set:
- critical_dependencies:
- access_control_model:
- upgradeability_model:
- external_addresses_needed:
- openzeppelin_mcp_required_for:
- testing_requirements:
- security_review_focus:
- deployment_prerequisites:
- handoff_skill: mantle-smart-contract-deployer
```

## References

- `references/development-checklist.md`
- `references/openzeppelin-mcp-handoff.md`
