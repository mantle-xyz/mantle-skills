# Safety Prohibitions & CLI Coverage Boundary

Canonical source for all safety rules. The main `SKILL.md` carries a 9-item summary AND the SUPREME RULE on calldata immutability; this file holds the full rationale, incident reports, and stop protocol. Load when:

- A `mantle-cli` command returns an error
- A user requests an operation outside the standard CLI verbs
- You are about to sign a tx and want to re-read the calldata integrity protocol
- You are unsure whether to refuse or proceed

---

## 🛑 STOP CONDITIONS — When You MUST Halt and Defer to the User

These three situations are non-negotiable. Claude MUST stop immediately and let the user decide the next move. Continuing past any of them risks **irreversible fund loss**.

### STOP 1. ANY `mantle-cli` error

If `mantle-cli` exits non-zero, prints an error JSON, returns an unexpected response shape, or any subprocess failure occurs:

- **STOP all subsequent operations.** Do NOT auto-retry. Do NOT try a different command to "work around" the error. Do NOT continue with the next planned step in the workflow.
- **Print the full error to the user verbatim** — the raw stderr / error JSON, NOT a paraphrase. The user needs the exact message to diagnose.
- **Tell the user the operation is halted for fund safety.**
- **Recommend restarting the OpenClaw agent** before retrying. The error may have left wallet state, allowances, or in-flight transactions in an unknown state. A fresh agent session re-pulls on-chain state cleanly. Continuing in the same session risks duplicate broadcasts, wrong allowances, or fund loss.
- **Do NOT proceed** until the user explicitly confirms how to recover.

This applies to ANY error, no exceptions: RPC timeout, insufficient gas, validation failure, JSON parse error, network error, capability-not-found, ABI mismatch — anything.

### STOP 2. Operations beyond the standard CLI verbs

If a user request cannot be fully expressed using the standard execute verbs (`swap`, `approve`, `lp`, `aave`) plus their read-only counterparts (`account`, `chain`, `catalog`, `defi`):

- **STOP — do not improvise.**
- **Tell the user**: "This operation is outside the standard CLI capability set. To avoid fund risk, I cannot proceed automatically."
- **Suggest a supported alternative** if one exists (e.g. "you wanted to bridge — that's not supported, but you can swap via Merchant Moe").
- **NEVER attempt the operation by any other means.** No Python. No JavaScript. No direct RPC calls. No `utils` calldata construction. No "manual" unsigned_tx assembly.
- **If the user insists**, recommend they **restart the OpenClaw agent with updated tooling** (i.e. wait for the next `mantle-cli` release that adds the capability) rather than improvising in-session.

> **Token transfers (native MNT and ERC-20) fall under this STOP condition.** `mantle-cli transfer send-native` / `transfer send-token` and the corresponding `mantle_buildTransferNative` / `mantle_buildTransferToken` MCP tools have been deliberately removed from the toolset. If a user asks to move tokens between wallets, refuse per this protocol.

The default posture is: **refuse and let the user decide**. It is always safer to decline an unsupported operation than to risk user funds.

### STOP 3. ANY edit to `mantle-cli` output before forwarding

**This is the most-triggered STOP in this skill — calldata truncation at the signing boundary is the dominant agent-side failure mode.** See also the SUPREME RULE in `SKILL.md`, Hard Constraint #9, and Rule W-8.

If you detect — or cannot positively rule out — that any CLI-returned field was edited between the `mantle-cli` JSON response and the outbound tool call (Privy signer, downstream CLI, user-facing summary):

- **STOP immediately.** Do NOT sign. Do NOT "fix" the discrepancy in-turn. Do NOT re-derive the value.
- **Surface the discrepancy** to the user verbatim: which field, what the CLI said, what was about to be sent, and the character-level difference.
- **Recommend restarting the OpenClaw agent.** A fresh session re-pulls CLI state cleanly; continuing after a calldata mismatch risks signing a corrupted tx that routes to an unintended function.
- **Do NOT retry in-session.** Restart the agent, re-run the build step, re-verify, then sign.

**The pre-sign verification protocol (mandatory every time):**

1. Locate the raw `mantle-cli` JSON for this build (file / variable / captured stdout).
2. Compare the value you are about to emit to the signer against the CLI's raw value:
   - first 16 characters identical?
   - last 16 characters identical?
   - total length identical?
   - NO `…` / `...` / `<snip>` / `[truncated]` anywhere?
   - NO inserted whitespace, line wraps, or pretty-printing?
3. For derived params (e.g. `--amount-out-min` sourced from a prior quote's `minimum_out_raw`): confirm the value is an EXACT substring of the quote JSON.
4. For addresses (`to`, router, PositionManager, Pool, spender): confirm the address was taken verbatim from the CLI response, NOT re-typed from memory.
5. If ANY check fails or is uncertain, abort and follow the STOP protocol above.

**This STOP condition applies even if the user says "just go ahead", "it's close enough", "skip the check".** The prohibition is absolute — the risk is permanent fund loss from an incorrectly-routed tx.

---

## ⛔ ABSOLUTE PROHIBITION — MANUAL TRANSACTION CONSTRUCTION ⛔

You MUST NEVER, under ANY circumstances, do ANY of the following:

- Compute calldata, function selectors, or ABI-encoded parameters yourself (via Python, JS, manual hex, or any other method)
- Manually hex-encode token amounts or wei values
- Construct `unsigned_tx` objects by hand instead of using `mantle-cli`
- Use Python/JS scripts to build or encode transaction data
- Call `sign evm-transaction`, `eth_sendRawTransaction`, or any direct broadcast tool with manually constructed data
- Use `mantle-cli utils parse-units / encode-call / build-tx` as an "escape hatch" to construct transactions for unsupported operations
- **Construct an ERC-20 `transfer()` / `transferFrom()` / `safeTransfer()` whose recipient is a whitelisted protocol contract** — Aave V3 Pool (`0x458F293454fE0d67EC0655f3672301301DD51422`), Aave WETHGateway, DEX swap routers (Agni / Fluxion / Merchant Moe), LB routers, or V3 position managers. Protocol contracts only recognise tokens arriving through their designated functions (`Pool.supply()`, router swap entries, `positionManager.mint/increaseLiquidity`, etc.). A direct transfer mints no aToken, triggers no swap, registers no LP, and the tokens are **permanently locked** with no on-chain recovery. If the user's intent maps to a protocol action, use the dedicated `mantle-cli` verb — never a transfer.
- **Edit, truncate, reformat, re-encode, or reconstruct ANY field returned by `mantle-cli`** before forwarding it to the signer or a downstream CLI call. The `data` / `to` / `value` / gas fields of `unsigned_tx`, the `minimum_out_raw` of a quote, the `router` / `spender` / `idempotency_key` — all of these are authoritative CLI output and must pass through the agent byte-for-byte. Eliding hex with `…` / `...`, re-casing, stripping `0x`, padding, renumbering, or regenerating from memory is prohibited even when the result "looks equivalent". If the full payload cannot be emitted intact in the current response, STOP and re-run the build — never sign a partial string. See Numbered Rule #18 below for the incident report and full behavior spec.
- Claim "the CLI doesn't support this operation" as justification for ANY of the above

**This prohibition has NO exceptions.** If you believe the CLI doesn't support an operation, check the catalog first (`mantle-cli catalog list/search/show`). If it truly doesn't exist, **STOP** (see STOP CONDITIONS above). Do NOT improvise.

### Every on-chain operation the CLI supports

```
mantle-cli swap wrap-mnt --amount <n> --json                                    # Wrap MNT → WMNT
mantle-cli swap unwrap-mnt --amount <n> --json                                  # Unwrap WMNT → MNT
mantle-cli approve --token <t> --spender <addr> --amount <n> --json             # ERC-20 approve
mantle-cli swap build-swap --provider <dex> --in <t> --out <t> --amount <n> --recipient <addr> --json  # DEX swap
mantle-cli lp add / remove / collect-fees ...                                   # LP operations
mantle-cli aave supply / borrow / repay / withdraw / set-collateral ...         # Aave operations
```

> **Token transfers (`transfer send-native` / `transfer send-token`) are deliberately NOT on this list** and have been removed from both `mantle-cli` and `mantle-mcp`. Refuse transfer requests per STOP CONDITION 2 — do not substitute `utils` calldata construction.

If the operation isn't on this list, refer to **STOP CONDITION 2** above.

### Real incidents

- **"Supply 150 USDC to Aave" = plain transfer → funds locked**: An agent received `"Please supply 150 USDC to Aave on Mantle."` and, because the user hadn't provided an on-behalf-of wallet address, modelled "supply to Aave" as "send 150 USDC to the Aave Pool address". It emitted a plain ERC-20 `transfer(0x458F29…, 150_000_000)` via the `utils encode-call` + `build-tx` pipeline. The tokens arrived at the Pool, **no aToken was minted, no collateral was recorded, and the 150 USDC was permanently locked** with no withdraw path. The correct flow was `mantle-cli aave supply --asset USDC --amount 150 --on-behalf-of <wallet>` — the agent should have ASKED for the wallet address rather than improvising a transfer.
- **USDC approve fund risk**: An agent bypassed `mantle-cli approve` for a USDC allowance bump, manually computed `approve(address,uint256)` calldata with Python, and produced incorrect encoding — approving the wrong amount. The CLI command would have handled this correctly.
- **15 MNT → 56.28 MNT**: Manual hex computation produced wrong amounts. A user intended to wrap/swap 15 MNT; the agent's hand-built calldata encoded 56.28 MNT instead.
- **Duplicate build calls**: A duplicated build + sign path caused 2× broadcasts of the same operation for two separate requests (0.2 MNT wrap and 0.608 MNT wrap) — wasting gas and shifting wallet state unexpectedly. Same failure mode applies to any build tool (swap, approve, LP, Aave).
- **Continuing past errors**: Agents that retried or "worked around" CLI failures left wallets in inconsistent state, leading to duplicate approvals and silent allowance drift. Restarting the agent on the first error would have avoided this.

---

## Numbered Safety Rules

0. **NEVER BUILD THE SAME TRANSACTION TWICE (CRITICAL — FUND SAFETY)**
   - Call each build command EXACTLY ONCE per user-requested action. NEVER call the same build command a second time with identical parameters to "verify" or "retry" — each built transaction may be signed and broadcast, causing **duplicate submissions and irreversible fund loss**.
   - Every build response includes an `idempotency_key` scoped to the signing wallet. ALWAYS pass `--sender <signing_wallet>` when calling build tools. If you accidentally call a builder twice and get the same key, the signer must execute only ONE.
   - If a transaction times out or you lose track of it, do NOT rebuild. Check the receipt first: `mantle-cli chain tx --hash <hash> --json`. The original may have already been mined. Rebuilding creates a new transaction with a different nonce that will ALSO execute.

1. **CLI only — never use MCP** — All operations via `mantle-cli ... --json`. Do not enable or connect to the MCP server (`mantle-mcp`).

2. **STOP on ANY `mantle-cli` error** — See STOP CONDITION 1 above. Halt, print the raw error, recommend the user restart the OpenClaw agent. Never auto-retry, never improvise around errors.

3. **STOP on operations outside the standard verbs** — See STOP CONDITION 2 above. Refuse and defer to the user. Never use `utils` escape hatch, Python, JS, or RPC workarounds.

4. **Never fabricate calldata** — Always use `mantle-cli` build commands. NEVER use Python `encode_abi`, JS `encodeFunctionData`, manual `0xa9059cbb` selectors, or any non-CLI method to produce calldata.

4a. **Never transfer tokens to a protocol contract (FUND SAFETY)** — Protocol actions are function calls, not transfers. An ERC-20 `transfer()` / `transferFrom()` / `safeTransfer()` whose recipient is the Aave V3 Pool, a DEX router, a position manager, or a WETHGateway mints no aToken, triggers no swap, registers no LP — the tokens are **permanently locked**. If the user asks to "send / deposit / supply / provide" tokens to Aave or a DEX, map the intent to the correct verb (`mantle-cli aave supply`, `mantle-cli swap build-swap`, `mantle-cli lp add`). Never construct a transfer to a protocol address, in any form (direct, via `utils`, via Python/JS, via raw calldata). If the user insists on "just sending" tokens to a protocol contract, REFUSE — this is the #1 cause of permanent fund loss in agent-driven DeFi.

5. **Never manually compute hex/wei values** — The dedicated CLI verbs handle decimal conversion. NEVER use Python, JS, or mental arithmetic to calculate `amount * 10**decimals` or hex-encode amounts. Use `mantle-cli utils parse-units` only for decimal→raw conversion of display values; never as a calldata-construction path (see ABSOLUTE PROHIBITION above).

6. **Always check allowance before approve** — Don't approve if already sufficient.

7. **Always get a quote before swap** — Use `mantle-cli defi swap-quote` to know expected output and get `minimum_out_raw` for slippage protection.

8. **`--amount-out-min` MUST equal `minimum_out_raw` from the quote, VERBATIM** — `minimum_out_raw` is already a raw integer in the output token's smallest unit (e.g. USDC 6 decimals: `9934699` = ~9.93 USDC). Do NOT multiply, divide, re-encode, or recalculate it. Do NOT set `--amount-out-min` to `0`, `1`, or any value below `minimum_out_raw`. If `build-swap` reverts, re-quote and use the new `minimum_out_raw` — NEVER lower the minimum to "make it work." A reverted swap with proper slippage protection is safe; a successful swap with `amount-out-min: 1` is exposed to sandwich attacks.

9. **Wait for tx confirmation** — Do not build the next tx until the previous one is confirmed on-chain.

10. **Show `human_summary`** — Present every build command's summary to the user before signing.

11. **Value field is hex** — The `unsigned_tx.value` is hex-encoded (e.g., `"0x0"`). Pass it directly to the signer.

12. **MNT is gas, not ERC-20** — MNT is the native gas token. To swap MNT, wrap it to WMNT first (`mantle-cli swap wrap-mnt`). Do NOT pass `"MNT"` to swap/approve/LP commands — those require WMNT. Moving MNT (or any ERC-20) between wallets is NOT a supported operation (see STOP CONDITION 2).

13. **xStocks tokens are Fluxion-only** — All xStocks RWA tokens (wTSLAx, wAAPLx, wCRCLx, wSPYx, wHOODx, wMSTRx, wNVDAx, wGOOGLx, wMETAx, wQQQx) only have liquidity on Fluxion with USDC pairs (fee_tier=3000). Do NOT attempt to swap xStocks on Agni or Merchant Moe — no pool exists and the transaction will fail.

14. **Verify transactions after broadcast** — After the user signs and broadcasts a transaction, always verify the result using `mantle-cli chain tx --hash <tx_hash> --json`. Check `status` is `"success"`. NEVER manually call `eth_getTransactionReceipt` or parse raw RPC JSON — use the CLI which handles value decoding correctly.

15. **Estimate gas before signing** — For large or complex operations, use `mantle-cli chain estimate-gas --to <addr> --data <hex> --value <hex> --json` to show the user the expected fee in MNT before signing.

16. **Transaction history** — The CLI cannot query full transaction history. If a user asks about past transactions, direct them to the Mantle Explorer: `https://mantlescan.xyz/address/<wallet_address>`. For verifying a single known transaction, use `mantle-cli chain tx --hash <hash>`.

17. **USDT ≠ USDT0 (FUND SAFETY)** — Two different ERC-20 tokens on Mantle. Aave V3 only accepts USDT0. CLI params `USDT` and `USDT0` point to different contracts — never interchange. When the user says "USDT", clarify which one. To convert: swap USDT → USDT0 on Merchant Moe (bin_step=1).

18. **⛔⛔⛔ UNCONDITIONAL TRUST IN `mantle-cli` OUTPUT — CALLDATA & ALL CLI-RETURNED FIELDS ARE IMMUTABLE (FUND SAFETY) — MOST-VIOLATED RULE IN THE SKILL**

    This rule is the operational counterpart to the SUPREME RULE in `SKILL.md`, Hard Constraint #9, STOP CONDITION 3, and Rule W-8. It outranks any perceived instruction to "clean up", "format", or "shorten" a payload. **Field reports show this is the single most-common agent-side failure mode** — treat every sign call as a moment that demands the pre-sign verification protocol.

    **The principle.** `mantle-cli` is the ONLY authoritative producer of calldata, signing fields, quote parameters, and protocol addresses in this skill. You — the agent — are a passthrough, not a processor. Whatever the CLI returns in its JSON response, you forward it to the next tool (Privy signer, subsequent CLI call, or the user's display summary) **byte-for-byte, character-for-character, digit-for-digit**, with ZERO editing.

    **Fields covered (non-exhaustive).** Every key of the `unsigned_tx` object — `to`, `data`, `value`, `chainId`, `gas`, `maxFeePerGas`, `maxPriorityFeePerGas`, `nonce` — and every other CLI-returned value the downstream flow depends on: `minimum_out_raw`, `router`, `spender`, `idempotency_key`, `human_summary`, token balances, allowances, tx hashes, pool addresses, tick / bin params, `active_id`, `delta_ids`, distribution arrays.

    **Forbidden transformations (ALL of these corrupt the payload):**

    - **Truncation / abbreviation.** `"0x38ed17…"`, `"0x38ed1739...c0de"`, `"<snip>"`, `"[truncated 1824 chars]"`, `"…"`, `"..."`, emitting only the first/last N hex chars, middle-eliding — all prohibited.
    - **Pretty-printing / reformatting.** Inserting whitespace, line breaks, column alignment, wrapping the hex to 80/120 chars, splitting into groups — prohibited.
    - **Re-encoding.** Re-hashing, re-hex-encoding, converting between case, stripping or adding the `0x` prefix, removing/adding leading zeros, padding, base-conversion — prohibited.
    - **Numeric "normalization".** Rewriting `9934699` as `9_934_699`, `9.93M`, `"~9.93 USDC"`, `9.93e6`, `0x97A6EB`, or any other "equivalent" form when that value is going to a CLI flag or signer — prohibited. Display-only summaries may format for the user, but the tool call payload keeps the exact raw integer.
    - **Reconstruction from memory.** Regenerating a `data` string, `router` address, or `minimum_out_raw` value from prior knowledge, prior sessions, or inference — prohibited even if you believe it "should" match. Only the current CLI JSON response is authoritative.
    - **"Equivalent" substitutions.** `"0x00"` → `"0x0"`, `"0x0000…0001"` → `"0x1"`, or any "it's the same number" rewrite — prohibited. The signer / downstream CLI expects the exact string the builder emitted.
    - **"Fixing" what looks wrong.** If the `data` looks short, weirdly formatted, or different from what you expected, do NOT edit it. Either rebuild via `mantle-cli` or STOP and surface the anomaly.

    **What to do when your output context threatens to clip the payload.** The correct behaviors, in order:

    1. Reference the raw JSON by file path / captured variable / stdout stream — never copy-paste if you cannot guarantee the whole string.
    2. If the full `unsigned_tx` is too long to emit in one response, emit it via a scoped tool invocation (e.g. a single JSON blob to the signing tool) rather than a human-readable message.
    3. If neither is possible, **STOP and tell the user the payload cannot be forwarded intact. Ask them to re-run the build step in a context that can carry the full string.** Do NOT sign a partial payload. Do NOT "best-effort" reconstruct.

    **Display vs. forward.** Showing a truncated form to the user for readability is acceptable ONLY if (a) the full raw string is what actually reaches the signer / next tool, and (b) the display explicitly marks the truncation:

    ```
    data (display-truncated; full value forwarded to signer): 0x38ed1739000000…c0de
    ```

    The raw string in the tool-call arguments remains untouched.

    **Mandatory pre-sign verification protocol — run EVERY time before calling the signer.** Answer all five questions; if any answer is NO or UNKNOWN, abort.

    1. Do I still have the raw `mantle-cli` JSON for this build available (file / variable / captured stdout)?
    2. Is the `data` field character-for-character identical to the CLI's `unsigned_tx.data`? (Same first 16 chars, same last 16 chars, same total length, no placeholders, no whitespace insertion.)
    3. Do `to`, `value`, `chainId`, `gas`, `maxFeePerGas`, `maxPriorityFeePerGas`, `nonce` match the CLI output exactly?
    4. For quote-derived params (e.g. `--amount-out-min` from a prior `minimum_out_raw`), is the value an EXACT substring of the quote JSON?
    5. Have I resisted the urge to "clean up", "shorten", or "normalize" any field?

    Abort conditions — follow STOP CONDITION 3 above.

    **Detection and refusal.** Before invoking the signer, compare the `data` / `to` / `value` you are about to pass against the raw CLI JSON. If they differ in any character — including stray whitespace, case flips, or a missing trailing zero — treat it as corruption: refuse to sign, surface the discrepancy verbatim, and recommend the user restart the OpenClaw agent. Same for `minimum_out_raw` feeding `--amount-out-min`: if the value you're passing is not an exact substring of the quote JSON, STOP.

    ### Real incidents (this is happening in the wild — do NOT repeat)

    - **2026-04 — Intermittent calldata truncation at the signing boundary.** Agent built a swap via `mantle-cli swap build-swap`, received a complete `unsigned_tx` with a ~1800-char `data` field, and when forwarding to the Privy signer emitted a shortened string (either `0x…` middle-eliding or a clipped tail). The signed transaction either reverted on-chain (ABI decode failure) or decoded into a different call with unintended arguments. Root cause: agent treated the calldata as a display artifact and "tidied" it before passing to the signing tool. Correct behavior: forward every character. If the calldata cannot be emitted intact, abort and re-run the build in a larger-context pass — never sign a partial payload.
    - **Middle-eliding pattern:** agent emitted `"data": "0x38ed1739000000000000000000000000…0000000000000000000000000000000000000000"` to the signer — the `…` became a literal byte in the payload. Signer rejected as invalid hex, wasted the `idempotency_key`; rebuild loop consumed two RPC quotas before the user noticed.
    - **`minimum_out_raw` reformat:** agent re-quoted, got `minimum_out_raw: 9934699`, passed `--amount-out-min 9_934_699` to `build-swap` — CLI rejected the flag → agent fell back to `--amount-out-min 1` to "make it work" → sandwich-attack exposure. Correct behavior: pass `9934699` verbatim; on CLI rejection, STOP and diagnose, never lower the minimum.
    - **Pool address retyped from memory:** agent was asked to supply to Aave, "helpfully" re-typed the Pool address from memory with a single character flipped, signed, tokens went to a non-contract address — unrecoverable. Correct behavior: copy the `to` field from the raw CLI JSON, never hand-type it.
    - **Pretty-printed `delta_ids`:** agent received `"delta_ids":[-5,-4,-3,-2,-1,0,1,2,3,4,5]` from `lp suggest-ticks`, rewrote it as `[ -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5 ]` with spaces for "readability" when passing to `lp add`. CLI rejected the malformed JSON; agent then tried to "fix" by removing brackets, producing further corruption.
    - **"Equivalent" hex substitution:** `"value": "0x0"` from CLI rewritten as `"value": "0"` (no prefix) — signer rejected as non-hex, agent reconstructed as `"0x0000000000000000"` — different field length → field encoder misalignment.

19. **Pre-sign mental checklist (practical form of Rule #18).** Before every Privy call, silently answer: *"Am I about to pass anything to the signer that I didn't copy verbatim from a `mantle-cli` JSON response in this turn?"* If yes — even once — STOP.

---

## CLI Coverage Boundary

The `mantle-cli` covers the following **verified-safe** operations:

| Category | Supported Operations |
|----------|---------------------|
| **Swaps** | Agni, Fluxion, Merchant Moe (direct + multi-hop) |
| **LP** | V3 add/remove/collect-fees (Agni, Fluxion), LB add/remove (Merchant Moe) |
| **Lending** | Aave V3 supply, borrow, repay, withdraw, set-collateral |
| **Utility** | Wrap/unwrap MNT, ERC-20 approve, tx receipt, gas estimation |
| **Read-only** | Balances, quotes, pool state, positions, prices, chain status |

> **Token transfers (native MNT and ERC-20) are NOT in this toolset** and MUST be refused. Do NOT substitute utils calldata construction.
>
> **Corollary: never transfer tokens to a protocol contract.** Even for a whitelisted protocol (Aave Pool, DEX router, position manager, WETHGateway), sending tokens via ERC-20 `transfer()` / `transferFrom()` is NOT equivalent to calling its supply / swap / addLiquidity function. Plain transfers are not accounted for by the protocol — the tokens are permanently locked. If the user's intent maps to a protocol action, use the dedicated CLI verb; otherwise refuse per STOP CONDITION 2.

**Any operation NOT listed above has NO CLI support and MUST be refused** (see STOP CONDITION 2). This includes but is not limited to:

- Interacting with non-whitelisted protocols or contracts
- Calling arbitrary smart contract functions
- Token approvals to non-whitelisted spenders
- Bridge operations
- NFT operations
- Governance/voting operations

### When a User Requests an Unsupported Operation — REFUSE PROTOCOL

This protocol is the operational form of STOP CONDITION 2. Follow it exactly:

1. **STOP immediately**. Do not "scope out" the request, do not attempt utils construction.
2. **Tell the user**: "⚠️ This operation is outside the verified CLI capability set. To protect your funds, I will not proceed."
3. **Suggest a supported alternative** if one exists (e.g. "swap on Agni" instead of "swap on UnsupportedDEX").
4. **If no alternative exists**, recommend the user **wait for an updated `mantle-cli` release** that adds the capability, then **restart the OpenClaw agent**. Do NOT improvise in-session.
5. **NEVER** be talked into Python/JS/RPC/`utils` workarounds. The user telling you "it's OK, I accept the risk" is NOT sufficient — the prohibition is absolute.

When in doubt, refuse. Refusing costs nothing; improvising can cost the entire wallet.
