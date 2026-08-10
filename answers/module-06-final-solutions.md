# Module 06 Final Assessment – Suggested Solutions

> Reference solution only. Other designs are valid when grain, history, additivity, Databricks behavior and validation are correct.

## Part A – MCQ

```text
1A  2A  3A  4A  5A
6A  7A  8A  9A 10A
11A 12A 13A 14A 15A
16A 17A 18B 19A 20A
```

---

## Part B – Dimensional Design

### B1 – Billing star

**Business process:** billing transaction.

**Fact grain:** one logical billing transaction after source/business-key deduplication.

Candidate model:

```text
gold_finance.dim_date
gold_finance.dim_customer   SCD2 for segment/history requirement
gold_finance.dim_plan
gold_finance.fact_billing_transaction
```

Fact columns:

```text
transaction_id       degenerate identifier / logical key
date_key
customer_key
plan_key
transaction_ts
amount
transaction_count = 1
payment_method
transaction_type
transaction_status
```

**Keys**

```text
dim_customer.customer_id = natural/business key
dim_customer.customer_key = surrogate/version key
```

**Measures**

- `amount`: additive across billing transactions for populations where business status rule permits it.
- `transaction_count`: additive.
- average transaction value: derived from `SUM(amount) / SUM(transaction_count)` rather than summed.

**History**

Historical customer segmentation means the fact must resolve customer version valid at `transaction_ts`, not simply the current customer version.

Possible mapping condition:

```sql
b.customer_id = c.customer_id
AND b.transaction_ts >= c.effective_from
AND b.transaction_ts < COALESCE(c.effective_to, TIMESTAMP '9999-12-31 00:00:00')
```

**Validations**

1. `transaction_id` unique in Gold fact.
2. fact row count reconciles to intended Silver population.
3. successful amount reconciles to Silver successful amount.
4. max one customer SCD version matches each fact timestamp.
5. no overlapping SCD2 intervals/customer.
6. max one current SCD2 row/customer.
7. unknown-customer rate measured.
8. plan lookup success/unknown rate measured.

### B2 – Network quality

Detailed fact:

```text
fact_network_event
Grain: one deduplicated logical call-end/drop event
```

Measures:

```text
call_count = 1
drop_count = CASE WHEN event_type='call_drop' THEN 1 ELSE 0 END
duration_seconds
```

Daily fact:

```text
fact_network_daily
Grain: one tower/date

total_calls
drops
total_duration_seconds
```

Derived:

```text
drop_rate = SUM(drops) / NULLIF(SUM(total_calls),0)
```

Do not average tower percentages blindly because denominators differ.

Reconciliation:

```text
SUM(daily.total_calls) == COUNT(detail call-end/drop events)
SUM(daily.drops) == SUM(detail.drop_count)
```

### B3 – Subscription lifecycle

**Event/transaction fact**

```text
one subscription state-change event
```

Question: How many activations/cancellations occurred each day?

**Periodic snapshot**

```text
one subscription/day
```

Question: How many subscriptions were active on each day?

**Accumulating snapshot**

```text
one subscription lifecycle instance, updated with milestones
```

Question: How long from order to activation to first usage/first bill?

### B4 – Bus matrix & ARPU

Example bus matrix:

| Process | Date | Customer | Plan | Tower | Geography |
|---|---:|---:|---:|---:|---:|
| Billing | X | X | X |  | X |
| Subscription Daily | X | X | X |  | X |
| Network Daily | X |  |  | X | X |

ARPU should not raw-join transaction rows to subscription snapshot rows.

Compute independently at common grain:

```text
billing_daily(date_key, geography_key, successful_revenue)
subscriber_daily(date_key, geography_key, active_subscribers)
```

Then:

```text
ARPU = successful_revenue / active_subscribers
```

---

## Part C – History, Late Data & Incremental

### C1 – SCD2 customer

Example:

```text
customer_key 101
customer_id 1001
segment mass
effective_from 2026-01-01
effective_to   2026-08-05
is_current false

customer_key 205
customer_id 1001
segment premium
effective_from 2026-08-05
effective_to NULL
is_current true
```

Mapping:

```text
T1 2026-08-04 → 101
T2 2026-08-06 → 205
```

Current-row validation:

```sql
SELECT customer_id, COUNT(*)
FROM dim_customer
WHERE is_current
GROUP BY customer_id
HAVING COUNT(*) <> 1;
```

Overlap validation can use `LEAD(effective_from)` ordered by version start and compare the prior `effective_to` to next start.

### C2 – Early-arriving fact

For SLA <5 minutes, a common practical choice is:

```text
map to explicit unknown member (customer_key=0)
publish fact quickly
monitor unknown facts
repair surrogate key after dimension arrives
```

An inferred member is also valid if source identity is trustworthy and the organization prefers creating a minimal customer dimension row immediately.

Holding the fact can preserve fully resolved dimensional integrity but may violate freshness SLA.

### C3 – Backdated change

If change arrives Aug 10 but is effective Aug 7, using Aug 10 as historical boundary rewrites Aug 7–9 incorrectly.

Repair:

1. close prior version at Aug 7;
2. insert/correct new version effective Aug 7;
3. validate non-overlap/current row;
4. re-evaluate fact rows for that customer from Aug 7 onward until next effective version boundary;
5. update their surrogate-key mapping if necessary;
6. reconcile metrics before/after repair.

### C4 – Databricks incremental flow

Typical design:

```text
Bronze/Silver changes
       ↓
pre-dedup by business key + valid sequence
       ↓
Dimension processing
  MERGE for simple SCD1/current state
  AUTO CDC for supported CDC/SCD1/SCD2 flows
       ↓
validate dimension history
       ↓
map facts to surrogate keys
       ↓
MERGE fact by logical transaction key
       ↓
reconciliation + quality gate
```

Retry should converge to the same logical target. Plain append is unsafe for rerunning the same logical fact batch.

Delete handling is business-specific: a source delete may close a dimension version, mark inactive, preserve history, or remove only current-state representation depending analytical requirements.

---

## Part D – Databricks Serving

### D1 – Medallion placement

```text
raw CDC                       → Bronze
clean integrated history      → Silver
fact_billing_transaction      → Gold Finance
dim_customer                  → Gold Finance/shared Gold dimension
monthly revenue aggregate     → Gold serving aggregate
```

A clean integrated Silver warehouse can also contain normalized/core structures that feed multiple Gold marts.

### D2 – Gold quality gate

Any ten well-justified checks earn full credit. Strong set:

1. fact logical key uniqueness;
2. valid grain/cardinality check;
3. dimension current-row uniqueness;
4. SCD interval overlap check;
5. source→Gold fact row-count reconciliation;
6. source→Gold revenue reconciliation;
7. orphan/unknown customer rate;
8. unknown plan rate;
9. negative/invalid amount rule;
10. date-key coverage;
11. freshness SLA;
12. late-data repair backlog;
13. duplicate source-key change feed check;
14. valid status/domain checks.

### D3 – Oral defense rubric

A strong answer follows this order:

```text
business processes
→ fact grains
→ shared/conformed dimensions
→ history semantics
→ late-data policy
→ Silver integration
→ Gold marts
→ incremental strategy
→ quality/reconciliation
→ serving/performance trade-off
```

Do not start the defense with tool names.

---

# Strong-answer checklist

A strong candidate can explain all of these without notes:

- why billing transaction and subscription daily snapshot are different facts;
- why customer 1001 can map to multiple surrogate keys across time;
- why average of drop rates can be wrong;
- why raw fact-to-fact joins fan out;
- why SCD2 effective time differs from ingestion time;
- why `MERGE` needs unique/well-defined source semantics;
- how AUTO CDC reduces procedural work but does not invent business keys/sequence truth;
- why Silver and Gold are refinement/serving responsibilities, not synonyms for 3NF/star in every architecture.
