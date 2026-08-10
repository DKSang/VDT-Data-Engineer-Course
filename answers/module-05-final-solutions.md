# Module 05 Final Assessment – Suggested Solutions

> Reference solution. Alternative answers are valid if transaction/isolation/platform semantics and reasoning are correct.

## Part A – MCQ

```text
1A  2A  3A  4A  5A
6A  7A  8A  9A 10A
11A 12A 13A 14A 15A
16A 17A 18A 19A 20A
```

## Part B – Modeling & Integrity

### B1 – Normalize flat subscription table

Problematic flat relation mixes several grains:

- customer attributes;
- subscription attributes;
- plan attributes;
- one derived/latest payment snapshot.

Useful dependencies include:

```text
customer_id -> customer_name, province
subscription_id -> customer_id, plan_id, subscription_status
plan_id -> plan_name, monthly_fee
transaction_id -> customer_id, amount, transaction_ts
```

Anomalies:

- update: changing plan name/fee requires changing many rows;
- insert: cannot represent a plan with zero subscriptions cleanly;
- delete: deleting last subscription can erase plan knowledge;
- payment history is lost if only `last_payment_*` is retained.

Practical decomposition:

```text
customers(customer_id PK, customer_name, province)
plans(plan_id PK, plan_name, monthly_fee)
subscriptions(subscription_id PK, customer_id FK, plan_id FK, status, ...)
billing_transactions(transaction_id PK, customer_id FK, amount, transaction_ts, ...)
```

Historical charged amount belongs on the billing transaction/fact event because current plan price can later change.

### B2 – Integrity contracts

Example PostgreSQL DDL:

```sql
CREATE TABLE subscriptions (
    subscription_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
    plan_id INT NOT NULL REFERENCES plans(plan_id),
    status TEXT NOT NULL CHECK (status IN ('active','suspended','cancelled')),
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);
```

Databricks Delta comparison:

- `NOT NULL` and `CHECK` can be enforced;
- primary key, foreign key and unique constraints are informational in current Databricks semantics covered by the module;
- uniqueness, orphan checks and reconciliation should still be validated in the pipeline when required.

## Part C – Transactions & Concurrency

### C1 – Atomic transfer

```sql
BEGIN;

UPDATE accounts
SET balance = balance - 200
WHERE account_id = 1;

UPDATE accounts
SET balance = balance + 200
WHERE account_id = 2;

COMMIT;
```

A stronger implementation should also make insufficient-funds handling explicit, e.g. conditional update/check.

ACID:

- Atomicity: both balance changes commit or neither does;
- Consistency: encoded invariants such as nonnegative balances remain valid;
- Isolation: concurrent transfers should not observe/produce invalid interleavings under chosen isolation/locking strategy;
- Durability: committed balances survive crash according to DB guarantees.

If statement 2 fails before commit, transaction should roll back rather than publish only debit.

An external checkpoint can still create retry duplication because database commit and external checkpoint are separate state transitions unless coordinated/idempotent.

### C2 – Isolation

Read Committed in PostgreSQL uses a new snapshot for each statement. Therefore Session A can read old status, then after B commits, read new status in a later SELECT in the same transaction.

Repeatable Read uses a stable transaction snapshot, so A continues seeing the original committed version for ordinary reads.

Non-repeatable read = re-reading the same logical row and observing a changed committed value inside one transaction.

Serializable may abort a transaction when concurrency would produce a non-serializable result. Applications should retry the entire logical transaction.

### C3 – Deadlock

Wait-for graph:

```text
T1 holds row 1 → waits row 2
T2 holds row 2 → waits row 1
```

This is a cycle. PostgreSQL detects deadlock and aborts one participant.

Prevention:

- acquire resources in consistent global order, e.g. lower account_id first;
- keep transactions short;
- retry aborted transaction safely.

## Part D – Indexes & Planner

### D1 – Candidate index

```sql
CREATE INDEX idx_billing_big_customer_ts
ON billing_big(customer_id, transaction_ts);
```

Reasoning:

- equality predicate first narrows customer;
- time is range/order dimension inside that customer;
- index can reduce scanned rows and potentially sorting work;
- cost: additional storage/cache footprint and maintenance on INSERT/UPDATE/DELETE.

Do not claim the index is always used; confirm with plan evidence.

### D2 – Plan reasoning

`estimated 200` vs `actual 2,000,000` is a severe cardinality-estimation error.

Potential effects:

- poor join order;
- Nested Loop selected when actual outer/input is huge;
- memory/aggregate decisions based on wrong row counts;
- underestimated total cost.

Possible causes:

- stale statistics;
- skew/nonuniform distribution;
- correlated predicates;
- cross-column dependencies;
- expression/cast affecting selectivity;
- upstream join fan-out.

Investigate:

- plan node where error first appears;
- statistics freshness;
- distinct counts/common values/histogram summaries;
- data skew;
- query predicates and join cardinality assumptions.

`EXPLAIN` shows estimated plan. `EXPLAIN ANALYZE` executes the statement and adds actual rows/timing; write-side effects must be handled carefully.

Seq Scan can be optimal when much of the table must be read or table is small enough that indexed access costs more.

## Part E – PostgreSQL → Databricks System Reasoning

A strong answer should include:

### 1. Avoid default heavy analytics on primary OLTP

Because large scans/joins can compete with user-facing reads/writes for CPU, I/O, memory, connections and concurrency resources.

### 2. Capture method

With <5-minute freshness plus inserts/updates/deletes, CDC is often the strongest candidate if source/infrastructure supports it. Timestamp incremental can be viable only with a trustworthy monotonically updated column and explicit delete strategy. Full snapshots are simpler but create source/load/freshness trade-offs.

### 3. Keys/order

Example:

```text
subscriptions: subscription_id
billing: transaction_id
ordering: source LSN/transaction sequence/CDC sequence where available
```

Do not use ingestion time as a substitute for source ordering unless contract says so.

### 4. Deletes

Need delete/tombstone signal from CDC or periodic reconciliation/snapshot strategy. A simple `updated_at` filter cannot infer hard deletes.

### 5. Retry/idempotency

Bronze can preserve change records with source metadata. Silver current state should apply deterministic source ordering and merge/upsert keyed by business identity. Re-running the same logical changes must not append duplicates to current-state targets.

### 6. Constraint difference

PostgreSQL can enforce PK/FK/UNIQUE. Databricks PK/FK/UNIQUE declarations can be informational, so downstream uniqueness/orphan validation is still required.

### 7. Delta optimistic concurrency

Writers operate against a consistent table snapshot, stage proposed changes, then validate against concurrent commits before committing a new table version. Conflicts can cause the write to fail and require retry rather than relying on PostgreSQL-style row-lock intuition.

### 8. Multi-table source atomicity

A source transaction can atomically change several tables, but an asynchronous CDC consumer may receive/process table changes in separate records/batches. Downstream atomic visibility requires source transaction metadata and explicit consumer semantics; it must not be assumed automatically.

### 9. Reconciliation examples

- source vs target row count by bounded interval;
- count-distinct business keys;
- revenue sum by day;
- orphan key count;
- duplicate current-state keys;
- CDC lag/max source sequence;
- delete/tombstone counts.

### 10. Failure/recovery examples

1. target write succeeds, checkpoint fails → retry idempotently from source sequence;
2. CDC outage/backlog → resume from durable offset, monitor lag, backfill if retention exceeded;
3. malformed/out-of-order change → quarantine or apply deterministic ordering rule, reconcile with source snapshot;
4. missed delete → periodic reconciliation/backfill or source delete capture.

## Strong-pass oral expectations

Candidate should be able to explain without notes:

```text
OLTP workload
normalization anomaly
PK/FK enforcement
ACID + WAL
Read Committed vs Repeatable Read
MVCC + locks
B-tree/selectivity
cardinality estimation
PostgreSQL vs Delta transaction model
CDC idempotency
```
