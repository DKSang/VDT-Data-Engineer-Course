# Module 05 – Lesson Answer Key

> Dùng sau khi đã tự làm lab. Đây là checkpoint kiến thức, không thay thế experiment evidence.

## Lesson 01 – Database Workloads & Architecture

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- OLTP: small concurrent transactions, point reads/writes, current business state.
- OLAP: scans, aggregation, history, cross-source analytics.
- Direct analytics on production source can compete for CPU/I/O/memory/locks/connections.
- Freshness has cost/complexity; CDC is not automatically required for every dashboard.
- Lakehouse complements rather than universally replaces operational databases.

## Lesson 02 – Relational Modeling & Normalization

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- grain = meaning of one row;
- functional dependency `A -> B` = A determines B under business rules;
- 1NF removes repeating groups/keeps atomic schema values;
- 2NF removes partial dependency on composite key;
- 3NF removes transitive non-key dependency;
- normalization reduces update/insert/delete anomalies;
- denormalization can be intentional in analytical serving if source-of-truth and refresh semantics are explicit.

## Lesson 03 – Keys, Constraints & Integrity

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- candidate key = minimal business-unique attribute set;
- surrogate key does not eliminate business key semantics;
- FK prevents orphan child reference in enforced RDBMS schema;
- PostgreSQL PK/FK/UNIQUE are enforced;
- Databricks `NOT NULL`/`CHECK` can be enforced; PK/FK/UNIQUE may be informational;
- unconstrained staging requires explicit validation before trusted publication.

## Lesson 04 – Transactions, ACID & WAL

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- transaction boundary should match business unit of work;
- Atomicity = all or none;
- Consistency depends on invariants actually encoded/respected;
- Isolation concerns concurrent visibility/interference;
- Durability means committed state survives failures according to configured guarantees;
- WAL records changes before dependent data-page persistence, enabling REDO crash recovery;
- ACID target transaction alone does not provide exactly-once across external checkpoint/state.

## Lesson 05 – Concurrency, MVCC & Isolation

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- PostgreSQL Read Committed uses statement-level snapshots;
- Repeatable Read gives stable transaction snapshot;
- Serializable aims for serializable committed outcome and can abort/retry transactions;
- MVCC reduces read/write blocking through version visibility but does not eliminate locks;
- deadlock = circular wait; consistent lock order reduces risk;
- long source snapshot transactions can improve extract consistency but may create operational cost.

## Lesson 06 – Indexes & Access Paths

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- index = extra access data structure with storage/write maintenance cost;
- B-tree is natural for equality/range/order workloads;
- low selectivity can make sequential scan cheaper;
- composite index order must reflect workload;
- GIN is useful for multi-valued/composite search patterns such as text/array operators;
- BRIN can be compact/useful for huge physically correlated datasets;
- measure before/after rather than claiming universal speedups.

## Lesson 07 – Planner, Statistics & EXPLAIN

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- SQL describes result; planner selects physical operators;
- cardinality estimates influence join order/algorithm/cost;
- `EXPLAIN` shows estimated plan; `EXPLAIN ANALYZE` executes and adds actual metrics;
- large estimated-vs-actual mismatch suggests cardinality-estimation problem;
- Nested Loop, Hash Join, Merge Join are different physical strategies;
- Seq Scan can be optimal;
- statistics summarize distributions for selectivity/row-count estimates.

## Lesson 08 – PostgreSQL ↔ Delta/Databricks

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Must explain:

- PostgreSQL WAL and Delta transaction log both support reliable committed state, but implementation/object scope differs;
- Delta uses versioned table snapshots and optimistic concurrency validation;
- Databricks readers see consistent snapshots;
- Delta write conflicts may fail and require retry;
- PK/FK/UNIQUE declarations on Databricks are not proof of clean data;
- OLTP→Delta CDC contract needs business key, ordering, delete semantics, retry/idempotency and reconciliation;
- source ACID does not automatically preserve arbitrary multi-table atomic visibility downstream.

# Oral self-check before leaving Module 05

Answer without notes:

1. Why is OLTP different from OLAP?
2. What problem does normalization solve?
3. PK vs business key?
4. ACID with money transfer?
5. What does WAL do?
6. Read Committed vs Repeatable Read?
7. MVCC vs locks?
8. Why can an index be ignored?
9. Why does a 1000x row-estimate error matter?
10. PostgreSQL transactions vs Delta transactions: what transfers conceptually and what does not?
