# Lesson 07 – Incremental Dimension & Fact Loading on Databricks

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- thiết kế incremental load cho dimensions/facts từ Silver → Gold;
- phân biệt current-state merge với historical SCD2 processing;
- pre-deduplicate source trước `MERGE` khi business key không unique;
- liên hệ Databricks `MERGE` với AUTO CDC/SCD Type 1/2;
- xử lý deletes, late updates và out-of-order changes;
- map fact vào surrogate key đúng version;
- thiết kế idempotency/reconciliation cho rerun.

## 2. Source alignment

### Primary Databricks sources

- Delta `MERGE`: https://docs.databricks.com/aws/en/delta/merge
- ETL in Databricks SQL: https://docs.databricks.com/aws/en/sql/get-started/sql-etl-tutorial
- AUTO CDC / Spark Declarative Pipelines tutorial: https://docs.databricks.com/aws/en/ldp/tutorial-pipelines
- Lakeflow Connect SCD history tracking: https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/scd

### Databricks semantics

Databricks supports Delta upserts with `MERGE`. For CDC streams, Databricks recommends declarative AUTO CDC patterns where possible because sequencing, deletes and out-of-order events are difficult to implement correctly with hand-written procedural merges.

### Scope note

Surrogate-key assignment, point-in-time fact mapping and dimensional reconciliation remain modeling responsibilities even when CDC application is managed declaratively.

## 3. Principles

### Principle 1 – Incremental dimensional loading is state management

The pipeline must know:

```text
what changed?
which business key?
what sequence/effective time?
what target version exists?
what happens on retry?
```

### Principle 2 – A MERGE condition is not a dedup contract

If source contains multiple candidate rows for one target business key, decide the winner before merging.

Do not expect `MERGE` to infer business ordering.

### Principle 3 – Fact loading depends on dimensions

A fact row with natural keys usually must resolve:

```text
customer_id → customer_key valid at fact time
plan_id     → plan_key valid at fact time
```

Therefore dimension availability/history affects fact correctness.

### Principle 4 – Rerun must converge to the same logical result

A failed/retried load must not create duplicate facts or duplicate current dimension versions.

## 4. Fundamentals

### 4.1 SCD1-style current dimension merge

Concept:

```sql
MERGE INTO gold.dim_plan t
USING staged_plan s
ON t.plan_id = s.plan_id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;
```

Exact production syntax should select explicit columns rather than treating `*` as a semantic contract.

This implements current-state overwrite behavior, not historical Type 2 by itself.

### 4.2 Pre-dedup source

If staging has repeated plan/customer updates:

```sql
SELECT *
FROM staged_customer
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY sequence_ts DESC, ingestion_ts DESC
) = 1;
```

Winner ordering must come from the data contract.

### 4.3 SCD2 state transitions

For a changed business key:

1. determine whether tracked attributes changed;
2. expire current version;
3. create new version;
4. maintain one-current-row invariant;
5. retain non-overlapping intervals.

AUTO CDC can manage this declaratively when the source change feed and sequencing semantics fit supported patterns.

### 4.4 Fact load

Silver fact source:

```text
transaction_id
customer_id
plan_id
transaction_ts
amount
```

Gold fact needs surrogate keys:

```text
transaction_id
date_key
customer_key
plan_key
amount
transaction_count
```

Point-in-time customer lookup:

```text
customer_id match
transaction_ts in [effective_from, effective_to)
```

### 4.5 Unknown key handling

If lookup fails:

```text
customer_key = 0
```

plus observability:

```text
unknown_customer_fact_count
unknown_customer_amount
```

A silent unknown rate is a quality defect.

### 4.6 Idempotent fact loading

For transaction fact where `transaction_id` is unique logical key:

Strategies:

- Delta `MERGE` by transaction id;
- replace bounded partition deterministically;
- declarative incremental target with unique business semantics.

Plain append on retry can duplicate rows.

### 4.7 Deletes

Dimension source delete can mean:

- mark current member inactive;
- close SCD2 version;
- preserve historical rows;
- physically remove current-state row.

The correct action is business-specific. CDC delete signal does not automatically define analytical deletion semantics.

### 4.8 Late/out-of-order changes

A valid sequence column lets AUTO CDC order changes by business/source sequence rather than arrival order.

But if source emits incorrect sequence/effective timestamps, downstream automation cannot recover true history by magic.

## 5. Worked example – Incremental customer + billing load

New customer changes:

```text
1001 segment mass → premium effective Aug 5
9999 new customer
```

New transactions:

```text
T500 customer 1001 Aug 6
T501 customer 9999 Aug 6
```

Pipeline reasoning:

```text
1. apply customer changes
2. validate current/history dimension
3. resolve transaction-time customer version
4. map surrogate keys
5. merge facts by transaction_id
6. reconcile counts/amounts
```

If fact T501 arrives before customer 9999 dimension member, use the chosen unknown/inferred strategy and schedule repair.

## 6. Hands-on lab

### Part A – Dedup staging

Create `stg_customer_changes` with multiple rows/customer and write deterministic winner query.

### Part B – SCD1 plan load

Use `MERGE` to update/insert current `dim_plan`.

### Part C – SCD2 customer flow

Either:

- implement explicit educational SQL; or
- use AUTO CDC in a supported Databricks pipeline.

Document:

```text
KEYS
SEQUENCE BY
DELETE semantics
tracked columns
SCD type
```

### Part D – Fact load

Build `fact_billing_transaction` and map:

```text
transaction date
customer version
plan version/current rule
```

### Part E – Retry test

Run the same logical batch twice.

Expected:

```text
fact business row count unchanged
no extra current dimension versions
revenue unchanged
```

### Part F – Late fact repair

Insert transaction with event time before current load window. Explain how candidate extraction and target merge catch it.

## 7. Knowledge check – MCQ

**Q1.** `MERGE` alone defines which duplicate source row wins?  
A. yes; B. no; C. only for SCD2; D. only with PK.

**Q2.** AUTO CDC requires meaningful:  
A. keys and sequence semantics; B. dashboard layout; C. Python virtualenv; D. B-tree index.

**Q3.** Fact SCD2 mapping should usually use:  
A. dimension version valid at fact event time; B. always current version; C. random surrogate key; D. ingestion filename.

**Q4.** Plain append retry can:  
A. duplicate facts; B. automatically dedup; C. fix history; D. create dimensions.

**Q5.** Unknown surrogate key should be accompanied by:  
A. monitoring/repair policy; B. silent ignore; C. random mapping; D. no validation.

**Q6.** CDC delete signal:  
A. fully determines analytical delete semantics; B. still requires target business rule; C. always means hard-delete history; D. cannot be processed.

## 8. Tự luận / Interview

1. Why must source be deduplicated before a target merge?
2. How do SCD2 dimension loads affect fact loads?
3. When would you choose AUTO CDC over handwritten MERGE logic?
4. How do you prove an incremental Gold load is idempotent?
5. How should late-arriving facts be repaired?
6. Why is source sequencing a data contract?

## 9. Exit criteria

- [ ] Implement one SCD1 merge.
- [ ] Explain one SCD2/AUTO CDC flow.
- [ ] Map fact to historical surrogate key.
- [ ] Prove retry convergence.
- [ ] Document late/delete policy.
- [ ] Score >=5/6 MCQ.
