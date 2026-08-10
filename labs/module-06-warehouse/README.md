# Module 06 Lab – Telecom Data Warehouse & Dimensional Modeling

## Primary environment

- Databricks SQL or Databricks Runtime with SQL support.
- Delta tables.
- A catalog/schema where you can create tables.

Run:

```text
databricks-setup.sql
```

The setup creates Silver source-aligned tables and starter Gold schemas/tables for modeling exercises.

## Learning goals

The lab is not a syntax drill. For each target table, document:

```text
Business process:
Grain:
Business key:
Surrogate key:
Dimensions:
Measures:
Additivity:
History policy:
Late-data policy:
Incremental strategy:
Validation:
```

## Target architecture

```text
silver.customer_history
silver.plan
silver.billing_transaction
silver.tower
silver.network_event
          │
          ▼
gold_finance.dim_date
gold_finance.dim_customer
gold_finance.dim_plan
gold_finance.fact_billing_transaction

gold_network.dim_date or shared date dimension
gold_network.dim_tower
gold_network.fact_network_daily
```

## Required experiments

1. Build a transaction fact at one row/logical billing transaction.
2. Build SCD2 customer dimension with non-overlapping versions.
3. Point-in-time map billing facts to historical customer version.
4. Build a daily tower network fact.
5. Reconcile detailed events to daily network totals.
6. Simulate early-arriving fact and unknown member.
7. Simulate late/backdated customer change and describe repair.
8. Run the same incremental logical batch twice and prove convergence.
9. Build a bus matrix for Billing / Subscription / Network.
10. Create one cross-process KPI at a common grain without raw fact-to-fact fan-out.

## Important lab rule

A query is not complete until you can answer:

```text
What does one output row mean?
Can any join multiply that grain?
Can every measure be aggregated the way I use it?
Which historical dimension version does the fact reference?
How do I prove source and Gold reconcile?
```

## Files

```text
labs/module-06-warehouse/
├── README.md
├── databricks-setup.sql
├── modeling-template.md
└── practice-set.md
```

## Suggested folder for your work

```text
my-work/module-06/
├── lesson-01-modeling.md
├── lesson-02-facts.sql
├── lesson-03-dimensions.sql
├── lesson-04-star-schema.sql
├── lesson-05-scd.sql
├── lesson-06-bus-matrix.md
├── lesson-07-incremental.sql
├── lesson-08-gold-serving.sql
└── validation.sql
```
