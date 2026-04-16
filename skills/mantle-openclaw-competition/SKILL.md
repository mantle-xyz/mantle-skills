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

Each catalog entry includes `category` (`query` / `analyze` / `execute`), `auth` (`none` / `optional` / `required`), `cli_command` template, and `workflow_before` (which tools to call first).

### Catalog-first constraint (MANDATORY — Hard Constraint #8)

**Before executing ANY operation, you MUST consult the catalog to verify the operation exists and retrieve its exact CLI command template.** This is a non-negotiable hard constraint at the same level as constraints 1–7.

**⛔ ABSOLUTE RULE: No catalog lookup → No execution. No exceptions.**

1. **Every session MUST start with a catalog load.** Run `mantle-cli catalog list --json` at the beginning of the session to load the full capability list. Do NOT proceed with any operation until the catalog response is received and parsed.
2. **Every operation MUST be verified against the catalog before execution.** Before running any `swap / lp / aave / approve` command:
   - Run `mantle-cli catalog show <tool-id> --json` to retrieve the exact command template, required parameters, and `workflow_before` dependencies.
   - If the operation is not in the catalog → **STOP and refuse**. The operation does not exist.
3. **Unknown token, pool, or pair?** Verify via `mantle-cli swap pairs --json` or `mantle-cli lp find-pools --json`. If not in the response → **STOP and refuse**. It is not whitelisted.
4. **Never invent CLI subcommands or flags.** If `catalog list` does not show a capability for the user's request, that capability does not exist. Do NOT guess command names, flags, or parameter formats. Do NOT extrapolate from other commands.
5. **Catalog data expires at session boundary.** Do NOT carry over catalog results from a previous session — always re-fetch.

**Incident reference:** Agent skipped catalog lookup, assumed `mantle-cli transfer send-token` existed, and attempted to construct a transfer command that does not exist in the CLI. Had the agent consulted `catalog list` first, it would have found zero matches and refused.

## Hard Constraints (8 critical rules)

Full rationale, incident reports, and the numbered detail list live in `references/safety-prohibitions.md`. The eight non-negotiables:

1. **CLI only** — never enable `mantle-mcp`; every command ends in `--json`.
2. **🛑 STOP on ANY `mantle-cli` error** — never auto-retry, never improvise. Print the raw error to the user verbatim, halt the workflow, and **recommend the user restart the OpenClaw agent** before continuing. Continuing past an unhandled error risks duplicate broadcasts, stale allowances, and fund loss.
3. **🛑 Refuse anything beyond the standard CLI verbs** — execute operations MUST be expressed via `swap / approve / lp / aave`. **Token transfers (native MNT and ERC-20) are NOT supported — refuse.** If a request can't map to one of the allowed verbs, **STOP and tell the user**. NEVER improvise with Python, JS, RPC calls, or `utils` calldata construction. The user accepting risk is NOT sufficient — the prohibition is absolute.
   - **Protocol actions are function calls, NOT transfers.** `aave supply / borrow / repay / withdraw`, `swap build-swap`, and `lp add / remove` invoke specific functions on the target contract that mint aTokens, route the trade, or register liquidity. Sending tokens directly to the Aave V3 Pool (`0x458F293454fE0d67EC0655f3672301301DD51422`), a DEX router, a position manager, or a WETHGateway via ERC-20 `transfer()` / `transferFrom()` does NOT trigger those functions — the tokens are **permanently locked** with no on-chain path to recover. If a user says "supply / deposit / lend X to Aave" or "send X to Aave", use `mantle-cli aave supply` — never model it as an ERC-20 transfer to the Pool address.
4. **Never fabricate calldata or compute wei** — the dedicated CLI verbs handle decimal conversion deterministically. NEVER use Python/JS for any encoding.
5. **Never build the same tx twice** — always pass `--sender <wallet>` so the response carries an `idempotency_key`. If a build times out, check `mantle-cli chain tx --hash <hash> --json` BEFORE rebuilding.
6. **🛡️ Always quote before swap — `amount-out-min` MUST come from the quote's `minimum_out_raw`, VERBATIM** — see "Slippage Protection Rules" section below for full details. Setting `--amount-out-min` to `0`, `1`, or any value less than `minimum_out_raw` is **absolutely prohibited** — it removes slippage protection and exposes the user to sandwich attacks and fund loss.
7. **"sign & WAIT"** — verify each tx (`status: success`) before building the next. Do NOT pipeline unsigned transactions.
8. **🔍 Catalog-first — ALWAYS consult the catalog before ANY operation** — run `mantle-cli catalog list --json` at session start and `mantle-cli catalog show <tool-id> --json` before each operation. No catalog lookup → no execution. See "Catalog-first constraint" section above for full rules.

## ⚠ USDT ≠ USDT0

USDT and USDT0 are **two different ERC-20 tokens** on Mantle (different contract addresses, different protocol support, different liquidity pools). Never confuse them.

- **Aave V3 only accepts USDT0** — NOT USDT. If the user only holds USDT, swap to USDT0 on Merchant Moe (bin_step=1) first.
- **When the user says "USDT", always clarify** — ask whether they mean USDT or USDT0 before executing any operation. Do not assume.
- **CLI params must be exact** — `--in USDT` and `--in USDT0` point to different contracts. Using the wrong symbol causes failed txs, wrong pools, or fund loss.
- **Always display both balances** when the user asks about USDT holdings or portfolio.

## 🛡️ Slippage Protection Rules (Hard Constraint #6 — detailed)

**⛔ ABSOLUTE RULE: `--amount-out-min` MUST equal the quote's `minimum_out_raw` value, passed VERBATIM. No exceptions.**

### Unit rules — DO NOT convert or recalculate

The `--amount-out-min` flag takes a **raw integer in the token's smallest unit** (wei-equivalent). The quote response already provides this as `minimum_out_raw`.

| Token | Decimals | Quote `minimum_out_raw` | Correct `--amount-out-min` | ❌ WRONG |
|-------|----------|------------------------|---------------------------|----------|
| USDC  | 6        | `9934699`              | `9934699`                 | `9934699000000` (re-multiplied) |
| USDT0 | 6        | `4500000`              | `4500000`                 | `4500000000000000000` (×10^18) |
| WMNT  | 18       | `15000000000000000000` | `15000000000000000000`    | `15` (used decimal form) |

**Rules:**
1. **Copy `minimum_out_raw` verbatim** from the quote response into `--amount-out-min`. Do NOT multiply, divide, or re-encode it. The CLI already computed the correct raw value with the correct token decimals.
2. **Never manually compute raw amounts.** Do NOT use Python/JS to calculate `decimal_amount × 10^decimals`. The quote's `minimum_out_raw` is the authoritative value.
3. **Never round, truncate, or "adjust" the value.** Pass the exact string from the quote.

### Floor rules — NEVER lower the minimum

4. **`--amount-out-min` MUST be ≥ `minimum_out_raw` from the quote.** Setting it to ANY value less than `minimum_out_raw` is prohibited. This includes:
   - `0` — prohibited (zero protection)
   - `1` — prohibited (effectively zero protection)
   - Any value below `minimum_out_raw` — prohibited
5. **If `build-swap` reverts with the quote's `minimum_out_raw`, the correct action is STOP — not lowering `amount-out-min`.** The revert means the pool price has moved beyond acceptable slippage since the quote was taken. The correct recovery is:
   - Wait 30 seconds for pool conditions to stabilize
   - Re-run the quote (`mantle-cli defi swap-quote ...`) to get fresh `minimum_out_raw`
   - Retry with the NEW quote's `minimum_out_raw`
   - If it reverts again after 2 retries, **STOP and inform the user** that market conditions are unfavorable
6. **Never bypass slippage protection "to make it work."** A reverted swap with proper slippage protection is SAFE (no funds lost). A successful swap with `amount-out-min: 1` is DANGEROUS (sandwich attack can steal nearly all output tokens).

### Incident reference

> **Real incident (this agent):** Quote returned `minimum_out_raw: 9934699` (USDC, 6 decimals = ~9.93 USDC). Agent passed `--amount-out-min 9934700000` (incorrectly re-multiplied by 10^3 → demanded 9934.7 USDC minimum). Transaction reverted because the pool cannot produce 9934 USDC from 15 WMNT. Agent then "fixed" by setting `--amount-out-min 1`, removing ALL slippage protection. The swap went through but was fully exposed to sandwich attacks. **Correct fix:** pass `9934699` verbatim from the quote.

## Workflow Execution Rules (mandatory)

These rules apply to **every** workflow (Swap, LP, Aave) and **every** reference file. Violations may cause irreversible fund loss.

### Rule W-1: Strict Sequential Step Enforcement

Each workflow defines a numbered step sequence. You MUST execute steps **in exact order** — skipping, reordering, or parallelising steps is **prohibited**.

- **NEVER skip an intermediate step** to jump to a later one. For example, you MUST NOT call `swap build-swap` (Step 5) without first completing the quote (Step 2) and allowance check (Step 3).
- **NEVER execute a step before its predecessor has completed successfully** (on-chain `status: success` for write operations, valid JSON response for read operations).
- **If a step fails**, follow STOP CONDITION 1 (`references/safety-prohibitions.md`). Do NOT skip the failed step and continue with later steps.
- **If a step's precondition is not met** (e.g. allowance already sufficient at Step 3), the step may be **explicitly marked as skipped with reason** in the output to the user, but execution must still proceed to the **next sequential step** — never jump ahead by more than one step.

### Rule W-2: User Confirmation Gate Before Transaction Execution

For **any** on-chain transaction (approve, swap, LP add/remove, Aave supply/borrow/repay/withdraw/set-collateral, wrap/unwrap), you MUST present a **Transaction Confirmation Summary** and receive **explicit user approval** before signing.

The summary MUST include:

1. **Intent** — One-sentence description of what the user asked for.
2. **Transaction details** — Operation type, input/output tokens & amounts (with USD estimate), recipient address, slippage protection, price impact, gas estimate.
3. **Risk warnings** — Price impact > 0.2%, large approvals, Isolation Mode caveats, etc.

**Format:**

```
⚠️ Transaction Confirmation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Intent:     <what the user asked for>
Operation:  <Swap / Approve / Supply / ...>
Input:      <amount> <token> (≈ $<usd>)
Output:     <expected_amount> <token> (≈ $<usd>)
Min output: <amount_out_min> <token>
Impact:     <price_impact>%
Recipient:  <address>
Est. gas:   <gas> MNT
Warnings:   <any risks>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Proceed? (yes/no)
```

- **NEVER broadcast without user confirmation.** "no" or no response → STOP.
- **Each transaction needs its own confirmation** — do NOT batch (e.g. approve and swap are confirmed separately).
- This applies **even in auto-mode** — every fund-moving tx requires explicit human approval.

### Rule W-3: Rate Limiting

- **Minimum 2-second gap** between consecutive `mantle-cli` calls. Never fire CLI commands in rapid succession.
- **No parallel CLI calls** — wait for the previous command's response before issuing the next.
- **After any write tx is confirmed**, wait at least **5 seconds** before the next write command to allow on-chain state (balances, allowances, positions) to settle.
- **If an RPC timeout or rate-limit error occurs**, wait **30 seconds**, then retry **once**. If it fails again, follow STOP CONDITION 1.

## Available Tools

| Tool | Purpose | Command |
|------|---------|---------|
| Catalog | Discover capabilities, tokens, pools | `mantle-cli catalog list / search / show` |
| Swap | DEX exchange | `mantle-cli swap pairs / wrap-mnt / unwrap-mnt / build-swap` + `mantle-cli defi swap-quote` |
| LP | Liquidity provision | `mantle-cli lp top-pools / find-pools / add / remove / collect-fees` + `mantle-cli defi analyze-pool` + `mantle-cli lp suggest-ticks` |
| Aave | Lending / borrowing | `mantle-cli aave supply / borrow / repay / withdraw / set-collateral / positions` |
| Account | Read state | `mantle-cli account allowances / balances` + `mantle-cli chain tx / estimate-gas` |

> **Token transfers are NOT in the toolset.** `mantle-cli transfer send-native` / `transfer send-token` and the corresponding `mantle_buildTransferNative` / `mantle_buildTransferToken` MCP tools have been deliberately removed. Refuse transfer requests per Hard Constraint #3 — do NOT fall back to the utils pipeline to simulate one.

> **No escape hatch.** If a user's request can't be expressed by the verbs above, **refuse** (see Hard Constraint #3). Do NOT use Python, JS, raw RPC, or `utils` calldata construction.

## When to Use

- Swap tokens on Mantle (Agni, Fluxion, Merchant Moe)
- Add / remove liquidity on a whitelisted DEX
- Supply / borrow on Aave V3
- Discover available assets, pools, or trading pairs (via `catalog` / `swap pairs` / `lp find-pools`)
- Optimize portfolio value (yield, leverage, exit timing)
- **Any DeFi operation that is part of the Mantle asset accumulation competition (OpenClaw / 龙虾活动)**

## Routing Priority (MANDATORY)

**This skill is the SOLE entry point for all Mantle asset accumulation competition operations.** Any request that matches the conditions below MUST be handled by this skill — do NOT delegate to `$mantle-defi-operator` or any other skill:

- The user mentions OpenClaw, 龙虾, asset accumulation competition, or the competition wallet
- The user requests swap / LP / Aave / approve / wrap / unwrap on Mantle with a competition context
- The user asks to check balances, positions, or portfolio value in a competition context
- The user asks to optimize portfolio value, yield strategy, leverage, or exit timing for the competition

**Why?** `$mantle-defi-operator` produces execution-ready *plans* but does NOT enforce the safety constraints (STOP-on-error, sign-and-WAIT, user confirmation gates, CLI-only, no fabricated calldata) that are critical for real fund operations in the competition. Routing competition operations to `$mantle-defi-operator` bypasses these guardrails and risks duplicate broadcasts, stale allowances, and fund loss.

If a non-competition Mantle DeFi request arrives (e.g. general protocol comparison, venue discovery without execution intent), delegate to `$mantle-defi-operator`.

## Workflow: Swap (skeleton)

> **⚠ Steps MUST be executed in strict order (Rule W-1). Each transaction requires user confirmation (Rule W-2).**

```
0. mantle-cli catalog show mantle_buildSwap --json                     → verify command exists, get template & workflow_before
   ↓ MUST complete before Step 1 (Hard Constraint #8)
1. mantle-cli swap pairs --json                                      → find bin_step / fee_tier
   ↓ MUST complete before Step 2
2. mantle-cli defi swap-quote --in X --out Y --amount N --provider best --json   → minimum_out_raw
   ⚠️ SAVE the `minimum_out_raw` value from the response — pass it VERBATIM to --amount-out-min in Step 5.
      DO NOT convert, multiply, or recalculate. See "Slippage Protection Rules" (Hard Constraint #6).
   ↓ MUST complete before Step 3
3. mantle-cli account allowances <wallet> --pairs X:<router> --json  → allowance check
   ↓ MUST complete before Step 4
4. IF insufficient: mantle-cli approve ...                           → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓ MUST confirm tx success before Step 5
5. ⚠️ USER CONFIRMATION — present Transaction Confirmation Summary:
   - Intent, input/output tokens & amounts, amount_out_min, price impact, gas estimate
   → User must explicitly approve before proceeding
   mantle-cli swap build-swap --provider <dex> --in X --out Y ... --amount-out-min <minimum_out_raw from Step 2, VERBATIM> --sender <wallet> --json
   ⚠️ --amount-out-min MUST be the EXACT `minimum_out_raw` from Step 2. NEVER set to 0, 1, or any lower value.
      If this reverts → re-quote (Step 2), do NOT lower amount-out-min. See "Slippage Protection Rules".
                                                                     → sign & WAIT
   ↓ MUST confirm tx success before Step 6
6. mantle-cli chain tx --hash <hash> --json                          → verify status: success
```

For MNT input: `swap wrap-mnt` first, then swap WMNT. For MNT output: swap to WMNT, then `swap unwrap-mnt`. Full step-by-step with retry logic and edge cases → **`references/swap-workflow.md`**.

## Workflow: Add Liquidity (skeleton)

> **⚠ Steps MUST be executed in strict order (Rule W-1). Each transaction requires user confirmation (Rule W-2).**

```
0. mantle-cli catalog show mantle_addLiquidity --json                → verify command exists, get template & workflow_before
   ↓ MUST complete before Step 1 (Hard Constraint #8)
1. mantle-cli lp top-pools --sort-by apr --min-tvl 10000 --json   (OR: lp find-pools for a specific pair)
   ↓ MUST complete before Step 2
2. mantle-cli defi analyze-pool ... --investment N --json         → APR, risk, projections
   ↓ MUST complete before Step 3
3. mantle-cli lp suggest-ticks ... --json                         → wide / moderate / tight
   ↓ MUST complete before Step 4
4. ⚠️ USER CONFIRMATION — present LP Confirmation Summary:
   - Intent, pool, token amounts, tick/bin range, strategy, estimated APR, risk warnings
   → User must explicitly approve before proceeding to approvals
   mantle-cli approve --token A --spender <position_manager>      → sign & WAIT
   ↓ MUST confirm tx success
5. mantle-cli approve --token B --spender <position_manager>      → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓ MUST confirm tx success before Step 6
6. mantle-cli lp add ... --sender <wallet> --json                 → ⚠️ USER CONFIRMATION → sign & WAIT
```

V3 (Agni / Fluxion) takes `--fee-tier`, `--tick-lower`, `--tick-upper`. LB (Merchant Moe) takes `--bin-step`, `--active-id`, `--delta-ids`, `--distribution-x/y`. xStocks LP only on Fluxion (USDC pairs, fee_tier=3000). Full args → **`references/lp-workflow.md`**.

## Workflow: Aave Supply → Borrow (skeleton)

> **⚠ Steps MUST be executed in strict order (Rule W-1). Each transaction requires user confirmation (Rule W-2).**

> **`aave supply` is a function call, NOT a transfer.** The CLI invokes `Pool.supply()` which pulls tokens via `transferFrom` AND mints aTokens. Never "simulate" a supply by constructing an ERC-20 `transfer()` to the Pool address (`0x458F293454fE0d67EC0655f3672301301DD51422`) — no aToken is minted, no collateral is recorded, the tokens are locked forever. Same principle for `borrow` / `repay` / `withdraw`: always use the dedicated `mantle-cli aave` verb.

```
0. mantle-cli catalog show mantle_aaveSupply --json                  → verify command exists, get template & workflow_before
   ↓ MUST complete before Step 1 (Hard Constraint #8)
1. ⚠️ USER CONFIRMATION — present Supply Confirmation Summary:
   - Intent, asset, amount, on-behalf-of address, expected aToken receipt
   → User must explicitly approve before proceeding
   mantle-cli approve --token X --spender <aave-pool>   → sign & WAIT
   ↓ MUST confirm tx success before Step 2
2. mantle-cli aave supply --asset X --amount N --on-behalf-of <wallet> --sender <wallet> --json
                                                                                       → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓ MUST confirm tx success before Step 3
3. mantle-cli aave positions --user <wallet> --json   → verify collateral_enabled
   ↓ MUST complete before Step 4
4. IF collateral_enabled=NO: mantle-cli aave set-collateral --asset X --user <wallet> --sender <wallet>
                                                                                       → ⚠️ USER CONFIRMATION → sign & WAIT
   ↓ MUST confirm tx success before Step 5
5. ⚠️ USER CONFIRMATION — present Borrow Confirmation Summary:
   - Intent, borrow asset, amount, current health factor, projected health factor, liquidation risk
   → User must explicitly approve before proceeding
   mantle-cli aave borrow --asset Y --amount N --on-behalf-of <wallet> --sender <wallet> --json
                                                                                       → sign & WAIT
```

**Edge cases** (Isolation Mode, LTV_IS_ZERO, USDT vs USDT0, repay/withdraw with `--amount max`): see **`references/aave-workflow.md`**.

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
