---
name: mantle-openclaw-competition
version: 0.1.24
description: "Use for ANY on-chain DeFi operation on the Mantle network by OpenClaw in the asset accumulation competition — swapping, liquidity provision, Aave V3 lending, ERC-20 approvals, MNT wrap/unwrap, or portfolio/state reads. ⚠️ WHITELIST-ONLY: only the 29 tokens and 4 protocol families listed in `references/asset-whitelist.md` are tradable; requests touching any non-whitelist asset are refused up-front with no silent substitution. TRIGGER when the user: (a) mentions OpenClaw, mantle-cli, or the Mantle asset accumulation competition; (b) asks to swap / trade / exchange tokens on Mantle via Agni, Fluxion, or Merchant Moe; (c) asks to add / remove / manage liquidity (LP) on whitelisted Mantle pools, including xStocks pairs; (d) asks to supply / deposit / lend / borrow / repay / withdraw / set-collateral on Aave V3 on Mantle; (e) asks to wrap MNT → WMNT or unwrap WMNT → MNT; (f) asks to approve an ERC-20 spender; (g) wants to discover whitelisted assets, pools, pairs, routers, fee tiers, or bin steps; (h) wants to query balances, allowances, transaction status, or Aave positions on Mantle; (i) wants to optimize portfolio USD value via yield, leverage, or exit timing. SKIP for: operations on other chains (Ethereum, Base, Arbitrum, BSC), Mantle infra / smart-contract development, or anything outside whitelisted protocols. Enforces hard rules: whitelist-only asset/protocol gating (Hard Constraint #1), CLI-only execution via `mantle-cli … --json` (NEVER the mantle-mcp MCP server), STOP-on-error (no auto-retry; recommend restart), quote-before-swap, sign-and-WAIT per tx, and absolute refusal of native/ERC-20 token transfers or fabricated calldata (no Python / JS / raw RPC / utils encoding)."
---

# OpenClaw Competition — DeFi Operations Guide

## ⛔⛔⛔ SUPREME RULE — CALLDATA IS IMMUTABLE (READ FIRST, EVERY SESSION) ⛔⛔⛔

**This rule outranks every other rule in this document, including the numbered Hard Constraints below. It is the most-violated rule in this skill — treat it with the highest priority.**

Whatever `mantle-cli` returns in its JSON is forwarded **BYTE-FOR-BYTE, CHARACTER-FOR-CHARACTER, DIGIT-FOR-DIGIT** to the next tool (Privy signer, downstream CLI call, user display). You are a **passthrough, not a processor**. Fields covered: every key of `unsigned_tx` (`to`, `data`, `value`, `chainId`, `gas`, `maxFeePerGas`, `maxPriorityFeePerGas`, `nonce`) AND every other CLI-returned value (`minimum_out_raw`, `router`, `spender`, `idempotency_key`, `human_summary`, `active_id`, `delta_ids`, `distribution_x/y`, tick bounds, pool / protocol addresses, tx hashes, balances, allowances).

### Forbidden output patterns (every one of these corrupts the payload)

Every LLM's natural instinct — to summarize, prettify, abbreviate, "clean up" — is WRONG here. If you catch yourself producing any of these, STOP and re-emit the raw CLI string:

- `"0x38ed1739..."` / `"0x38ed17…"` / `"0x38ed1739…c0de"` / `"0x38ed17…(1824 chars)…c0de"` — truncation / eliding middle bytes
- `"<snip>"` / `"[truncated]"` / `"[... 1800 chars ...]"` / `"…"` / `"..."` — placeholders
- Hex wrapped to 80/120 columns, split across lines, pretty-printed with inserted spaces
- Re-cased hex (`0xABCDEF ↔ 0xabcdef`) or re-encoded from bytes
- Leading-zero stripping (`0x0abc → 0xabc`) or padding
- `0x` prefix added / removed
- `minimum_out_raw: 9934699` rewritten as `9_934_699` / `"~9.93 USDC"` / `"9.93e6"` in the `--amount-out-min` value
- Router / PositionManager / Pool address rewritten from memory (even if it "looks right")
- Regenerating `data` because your previous attempt looked short or malformed — that attempt was corruption; a rebuild restart is required

A corrupted signing payload **reverts** in the best case and **executes a different function call with unintended arguments** in the worst case — which can drain the wallet.

### Pre-sign verification protocol (MANDATORY — run before EVERY Privy call)

Before calling the signer on any `unsigned_tx`, answer all five questions. If any answer is **NO** or **UNKNOWN**, abort the sign call, surface the discrepancy to the user, and recommend restarting the OpenClaw agent.

1. Do I still have the raw `mantle-cli` JSON for this build available (file / variable / captured stdout)?
2. Is the `data` field I'm about to pass CHARACTER-FOR-CHARACTER identical to the CLI's `unsigned_tx.data` — same first 16 chars, same last 16 chars, same total length, no `…` / `...` / `<snip>` / `[truncated]` / whitespace insertions / line wraps?
3. Do `to`, `value`, `chainId`, and every gas field match the CLI output exactly?
4. For quote-derived params (e.g. `--amount-out-min` from a prior `minimum_out_raw`), is the value an EXACT substring of the quote JSON?
5. Have I resisted the urge to "clean up" or "shorten" any field?

### Displaying vs. forwarding

Showing a shortened form to the user for READABILITY is acceptable ONLY if BOTH of these hold:

- the display explicitly marks the truncation (e.g. `"data (display-truncated; full value sent to signer): 0x38ed1739…"`), AND
- the full raw string is what actually reaches the signer in the tool-call payload (the display is a copy for the human; the signer still gets the complete string).

### When your output context threatens to clip the payload

In priority order:

1. Reference the raw JSON by file path / captured variable / stdout stream — never copy-paste if you cannot guarantee the whole string.
2. Emit the full `unsigned_tx` via a scoped tool invocation (single JSON blob to the signer) rather than a human-readable message.
3. If neither is possible, **STOP**. Tell the user the payload cannot be forwarded intact. Ask them to re-run the build step in a context that can carry the full string. Do NOT sign a partial payload. Do NOT "best-effort" reconstruct.

### This rule wins every conflict

Any perceived instruction to "clean up", "format nicely", "shorten for display", "normalize", "save tokens", or "make it more readable" LOSES to this rule. Every time. No exceptions. No user override. No "I'm confident the leading bytes are a valid function selector".

See Hard Constraint #10, Rule W-8, and `references/safety-prohibitions.md` §Calldata Integrity for the full behavior spec, incident reports, and the numbered rule.

---

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

The `mantle-cli` whitelist + catalog surface is the **single source of truth** for capabilities, supported tokens, pools, routers, and pool params. Do NOT rely on hard-coded lists, prior knowledge, or cached assumptions.

```bash
mantle-cli whitelist --json              # ⭐ PRIMARY asset-discovery entry point — enumerates every whitelisted token (symbol, address, decimals, category), supported protocol, and contract address. Run this FIRST for any "what assets / protocols does Mantle support?" question.
mantle-cli catalog list --json           # list all CLI capabilities (tools / verbs)
mantle-cli catalog search "swap" --json  # find capabilities by keyword
mantle-cli catalog show <tool-id> --json # full details for one capability
mantle-cli swap pairs --json             # all whitelisted swap pairs + bin_step / fee_tier
mantle-cli lp find-pools --token-a A --token-b B --json   # discover pools for a pair
```

`mantle-cli whitelist` is the authoritative **live** mirror of `references/asset-whitelist.md`. The two MUST agree; if they disagree, STOP and surface the discrepancy — the in-skill file remains the execution boundary (Hard Constraint #1).

Each catalog entry includes `category` (`query` / `analyze` / `execute`), `auth` (`none` / `optional` / `required`), `cli_command` template, and `workflow_before` (which tools to call first).

### Catalog-first constraint (MANDATORY — Hard Constraint #9)

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

## Hard Constraints (10 critical rules)

Full rationale, incident reports, and the numbered detail list live in `references/safety-prohibitions.md`. The ten non-negotiables:

1. **🔒 Whitelist-only — every asset and every protocol contract MUST appear in `references/asset-whitelist.md`.** Before the first CLI call that touches an asset or protocol contract (swap / LP / Aave / approve / wrap / unwrap, including quotes and pool discovery), verify every token symbol and every `--spender` / `--provider` / `to` address against `references/asset-whitelist.md`. If any item is missing — **STOP, tell the user which item was rejected, and do NOT proceed**, even if the user insists, accepts risk, or asks you to "just try". No silent substitution: if the user names a non-whitelist asset (e.g. `stETH`, `mETH`, `wHOODx`, `sUSDe`, `WBTC`, `GHO`), refuse and cite the whitelist — do NOT quietly quote a similar whitelisted asset instead. This rule overrides any inference drawn from `mantle-cli catalog list`, `swap pairs`, `aave markets`, or prior-session memory: those surfaces may carry informational tokens, but execution is gated by the whitelist file. This rule is checked FIRST, before every other Hard Constraint.
2. **CLI only** — never enable `mantle-mcp`; every command ends in `--json`.
3. **🛑 STOP on ANY `mantle-cli` error** — never auto-retry, never improvise. Print the raw error to the user verbatim, halt the workflow, and **recommend the user restart the OpenClaw agent** before continuing. Continuing past an unhandled error risks duplicate broadcasts, stale allowances, and fund loss.
4. **🛑 Refuse anything beyond the standard CLI verbs** — execute operations MUST be expressed via `swap / approve / lp / aave`. **Token transfers (native MNT and ERC-20) are NOT supported — refuse.** If a request can't map to one of the allowed verbs, **STOP and tell the user**. NEVER improvise with Python, JS, RPC calls, or `utils` calldata construction. The user accepting risk is NOT sufficient — the prohibition is absolute.
   - **Protocol actions are function calls, NOT transfers.** `aave supply / borrow / repay / withdraw`, `swap build-swap`, and `lp add / remove` invoke specific functions on the target contract that mint aTokens, route the trade, or register liquidity. Sending tokens directly to the Aave V3 Pool (`0x458F293454fE0d67EC0655f3672301301DD51422`), a DEX router, a position manager, or a WETHGateway via ERC-20 `transfer()` / `transferFrom()` does NOT trigger those functions — the tokens are **permanently locked** with no on-chain path to recover. If a user says "supply / deposit / lend X to Aave" or "send X to Aave", use `mantle-cli aave supply` — never model it as an ERC-20 transfer to the Pool address.
5. **Never fabricate calldata or compute wei** — the dedicated CLI verbs handle decimal conversion deterministically. NEVER use Python/JS for any encoding.
6. **Never build the same tx twice** — always pass `--sender <wallet>` so the response carries an `idempotency_key`. If a build times out, check `mantle-cli chain tx --hash <hash> --json` BEFORE rebuilding.
7. **🛡️ Always quote before swap — `amount-out-min` MUST come from the quote's `minimum_out_raw`, VERBATIM** — see "Slippage Protection Rules" section below for full details. Setting `--amount-out-min` to `0`, `1`, or any value less than `minimum_out_raw` is **absolutely prohibited** — it removes slippage protection and exposes the user to sandwich attacks and fund loss.
8. **"sign & WAIT"** — verify each tx (`status: success`) before building the next. Do NOT pipeline unsigned transactions.
9. **🔍 Catalog-first — ALWAYS consult the catalog before ANY operation** — run `mantle-cli catalog list --json` at session start and `mantle-cli catalog show <tool-id> --json` before each operation. No catalog lookup → no execution. See "Catalog-first constraint" section above for full rules.
10. **⛔⛔⛔ UNCONDITIONAL TRUST IN `mantle-cli` OUTPUT — CALLDATA IS IMMUTABLE. See the SUPREME RULE at the top of this document.** This is the most-violated rule in the skill. Every CLI-returned value (`unsigned_tx.data`, `unsigned_tx.to`, `unsigned_tx.value`, gas fields, `minimum_out_raw`, `router`, `spender`, `idempotency_key`, `active_id`, tick bounds, pool addresses, balances, allowances, tx hashes, `human_summary`) is forwarded to the signer / next tool byte-for-byte, character-for-character. **You MUST run the pre-sign verification protocol (SUPREME RULE → "Pre-sign verification protocol") before EVERY signer call.** Any edit — truncation, re-casing, leading-zero stripping, `0x` toggling, wrapping, placeholder `…`, "regeneration" from memory, silently reformatting a raw integer into `9_934_699` / `"~9.93 USDC"` — is a HARD STOP: refuse to sign, surface the discrepancy, restart. Displaying a shortened form to the user is acceptable ONLY if the display marks the truncation AND the full string still reaches the signer. See SUPREME RULE, Rule W-8, and `references/safety-prohibitions.md` §Calldata Integrity.

## ⚠ USDT ≠ USDT0

USDT and USDT0 are **two different ERC-20 tokens** on Mantle (different contract addresses, different protocol support, different liquidity pools). Never confuse them.

- **Aave V3 only accepts USDT0** — NOT USDT. If the user only holds USDT, swap to USDT0 on Merchant Moe (bin_step=1) first.
- **When the user says "USDT", always clarify** — ask whether they mean USDT or USDT0 before executing any operation. Do not assume.
- **CLI params must be exact** — `--in USDT` and `--in USDT0` point to different contracts. Using the wrong symbol causes failed txs, wrong pools, or fund loss.
- **Always display both balances** when the user asks about USDT holdings or portfolio.

## 🔤 Asset Alias Resolution

Generic name → Mantle-whitelisted canonical token. The authoritative list lives in **`references/asset-whitelist.md`** (21 tokens: MNT/WMNT, USDC, USDT, USDT0, WETH, USDe, MOE, cmETH, FBTC, 8 xStocks, 4 community tokens). Mantle mostly exposes **wrapped / liquid-staked / synthetic variants**, not the "raw" asset — so a generic mention of BTC/ETH/a US stock ALWAYS maps to a Mantle-native wrap from the whitelist. Verify the candidate via `mantle-cli swap pairs --json` (swap/LP) or `aave markets --json` (lending) before use — swap support does NOT imply Aave support. **If the user names a token outside the whitelist (e.g. `stETH`, `mETH`, `WBTC`, `sUSDe`, `wHOODx`), refuse per Hard Constraint #1 — do NOT silently quote or swap a "similar" whitelisted asset.** Multiple whitelisted candidates → **ASK**, never pick silently. Generic balance queries ("how much BTC/ETH?") → list ALL whitelisted variants.

- **BTC / bitcoin** → **FBTC** (the only Mantle-whitelisted BTC wrap). Refuse WBTC / solvBTC / renBTC — not on the whitelist.
- **ETH / ether** → Mantle exposes **WETH** (wrapped ETH) and **cmETH** (restaked mETH). ASK which one — they have different yield and risk profiles. Refuse mETH / stETH / wstETH / rETH — not on the whitelist.
- **US stocks / TSLA / AAPL / NVDA / etc.** → **xStocks wrap assets only** (prefix `w`, suffix `x`). The canonical whitelist covers exactly 8 tickers:
  - TSLA → **wTSLAx**, AAPL → **wAAPLx**, NVDA → **wNVDAx**, GOOGL → **wGOOGLx**, META → **wMETAx**, MSTR → **wMSTRx**, SPY → **wSPYx**, QQQ → **wQQQx**.
  - xStocks have liquidity on **Fluxion only**, paired with **USDC**, `fee_tier=3000`. Refuse to quote / swap them on Agni or Merchant Moe — no pool exists (Safety Rule #13).
  - Not on Aave V3 whitelist — refuse supply/borrow requests for xStocks.
  - If the user names a stock not in the 8-ticker list above (e.g. HOOD, CRCL, AMZN), **refuse per Hard Constraint #1** — that token is not on the whitelist, regardless of whether `mantle-cli swap pairs` shows a candidate pool.
- **stablecoin / USD** → **USDC**, **USDT0**, **USDe** — ask which + which protocol. Aave only accepts **USDC**, **USDT0**, and **USDe** among stables. Refuse sUSDe / GHO / syrupUSDT / other stables — not on the whitelist.
- **USDT** → clarify USDT vs USDT0 (§USDT ≠ USDT0). Aave requires **USDT0**.
- **MNT** → native MNT (wrap/unwrap / gas only) vs **WMNT** (swap / LP / Aave — all ERC-20 paths).
- **Community tokens** → **BSB**, **ELSA**, **VOOI**, **SCOR** (Fluxion, typically paired with USDT0, multi-hop via USDT0 bridge).
- **RWA as a category** → always xStocks wrap assets (see above). Never an unwrapped stock ticker — Mantle has no unwrapped US equity on-chain.

**Rule of thumb.** If the user says a well-known off-chain asset name (BTC, ETH, TSLA, AAPL…), translate it to its whitelisted Mantle wrap BEFORE any `swap-quote` / `pairs` / `aave markets` call. Never pass the generic ticker (`BTC`, `ETH`, `TSLA`) to the CLI — the CLI expects the canonical symbol (`FBTC`, `WETH` / `cmETH`, `wTSLAx`). If no whitelisted wrap exists for the request, refuse.

## 🛡️ Slippage Protection Rules (Hard Constraint #7 — detailed)

**⛔ `--amount-out-min` MUST equal the quote's `minimum_out_raw`, passed VERBATIM. No exceptions.**

- `minimum_out_raw` is a **raw integer** in the output token's smallest unit. The CLI already handles decimal conversion — do NOT multiply, divide, or re-encode it.
- **Prohibited values:** `0`, `1`, or anything below `minimum_out_raw`. These remove slippage protection and expose the user to sandwich attacks.
- **If `build-swap` reverts:** re-quote to get a fresh `minimum_out_raw` and retry — NEVER lower `amount-out-min` to "make it work." After 2 failed retries, STOP and inform the user.

> **Incident:** Agent re-multiplied `minimum_out_raw: 9934699` → passed `9934700000` → revert → fell back to `--amount-out-min 1` (zero protection). **Correct fix:** pass `9934699` verbatim.

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
- **On ANY `mantle-cli` non-zero exit (including RPC timeout / rate-limit)**: STOP immediately per STOP CONDITION 1. Do NOT auto-retry write commands (`approve`, `swap build-swap`, `wrap-mnt`, `unwrap-mnt`, `lp add/remove/collect-fees`, `aave supply/borrow/repay/withdraw/set-collateral`) — re-running a build or sign step after a timeout risks a duplicate broadcast with stale state.
- **Post-sign receipt polling is the ONLY permitted retry path** — if the tx was already signed and broadcast (you have a hash), you MAY retry `mantle-cli chain tx --hash <hash> --json` until you get a deterministic `status: success | reverted`. Rebuilding / re-signing is governed by Rule W-8 only.

### Rule W-4: Post-Operation Balance Verification (MANDATORY)

After **any** write tx confirms (`status: success`), ALWAYS run `mantle-cli account balances <wallet> --json` to fetch actual on-chain balances (full-whitelist coverage per Rule W-7). **NEVER report, display, or infer balance changes from your own calculation** — only show what the CLI returns. Fabricated or estimated balances are prohibited.

### Rule W-5: Swap Direction Disambiguation ⚠️

When the user says "use **X** to get **N Y**", "swap **X** for **N Y**", or "buy **N Y** with **X**":
- **N** is the **output** quantity (Y tokens to receive) — NOT the input amount.
- **❌ Wrong:** "use MNT to get 10 USDC" → interpreted as "swap 10 MNT → USDC"
- **✅ Correct:** "use MNT to get 10 USDC" → target output ≈ 10 USDC
- **✅ Converse:** "swap 10 MNT for USDC" → input = 10 MNT (output variable). The number attaches to the side it's adjacent to — never flip it.

**Estimating the input amount (the CLI only supports fixed-input swaps).** Do NOT guess how much X is needed to receive N Y. Instead, use a reverse `swap-quote` to derive the estimate from live on-chain liquidity:

1. Call `mantle-cli defi swap-quote --in Y --out X --amount N --provider best --json` — this asks "if I swapped N Y back to X right now, how much X would I get?", which is a good proxy for the X needed to buy N Y.
2. Take the quoted X amount and add a small buffer (suggest +0.5%–1%) to cover slippage, fees, and price impact asymmetry between the two directions. This buffered X is the input for the real forward swap.
3. In the Transaction Confirmation Summary (Rule W-2), clearly state: input = `<buffered X>`, expected output ≈ `N Y` (may be slightly higher or lower), and the buffer %. Let the user approve or adjust the buffer before you broadcast.
4. If the user insists on receiving **exactly** N Y (not ≈ N Y), inform them the CLI has no fixed-output swap and the reverse-quote method is the closest feasible approach — never silently claim exact output, and never flip input/output to fake a fixed-output swap.

### Rule W-6: Allowance Disclosure & Approve Confirmation

After every `allowances` check, display the **current allowance (raw + human-readable), spender address, and the required amount** for the planned operation to the user BEFORE deciding to approve or skip. If `approve` is required, present the exact spender address and approval amount in the Transaction Confirmation Summary (Rule W-2) for explicit user approval. Do NOT silently approve (max or otherwise), and do NOT silently skip approve based on your own reading of the allowance.

### Rule W-7: Full-Whitelist Balance Query

When querying balances **without a specific asset filter**, you MUST return **all whitelisted assets** — never omit any. Procedure:

1. Run `mantle-cli account balances <wallet> --json` without token filters.
2. Cross-check the response against the whitelisted token list from `mantle-cli catalog list --json` (or `mantle-cli swap pairs --json`).
3. For any whitelisted asset missing from step 1's output, query it explicitly and merge the result.

Silently omitting any whitelisted asset (e.g., MOE) from a balance report is a hard error — never present an incomplete portfolio.

### Rule W-8: Signing Flow Integrity 🔐

**See the SUPREME RULE at the top of this document.** This section is the operational form of that rule for the signing step. Every sign call MUST be preceded by the 5-question pre-sign verification protocol from the SUPREME RULE.

**Canonical path:** `mantle-cli` build → complete `unsigned_tx` → **pre-sign verification protocol** → Privy API sign → wait for on-chain receipt. No shortcuts, no alternatives.

**`unsigned_tx` MUST carry the full parameter set returned by `mantle-cli`:**

```ts
unsigned_tx: {
  to: string;                     // required
  data: string;                   // required
  value: string;                  // required
  chainId: number;                // required
  gas?: string;                   // suggested gas limit
  maxFeePerGas?: string;          // EIP-1559: baseFee × 2 + tip, hex wei
  maxPriorityFeePerGas?: string;  // EIP-1559 tip, hex wei
  nonce?: number;                 // only when explicitly overridden (e.g. after mantle_getNonce)
};
```

- **Never mutate, strip, or re-encode** any field returned by `mantle-cli`. Pass `unsigned_tx` to Privy **verbatim**.
- **Never hand-assemble `unsigned_tx`** from your own values — the CLI is the sole producer. Fabricating `to` / `data` / `value` / gas params is the same violation as Hard Constraint #5 (no fabricated calldata).
- **⛔ ZERO CALLDATA EDITING (Hard Constraint #10).** The `data` field is often a multi-hundred or multi-thousand char hex string. Forward it to Privy **byte-for-byte, character-for-character**, exactly as `mantle-cli` produced it. NEVER:
  - truncate, shorten, or abbreviate (`"0x38ed17…"`, `"0x38ed1739...c0de"`, `"<snip>"`, `"[truncated]"`, `"…"`) — these corrupt the payload and will either revert or, worse, execute the wrong call;
  - pretty-print, reformat, wrap to a line width, split across lines, or insert whitespace;
  - re-encode, re-hex, lowercase/uppercase-normalize, strip leading zeros, or drop the `0x` prefix;
  - reconstruct or "fill in" bytes from memory / inference — if your display context would clip the string, read it back from the raw CLI JSON (by file path or captured variable) or abort and ask the user to re-run. Never guess the missing part.
  - Same discipline applies to `to`, `value`, `chainId`, `gas`, `maxFeePerGas`, `maxPriorityFeePerGas`, and `nonce` — every integer and hex value goes through untouched.
- **Displaying a shortened `data` to the user for readability is OK ONLY if the full raw string is still what reaches the signer.** Mark any truncation in the display (`"data (display-truncated; full value sent to signer): 0x38ed1739…"`) and keep the original string in the tool call payload unchanged.

**One unsigned_tx = one signature. No exceptions.**

- After signing, WAIT for the receipt (`mantle-cli chain tx --hash <hash> --json`) before any further action.
- **On 504 / timeout / network error:** do NOT re-sign. First query the chain for the receipt — if the tx is already mined (any status), resume from there; only if it is truly absent from the chain may you rebuild via `mantle-cli` (new `idempotency_key`) and sign the **new** `unsigned_tx`. Re-signing the old `unsigned_tx` risks duplicate broadcast and nonce collision.
- **If Privy timed out before returning a tx hash** (signing-stage failure, no broadcast): there is nothing to query on-chain. Rebuild via `mantle-cli` with a new `idempotency_key` and sign the fresh `unsigned_tx`. Discard the old one.

### Rule W-9: Pre-Execution Readiness Check (MANDATORY)

**⛔ Balance AND allowance are TWO separate `mantle-cli` tool calls — never merged into one pipeline. The allowance value MUST come from `mantle-cli account allowances --json`, not from a piped script or inference. Completing only the balance check is a hard error.**

Before executing **ANY** write operation (swap, approve, lp add/remove, aave supply/borrow/repay/withdraw/set-collateral, wrap/unwrap), confirm the user's intent is feasible against actual on-chain state. Two queries, in this order:

1. **Balance check** — `mantle-cli account token-balances <wallet> --json`. Verify `balance(input_token) ≥ planned input amount` (for wrap/unwrap: native MNT for wrap, WMNT for unwrap). If insufficient → **STOP**, report the actual balance to the user, do NOT proceed.
2. **Allowance check** — `mantle-cli account allowances <wallet> --pairs <token>:<spender> --json`. Verify `allowance(input_token, spender) ≥ planned input amount`. If insufficient → route to the approve flow (Rule W-6). Do NOT silently skip.

These checks MUST occur BEFORE the Transaction Confirmation Summary (Rule W-2) — the summary presented to the user MUST reflect real on-chain state, not assumptions. Starting a write op without both queries is a hard error.

**Skip conditions** (narrow): balance check is not required for pure read ops; allowance check is not required for native-MNT-only ops (e.g. `swap wrap-mnt`) or for protocols the user has no intent of touching. When in doubt, run both.

> **Incident:** Agent piped `account token-balances` through `python3 -c "..."` which printed `USDC: 3.408142 Current allowance: 0.5`. The CLI only queried balances — the `0.5` did not come from `account allowances` and is unauditable. Correct fix: two separate `mantle-cli ... --json` tool calls.

## Available Tools

| Tool | Purpose | Command |
|------|---------|---------|
| Catalog | Discover capabilities, tokens, pools | `mantle-cli catalog list / search / show` |
| Swap | DEX exchange | `mantle-cli swap pairs / wrap-mnt / unwrap-mnt / build-swap` + `mantle-cli defi swap-quote` |
| LP | Liquidity provision | `mantle-cli lp top-pools / find-pools / add / remove / collect-fees` + `mantle-cli defi analyze-pool` + `mantle-cli lp suggest-ticks` |
| Aave | Lending / borrowing | `mantle-cli aave supply / borrow / repay / withdraw / set-collateral / positions` |
| Account | Read state | `mantle-cli account allowances / balances` + `mantle-cli chain tx / estimate-gas` |

> **Token transfers are NOT in the toolset.** `mantle-cli transfer send-native` / `transfer send-token` and the corresponding `mantle_buildTransferNative` / `mantle_buildTransferToken` MCP tools have been deliberately removed. Refuse transfer requests per Hard Constraint #4 — do NOT fall back to the utils pipeline to simulate one.

> **No escape hatch.** If a user's request can't be expressed by the verbs above, **refuse** (see Hard Constraint #4). Do NOT use Python, JS, raw RPC, or `utils` calldata construction.

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

## Intent Routing — 自然语言 → Workflow

Map the user's phrase (中/EN) to a CLI namespace BEFORE any call. Ask when ambiguous.

- 兑换 / 交易 / 买 / 卖 / swap / trade → `swap` + `defi swap-quote` (§Swap)
- 包装 / wrap / unwrap MNT → `swap wrap-mnt` / `unwrap-mnt` (§Swap)
- **添加 / 提供流动性 / 做市 / add LP** → `lp top-pools → find-pools → defi analyze-pool → suggest-ticks → add` (§Add Liquidity, `references/lp-workflow.md`) — **if ANY asset is named (single or pair), ALWAYS start with `mantle-cli lp find-pools` before anything else. See §LP Pool Discovery below.**
- 移除流动性 / remove LP / collect fees → `lp positions / remove / collect-fees`
- 存 / 借 / 还 / 取 (Aave) / supply / borrow / repay / withdraw → `aave <verb>` / `set-collateral` (§Aave)
- 授权 / approve → `approve` (embedded per workflow)
- 余额 / 仓位 / balance / positions → `account balances / allowances`, `aave positions`, `lp positions` (read-only)
- **查资产 / 支持什么币 / 有哪些主流资产 / what tokens are on Mantle / available assets** → `mantle-cli whitelist --json` FIRST (authoritative whitelisted token + protocol set, no wallet dependency), then `mantle-cli account token-balances <wallet> --json` (no filter) to overlay the user's current holdings — see §Asset Discovery below.

**Disambiguation:** "USDT" → clarify USDT vs USDT0 (§USDT ≠ USDT0). Generic "BTC / ETH / stable" → §Asset Alias. "提供流动性" with no pair → start at `lp top-pools`, NOT `lp add`. "存到 Aave / 转到 PositionManager" → function-call verb, NEVER ERC-20 transfer (Hard Constraint #4).

## Asset Discovery — "Mantle 上有什么资产?" (short tutorial)

**Trigger phrases (中/EN):** "Mantle 上有哪些主流资产?", "支持什么币?", "有什么资产可以用?", "what tokens does Mantle support?", "what assets are available on Mantle?", "list supported tokens", or any open-ended question about the Mantle asset set with no specific token in mind. Also covers category questions ("有没有 BTC?", "支持美股吗?", "can I trade ETH?") — same flow, then narrow to the canonical wrap.

**⛔ Do NOT answer from memory.** Do not list hard-coded tokens from prior knowledge, training data, or a previous session. The whitelisted asset set is owned by `mantle-cli`.

**Step-by-step:**

1. **First call — authoritative whitelist:** `mantle-cli whitelist --json`.
   - This is the **primary asset-discovery entry point.** It returns the live authoritative enumeration of every whitelisted token (symbol, address, decimals, category), every supported protocol, and every associated contract address — with no wallet dependency. Every category question ("有哪些主流资产?", "支持 BTC 吗?", "what tokens can I trade?") is answered from this response FIRST, before any other CLI call.
   - Learn the exact flags and sub-views (e.g. `--tokens`, `--protocols`, category filters) from the CLI itself, not from memory: `mantle-cli whitelist --help` or `mantle-cli catalog show <whitelist tool-id> --json`.
   - Cross-check the response against `references/asset-whitelist.md` (Hard Constraint #1 execution boundary). The two MUST agree. If the CLI returns a symbol / address that is not in the file (or vice versa), **STOP**, surface the discrepancy to the user, and refuse to proceed — do NOT silently trust either side. The in-skill file remains the authoritative execution gate.
2. **Second call — balance overlay (only when the user asks about their wallet):** `mantle-cli account token-balances <wallet> --json` **with no token filter.**
   - Overlays the user's current holdings on top of the whitelist so a single combined reply covers both "what does Mantle support?" and "what do I currently hold?" (including zero-balance entries). Skip this call for pure "what assets exist?" questions that don't reference the wallet.
   - Apply Rule W-7: every whitelisted symbol returned by step 1 MUST appear in the combined output. Query any missing asset explicitly and merge.
3. **Translate generic category names to their Mantle-canonical wrap BEFORE presenting.** Mantle exposes wrapped / LST / synthetic variants, not the raw asset. Use §Asset Alias Resolution; never surface a non-whitelist asset (see `references/asset-whitelist.md` and Hard Constraint #1):
   - **BTC** → **FBTC** (only Mantle BTC wrap — no WBTC/solvBTC/renBTC).
   - **ETH** → **WETH** and **cmETH** (restaked mETH) — list both on a generic ETH query. Refuse mETH / stETH / wstETH / rETH.
   - **Stocks / TSLA / AAPL / NVDA / …** → **xStocks wrap assets** (`w<TICKER>x`), exactly 8 tickers: wTSLAx, wAAPLx, wNVDAx, wGOOGLx, wMETAx, wMSTRx, wSPYx, wQQQx. Fluxion-only, paired with USDC (fee_tier=3000). Not on Aave. Refuse any other stock (HOOD / CRCL / AMZN / …) — not on the whitelist.
   - **Stablecoins / USD** → USDC, USDT0, USDe — clarify which. USDT ≠ USDT0. Refuse sUSDe / GHO / syrupUSDT.
   - **Community tokens** → BSB, ELSA, VOOI, SCOR (Fluxion, USDT0-paired).
   - **MNT** → native MNT (gas, wrap/unwrap only) vs WMNT (ERC-20 for swap / LP / Aave).
4. **Present the result verbatim** to the user — symbol, balance (human-readable), USD value if the response includes it. Per Rule W-4, NEVER fabricate or estimate numbers; only show what the CLI returned. When answering a category question ("有 BTC 吗?"), reply with the canonical wrap ("Mantle 上的 BTC 曝光通过 **FBTC**，你当前余额 X …") rather than a yes/no.
5. **Cross-check for completeness (Rule W-7).** Make sure every whitelisted variant for the category is listed (FBTC; WETH + cmETH; USDC + USDT0 + USDe; USDT vs USDT0; the full 8-ticker xStocks set when asked about stocks; BSB/ELSA/VOOI/SCOR for community). If any whitelisted asset is missing from step 1's response, query it explicitly and merge. Never fabricate a non-whitelist entry to fill out a category.
6. **Drill-down (only if the user asks for more detail):**
   - "Where can I swap X?" → `mantle-cli swap pairs --json` (xStocks: Fluxion-only).
   - "Can I lend/borrow X on Aave?" → `mantle-cli aave markets --json` — xStocks are NOT on Aave; refuse that path.
   - "What pools exist for A/B?" → `mantle-cli lp find-pools --token-a A --token-b B --json`.
   - Swap support does NOT imply Aave support — always re-verify per protocol.
7. If the user uses a ticker you can't resolve (some obscure stock, LST, or stablecoin), confirm via `mantle-cli whitelist --json` (step 1) first; if no `w<TICKER>x` / canonical entry exists, also run `mantle-cli swap pairs --json` and `aave markets --json` for completeness — if still absent, **STOP** and tell the user it's not whitelisted.

**Worked examples:**

- User: "What mainstream assets does Mantle support?"
  → `mantle-cli whitelist --json` first (authoritative list). Optionally follow with `account token-balances --json` if the user cares about current holdings. Reply with the full whitelist (MNT / WMNT / WETH / cmETH / FBTC / USDC / USDT / USDT0 / USDe / MOE / wTSLAx / wAAPLx / wNVDAx / wGOOGLx / wMETAx / wMSTRx / wSPYx / wQQQx / BSB / ELSA / VOOI / SCOR), grouped by category (native, ETH-family, BTC, stables, stocks, community, DeFi); include per-wallet balances if step 2 ran. Flag USDT vs USDT0.
- User: "Is there any BTC I can use?"
  → `mantle-cli whitelist --json` (confirm FBTC is the only whitelisted BTC wrap), then `account token-balances --json` for the balance, then reply: "Mantle's BTC exposure is via **FBTC** (the only whitelisted BTC wrap); your current FBTC balance is X." Do NOT list WBTC / solvBTC.
- User: "Can I trade ETH?"
  → `mantle-cli whitelist --json` (enumerates WETH + cmETH), then `account token-balances --json`, then reply with the two whitelisted ETH-family wraps (WETH / cmETH), each balance, and ask which one the user wants to trade. Refuse mETH / stETH / wstETH.
- User: "Do you support US stocks, for example TSLA?"
  → `mantle-cli whitelist --json` (confirms the 8-ticker xStocks set), then `account token-balances --json`, then reply: "Supported xStocks: wTSLAx, wAAPLx, wNVDAx, wGOOGLx, wMETAx, wMSTRx, wSPYx, wQQQx. TSLA maps to **wTSLAx**, which trades only on **Fluxion** paired with USDC (fee_tier=3000) and is NOT an Aave reserve. Your current wTSLAx balance is X."

## LP Pool Discovery — "我要给 A/B 提供流动性" / "用 X 做 LP" (short tutorial)

**Trigger phrases (中/EN):** "add liquidity", "provide LP", "LP for A/B", "做 LP", "提供流动性", "加池子", "用 USDC 做市", "给 FBTC/USDC 做市", or any LP-add intent — whether the user names a full pair (A/B) or just a single asset (X).

**⛔ Mandatory first call — `mantle-cli lp find-pools` (applies to BOTH single-asset and pair intents).**

1. **Before any other LP action** (`analyze-pool`, `suggest-ticks`, `approve`, `lp add`), call `mantle-cli lp find-pools` via `mantle-cli`. Do NOT skip it, even if the user named a full pair.
2. **Learn the subcommand from the CLI itself**, not from memory. Run `mantle-cli catalog show <find-pools tool-id> --json` (the tool-id comes from `catalog list`) to get the exact flags, accepted token params, and whether single-asset queries are supported directly. Don't assume the flag shape from a previous session.
3. **Trust the response verbatim** (per the SUPREME RULE). The DEX(es), fee tier / bin step, PositionManager / Router address, and TVL/APR all come from `find-pools`. Never fabricate them from memory.
4. **Empty result → STOP.** Tell the user no whitelisted pool was found; suggest a supported alternative if one exists (e.g. swap one side to a common quote first). Never fall through to `lp add` or pick a pool from memory.
5. **Translate generic asset names first** (§Asset Alias — BTC→FBTC, ETH→mETH/cmETH/WETH, TSLA→wTSLAx, etc.) before passing them to the CLI.

After `find-pools` succeeds: `defi analyze-pool` → `suggest-ticks` (V3) or derive LB params from the pool state → `approve` both tokens → `lp add`. This ordering is enforced by Rule W-1.

## Workflow: Swap (skeleton)

> **⚠ Steps MUST be executed in strict order (Rule W-1). Each transaction requires user confirmation (Rule W-2).**

```
0. mantle-cli catalog show mantle_buildSwap --json                     → verify command exists, get template & workflow_before
   ↓ MUST complete before Step 1 (Hard Constraint #9)
1. mantle-cli swap pairs --json                                      → find bin_step / fee_tier
   ↓ MUST complete before Step 2
2. mantle-cli defi swap-quote --in X --out Y --amount N --provider best --json   → minimum_out_raw
   ⚠️ SAVE the `minimum_out_raw` value from the response — pass it VERBATIM to --amount-out-min in Step 5.
      DO NOT convert, multiply, or recalculate. See "Slippage Protection Rules" (Hard Constraint #7).
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
   ↓ MUST complete before Step 1 (Hard Constraint #9)
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
   ↓ MUST complete before Step 1 (Hard Constraint #9)
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
| `references/asset-whitelist.md` | **Load every session before any asset/protocol touches the CLI** — canonical list of 21 tokens + protocol contracts (Hard Constraint #1) |
| `references/swap-workflow.md` | First swap of the session, or handling timeout / retry / wrap-mnt (also contains the swap-specific calldata integrity banner) |
| `references/lp-workflow.md` | Adding / removing liquidity, or suggesting tick ranges (also contains the LP-specific calldata integrity banner) |
| `references/aave-workflow.md` | Any Aave operation, or troubleshooting collateral / Isolation Mode (also contains the Aave-specific calldata integrity banner) |
| `references/safety-prohibitions.md` | A `mantle-cli` error occurred, the user requested something outside standard verbs, **or you are about to sign a tx and want to re-read the pre-sign verification protocol (STOP CONDITION 3 + Rule #18)** |

For full CLI documentation and the live whitelisted asset/protocol list: `mantle-cli whitelist --json` (primary), `mantle-cli catalog list --json`, and `mantle-cli catalog show <tool-id> --json`.

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
