# Module 06 – Lesson Answer Key

> Self-check only. Do the modeling/labs before reading.

## Lesson 01 – Warehouse Layers, Business Process & Grain

**MCQ:** 1B, 2B, 3B, 4A, 5B, 6B.

Strong answers must include:

- business process is measurable activity, not entity;
- fact grain = meaning of one fact row;
- medallion layer != dimensional model type;
- Gold can contain several marts/aggregates;
- mixed-grain measures can double count;
- trusted Silver detail should support Gold rebuild/reconciliation.

## Lesson 02 – Fact Tables & Measures

**MCQ:** 1A, 2B, 3B, 4B, 5A, 6A.

Strong answers:

- transaction fact = discrete event;
- periodic snapshot = state each period;
- accumulating snapshot = lifecycle milestones;
- balance is often semi-additive over time;
- ratios should aggregate additive numerator/denominator;
- detail and aggregate facts can coexist with explicit grain/reconciliation.

## Lesson 03 – Dimensions & Keys

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6B.

Strong answers:

- natural key = source/business identity;
- surrogate key = warehouse-controlled row/version identity;
- SCD2 uses multiple surrogate keys for one business key over time;
- role-playing dimension reuses same dimension under different semantic roles;
- unknown member avoids untracked orphan facts while preserving repair path;
- informational PK/FK still require data-quality validation on Databricks.

## Lesson 04 – Star Schema Workflow

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Strong answers:

- process → grain → dimensions → facts;
- star reduces repeated analytical join complexity;
- snowflake normalizes dimension hierarchies but adds joins;
- simplicity cannot replace historical correctness;
- Gold fact must reconcile to trusted detailed population.

## Lesson 05 – SCD & Late Data

**MCQ:** 1A, 2A, 3A, 4B, 5A, 6B.

Strong answers:

- SCD1 overwrite/current-state;
- SCD2 full history/version rows;
- effective time can differ from ingestion time;
- Type 2 intervals should not overlap per business key;
- early-arriving facts need unknown/inferred/hold policy;
- AUTO CDC reduces procedural CDC/SCD logic but still relies on correct keys/sequence semantics.

## Lesson 06 – Conformed Dimensions & Bus Matrix

**MCQ:** 1A, 2A, 3A, 4B, 5A, 6A.

Strong answers:

- conformance = shared business meaning/key/history contract;
- bus matrix exposes business-process/dimension integration;
- raw fact-to-fact joins often fan out when grains differ;
- cross-process KPI should aggregate to common grain first;
- bridges represent many-to-many and need explicit allocation/aggregation rules.

## Lesson 07 – Incremental Databricks Loading

**MCQ:** 1B, 2A, 3A, 4A, 5A, 6B.

Strong answers:

- pre-dedup staged source before MERGE if multiple rows/business key;
- `MERGE` does not infer winner semantics;
- fact loading depends on correct dimension version availability;
- rerun should converge to same logical result;
- unknown-member usage needs monitoring + later repair;
- source delete event does not by itself define analytical deletion policy.

## Lesson 08 – Gold Serving Models

**MCQ:** 1A, 2A, 3A, 4A, 5A, 6A.

Strong answers:

- Silver can contain integrated detailed warehouse structures;
- Gold is business-serving/presentation layer and may contain marts + aggregates;
- shared dimensions need ownership/definition/history contract;
- serving optimization comes after grain/history correctness;
- aggregate tables need source/grain/refresh/reconciliation lineage;
- key integrity still needs explicit validation when constraints are informational.

## Final self-check before Module 07

Explain without notes:

1. process vs entity;
2. grain;
3. transaction vs periodic vs accumulating fact;
4. additive vs semi/non-additive;
5. natural vs surrogate key;
6. SCD1 vs SCD2;
7. point-in-time dimension mapping;
8. early/late-arriving data;
9. conformed dimension and bus matrix;
10. fact-to-fact fan-out;
11. MERGE vs AUTO CDC responsibility;
12. Silver warehouse core vs Gold dimensional mart.
