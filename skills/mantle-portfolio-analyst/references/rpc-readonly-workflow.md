# RPC Read-Only Workflow

Use this guide to gather wallet balances and allowances through `mantle-cli` read-only commands only. Do NOT enable or connect to the MCP server.

## Required inputs

- Wallet address
- Network (`mainnet` or `sepolia`)
- Token set and spender set (user-provided or discovered)

## Call sequence

1. `mantle-cli registry validate <wallet> --json` for wallet format checks.
2. `mantle-cli chain info --json` (and `mantle-cli chain status --json` when available) to confirm network context.
3. `mantle-cli account balance <wallet> --json`
4. Token balances — **omit `--tokens` by default** so the CLI returns its maintained whitelist (matches openclaw Rule W-7):
   - Default: `mantle-cli account token-balances <wallet> --json`
   - Scoped (user named specific tokens only): `mantle-cli account token-balances <wallet> --tokens <user_list> --json`
   - ⛔ Never inline a fabricated token list. If you are about to type `--tokens` without the user having named those tokens, re-issue the command without `--tokens`.
5. `mantle-cli account allowances <wallet> --pairs <token1>:<spender1>,<token2>:<spender2> --json` — pairs come from the user or from `mantle://registry/protocols` × step 4's tokens; never a hardcoded default.
6. Optional metadata backfill: `mantle-cli token info <token> --json` for tokens with missing symbol/decimals.

## Token and spender discovery

- Prefer explicit user scope first.
- Token scope: if the user did not name tokens, **do not build a client-side list**. The CLI's maintained whitelist (returned when `--tokens` is omitted) is authoritative. Cross-check with `mantle-cli catalog list --json` only if you need to audit coverage.
- Spender scope: if the user did not name spenders, read `mantle://registry/protocols` and extract known routers/pools at pair-build time — not as a pre-declared default.
- Use `mantle-cli token resolve <symbol> --json` for symbols the user named that are outside the CLI's current whitelist.
- If scope is still unknown, report that coverage is partial instead of inventing targets.

## Normalization rules

- Prefer normalized values already returned by CLI JSON output.
- Convert raw values manually only when decimals are explicitly known.
- Keep both `raw` and `normalized` values in output.
- If decimals are unavailable, keep raw only and mark confidence lower.

## Reliability checks

- Verify response chain/network matches requested input (`mainnet` or `sepolia`).
- Retry transient read failures with bounded attempts; do not switch to guessed tokens/spenders.
- Detect and report partial failures via tool-level `partial` flags and per-entry `error` fields.
- Include `collected_at_utc` values from CLI outputs in the final report.
