---
name: mantle-address-registry-navigator
description: Use when a Mantle task needs a verified contract or token address, whitelist validation, anti-phishing checks, or safe registry-backed lookup before onchain interaction.
---

# Mantle Address Registry Navigator

## Overview

Resolve addresses from trusted sources only and fail closed when data is missing or stale. Never synthesize contract addresses from memory.

## Source Priority

1. `mantle_resolveToken` for token symbol/name requests.
2. `mantle_resolveAddress` for contract key, alias, or label requests.
3. Local registry file: `assets/registry.json` (fallback/manual cross-check only).
4. If no source provides a verified match, stop and return a blocked result.

## Lookup Workflow

1. Normalize the request:
   - `network` (`mainnet` or `sepolia`; local registry fallback maps `sepolia` to `testnet`)
   - `identifier` (contract key, symbol, or alias)
   - `category` (system, token, bridge, `defi`, or `any`)
   - optional `protocol_id` + `contract_role` when a DeFi request names a protocol but not a registry key
2. Resolve candidates via source priority. For local DeFi fallback, prefer exact `key` matches first, then exact `protocol_id` + `contract_role`.
3. Validate the chosen candidate with `mantle_validateAddress` and registry metadata:
   - `valid_format` is `true`.
   - Address is not the zero address.
   - Entry environment matches request.
   - Entry status is usable (`active`) for execution.
   - Entry has provenance (`source.url` and `source.retrieved_at`).
   - If the request names an intended action, the entry `supports` that action.
4. Return one canonical result with provenance metadata.
5. If multiple candidates remain ambiguous, ask a clarifying question instead of choosing arbitrarily.

## Safety Rules

- Never output guessed addresses.
- Never treat user-supplied addresses as trusted without registry/tool verification.
- Mark deprecated or paused contracts as non-executable.
- Never return placeholder/template values from `assets/registry.json` (for example `REPLACE_WITH_EIP55_CHECKSUM_ADDRESS`).
- If registry freshness is unknown, label confidence as `low` and request manual confirmation.
- If a DeFi request only names a protocol and multiple active roles exist, stop and ask which contract role is needed.

## Response Format

Return results in this structure:

```text
Address Resolution Result
- identifier:
- network:
- address:
- category:
- status:
- source_url:
- source_retrieved_at:
- confidence: high | medium | low
- notes:
```

## Resources

- `assets/registry.json`
- `references/address-registry-playbook.md`
