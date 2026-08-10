# Module 05 Final Assessment – Database Fundamentals

> Không xem `answers/module-05-final-solutions.md` trước khi hoàn thành.

## Quy định

- Primary lab engine: PostgreSQL 18.
- Databricks section uses current official Delta/Databricks behavior.
- Suggested time: **180 minutes**.
- Với concurrency experiment, ghi observed behavior; không bịa kết quả nếu môi trường không reproduce chính xác.
- Với performance, correctness phải được chứng minh trước optimization.

---

# Part A – Fundamentals MCQ (20 points)

1. OLTP thường tối ưu cho: A. many small concurrent transactions; B. only full scans; C. no writes; D. offline ML only.
2. Grain mô tả: A. meaning of one row; B. index size; C. isolation level; D. WAL segment.
3. `plan_id -> plan_name` là: A. functional dependency; B. deadlock; C. scan node; D. transaction.
4. Update anomaly thường liên quan: A. duplicated facts across rows; B. MVCC only; C. WAL only; D. SELECT LIMIT.
5. PK chủ yếu biểu diễn: A. identity; B. sort only; C. compression; D. checkpoint.
6. FK bảo vệ: A. referential integrity; B. query speed; C. WAL size; D. isolation.
7. Atomicity: A. all-or-nothing; B. fastest plan; C. no locks; D. no NULL.
8. Durability: A. committed change survives failure under guarantees; B. no rollback; C. no logs; D. only replicas.
9. WAL principle: A. log before dependent data-page persistence; B. flush all pages before log; C. stores only SELECT; D. removes recovery.
10. PostgreSQL default isolation: A. Read Committed; B. Serializable; C. Dirty Read; D. No isolation.
11. MVCC helps by: A. versioned snapshot visibility; B. removing all locks; C. enforcing all constraints; D. sorting tables.
12. Deadlock requires: A. circular wait; B. one transaction only; C. no locks; D. one SELECT.
13. Serializable applications may need: A. retry; B. drop indexes; C. disable WAL; D. no transactions.
14. B-tree is naturally useful for: A. equality/range/order; B. only full-text; C. deadlock detection; D. CDC.
15. Low-selectivity predicate may lead planner to: A. Seq Scan; B. always index; C. syntax failure; D. rollback.
16. `EXPLAIN ANALYZE`: A. executes query for actual metrics; B. estimates only; C. creates index; D. updates schema.
17. Estimated 100 vs actual 100000 indicates: A. cardinality-estimation error; B. perfect plan; C. FK error; D. normalization.
18. Databricks PK/FK/UNIQUE are commonly: A. informational; B. always PostgreSQL-enforced; C. impossible; D. WAL records.
19. Databricks `NOT NULL` / `CHECK` on Delta can be: A. enforced; B. comments only; C. indexes; D. CDC offsets.
20. Source DB ACID automatically guarantees downstream CDC exactly-once: A. No; B. Yes; C. only DELETE; D. only batch.

---

# Part B – Modeling & Integrity (20 points)

## B1 – Normalize a flat subscription table (10 points)

Input:

```text
customer_id
customer_name
province
subscription_id
plan_id
plan_name
monthly_fee
subscription_status
last_payment_amount
last_payment_ts
```

Tasks:

1. Define current grain and why it is problematic.
2. List at least 4 functional dependencies.
3. Identify one insert, update and delete anomaly.
4. Decompose to practical 3NF relations.
5. Explain where historical payment amount should live and why current plan fee is insufficient.

## B2 – Integrity contracts (10 points)

Design PostgreSQL DDL for `subscriptions` including:

- PK;
- FK customer;
- FK plan;
- accepted status;
- start/end date invariant;
- required columns.

Then answer:

1. Which equivalent constraints are enforced on Databricks Delta?
2. Which are informational?
3. What validation queries remain necessary in a lakehouse pipeline?

---

# Part C – Transactions & Concurrency (25 points)

## C1 – Atomic transfer (8 points)

Accounts A=500, B=500. Transfer 200 A→B.

1. Write transaction SQL.
2. Explain A/C/I/D for this action.
3. What happens if second UPDATE fails before COMMIT?
4. Why can an external checkpoint still make an end-to-end pipeline non-idempotent despite DB ACID?

## C2 – Isolation experiment (9 points)

Session A under Read Committed reads subscription status.
Session B updates and commits.
Session A reads again.

1. What can A see and why?
2. Repeat reasoning for Repeatable Read.
3. Define non-repeatable read.
4. Why can Serializable abort/retry rather than block every anomaly?

## C3 – Deadlock (8 points)

T1 locks account 1 then requests 2.
T2 locks account 2 then requests 1.

1. Draw wait-for cycle.
2. What does PostgreSQL do?
3. Give one prevention strategy.
4. Give retry/rollback handling strategy.

---

# Part D – Indexes & Planner (20 points)

## D1 – Access path design (8 points)

Query:

```sql
SELECT transaction_id, transaction_ts, amount
FROM billing_big
WHERE customer_id = 1001
  AND transaction_ts >= TIMESTAMPTZ '2026-03-01 00:00:00+07'
  AND transaction_ts <  TIMESTAMPTZ '2026-04-01 00:00:00+07'
ORDER BY transaction_ts;
```

1. Propose candidate index.
2. Explain column order.
3. Explain read benefit.
4. Explain write/storage cost.

## D2 – Plan reasoning (12 points)

A plan node reports:

```text
estimated rows = 200
actual rows = 2,000,000
```

1. Name the problem.
2. Why can this affect join algorithm/order?
3. List 4 possible causes.
4. What statistics/evidence would you inspect?
5. Explain EXPLAIN vs EXPLAIN ANALYZE.
6. Why is Seq Scan not automatically bad?

---

# Part E – PostgreSQL → Databricks System Reasoning (15 points)

Scenario:

> Production PostgreSQL stores subscriptions and billing. Databricks needs analytics under 5-minute freshness. Source has inserts, updates, deletes and high daytime traffic.

Answer:

1. Why not default to heavy analytical queries directly on primary OLTP?
2. Snapshot vs timestamp incremental vs CDC: choose and justify.
3. Define source business keys and ordering metadata.
4. How do deletes reach target?
5. How does retry remain idempotent?
6. PostgreSQL PK/FK vs Databricks PK/FK enforcement difference?
7. Explain Delta optimistic concurrency in one paragraph.
8. Why does source transaction atomicity not automatically make multi-table CDC atomic from downstream reader's perspective?
9. Give 4 reconciliation metrics/checks.
10. Give 3 failure scenarios and recovery actions.

---

# Rubric

| Part | Points |
|---|---:|
| A – Fundamentals | 20 |
| B – Modeling & Integrity | 20 |
| C – Transactions & Concurrency | 25 |
| D – Indexes & Planner | 20 |
| E – PostgreSQL → Databricks | 15 |
| **Total** | **100** |

## Pass criteria

- >=75/100 total.
- Part C >=17/25.
- Part D >=12/20.
- Must not miss these fundamentals:
  - PK/FK semantics;
  - atomic transaction boundary;
  - Read Committed vs Repeatable Read;
  - MVCC does not mean no locks;
  - index has write/storage cost;
  - cardinality estimates matter;
  - Databricks PK/FK are not assumed enforced;
  - source ACID != end-to-end CDC exactly-once.

## Strong pass

>=85/100 and can explain Parts C/E orally without notes.
