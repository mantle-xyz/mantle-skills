---
name: mantle-openclaw-competition
version: 0.1.12
description: "Use for ANY on-chain DeFi operation on the Mantle network by OpenClaw in the asset accumulation competition — swapping, liquidity provision, Aave V3 lending, ERC-20 approvals, MNT wrap/unwrap, or portfolio/state reads. TRIGGER when the user: (a) mentions OpenClaw, mantle-cli, or the Mantle asset accumulation competition; (b) asks to swap / trade / exchange tokens on Mantle via Agni, Fluxion, or Merchant Moe; (c) asks to add / remove / manage liquidity (LP) on whitelisted Mantle pools, including xStocks pairs; (d) asks to supply / deposit / lend / borrow / repay / withdraw / set-collateral on Aave V3 on Mantle; (e) asks to wrap MNT → WMNT or unwrap WMNT → MNT; (f) asks to approve an ERC-20 spender; (g) wants to discover whitelisted assets, pools, pairs, routers, fee tiers, or bin steps; (h) wants to query balances, allowances, transaction status, or Aave positions on Mantle; (i) wants to optimize portfolio USD value via yield, leverage, or exit timing. SKIP for: operations on other chains (Ethereum, Base, Arbitrum, BSC), Mantle infra / smart-contract development, or anything outside whitelisted protocols. Enforces hard rules: CLI-only execution via `mantle-cli … --json` (NEVER the mantle-mcp MCP server), STOP-on-error (no auto-retry; recommend restart), quote-before-swap, sign-and-WAIT per tx, and absolute refusal of native/ERC-20 token transfers or fabricated calldata (no Python / JS / raw RPC / utils encoding)."
---

# OpenClaw Competition — DeFi Operations Guide

## Overview

OpenClaw competes in the Mantle asset accumulation competition: each participant starts with 100 MNT in a fresh wallet and grows total portfolio value (USD) through whitelisted protocol interactions. This skill provides the workflow skeleton; details for each operation live in `references/`.

## Setup

```bash
# Install mantle-cli (CLI only — no MCP server)
npm install @mantleio/mantle-cli
npx mantle-cli --help   # verify
```

If this skills repo has its own `package.json`:

```bash
cd <skills-repo-root> && npm install
npx mantle-cli --help
```

**Golden rule:** every command MUST end in `--json` so the output is machine-parseable. Never enable or connect the `mantle-mcp` MCP server.

### Discover available commands & whitelisted assets/protocols

The `mantle-cli` catalog is the **single source of truth** for capabilities, supported tokens, pools, routers, and pool params. Do NOT rely on hard-coded lists, prior knowledge, or cached assumptions.

```bash
mantle-cli catalog list --json           # list all capabilities
mantle-cli catalog search "swap" --json  # find capabilities by keyword
mantle-cli catalog show <tool-id> --json # full details for one capability
mantle-cli swap pairs --json             # all whitelisted swap pairs + bin_step / fee_tier
mantle-cli lp find-pools --token-a A --token-b B --json   # discover pools for a pair
```

## Hard Constraints (8 critical rules)

Full rationale, incident reports, and the numbered detail list live in `references/safety-prohibitions.md`. The eight non-negotiables:

1. **CLI only** — never enable `mantle-mcp`; every command ends in `--json`.
2. **🛑 STOP on ANY `mantle-cli` error** — never auto-retry, never improvise. Print the raw error verbatim, halt, and recommend restarting the agent.
3. **🛑 Refuse anything beyond standard CLI verbs** — only `swap / approve / lp / aave`. Token transfers are NOT supported — refuse. Never improvise with Python, JS, RPC, or `utils`. Protocol actions (supply, swap, LP) are function calls, NOT transfers — sending tokens directly to a protocol contract locks them permanently.
4. **Never fabricate calldata or compute wei** — the CLI handles encoding and decimal conversion.
5. **Never build the same tx twice** — always pass `--sender <wallet>` for `idempotency_key`. If timeout, check `chain tx --hash` BEFORE rebuilding.
6. **🛡️ Slippage protection** — always quote before swap. `--amount-out-min` MUST equal the quote's `minimum_out_raw`, passed **VERBATIM** (it is already a raw integer in the output token's smallest unit — do NOT re-multiply or convert). Setting it to `0`, `1`, or any value below `minimum_out_raw` is **absolutely prohibited**. If `build-swap` reverts, **re-quote** — never lower the minimum. See `references/safety-prohibitions.md` rule 8 for unit examples and the full incident report.
7. **"sign & WAIT"** — verify each tx (`status: success`) before building the next.
8. **🔍 Catalog-first** — run `mantle-cli catalog list --json` at session start, `catalog show <tool-id> --json` before each operation. No catalog lookup → no execution. Never invent CLI subcommands — if catalog doesn't list it, it doesn't exist.

## ⚠ USDT ≠ USDT0

Two different ERC-20 tokens on Mantle. Aave V3 only accepts USDT0. CLI params `USDT` and `USDT0` point to different contracts — never interchange. When user says "USDT", always clarify. To convert: swap USDT → USDT0 on Merchant Moe (bin_step=1). Always display both balances.

## Workflow Execution Rules (mandatory)

These rules apply to **every** workflow and **every** reference file. Violations may cause irreversible fund loss.

- **W-1: Strict step order** — execute steps in exact sequence. Never skip, reorder, or parallelize. If a step fails, STOP (see Hard Constraint #2).
- **W-2: User confirmation gate** — every on-chain tx requires a Transaction Confirmation Summary (intent, amounts, slippage, gas, warnings) and explicit user approval before signing. Each tx confirmed separately. Applies even in auto-mode. Format details in `references/swap-workflow.md`.
- **W-3: Rate limiting** — minimum 2s gap between CLI calls, no parallel calls, 5s wait after write tx confirmation. RPC timeout → wait 30s, retry once, then STOP.

## Available Tools

| Tool | Purpose | Command |
|------|---------|---------|
| Catalog | Discover capabilities, tokens, pools | `mantle-cli catalog list / search / show` |
| Swap | DEX exchange | `mantle-cli swap pairs / wrap-mnt / unwrap-mnt / build-swap` + `mantle-cli defi swap-quote` |
| LP | Liquidity provision | `mantle-cli lp top-pools / find-pools / add / remove / collect-fees` + `mantle-cli defi analyze-pool` + `mantle-cli lp suggest-ticks` |
| Aave | Lending / borrowing | `mantle-cli aave supply / borrow / repay / withdraw / set-collateral / positions` |
| Account | Read state | `mantle-cli account allowances / balances` + `mantle-cli chain tx / estimate-gas` |

> **Token transfers are NOT in the toolset.** Refuse transfer requests. No escape hatch — if it can't be expressed by the verbs above, refuse.

## When to Use

- Swap tokens on Mantle (Agni, Fluxion, Merchant Moe)
- Add / remove liquidity on a whitelisted DEX
- Supply / borrow on Aave V3
- Discover available assets, pools, or trading pairs (via `catalog` / `swap pairs` / `lp find-pools`)
- Optimize portfolio value (yield, leverage, exit timing)
- **Any DeFi operation that is part of the Mantle asset accumulation competition (OpenClaw / 龙虾活动)**

## Routing Priority (MANDATORY)

**This skill is the SOLE entry point for all Mantle asset accumulation competition operations.** Do NOT delegate to `$mantle-defi-operator` or any other skill when the user mentions OpenClaw, 龙虾, the competition wallet, or requests any DeFi operation in a competition context.

If a non-competition Mantle DeFi request arrives (e.g. general venue discovery without execution intent), delegate to `$mantle-defi-operator`.

## Workflow: Swap (skeleton)

> **⚠ Steps MUST be executed in strict order (W-1). Each transaction requires user confirmation (W-2).**

```
0. mantle-cli catalog show mantle_buildSwap --json                     → verify command exists (Hard Constraint #8)
   ↓
1. mantle-cli swap pairs --json                                      → find bin_step / fee_tier
   ↓
2. mantle-cli defi swap-quote --in X --out Y --amount N --provider best --json   → minimum_out_raw
   ⚠️ SAVE `minimum_out_raw` — pass VERBATIM to --amount-out-min in Step 5. DO NOT convert.
   ↓
3. mantle-cli account allowances <wallet> --pairs X:<router> --json  → allowance check
   ↓
4. IF insufficient: mantle-cli approve ...                           → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓
5. ⚠️ USER CONFIRMATION →
   mantle-cli swap build-swap ... --amount-out-min <minimum_out_raw VERBATIM> --sender <wallet> --json
   ⚠️ If reverts → re-quote (Step 2), NEVER lower amount-out-min. → sign & WAIT
   ↓
6. mantle-cli chain tx --hash <hash> --json                          → verify status: success
```

For MNT input: `swap wrap-mnt` first. Full details → **`references/swap-workflow.md`**.

## Workflow: Add Liquidity (skeleton)

> **⚠ Strict step order (W-1). User confirmation required (W-2).**

```
0. mantle-cli catalog show mantle_addLiquidity --json                → verify command exists (Hard Constraint #8)
   ↓
1. mantle-cli lp top-pools --sort-by apr --min-tvl 10000 --json   (OR: lp find-pools for a specific pair)
   ↓
2. mantle-cli defi analyze-pool ... --investment N --json         → APR, risk, projections
   ↓
3. mantle-cli lp suggest-ticks ... --json                         → wide / moderate / tight
   ↓
4. ⚠️ USER CONFIRMATION → mantle-cli approve --token A --spender <position_manager> → sign & WAIT
   ↓
5. mantle-cli approve --token B --spender <position_manager>      → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓
6. mantle-cli lp add ... --sender <wallet> --json                 → ⚠️ USER CONFIRMATION → sign & WAIT
```

Full args → **`references/lp-workflow.md`**.

## Workflow: Aave Supply → Borrow (skeleton)

> **⚠ Strict step order (W-1). User confirmation required (W-2).**
>
> **`aave supply` is a function call, NOT a transfer.** Never send tokens directly to the Aave Pool address — they will be permanently locked. Always use `mantle-cli aave supply`.

```
0. mantle-cli catalog show mantle_aaveSupply --json                  → verify command exists (Hard Constraint #8)
   ↓
1. ⚠️ USER CONFIRMATION → mantle-cli approve --token X --spender <aave-pool> → sign & WAIT
   ↓
2. mantle-cli aave supply --asset X --amount N --on-behalf-of <wallet> --sender <wallet> --json → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓
3. mantle-cli aave positions --user <wallet> --json   → verify collateral_enabled
   ↓
4. IF collateral_enabled=NO: mantle-cli aave set-collateral ... → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓
5. ⚠️ USER CONFIRMATION → mantle-cli aave borrow --asset Y --amount N ... → sign & WAIT
```

Edge cases (Isolation Mode, LTV_IS_ZERO, USDT vs USDT0, `--amount max`) → **`references/aave-workflow.md`**.

## References

| File | Load when |
|------|-----------|
| `references/swap-workflow.md` | First swap of the session, or handling timeout / retry / wrap-mnt |
| `references/lp-workflow.md` | Adding / removing liquidity, or suggesting tick ranges |
| `references/aave-workflow.md` | Any Aave operation, or troubleshooting collateral / Isolation Mode |
| `references/safety-prohibitions.md` | A `mantle-cli` error occurred, the user requested something outside standard verbs, or you need the full STOP protocol + numbered rule list + incident reports |

For full CLI documentation and the live whitelisted asset/protocol list: `mantle-cli catalog list --json` and `mantle-cli catalog show <tool-id> --json`.

## Integrity Verification

Each release includes `integrity.json` mapping version → SHA-256 hashes for every file. Verify after download:

```bash
python3 -c "
import hashlib, json, os, sys
manifest = json.load(open('integrity.json'))
ok = True
for f, expected in manifest['files'].items():
    actual = hashlib.sha256(open(f,'rb').read()).hexdigest()
    if actual != expected:
        print(f'MISMATCH {f}: expected {expected[:16]}… got {actual[:16]}…')
        ok = False
if ok: print(f'All files verified for v{manifest[\"version\"]}')
else: sys.exit(1)
"
```

**On publish/update:** regenerate `integrity.json` with new hashes and bump `version`.
