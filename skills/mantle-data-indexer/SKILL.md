---
name: mantle-data-indexer
description: Use when a Mantle task needs historical wallet activity, time-windowed metrics, event backfills, or protocol analytics that raw RPC cannot answer efficiently.
---

# Mantle Data Indexer

## Overview

Use GraphQL or SQL indexers to answer historical questions on Mantle with reproducible queries, clear time boundaries, and source attribution.

## Workflow

1. Normalize request:
   - objective (for example volume, swaps, user history)
   - entities (wallet, pool, token, protocol)
   - time range (absolute UTC start/end)
2. Resolve endpoint availability:
   - `mantle_querySubgraph` requires `endpoint` + `query`.
   - `mantle_queryIndexerSql` requires `endpoint` + `query`.
   - If endpoint config is missing, request it explicitly instead of guessing.
   - In E2E `endpoint-configured` scenarios, skip when `E2E_SUBGRAPH_ENDPOINT` or `E2E_SQL_ENDPOINT` is unset.
3. Select source by availability and latency target:
   - GraphQL indexer -> `mantle_querySubgraph`
   - SQL indexer -> `mantle_queryIndexerSql`
4. Build query from `references/query-templates.md`.
5. Execute with pagination and deterministic ordering.
6. Normalize units and decimals before aggregation.
7. Produce output with query provenance, tool warnings, and caveats.

## Guardrails

- Confirm chain scope is Mantle before querying.
- Use absolute timestamps and include timezone (`UTC`).
- Do not invent endpoint URLs. If missing, report blocked input and request an endpoint.
- Keep SQL read-only; avoid mutation statements.
- Do not merge datasets with mismatched granularity without labeling.
- Distinguish `no data` from `query failure`.
- Propagate tool warnings (for example `hasNextPage=true` or SQL truncation).
- If indexer lag is known or suspected, disclose it.

## Output Format

```text
Mantle Historical Data Report
- objective:
- source_type: graphql | sql
- source_endpoint:
- queried_at_utc:
- time_range_utc:
- entity_scope:

Query Summary
- dataset_or_subgraph:
- filters_applied:
- pagination_strategy:
- records_scanned:

Results
- metric_1:
- metric_2:
- sample_rows:

Quality Notes
- indexer_lag_status:
- tool_warnings:
- assumptions:
- caveats:
- confidence:
```

## References

- `references/indexer-selection-and-quality.md`
- `references/query-templates.md`
