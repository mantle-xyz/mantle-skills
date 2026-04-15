# Risk Checklist

Apply all checks before execution intent is approved.

## Input completeness

- `operation_type` present
- `chain/environment` present
- token and amount fields present
- target contract/router/pool address present

Fail if any mandatory field is missing.

## Slippage check

- Compare proposed slippage against user-defined cap.
- If no user cap exists, apply default from `risk-threshold-guidance.md`.
- Fail when cap exceeded.

## Liquidity depth check

- Estimate price impact from quote/simulation context.
- Warn on moderate impact, fail on severe impact (threshold-driven).
- If liquidity data unavailable, set warn with reduced confidence.

## Address safety check

- Verify all addresses against trusted registry/tooling.
- Flag unknown, suspicious, or blacklisted addresses.
- Fail on blacklisted/explicitly flagged addresses.

## Operation-to-contract semantic check

A legitimate address can still be misused. This check catches protocol-function calls modelled as plain ERC-20 transfers.

- Inspect the `unsigned_tx` calldata:
  - If the calldata selector is `0xa9059cbb` (ERC-20 `transfer(address,uint256)`) OR `0x23b872dd` (`transferFrom`), decode the recipient (first argument).
  - If the recipient is a known protocol contract (Aave V3 Pool, DEX router, position manager, LP pool, WETHGateway, etc.), fail with verdict `block` and message:
    > "Plain ERC-20 transfer targeting protocol contract `<label>` (`<address>`). Protocol contracts only recognise tokens received via their designated functions (for Aave: `Pool.supply()`; for swaps: the router's swap/exactInput entry). Direct transfers are not accounted for and will lock funds. Rebuild with the dedicated protocol tool (e.g. `mantle-cli aave supply`, `mantle-cli swap build-swap`)."
- If the operation type claims to be `supply`/`borrow`/`repay`/`withdraw` but the calldata selector is `transfer`/`transferFrom` instead of the expected Aave function selectors (`supply=0x617ba037`, `withdraw=0x69328dec`, `borrow=0xa415bcad`, `repay=0x573ade81`), fail with verdict `block`.
- If the target contract for an Aave intent is NOT the Aave V3 Pool (`0x458F293454fE0d67EC0655f3672301301DD51422` on Mantle mainnet), fail with verdict `block`.

## Allowance scope check

- Detect approvals broader than required for intended amount.
- Warn on broad allowances.
- Fail if operation requires new unlimited approval without user confirmation.

## Gas and deadline sanity

- Check gas estimate reasonableness versus recent baseline.
- Check transaction deadline is not stale and not excessively long.
- Warn or fail according to threshold profile.

## Finalization rule

- Any `fail` in critical categories => final verdict `block`.
- No `fail` and at least one `warn` => final verdict `warn`.
- All checks pass => final verdict `pass`.
