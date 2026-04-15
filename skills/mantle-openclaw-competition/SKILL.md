---
name: mantle-openclaw-competition
version: 0.4.0
description: "Use when OpenClaw needs to execute DeFi operations for the asset accumulation competition on Mantle. Covers swap, LP, and Aave lending workflows on whitelisted Mantle protocols via mantle-cli."
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

The `mantle-cli` catalog is the authoritative source for capabilities, supported tokens, pools, routers, and pool params. Do NOT rely on hard-coded lists.

```bash
mantle-cli catalog list --json           # list all capabilities
mantle-cli catalog search "swap" --json  # find capabilities by keyword
mantle-cli catalog show <tool-id> --json # full details for one capability
mantle-cli swap pairs --json             # all whitelisted swap pairs + bin_step / fee_tier
mantle-cli lp find-pools --token-a A --token-b B --json   # discover pools for a pair
```

Each catalog entry includes `category` (`query` / `analyze` / `execute`), `auth` (`none` / `optional` / `required`), `cli_command` template, and `workflow_before` (which tools to call first).

## Hard Constraints (7 critical rules)

Full rationale, incident reports, and the numbered detail list live in `references/safety-prohibitions.md`. The seven non-negotiables:

1. **CLI only** — never enable `mantle-mcp`; every command ends in `--json`.
2. **🛑 STOP on ANY `mantle-cli` error** — never auto-retry, never improvise. Print the raw error to the user verbatim, halt the workflow, and **recommend the user restart the OpenClaw agent** before continuing. Continuing past an unhandled error risks duplicate broadcasts, stale allowances, and fund loss.
3. **🛑 Refuse anything beyond the standard CLI verbs** — execute operations MUST be expressed via `swap / approve / lp / aave`. **Token transfers (native MNT and ERC-20) are NOT supported — refuse.** If a request can't map to one of the allowed verbs, **STOP and tell the user**. NEVER improvise with Python, JS, RPC calls, or `utils` calldata construction. The user accepting risk is NOT sufficient — the prohibition is absolute.
4. **Never fabricate calldata or compute wei** — the dedicated CLI verbs handle decimal conversion deterministically. NEVER use Python/JS for any encoding.
5. **Never build the same tx twice** — always pass `--sender <wallet>` so the response carries an `idempotency_key`. If a build times out, check `mantle-cli chain tx --hash <hash> --json` BEFORE rebuilding.
6. **Always quote before swap** — pass `amount_out_min` from the quote; never set `allow_zero_min`.
7. **"sign & WAIT"** — verify each tx (`status: success`) before building the next. Do NOT pipeline unsigned transactions.

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

## Workflow: Swap (skeleton)

```
1. mantle-cli swap pairs --json                                      → find bin_step / fee_tier
2. mantle-cli defi swap-quote --in X --out Y --amount N --provider best --json   → minimum_out_raw
3. mantle-cli account allowances <wallet> --pairs X:<router> --json  → allowance check
4. IF insufficient: mantle-cli approve ...                           → sign & WAIT
5. mantle-cli swap build-swap --provider <dex> --in X --out Y ... --amount-out-min <quote> --sender <wallet> --json
                                                                     → sign & WAIT
6. mantle-cli chain tx --hash <hash> --json                          → verify status: success
```

For MNT input: `swap wrap-mnt` first, then swap WMNT. For MNT output: swap to WMNT, then `swap unwrap-mnt`. Full step-by-step with retry logic and edge cases → **`references/swap-workflow.md`**.

## Workflow: Add Liquidity (skeleton)

```
1. mantle-cli lp top-pools --sort-by apr --min-tvl 10000 --json   (OR: lp find-pools for a specific pair)
2. mantle-cli defi analyze-pool ... --investment N --json         → APR, risk, projections
3. mantle-cli lp suggest-ticks ... --json                         → wide / moderate / tight
4. mantle-cli approve --token A --spender <position_manager>      → sign & WAIT
5. mantle-cli approve --token B --spender <position_manager>      → sign & WAIT
6. mantle-cli lp add ... --sender <wallet> --json                 → sign & WAIT
```

V3 (Agni / Fluxion) takes `--fee-tier`, `--tick-lower`, `--tick-upper`. LB (Merchant Moe) takes `--bin-step`, `--active-id`, `--delta-ids`, `--distribution-x/y`. xStocks LP only on Fluxion (USDC pairs, fee_tier=3000). Full args → **`references/lp-workflow.md`**.

## Workflow: Aave Supply → Borrow (skeleton)

```
1. mantle-cli approve --token X --spender <aave-pool>   → sign & WAIT
2. mantle-cli aave supply --asset X --amount N --on-behalf-of <wallet> --sender <wallet> --json
                                                                                       → sign & WAIT
3. mantle-cli aave positions --user <wallet> --json   → verify collateral_enabled
4. IF collateral_enabled=NO: mantle-cli aave set-collateral --asset X --user <wallet> --sender <wallet>
                                                                                       → sign & WAIT
5. mantle-cli aave borrow --asset Y --amount N --on-behalf-of <wallet> --sender <wallet> --json
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
