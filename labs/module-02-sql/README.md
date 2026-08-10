# Module 02 SQL Lab – Telecom Dataset

## Primary environment: Databricks

Module 02 now uses **Databricks SQL / Databricks Runtime + Delta tables** as the primary lab environment.

Recommended setup:

1. Open a Databricks workspace / Free Edition.
2. Choose a schema where you can create tables.
3. Run:

```text
databricks-setup.sql
```

4. Run each lesson query in SQL editor or a notebook SQL cell.
5. For Lesson 08, use `EXPLAIN` and the Databricks **Query Profile** after query execution.

The setup intentionally does **not** rely on database-enforced primary/foreign keys. Learners must validate uniqueness and cardinality explicitly because Data Engineering pipelines frequently consume data where assumptions are logical contracts rather than enforced OLTP constraints.

## Optional local environment: PostgreSQL

The legacy files remain useful for offline SQL practice:

```text
schema.sql
seed.sql
```

They are **supplementary only**. PostgreSQL B-tree/index/planner behavior is no longer part of Module 02 pass criteria.

## Data model

```text
plans 1 ────────< subscriptions >──────── 1 customers
                         │
customers 1 ─────< billing_transactions

cell_towers 1 ───< network_events

customers 1 ─────< customer_status_history
```

### Expected grain

| Table | Grain |
|---|---|
| `customers` | 1 row / customer |
| `plans` | 1 row / plan |
| `subscriptions` | 1 row / subscription contract |
| `billing_transactions` | 1 row / billing transaction |
| `cell_towers` | 1 row / cell tower |
| `network_events` | 1 row / ingested event version |
| `customer_status_history` | 1 row / customer status change |

Important distinction: raw `network_events` is **not** 1 row/logical event because multiple ingested versions may share the same `event_id`.

## Intentional data conditions

- duplicate/versioned `network_events.event_id`;
- late-arriving event;
- history relation with multiple rows/customer;
- NULL customer attributes;
- success/failed/refunded billing states;
- join fan-out opportunity;
- time-based incremental extraction fields.

## Per-exercise notebook/header template

```sql
-- Expected input grain:
-- Expected output grain:
-- Business key:
-- Cardinality assumption:
-- Failure/data-quality risk:

-- Query

-- Validation
```

## Databricks-specific experiments

During Module 02 you should explicitly practice:

```text
QUALIFY
LEFT SEMI JOIN
LEFT ANTI JOIN
try_cast
MERGE INTO Delta table
EXPLAIN FORMATTED / EXPLAIN COST
Query Profile
```

Optional awareness:

```text
AQE
Photon
query performance insights
ANALYZE TABLE / statistics
```

The deep internals are deferred to Spark/Databricks modules.

## Files

```text
labs/module-02-sql/
├── README.md
├── databricks-setup.sql     # primary
├── practice-set.md
├── schema.sql               # optional PostgreSQL
└── seed.sql                 # optional PostgreSQL
```

> The module goal is not “write SQL on any database”. It is to build strong relational reasoning and then apply it using the SQL surface that a Databricks Data Engineer actually works with.