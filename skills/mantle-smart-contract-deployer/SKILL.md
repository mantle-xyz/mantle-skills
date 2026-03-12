---
name: mantle-smart-contract-deployer
description: Use when a finalized Mantle contract build needs deployment-readiness checks, external signer handoff, receipt capture, or explorer verification.
---

# Mantle Smart Contract Deployer

## Overview

Run a safe deployment planning pipeline from finalized build inputs to explorer verification readiness. This skill starts after contract architecture and implementation are already decided; for Mantle contract design or authoring guidance, use `$mantle-smart-contract-developer`.

## Workflow

1. Collect deployment inputs:
   - source path and contract name
   - compiler version and optimizer settings
   - constructor args
   - target environment (`mainnet` or `testnet`)
   - finalized artifacts or development brief from `$mantle-smart-contract-developer`
2. Run pre-deploy checks from `references/deployment-checklist.md`.
3. Build artifacts and bytecode fingerprint.
4. Estimate gas and deployment cost; confirm limits.
5. Produce an external execution handoff package (unsigned deployment payload, gas bounds, and signer instructions).
6. After the user/external executor submits, capture receipt metadata and persist deployment evidence.
7. Verify source on explorer using `references/verification-playbook.md`, then record verification evidence.

## Guardrails

- This skill is read-only with mantle-mcp v0.2: never claim signed/broadcast/deployed/executed transactions.
- This skill does not design or write contracts; route that work to `$mantle-smart-contract-developer` and OpenZeppelin MCP.
- If the user asks for execution, provide a wallet/signer handoff checklist and state execution must happen externally.
- Never deploy with unresolved constructor argument ambiguity.
- Never skip chain ID or environment confirmation.
- Never claim verification success without explorer response evidence.
- If compile hash changes after quote/approval, restart pre-deploy checks.

## Output Format

```text
Mantle Deployment Report
- contract_name:
- environment:
- chain_id:
- compiler_profile:
- bytecode_hash:

Deployment
- execution_mode: external_wallet_or_signer
- tx_hash: (from external execution evidence)
- deployed_address: (from external execution evidence)
- block_number: (from external execution evidence)
- gas_used: (from external execution evidence)
- deployment_fee_native: (from external execution evidence)

Verification
- explorer:
- status: verified | pending | failed
- verification_id_or_link:
- failure_reason:

Artifacts
- constructor_args_encoded:
- abi_path:
- metadata_path:
```

## References

- `references/deployment-checklist.md`
- `references/verification-playbook.md`
