# Lesson 04 – Star Schema Design Workflow

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- đi từ business requirement đến một star schema có thể bảo vệ được;
- áp dụng workflow process → grain → dimensions → facts;
- thiết kế date dimension và foreign-key paths rõ;
- phân biệt star schema và snowflake schema;
- nhận diện over-normalized analytical model;
- thiết kế validation trước khi publish Gold mart.

## 2. Source alignment

### Primary Databricks sources

- Data modeling: https://docs.databricks.com/aws/en/transform/data-modeling
- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Medallion architecture: https://docs.databricks.com/aws/en/lakehouse/medallion

### Databricks interpretation

Databricks currently recommends avoiding heavily normalized designs for new lakehouse analytical models and notes that star/snowflake schemas can perform well because standard queries require fewer joins and file-level statistics can skip more data.

### Supplementary fundamentals

The four-step dimensional design sequence in this lesson is vendor-neutral modeling practice.

## 3. Principles

### Principle 1 – Design one business process at a time

Trying to build a universal fact table for billing, subscription and network quality usually creates mixed grain and ambiguous metrics.

### Principle 2 – The star should make common business questions obvious

An analyst should be able to see:

```text
fact_billing_transaction
  → dim_date
  → dim_customer
  → dim_plan
```

and understand how to answer daily revenue by province/segment/plan.

### Principle 3 – Denormalization in a dimension can be intentional

In analytical serving, repeating descriptive attributes inside a dimension can be preferable to forcing analysts through long normalized join chains.

### Principle 4 – Simplicity does not excuse wrong history

A simple star schema is useful only if fact-to-dimension relationships preserve intended historical semantics.

## 4. Fundamentals

### 4.1 Four-step workflow

```text
1. Choose business process
2. Declare grain
3. Identify dimensions
4. Identify facts/measures
```

Do not invert step 2 and 4.

### 4.2 Star schema

A central fact table references denormalized dimensions.

```text
              dim_date
                 |
dim_customer -- fact_billing -- dim_plan
                 |
          dim_payment_method
```

Advantages:

- fewer joins;
- business-friendly structure;
- predictable filter/group paths;
- easier BI consumption.

### 4.3 Snowflake schema

Dimension hierarchies are further normalized.

Example:

```text
dim_tower → dim_site → dim_province → dim_region
```

Possible benefits:

- less duplicated hierarchy data;
- centralized hierarchy maintenance.

Costs:

- more joins;
- more complex semantic paths;
- more opportunities for cardinality errors.

Choose based on workload and maintainability, not ideology.

### 4.4 Dimension attribute placement

Question:

> Should `province` be copied into `dim_customer`?

If province is an analytical attribute of customer at the required history grain, keeping it in customer dimension can make star queries simpler.

But if province has rich independently managed hierarchy and shared semantics, a separate dimension/bridge may be justified.

### 4.5 Fact key shape

Example:

```text
fact_billing_transaction
transaction_id          degenerate business identifier
date_key                FK
customer_key            FK
plan_key                FK
amount                   measure
transaction_count       measure = 1
```

### 4.6 Date dimension

Typical integer key:

```text
20260810
```

This is not required by Databricks itself; it is a modeling choice that supports role-playing and business-calendar attributes.

### 4.7 Validation contract

Before publish:

```text
fact row count expected?
fact business key unique?
all dimension keys resolvable?
unknown-key rate acceptable?
revenue reconciles to Silver?
SCD2 effective intervals non-overlapping?
```

## 5. Worked example – Billing star

### Requirement

Finance asks:

> Daily successful revenue and transaction count by province, customer segment and plan type, with drill-through to transaction.

### Step 1 – Process

Billing transaction.

### Step 2 – Grain

One logical billing transaction.

### Step 3 – Dimensions

```text
dim_date
dim_customer
dim_plan
```

Potential low-cardinality attributes like payment method can initially stay in fact or become small dimension depending governance/reuse needs.

### Step 4 – Measures

```text
amount
transaction_count = 1
```

### Gold query shape

```sql
SELECT
  d.calendar_date,
  c.province,
  c.segment,
  p.plan_type,
  SUM(f.amount) AS revenue,
  SUM(f.transaction_count) AS txn_count
FROM fact_billing_transaction f
JOIN dim_date d ON d.date_key = f.date_key
JOIN dim_customer c ON c.customer_key = f.customer_key
JOIN dim_plan p ON p.plan_key = f.plan_key
GROUP BY ALL;
```

The model makes the business question obvious, but correctness still depends on fact grain and historical dimension mapping.

## 6. Hands-on lab

### Part A – Design billing star

Create a diagram with:

```text
dim_date
dim_customer
dim_plan
fact_billing_transaction
```

Document each table grain and key.

### Part B – Design network quality star

Requirement:

> Daily call quality by tower, province and technology.

Design either:

- detailed event fact; or
- daily tower fact.

Then explain whether you need both.

### Part C – Snowflake challenge

Compare:

```text
dim_tower(province, region)
```

versus:

```text
dim_tower → dim_province → dim_region
```

Discuss query complexity, reuse and maintenance.

### Part D – Validation plan

Write at least 8 checks before publishing billing Gold mart.

## 7. Knowledge check – MCQ

**Q1.** Four-step workflow begins with:  
A. business process; B. surrogate key; C. index; D. dashboard.

**Q2.** Grain should be declared before:  
A. measures/facts; B. repository creation; C. SQL warehouse size; D. visualization color.

**Q3.** Star schema usually has:  
A. central fact and surrounding dimensions; B. only dimensions; C. no keys; D. only nested JSON.

**Q4.** Snowflaking generally:  
A. increases dimension normalization and joins; B. removes all joins; C. is required by Databricks; D. means SCD2.

**Q5.** A Gold billing mart should reconcile revenue to:  
A. trusted detailed source/Silver population; B. random sample only; C. dashboard cache; D. README.

**Q6.** Simpler schema:  
A. can still be historically wrong; B. guarantees correct SCD mapping; C. guarantees no duplicates; D. removes need for grain.

## 8. Tự luận / Interview

1. Walk through the four-step design process for billing.
2. Star vs snowflake: what trade-off matters on Databricks?
3. Why can a heavily normalized serving model hurt analyst usability?
4. What validations prove a Gold fact is trustworthy?
5. Why is date dimension useful beyond extracting year/month from timestamp?
6. How would you decide whether province belongs in customer/tower dimension or separate shared geography dimension?

## 9. Exit criteria

- [ ] Produce one billing star schema diagram.
- [ ] Declare grain for every table.
- [ ] Explain star vs snowflake trade-off.
- [ ] Write >=8 Gold validation checks.
- [ ] Score >=5/6 MCQ.
