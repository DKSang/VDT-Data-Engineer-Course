# Lesson 06 – Conformed Dimensions, Bus Matrix & Multiple Data Marts

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- giải thích conformed dimension và vì sao nó quan trọng khi có nhiều marts;
- thiết kế bus matrix giữa business processes và shared dimensions;
- tránh semantic drift giữa Billing, Subscription và Network marts;
- phân biệt shared dimension với duplicated look-alike tables;
- nhận diện khi bridge table cần thiết;
- thiết kế cross-process metrics mà không join facts trực tiếp gây fan-out.

## 2. Source alignment

### Primary Databricks sources

- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Medallion architecture: https://docs.databricks.com/aws/en/lakehouse/medallion
- Data modeling: https://docs.databricks.com/aws/en/transform/data-modeling
- Unity Catalog concepts for governed shared data assets.

### Supplementary fundamentals

Conformed dimensions and bus matrices are vendor-neutral warehouse design techniques used here to implement Databricks' idea of a trusted warehouse feeding multiple Gold marts.

## 3. Principles

### Principle 1 – Shared business words need shared semantics

If Billing defines `customer` one way and Subscription defines it another, cross-domain analysis becomes unreliable even if both schemas are individually valid.

### Principle 2 – Conformance is about meaning, not identical column names

Two tables named `dim_customer` are not conformed if:

- segment rules differ;
- history rules differ;
- key mapping differs;
- geography attributes mean different things.

### Principle 3 – Do not join facts to facts without a grain plan

Joining transaction facts directly to daily snapshot facts can multiply rows.

Usually aggregate facts to a common grain through conformed dimensions before comparing metrics.

### Principle 4 – Build reusable dimensions deliberately

A shared date/customer/plan/geography dimension can simplify multiple marts, but only when its business meaning truly applies across those processes.

## 4. Fundamentals

### 4.1 Conformed dimension

A dimension whose keys/attributes/semantics are consistently reusable across multiple fact tables.

Example:

```text
dim_date
  used by billing
  used by subscriptions
  used by network daily metrics
```

### 4.2 Bus matrix

Rows = business processes/facts.  
Columns = dimensions.

Example:

| Process | Date | Customer | Plan | Tower | Geography |
|---|---:|---:|---:|---:|---:|
| Billing | X | X | X |  | X |
| Subscription Snapshot | X | X | X |  | X |
| Network Daily | X |  |  | X | X |

This exposes integration points before code is written.

### 4.3 Semantic drift example

Billing `province` = customer billing address.  
Network `province` = tower physical location.

Both are called province but represent different context.

A shared `dim_geography` can work if roles are explicit:

```text
customer_geography_key
tower_geography_key
```

### 4.4 Multiple facts at different grain

```text
fact_billing_transaction
Grain: transaction

fact_subscription_daily
Grain: subscription/date
```

To compare daily revenue with active subscribers:

1. aggregate billing to date/geography;
2. aggregate subscription snapshot to same date/geography;
3. join aggregated results on conformed dimensions.

Do not raw-join transactions to snapshots by customer/date unless the resulting cardinality is intentionally modeled.

### 4.5 Bridge table awareness

Many-to-many relationships may require bridge tables.

Example:

```text
customer belongs to multiple marketing segments simultaneously
```

A bridge can map:

```text
customer_key
segment_key
weight/allocation optional
```

Bridges add complexity and can multiply measures; aggregation semantics must be explicit.

### 4.6 Data marts

A Gold layer can contain several marts:

```text
gold_finance
gold_network
gold_subscriber
```

Shared dimensions can be centrally governed or published as trusted reusable assets.

## 5. Worked example – ARPU by province

Requirement:

> Revenue per active subscriber per day by province.

Inputs:

```text
fact_billing_transaction  transaction grain
fact_subscription_daily   subscription/day grain
```

Wrong:

```text
billing fact JOIN subscription snapshot ON customer/date
```

because multiple transactions × potentially multiple subscriptions can fan out.

Correct reasoning:

```text
billing_daily:
  date_key, geography_key, revenue

subscriber_daily:
  date_key, geography_key, active_subscribers

then:
  revenue / active_subscribers
```

The two facts meet at a declared common grain.

## 6. Hands-on lab

### Part A – Build telecom bus matrix

Include at least:

```text
Billing Transaction
Subscription Daily Snapshot
Network Event or Daily Network Quality
```

Candidate dimensions:

```text
Date
Customer
Plan
Tower
Geography
Payment Method
```

### Part B – Define conformance contract

For `dim_customer`, write:

```text
Business key:
Surrogate-key policy:
History policy:
Segment definition:
Province definition:
Unknown-member policy:
Owner:
```

### Part C – Cross-process metric

Design ARPU by day/province without raw fact-to-fact fan-out.

### Part D – Semantic collision

Compare:

```text
customer province
tower province
```

Decide whether one geography dimension can support both through role-playing keys.

### Part E – Bridge challenge

Customer can belong to multiple campaigns. Design bridge and explain how a revenue metric could be double-counted if allocated to every campaign without weighting/business rule.

## 7. Knowledge check – MCQ

**Q1.** A conformed dimension primarily provides:  
A. shared business semantics across facts; B. faster Python; C. automatic SCD2; D. transaction isolation.

**Q2.** Bus matrix rows typically represent:  
A. business processes/facts; B. columns only; C. indexes; D. warehouses.

**Q3.** Joining facts at different grains directly can cause:  
A. fan-out/double counting; B. schema enforcement; C. automatic conformance; D. no issue.

**Q4.** Same column name `province` guarantees same meaning?  
A. yes; B. no; C. only in Delta; D. only in Gold.

**Q5.** Bridge table is commonly associated with:  
A. many-to-many modeling; B. ACID logging; C. Python packaging; D. query history.

**Q6.** Cross-process metrics should usually combine facts after:  
A. aligning them to a common grain; B. `SELECT *`; C. removing all dimensions; D. random dedup.

## 8. Tự luận / Interview

1. What makes a dimension conformed?
2. Why is a bus matrix useful before implementation?
3. How would you calculate ARPU across billing and subscription facts safely?
4. Why can two “province” attributes require different semantic roles?
5. When is a bridge table needed and what aggregation risk does it introduce?
6. How can Unity Catalog governance help shared dimensional assets operationally, even though conformance itself is a modeling concept?

## 9. Exit criteria

- [ ] Build telecom bus matrix.
- [ ] Define one conformed-dimension contract.
- [ ] Design one safe cross-fact metric.
- [ ] Explain bridge fan-out risk.
- [ ] Score >=5/6 MCQ.
