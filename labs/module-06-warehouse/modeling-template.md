# Dimensional Modeling Design Template

Use one copy per business process.

## 1. Business process

- Name:
- Business owner:
- Primary users:
- Questions to answer:

## 2. Fact grain

> One row represents ______________________________.

- Logical business key:
- Event/effective timestamp:
- Can source send duplicates/corrections?
- Does fact row change after creation?

## 3. Dimensions

| Dimension | Natural key | Surrogate key | History rule | Role |
|---|---|---|---|---|
| | | | | |

## 4. Measures

| Measure | Definition | Additive? | Allowed aggregation | Validation |
|---|---|---|---|---|
| | | | | |

For ratios, document numerator and denominator separately.

## 5. History semantics

- Which dimension attributes need current-state only?
- Which need SCD2/history?
- Which timestamp represents effective business change?
- Which timestamp only represents ingestion/arrival?
- What version should historical facts reference?

## 6. Late-data rules

### Early-arriving fact

- Unknown key?
- Inferred member?
- Hold/retry?

### Late/backdated dimension

- How is history repaired?
- Which facts are re-evaluated?

### Late fact

- Candidate extraction strategy:
- Target idempotency strategy:

## 7. Incremental load

- Watermark/change feed:
- Source dedup key:
- Winner/sequence rule:
- `MERGE` / AUTO CDC / other:
- Delete semantics:
- Retry behavior:

## 8. Data-quality contract

At minimum:

- grain uniqueness;
- no unexpected orphan dimension keys;
- unknown-member rate threshold;
- one-current-row rule for SCD2;
- no SCD2 interval overlap;
- allowed measure ranges;
- source/target count reconciliation;
- source/target amount reconciliation;
- freshness SLA.

## 9. Bus-matrix integration

Which conformed dimensions does this process share?

| Process | Date | Customer | Plan | Tower | Geography | Other |
|---|---:|---:|---:|---:|---:|---|
| Current process | | | | | | |

## 10. Serving/performance review

- Most common filters:
- Most common grouping dimensions:
- Query profile bottleneck:
- Aggregate table/materialized view candidate:
- Optimization correctness risk:

## 11. Interview defense

In <=3 minutes explain:

1. business process;
2. grain;
3. facts/dimensions;
4. history rule;
5. incremental strategy;
6. validation;
7. one trade-off you consciously accepted.
