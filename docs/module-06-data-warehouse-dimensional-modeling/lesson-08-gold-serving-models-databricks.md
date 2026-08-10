# Lesson 08 – Gold Serving Models on Databricks

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- đặt dimensional marts đúng vị trí trong medallion architecture;
- giải thích Silver warehouse core vs Gold business-serving marts;
- chọn star/snowflake/aggregate serving model theo workload;
- thiết kế Unity Catalog organization cho reusable dimensions/facts;
- dùng Databricks SQL để validate và serve Gold models;
- reasoning về performance mà không phá grain/history correctness;
- bảo vệ end-to-end telecom warehouse design.

## 2. Source alignment

### Primary Databricks sources

- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Data modeling: https://docs.databricks.com/aws/en/transform/data-modeling
- Medallion architecture: https://docs.databricks.com/aws/en/lakehouse/medallion
- Databricks SQL data warehousing docs
- Unity Catalog documentation
- Query Profile / performance docs referenced from Module 02

### Databricks architecture position

Databricks documents that Silver can host an integrated warehouse core, often normalized, while Gold can host one or more business-facing data marts. Gold commonly uses dimensional models and aggregates tailored for analytics/reporting.

## 3. Principles

### Principle 1 – Gold is a product interface, not a dumping ground

Gold tables should have clear users, business purpose, grain, ownership and freshness expectations.

### Principle 2 – Serving optimization comes after semantic correctness

Do not flatten everything simply to remove joins if that creates:

- repeated mixed-grain measures;
- broken history;
- unclear ownership;
- inconsistent metrics.

### Principle 3 – Reusable dimensions need governance

If `dim_customer` is shared across marts, its definition, owner, history policy and quality SLA should be discoverable and controlled.

### Principle 4 – Gold may contain both detailed marts and aggregates

Example:

```text
fact_billing_transaction
fact_network_daily
agg_revenue_monthly
```

These tables serve different query patterns and must have different grain contracts.

## 4. Fundamentals

### 4.1 Suggested catalog/schema organization

Example only:

```text
telecom
  bronze
  silver
  gold_finance
  gold_network
  gold_subscriber
```

Or:

```text
telecom_gold
  finance
  network
  subscriber
```

Organization should follow governance boundaries and ownership, not copy a template blindly.

### 4.2 Silver integrated layer

Possible Silver assets:

```text
customer_current_clean
customer_history_clean
billing_transaction_clean
plan_clean
network_event_clean
```

Characteristics:

- validated;
- detailed;
- source-integrated;
- suitable for rebuilding marts.

### 4.3 Gold finance mart

```text
dim_date
dim_customer
dim_plan
fact_billing_transaction
```

Business consumers query consistent facts/dimensions without reconstructing source joins repeatedly.

### 4.4 Gold network mart

```text
dim_date
dim_tower
fact_network_daily
```

Measures:

```text
total_calls
drops
drop_rate derived
```

### 4.5 Aggregate serving tables

If dashboard repeatedly requests monthly revenue:

```text
agg_monthly_revenue_by_province_plan
```

can be created from the trusted detailed fact.

It must document:

```text
grain
source fact
refresh SLA
reconciliation
```

### 4.6 Star/snowflake performance reasoning

Databricks data-modeling guidance notes that heavily normalized models often require more joins, while star/snowflake schemas can work well for analytical workloads.

But performance is evidence-based:

- scan amount;
- joins/shuffle;
- table statistics/layout;
- query profile;
- warehouse compute.

Do not optimize only from schema shape.

### 4.7 Constraints and expectations

Unity Catalog can expose relationships/constraints, but Module 05 already established that some Databricks key constraints are informational rather than enforcing uniqueness/referential integrity.

Therefore Gold pipelines still need validation queries.

### 4.8 Gold data-quality contract

For each fact:

```text
business grain unique
FK lookup success/unknown rate
measure domain valid
source/target row count reconciliation
source/target amount reconciliation
freshness SLA
SCD overlap/current-version validation
```

### 4.9 Serving BI safely

A dashboard metric should map to a governed definition.

Example:

```text
successful_revenue = SUM(amount)
WHERE transaction_status = 'success'
```

If Finance and Operations use different definitions, encode separate named measures/data products rather than silently reusing one label.

## 5. Worked example – Telecom Gold architecture

```text
Sources
PostgreSQL / API / Network Events
          │
          ▼
Bronze Delta
raw replayable records
          │
          ▼
Silver Delta
clean + dedup + integrated + detailed
          │
     ┌────┴─────────────┐
     ▼                  ▼
Gold Finance        Gold Network
     │                  │
dim_date           dim_date
dim_customer       dim_tower
dim_plan           fact_network_daily
fact_billing
     │                  │
     └───────┬──────────┘
             ▼
       Databricks SQL
       BI / reporting
```

Cross-domain KPI such as revenue vs network quality should combine facts only after aligning to compatible conformed dimensions/grain.

## 6. Hands-on lab

### Part A – Build Gold schemas

Create:

```text
gold_finance
gold_network
```

### Part B – Build dimensions/facts

At minimum:

```text
dim_date
dim_customer
dim_plan
dim_tower
fact_billing_transaction
fact_network_daily
```

### Part C – Validation suite

Write at least 12 checks:

- duplicate dimension business/current key;
- SCD2 overlap;
- multiple current rows;
- orphan/unknown facts;
- duplicate transaction facts;
- negative revenue;
- billing reconciliation;
- event-to-daily reconciliation;
- zero-denominator behavior;
- freshness;
- date-key coverage;
- late-data repair status.

### Part D – Serving queries

1. Daily revenue by province/segment/plan.
2. Daily network drop rate by tower.
3. Top 5 plans by revenue.
4. ARPU using common day/geography grain.

### Part E – Performance review

Choose one Gold query and inspect Databricks SQL plan/profile.

Report:

```text
semantic grain
scan inputs
join structure
largest intermediate step
candidate optimization
correctness risk of optimization
before/after evidence
```

## 7. Knowledge check – MCQ

**Q1.** Gold layer is primarily:  
A. business-facing refined serving layer; B. raw ingestion only; C. PostgreSQL WAL; D. Python package cache.

**Q2.** Silver can contain:  
A. integrated detailed warehouse structures; B. only dashboard screenshots; C. no joins; D. only ML models.

**Q3.** Gold dimensional mart should be optimized only after:  
A. semantic correctness/grain is proven; B. adding random columns; C. removing validation; D. deleting history.

**Q4.** Shared dimensions should have:  
A. governance/definition/history policy; B. no owner; C. random keys; D. separate meanings per mart under same name.

**Q5.** Aggregate table should document:  
A. grain/source/refresh/reconciliation; B. only row count; C. only file path; D. no lineage.

**Q6.** Databricks informational PK/FK means pipeline should:  
A. still validate key integrity; B. assume enforcement; C. ignore duplicates; D. never use dimensions.

## 8. Tự luận / Interview

1. Silver warehouse core vs Gold data mart differ in responsibility how?
2. Why can Gold contain both detailed fact and aggregate fact?
3. How would you organize telecom marts in Unity Catalog?
4. What quality checks must run before BI consumes Gold?
5. How do you optimize a star query without changing business semantics?
6. Defend the complete telecom medallion + dimensional architecture in three minutes.

## 9. Exit criteria

- [ ] Build end-to-end Silver → Gold design.
- [ ] Implement at least two marts.
- [ ] Run >=12 Gold validations.
- [ ] Perform one plan/profile review.
- [ ] Explain architecture without confusing medallion layers and dimensional modeling.
- [ ] Score >=5/6 MCQ.
