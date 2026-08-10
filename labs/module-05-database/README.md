# Module 05 Lab – Database Fundamentals

## Primary environment

Use **PostgreSQL 18** for RDBMS experiments.

Quick Docker setup:

```bash
docker run --name vdt-db-fundamentals \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=vdt_db \
  -p 5433:5432 \
  -d postgres:18
```

Then run:

```text
postgres-setup.sql
```

For concurrency labs, open **two separate SQL sessions**.

## Files

```text
labs/module-05-database/
├── README.md
├── postgres-setup.sql
├── concurrency-lab.md
├── databricks-contrast.sql
└── practice-set.md
```

## What this lab intentionally contains

- PK/FK/UNIQUE/CHECK constraints;
- normalized customer/plan/subscription/billing relations;
- an unconstrained staging table for bad-data experiments;
- accounts table for transaction/locking/deadlock exercises;
- event table large enough to scale for index/planner labs;
- columns with skewed distributions;
- history relation with multiple rows/customer;
- Delta contrast tasks for Databricks.

## Learning rules

For every experiment record:

```text
Hypothesis:
SQL:
Observed behavior:
Why it happened:
What principle it demonstrates:
```

Do not submit only screenshots.

## Minimum deliverables

```text
my-work/module-05/
├── lesson-01-notes.md
├── lesson-02-model.sql
├── lesson-03-constraints.sql
├── lesson-04-transactions.sql
├── lesson-05-concurrency-notes.md
├── lesson-06-indexes.sql
├── lesson-07-explain-notes.md
├── lesson-08-databricks-contrast.md
└── final-assessment.md
```

## Safety note

`EXPLAIN ANALYZE` executes the statement. Use read-only queries for normal labs; if experimenting with write statements, use a disposable lab database and explicit transaction/rollback where appropriate.
