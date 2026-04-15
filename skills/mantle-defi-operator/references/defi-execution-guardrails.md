# DeFi Pre-Execution Guardrails

Apply these controls before any potential state-changing DeFi action.

## Tool discovery via Capability Catalog

- Read `mantle://registry/capabilities` to discover available tools before constructing any plan.
- Use `category` to filter: `query` for reads, `analyze` for insights, `execute` for transaction building.
- Use `auth` to check wallet requirements: `required` tools need a wallet address, `none` tools don't.
- Use `workflow_before` to understand call ordering (e.g., `getSwapQuote` before `buildSwap`).
- For simple read-only tasks (query/analyze), the Capability Catalog is sufficient — no skill loading needed.
- For execution planning, continue with the guardrails below.

## Capability boundary (CLI-only)

- All on-chain operations use `mantle-cli` commands with `--json`. Do NOT enable or connect to the MCP server.
- The CLI is read-focused for queries and builds unsigned transactions for writes — it does not sign, broadcast, deploy, or execute transactions.
- This skill must stop at analysis + plan generation.
- Never fabricate tx hashes, receipts, or settlement outcomes.

## ⛔ ABSOLUTE PROHIBITION — No manual transaction construction

**NEVER**, under any circumstances:
- Compute calldata, function selectors, or ABI-encoded parameters (via Python `encode_abi`, JS `encodeFunctionData`, manual `0xa9059cbb` selectors, or ANY other method)
- Manually hex-encode token amounts or wei values
- Construct `unsigned_tx` JSON objects by hand
- Use Python/JS scripts to build transaction data
- Call `sign evm-transaction` or `eth_sendRawTransaction` with hand-crafted data
- Reason that "the CLI doesn't support this" to justify manual construction — check the catalog first

**The CLI supports these operations — token transfers are NOT among them:**
```bash
mantle-cli swap build-swap ...                                         # DEX swap
mantle-cli approve ...                                            # ERC-20 approve
mantle-cli swap wrap-mnt / unwrap-mnt ...                              # Wrap/unwrap
mantle-cli lp add / remove / collect-fees ...                          # LP
mantle-cli aave supply / borrow / repay / withdraw / set-collateral ...  # Aave
```

> **Transfers are deliberately out of scope.** `mantle-cli` has no `transfer` command and `mantle-mcp` exposes no `mantle_buildTransferNative` / `mantle_buildTransferToken` tools. If a user asks to move tokens between wallets, REFUSE and state that transfers are not supported.

**Real incident**: Agent claimed `mantle-cli` didn't support ERC-20 approve and manually computed `approve(address,uint256)` calldata with Python for a USDC allowance bump, bypassing all safety checks. This was FALSE — `mantle-cli approve --token USDC --spender <router> --amount <n>` handles all whitelisted-spender approvals with deterministic decimal conversion.

If a truly unsupported operation is needed, use the safe encoding utilities instead of Python/JS:
```bash
mantle-cli utils parse-units --amount <decimal> --decimals <n> --json   # Step 1: Decimal → raw/wei
mantle-cli utils encode-call --abi '<sig>' --function <name> --args '<json>' --json  # Step 2: ABI-encode → calldata
mantle-cli utils build-tx --to <addr> --data <hex> [--value <mnt>] --json  # Step 3: Calldata → unsigned_tx
```
The `build-tx` output includes `⚠ UNVERIFIED MANUAL CONSTRUCTION` warning. Mark the resulting transaction as **UNVERIFIED** in the handoff.

## Coordination boundary

- Use this skill to assemble a final plan, not to replace specialized address, risk, or portfolio skills.
- Route address trust to `mantle-address-registry-navigator`.
- Route pass/warn/block verdicts to `$mantle-risk-evaluator`.
- Route allowance and balance evidence to `$mantle-portfolio-analyst` when approval scope or wallet coverage matters.

## Address trust

- Resolve execution-ready token/router/pool/position-manager addresses from the shared `mantle-address-registry-navigator` registry.
- Mark the plan as blocked for unverified or malformed addresses.
- Mention the selected registry key in the final handoff.
- Discovery-only protocols may be mentioned for comparison, but they are not execution targets until their contracts are verified.
- Live metrics may influence ranking, but they never establish address trust.

## Intent completeness

- Ensure operation type, token amounts, recipient, slippage cap, and deadline are present.
- Mark the plan as blocked if any mandatory field is missing.

## Risk coupling

- Require latest preflight verdict from `$mantle-risk-evaluator` when available.
- For `warn`/`high-risk` outcomes, require explicit user confirmation.
- For `block` outcomes, do not produce an execution-ready plan.

## Allowance controls

- Prefer minimal required approval over unlimited approval.
- Use `$mantle-portfolio-analyst` when allowance scope, spender exposure, or balance coverage needs read-only evidence.
- If unlimited approval is requested, require explicit user acknowledgement.
- Include an explicit allowance re-check in the external execution checklist.

## Execution handoff integrity

- Use deterministic route and calldata inputs from selected quote/liquidity context.
- Record required call sequence and parameter values for the external executor.
- Define post-execution reconciliation checks (balances/allowances/slippage) to run after user-confirmed execution.

## Transaction deduplication (CRITICAL)

Every build-tool response includes an `idempotency_key` — a deterministic keccak256 hash scoped to the signing wallet. The key includes `sender` (wallet address), `request_id` (caller-provided intent ID), and `unsigned_tx` fields (to, data, value, chainId).

**Scoping rules:**
- **Same wallet, same calldata** → same key → deduplicated ✓
- **Different wallets, same calldata** → different keys → both can execute ✓
- **Same wallet, same calldata, different request_id** → different keys → both can execute ✓

**Rules for the agent:**
1. Call each build tool EXACTLY ONCE per user intent. Do not "retry" or "verify" by calling again.
2. ALWAYS pass `sender=<signing_wallet_address>` when calling build tools.
3. If the same user explicitly requests two separate identical build calls (e.g., two sequential approvals with the same spender/amount), pass a distinct `request_id` for each.
4. If you accidentally call a builder twice, compare `idempotency_key` values. If they match, discard the duplicate.

**Rules for the external signer / executor:**
1. Before signing, check if this `idempotency_key` was already signed within the last 5 minutes.
2. If yes, REJECT the duplicate — return the original transaction hash instead.
3. After broadcast, store `(idempotency_key → tx_hash)` for deduplication lookups.
4. If `idempotency_scope.sender` is `"unscoped"`, inject the signing wallet address into the key before deduplication.

**Rules for retry after timeout:**
1. NEVER rebuild the transaction on timeout. The original may have already been mined.
2. Instead: use `mantle-cli chain tx --hash <original_hash>` to check receipt.
3. Only rebuild if the original hash is confirmed as dropped (not in any block and not in mempool).

## CLI coverage boundary

The `mantle-cli` covers verified-safe operations (swaps on whitelisted DEXes, Aave V3, V3/LB LP, ERC-20 approve, WMNT wrap/unwrap) PLUS general-purpose encoding utilities. Token transfers (native MNT and ERC-20) are deliberately excluded. If the requested operation has no corresponding dedicated CLI command:

1. **Do NOT use Python/JS/manual hex.** Use the CLI utils pipeline instead:
   - `mantle-cli utils parse-units` — convert decimal amounts to raw integers
   - `mantle-cli utils encode-call` — ABI-encode the function call
   - `mantle-cli utils build-tx` — wrap calldata into a validated unsigned_tx
2. **Warn the user** that the resulting transaction is `UNVERIFIED` — it was not built by a dedicated, protocol-specific CLI command.
3. **Require explicit user confirmation** before signing the `⚠ UNVERIFIED` unsigned_tx.
4. **When in doubt, mark the plan as `blocked`** rather than risk user funds.
