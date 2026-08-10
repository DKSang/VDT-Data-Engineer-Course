# Lesson 08 – PostgreSQL ↔ Delta Lake / Databricks Transaction Model

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- map familiar database concepts into Delta Lake without assuming identical implementation;
- compare PostgreSQL MVCC/row-store transactions with Delta table-version/optimistic-concurrency model;
- explain Databricks snapshot reads and write isolation at high level;
- explain Delta transaction log and table-version atomic commit;
- distinguish enforced vs informational constraints on Databricks;
- understand the scope of single-table statement transactions and newer multi-statement/multi-table transaction capabilities;
- design OLTP → lakehouse ingestion with explicit consistency and CDC assumptions.

## 2. Source alignment

### Primary Databricks sources

- ACID guarantees: https://docs.databricks.com/aws/en/lakehouse/acid
- Delta Lake: https://docs.databricks.com/aws/en/delta
- Isolation/write conflicts: https://docs.databricks.com/aws/en/optimizations/isolation/
- Isolation levels: https://docs.databricks.com/aws/en/optimizations/isolation/isolation-levels
- Transactions: https://docs.databricks.com/aws/en/transactions
- Constraints: https://docs.databricks.com/aws/en/tables/constraints

### Supplementary primary sources

- PostgreSQL MVCC: https://www.postgresql.org/docs/18/mvcc.html
- PostgreSQL isolation: https://www.postgresql.org/docs/18/transaction-iso.html
- PostgreSQL WAL: https://www.postgresql.org/docs/18/wal-intro.html

## 3. Principles

### Principle 1 – Shared vocabulary does not imply identical guarantees

Both systems use words like:

```text
ACID
transaction
snapshot
isolation
constraint
```

But implementation and scope differ. Always ask:

```text
What object is transactional?
What is the isolation level?
What conflicts?
What is enforced?
What must retry?
```

### Principle 2 – Delta commits table state through versioned metadata

Delta extends Parquet data files with a transaction log. A successful commit publishes a new table version/snapshot.

This is conceptually different from PostgreSQL's page/WAL/MVCC implementation even though both provide ACID-oriented guarantees.

### Principle 3 – Databricks uses optimistic concurrency for Delta writes

Writers can work against snapshots and validate conflicts at commit. Conflicting operations can fail instead of using the row-lock intuition common in OLTP databases.

### Principle 4 – Informational constraints are documentation/optimization metadata, not validation proof

On Databricks, `NOT NULL` and `CHECK` can be enforced on Delta tables, while primary key, foreign key and unique constraints can be informational.

Therefore:

```text
declared key != guaranteed clean data
```

unless you know enforcement semantics.

## 4. Fundamentals

### 4.1 PostgreSQL mental model recap

```text
row versions / MVCC
WAL for crash recovery
transactions across statements/tables
row/table locks when needed
Read Committed default
Repeatable Read / Serializable available
constraints enforced by database
```

### 4.2 Delta table mental model

Simplified:

```text
Parquet data files
      +
Delta transaction log
      ↓
version 100
version 101
version 102
```

A reader sees a consistent table version/snapshot. A write stages data changes and commits a new version when validation succeeds.

### 4.3 Atomicity in Delta

Files written but not referenced by a successful transaction-log commit do not become part of the current table state.

Atomic visibility comes from committing the new table version.

### 4.4 Optimistic concurrency

Simplified write stages:

```text
read current snapshot if needed
write candidate files
validate against concurrent commits
commit new version or fail conflict
```

Contrast with lock-first mental model:

```text
lock row → modify → unlock
```

Do not assume one implementation for the other.

### 4.5 Isolation on Databricks

Databricks documentation describes snapshot isolation for reads and write-serializable behavior for writes by default, with stronger Serializable configuration for applicable Delta workloads.

At fresher level, remember:

- readers see a consistent snapshot;
- writers may conflict during commit validation;
- conflict handling/retry is part of robust pipeline design.

### 4.6 Transaction scope

Historically/commonly, a SQL statement against a Delta table is an atomic table transaction.

Current Databricks also documents multi-statement/multi-table transactions using transaction syntax for eligible Unity Catalog managed tables with required features/catalog commits. Treat feature availability/status as environment/version dependent; check current docs before production design.

### 4.7 Constraints comparison

PostgreSQL:

```text
PRIMARY KEY → enforced
FOREIGN KEY → enforced
UNIQUE → enforced
NOT NULL → enforced
CHECK → enforced
```

Databricks Delta:

```text
NOT NULL → enforced
CHECK → enforced
PRIMARY KEY → informational
FOREIGN KEY → informational
UNIQUE → informational
```

Therefore Silver/Gold validation is still required when uniqueness/referential integrity matters.

### 4.8 OLTP source → lakehouse

You need separate contracts for:

```text
source transaction consistency
capture mechanism
ordering
business key
delete semantics
late/backdated update
target idempotency
```

A CDC stream can preserve row-level changes, but analytical correctness still depends on sequencing, keys and merge logic.

### 4.9 Snapshot vs change stream

Full snapshot answers:

> What state exists at a point/window?

CDC answers:

> What changes occurred?

They solve different problems and have different recovery/reconciliation needs.

## 5. Worked example – Subscription CDC into Delta

Operational PostgreSQL:

```text
subscriptions
PK subscription_id
FK customer_id
status updates transactionally
```

Pipeline receives changes:

```text
subscription_id=2001 status=active   sequence=100
subscription_id=2001 status=suspended sequence=101
```

Target Delta Silver table:

```text
current_subscription_state
```

Requirements:

1. business key = subscription_id;
2. latest ordering = source change sequence/commit metadata;
3. source batch must have deterministic winner per target key before MERGE if multiple versions present;
4. retry must be idempotent;
5. periodic reconciliation compares source snapshot/count/checksum metrics with target expectations.

Key lesson:

> Source database ACID does not automatically make an asynchronous CDC pipeline exactly-once or perfectly ordered end-to-end.

## 6. Hands-on lab

### Part A – Concept mapping table

Fill:

| Concept | PostgreSQL | Databricks Delta |
|---|---|---|
| persistent change log | | |
| read snapshot | | |
| write conflict | | |
| PK enforcement | | |
| multi-statement transaction | | |
| retry scenario | | |

### Part B – Constraint contrast

Create equivalent customer tables in PostgreSQL and Databricks.

Attempt:

- duplicate business key;
- NULL required field;
- invalid CHECK value;
- orphan foreign key.

Record what is actually rejected by each platform.

### Part C – Delta history

On Databricks:

1. create Delta table;
2. insert/update rows;
3. inspect table history/version information;
4. reason about versioned snapshots.

Do not need to master time travel yet; Module 10 will go deeper.

### Part D – Concurrent write reasoning

Draw two writers starting from same Delta snapshot and changing overlapping data.

Explain:

```text
read
write candidate files
validate
commit/conflict
```

### Part E – CDC architecture

Design:

```text
PostgreSQL OLTP
    ↓
CDC
    ↓
Bronze change log
    ↓
Silver current state
    ↓
Gold analytics
```

Document:

```text
business key
ordering key
update semantics
delete semantics
retry/idempotency
reconciliation
```

### Challenge – consistent business transaction across tables

Source transaction updates:

```text
subscriptions
billing_transactions
```

CDC delivers changes asynchronously.

Question:

> How will downstream know the two changes came from one source transaction or belong together?

Discuss source transaction metadata, ordering, micro-batch boundaries and downstream consistency expectations. Do not assume row-by-row CDC preserves arbitrary multi-table atomicity in the consumer view.

## 7. Knowledge check – MCQ

**Q1.** Delta Lake adds to Parquet primarily:  
A. transaction log / ACID table semantics  
B. PostgreSQL WAL pages  
C. B-tree for every column  
D. row locks only

**Q2.** Databricks Delta concurrency is commonly described as:  
A. optimistic concurrency  
B. no concurrency  
C. only table locks  
D. Git merge

**Q3.** Databricks PK/FK/UNIQUE constraints should be treated as:  
A. informational unless documented otherwise  
B. PostgreSQL-enforced automatically  
C. impossible metadata  
D. replacement for all DQ checks

**Q4.** `NOT NULL` and `CHECK` on Delta can be:  
A. enforced  
B. comments only always  
C. indexes  
D. CDC offsets

**Q5.** Source ACID guarantees end-to-end CDC exactly-once automatically?  
A. No  
B. Yes  
C. only for DELETE  
D. only for JSON

**Q6.** A robust OLTP→Delta pipeline should define:  
A. key/order/delete/retry/reconciliation semantics  
B. only table name  
C. only cluster size  
D. no failure handling

## 8. Tự luận / Interview

1. PostgreSQL WAL vs Delta transaction log: similarities and differences.
2. What does optimistic concurrency mean?
3. Why do Delta readers get snapshot consistency?
4. PostgreSQL PK vs Databricks PK enforcement.
5. Why can CDC violate your intuitive view of a multi-table source transaction downstream?
6. What should a Silver current-state MERGE contract include?
7. Why does source ACID not solve pipeline idempotency?
8. When would snapshot extraction be simpler than CDC?

## 9. Exit criteria

- [ ] complete PostgreSQL↔Delta comparison table;
- [ ] demonstrate/describe constraint enforcement differences;
- [ ] explain optimistic concurrency and snapshot reads;
- [ ] design CDC contract with key/order/delete/retry;
- [ ] explain why end-to-end exactly-once is broader than source ACID;
- [ ] >=5/6 MCQ.
