---
name: mantle-defi-operator
version: 0.1.17
description: "Use when a Mantle DeFi task needs discovery, venue comparison, or execution-ready planning with verified contracts, preflight evidence, and an external handoff."
---

# Mantle Defi Operator

## Overview

Coordinate deterministic pre-execution planning for Mantle DeFi intents. This skill should orchestrate verified address lookup, preflight evidence, and execution handoff steps instead of duplicating specialized address, risk, or portfolio analysis.

## CLI-First Transaction Building

**ALWAYS use `mantle-cli` commands to build unsigned transactions.** The CLI produces correct calldata with verified addresses and ABI encoding. Do NOT:
- Manually construct calldata or hex-encode function calls
- Extract contract addresses from text responses and build transactions yourself
- Add a `from` field to unsigned transactions — this breaks Privy and other signers

### Tool Discovery via Capability Catalog

Before building any transaction, consult the **Capability Catalog** via CLI for the authoritative list of available tools, their read/write nature, wallet requirements, and call ordering:

```bash
mantle-cli catalog list --json                    # all capabilities
mantle-cli catalog list --category execute --json  # only tx-building commands
mantle-cli catalog search "swap" --json            # keyword search
mantle-cli catalog show mantle_buildSwap --json    # full details + CLI command template
```

Each entry includes:
- `category: query` — read-only, no state change, no wallet needed for most
- `category: analyze` — computed insights (APR, risk, recommendations), read-only
- `category: execute` — builds unsigned transactions, requires wallet address
- `workflow_before` — tells you which tools to call before a given tool
- `cli_command` — the exact CLI command template with placeholders

### Available CLI commands for DeFi operations:

```bash
# Swap operations
mantle-cli swap build-swap --provider <dex> --in <token> --out <token> --amount <n> --recipient <addr> --json
mantle-cli approve --token <token> --spender <router> --amount <n> --json
mantle-cli swap wrap-mnt --amount <n> --json
mantle-cli swap unwrap-mnt --amount <n> --json
mantle-cli swap pairs --json

# Aave V3 lending
mantle-cli aave supply --asset <token> --amount <n> --on-behalf-of <addr> --json
mantle-cli aave set-collateral --asset <token> [--user <addr>] [--disable] --json  # enable/disable collateral + diagnostics
mantle-cli aave borrow --asset <token> --amount <n> --on-behalf-of <addr> --json
mantle-cli aave repay --asset <token> --amount <n|max> --on-behalf-of <addr> --json
mantle-cli aave withdraw --asset <token> --amount <n|max> --to <addr> --json
mantle-cli aave positions --user <addr> --json   # positions + per-reserve collateral_enabled
mantle-cli aave markets --json

# Liquidity provision
mantle-cli lp top-pools [--sort-by volume|apr|tvl] [--limit <n>] [--provider <dex>] [--min-tvl <usd>] --json  # BEST STARTING POINT — discover top LP opportunities across ALL DEXes, no token pair needed
mantle-cli lp find-pools --token-a <t> --token-b <t> --json           # Discover all pools for a SPECIFIC token pair
mantle-cli lp pool-state <pool-or-tokens> --json
mantle-cli lp suggest-ticks <pool-or-tokens> --json
mantle-cli lp analyze <pool-or-tokens> [--investment-usd <n>] --json  # Deep pool analysis: APR, risk, range comparison
mantle-cli lp positions --owner <addr> --json
mantle-cli lp add --provider <dex> --token-a <t> --token-b <t> (--amount-a <n> --amount-b <n> | --amount-usd <n>) --recipient <addr> --json
mantle-cli lp remove --provider <dex> --recipient <addr> --token-id <id> (--liquidity <n> | --percentage <1-100>) --json
mantle-cli lp collect-fees --provider <p> --token-id <id> --recipient <addr> --json

# Read operations (no signing needed)
mantle-cli defi swap-quote --in <token> --out <token> --amount <n> --provider best --json
mantle-cli defi lending-markets --json
mantle-cli account balance <addr> --tokens USDC,USDT0 --json
```

All `--json` build outputs contain TWO views of the transaction:
- `unsigned_tx` — signer-agnostic view (chainId/nonce as integers, no `from`). Use for logging, diffing, and non-Privy signers (viem, ethers).
- `signable_tx` — Privy-ready view (chainId/nonce/value as hex strings, `from` pre-filled). Pass this verbatim to Privy's `sign evm-transaction --transaction` parameter (e.g. `jq -c .signable_tx <file>`).

**Pick the right object for your signer; never hand-convert between them.** If `signable_tx` is missing (older CLI), STOP — do not manually transform `unsigned_tx`.

## When Not to Use

- Use `mantle-address-registry-navigator` when the task is only address lookup, whitelist validation, or anti-phishing review.
- Use `$mantle-risk-evaluator` when the task is only to return a `pass` / `warn` / `block` preflight verdict.
- Use `$mantle-portfolio-analyst` when the task is only balance coverage, allowance exposure, or spender-risk review.
- Stay in `discovery_only` mode when the user is exploring venues and has not asked for execution-ready planning.

## Quick Checklist

- `discovery_only`
  - Return venue suggestions, rationale, and discovery sources only.
  - Do not return router addresses, hex contract addresses (0x...), approval steps, calldata, or sequencing anywhere in the response.
  - Set `handoff_available` to `no`.
- `compare_only`
  - Compare verified venues and call out missing execution inputs.
  - Allow verified registry keys or contract roles (by name, not hex address), but stop short of approval instructions or calldata.
  - Do not include hex contract addresses (0x...) anywhere in the response -- not in rationale, not in fields. Use protocol and role names only.
  - Leave `risk_report_ref` / `portfolio_report_ref` empty or explicitly missing when evidence is not available.
  - Set `handoff_available` to `no`.
- `execution_ready`
  - Require `address_resolution_ref`.
  - Require `risk_report_ref` unless explicitly unnecessary for the operation.
  - Require `portfolio_report_ref` when allowance scope or balance coverage matters, or explain why it is unnecessary.
  - Only then expose approval planning, sequencing, calldata, and `handoff_available: yes`.

## Workflow

1. Normalize intent:
   - `swap`, `add_liquidity`, `remove_liquidity`, `supply`, `borrow`, `repay`, `withdraw`, `set_collateral`, or compound flow
   - For Aave lending intents (supply/borrow/repay/withdraw), NEVER rewrite the intent as "send tokens to the Aave Pool" — that is a different, unsafe operation. See `references/lending-sop.md` ("supply is NOT a token transfer").
   - token addresses, amounts, recipient, deadline, slippage
2. Run prep checks from `references/defi-execution-guardrails.md`.
3. Resolve candidate protocol contracts from `mantle-address-registry-navigator` using the required registry key or protocol role for the requested action.
4. Classify the planning mode:
   - `execution_ready`: verified addresses plus enough quote/risk evidence to produce a handoff
   - `compare_only`: venue comparison is possible, but execution gating is incomplete; also use this mode when the user names an unverified protocol -- list it under `discovery_only` in Protocol Selection, set `readiness: blocked`, and recommend verified curated alternatives
   - `discovery_only`: high-level ecosystem exploration without execution readiness (no specific venue comparison requested)
5. Build the candidate set from `references/curated-defaults.yaml`; carry forward each default's freshness metadata and rationale, and if the user names another protocol, keep it `compare_only` until its contracts are verified.
6. Rank only eligible candidates with live signals from `references/protocol-selection-policy.md`:
   - swaps: quote quality, recent volume, pool depth, slippage risk
   - liquidity: TVL, recent volume, pool fit, operational complexity
   - lending: TVL, utilization, asset support, withdrawal liquidity
   - if live metrics are stale or unavailable, fall back to curated defaults and say so explicitly
   - if only one curated, verified candidate fits the requested action, recommend it first before asking optimization follow-ups
7. Pull supporting evidence before execution planning:
   - address trust from `mantle-address-registry-navigator`
   - preflight verdict from `$mantle-risk-evaluator` when a state-changing path is being prepared
   - allowance and spend-capacity context from `$mantle-portfolio-analyst` when approval scope or wallet coverage matters
8. Structure the result per `planning_mode` using the `Quick Checklist`:
   - `recommended`
   - `also_viable`
   - `discovery_only`
   - mention `DefiLlama` only for broader ecosystem discovery, never as contract truth
9. Load operation SOP only for `execution_ready` planning:
   - swap: `references/swap-sop.md`
   - liquidity: `references/liquidity-sop.md`
   - lending (supply/borrow/repay/withdraw): `references/lending-sop.md`
10. Resolve quote, pool, or market route only after the protocol choice is gated by verified contracts and supporting evidence.
11. If an approval is required, carry forward the allowance evidence and prepare the smallest viable `approve` step.
12. If account supports batching (for example ERC-4337 smart account), note whether approve+action can be safely batched by the external executor.
13. Produce an execution handoff plan (calls, parameters, sequencing, and risk notes). Do not sign, broadcast, deploy, or claim execution.
14. Define post-execution verification checks (balances, allowances, slippage) to run after the user confirms external execution.

## Guardrails

**⛔ ABSOLUTE PROHIBITION — MANUAL TRANSACTION CONSTRUCTION ⛔**

You MUST NEVER, under ANY circumstances, do ANY of the following:
- Compute calldata, function selectors, or ABI-encoded parameters yourself (via Python, JS, manual hex, or any other method)
- Manually hex-encode token amounts or wei values
- Construct `unsigned_tx` or `signable_tx` objects by hand instead of using `mantle-cli`
- Hand-convert `unsigned_tx` fields into `signable_tx` shape (chainId/nonce int→hex, appending `from`) — always use the `signable_tx` object the CLI already emitted
- Use Python/JS scripts to build or encode transaction data
- Call `sign evm-transaction`, `eth_sendRawTransaction`, or any direct broadcast tool with manually constructed data
- Claim "the CLI doesn't support this operation" as justification for manual construction

**This prohibition has NO exceptions.** If you believe the CLI doesn't support an operation, you are WRONG — check the catalog first (`mantle-cli catalog list --json`). If the operation truly doesn't exist in the catalog, use the safe encoding utilities (`mantle-cli utils encode-call`, `mantle-cli utils parse-units`). Do NOT use Python/JS.

**Token transfers are NOT supported by this skill.** `mantle-cli` and `mantle-mcp` have NO transfer commands — `transfer send-native` / `transfer send-token` / `mantle_buildTransferNative` / `mantle_buildTransferToken` have been deliberately removed. If a user asks to move tokens between wallets, REFUSE and tell them transfers are out of scope for this skill.

**Safe encoding utilities (ESCAPE HATCH for truly unsupported operations):**
```
mantle-cli utils parse-units --amount <decimal> --decimals <n> --json   # Step 1: Decimal → raw/wei
mantle-cli utils encode-call --abi '<sig>' --function <name> --args '<json>' --json  # Step 2: ABI-encode → calldata
mantle-cli utils build-tx --to <addr> --data <hex> [--value <mnt>] --json  # Step 3: Calldata → unsigned_tx
```

**Real incident**: Agent bypassed `mantle-cli approve` for a USDC allowance, manually computed `approve(address,uint256)` calldata with Python, and produced incorrect encoding. The CLI command would have handled this correctly and safely.

---

- **DUPLICATE TRANSACTION PREVENTION (CRITICAL)**:
  - **ONE BUILD CALL PER INTENT**: For each user-requested action (swap, LP, approve, etc.), call the corresponding build tool EXACTLY ONCE. NEVER call the same build tool a second time with the same or similar parameters for the same user request. If you already obtained an `unsigned_tx`, use that result — do not "verify" or "retry" by calling the builder again.
  - **IDEMPOTENCY KEY**: Every build-tool response includes an `idempotency_key` (deterministic hash scoped to the signing wallet). ALWAYS pass `sender=<signing_wallet_address>` when calling build tools — this ensures different wallets can independently execute identical payloads without false deduplication. If you accidentally call a builder twice from the same wallet and get the same `idempotency_key`, the external signer MUST execute only ONE of them.
  - **NO SPECULATIVE BUILDS**: Do NOT build transactions "to see what they look like" and then build them again for real. Each build call may result in execution.
  - **WAIT BEFORE NEXT STEP**: After a transaction is signed and broadcast, ALWAYS verify its receipt (`mantle-cli chain tx --hash <hash>`) before proceeding to the next step. NEVER submit the next transaction until the previous one is confirmed on-chain.
  - **TIMEOUT ≠ FAILURE**: If a transaction submission times out or you lose track of it, do NOT rebuild and resubmit. Instead, check the wallet's recent transactions or use the transaction hash to verify status. Rebuilding creates a NEW transaction with a different nonce that will ALSO execute, causing duplicate submissions.
- **CLI-FIRST RULE**: ALWAYS use `mantle-cli` commands with `--json` to build unsigned transactions. For standard operations (swap, LP, Aave, approve), use the dedicated commands. For unsupported operations, use the utils pipeline: `utils parse-units` → `utils encode-call` → `utils build-tx`. NEVER use Python/JS/manual hex to construct calldata.
- **NO MANUAL HEX/WEI CONSTRUCTION**: NEVER manually compute wei values, hex-encode amounts, or use Python/JS to calculate `amount * 10**decimals`. Use `mantle-cli utils parse-units` for decimal→raw conversion. The CLI uses `parseUnits()` for deterministic decimal-to-wei conversion.
- **`from` FIELD HANDLING**: Never add `from` to `unsigned_tx`. For Privy, do NOT manually append `from` to `unsigned_tx` — instead use the `signable_tx` object the CLI already emits (it has `from` pre-filled plus hex-encoded chainId/nonce). Hand-appending `from` + int→hex conversion was the exact failure mode `signable_tx` was introduced to replace.
- **NO MANUAL ROUTING**: NEVER manually discover intermediate pools, split multi-hop swaps into separate transactions, or use external aggregators/routing services. The CLI auto-discovers 2-hop routes via bridge tokens (WMNT, USDC, USDT0, USDT, USDe, WETH) when no direct pair exists. Just pass `--in` and `--out` — the CLI handles the routing.
- **USDT vs USDT0**: Mantle has two official USDT variants — USDT (bridged Tether, `0x201E...`) and USDT0 (LayerZero OFT, `0x779D...`). Both have deep DEX liquidity. **Only USDT0 works on Aave V3.** If a user holds USDT and wants to use Aave, guide them to swap USDT → USDT0 first via Merchant Moe (USDT/USDT0 pool, bin_step=1).
- **FACTORY-FIRST POOL DISCOVERY**: When looking for LP pools for a specific token pair, use `mantle-cli lp find-pools --json` which queries factory contracts on-chain. When the user asks for the BEST pools or LP recommendations WITHOUT specifying tokens, use `mantle-cli lp top-pools --json` first to discover top opportunities by volume/APR/TVL across ALL DEXes (including meme tokens, xStocks, and newly launched pools).
- **ANALYZE BEFORE LP**: Before adding liquidity, ALWAYS run `mantle-cli defi analyze-pool --json` to get fee APR, multi-range comparison, risk scoring, and investment projections. Do NOT add liquidity based on guesswork about which range or how much to invest.
- **USD AMOUNT MODE**: When the user specifies an investment in USD (e.g. "invest $1000"), use `--amount-usd` instead of manually computing token amounts. The CLI reads pool state and computes the correct token ratio for the target tick range. Do NOT blindly split 50/50.
- **PERCENTAGE REMOVAL**: When the user wants to remove a fraction of a V3 position (e.g. "remove half"), use `--percentage 50` instead of manually reading and computing liquidity amounts. The CLI reads the position on-chain and calculates the exact liquidity to remove.
- **WETH EXISTS ON MANTLE**: WETH (bridged ETH) is at `0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111` with ~125K ETH supply and pools on all DEXes. Do NOT claim WETH doesn't exist. MNT being the gas token does not mean ETH is absent — ETH is bridged from L1.
- NEVER claim to have signed, broadcast, deployed, or executed any transaction. Do not use phrases like "I executed the swap", "the transaction was submitted", "swap complete", or "funds have been transferred." This skill produces plans only; an external signer/wallet must execute them.
- Act as a coordinator: when specialized address, risk, or portfolio skills apply, cite or request their output instead of re-deriving those judgments from scratch.
- In `discovery_only`, do not provide router addresses, approval steps, calldata, or execution sequencing.
- In `compare_only`, verified registry keys or contract roles may be named, but executable calldata and approval instructions stay out until execution evidence is complete.
- Do not proceed to external execution planning on `warn`/`high-risk` intents without explicit user confirmation.
- Reject unknown or unverified token/router/pool addresses.
- Never treat discovery data as a substitute for a verified registry key.
- If the required contract role cannot be resolved from the shared registry, mark the plan `blocked`.
- Mention discovery-only protocols only after clearly separating them from execution-ready options.
- Keep per-step idempotency notes for external retries.
- If the user asks for onchain execution, provide a handoff checklist and state that an external signer/wallet is required.

## Output Format

**MANDATORY:** Every response MUST use this exact structured template. Do not use prose or free-form text instead of this template. Fill every field; use "not applicable in {planning_mode} mode" for fields that do not apply to the current mode. In `discovery_only` mode, fields under Execution Handoff and Post-Execution Verification Plan must all say "not applicable in discovery_only mode."

```text
Mantle DeFi Pre-Execution Report
- operation_type:
- planning_mode: discovery_only | compare_only | execution_ready
- environment:
- intent_summary:
- analyzed_at_utc:

Preparation
- supporting_skills_used:
- address_resolution_ref:
- risk_report_ref:
- portfolio_report_ref:
- curated_defaults_considered:
- quote_source:
- expected_output_min:
- allowance_status:
- approval_plan:

Protocol Selection
- recommended:
- also_viable:
- discovery_only:
- rationale:
- data_freshness:
- confidence: high | medium | low

Execution Handoff
- recommended_calls:
- calldata_inputs:
- registry_key:
- sequencing_notes:
- batched_execution_possible: yes | no
- handoff_available: yes | no

Post-Execution Verification Plan
- balances_to_recheck:
- allowances_to_recheck:
- slippage_checks:
- anomalies_to_watch:

Status
- preflight_verdict: pass | warn | block | unknown
- readiness: ready | blocked | needs_input
- blocking_issues:
- next_action:
```

## References

- `references/defi-execution-guardrails.md`
- `references/swap-sop.md`
- `references/liquidity-sop.md`
- `references/lending-sop.md`
- `references/curated-defaults.yaml`
- `references/protocol-selection-policy.md`
