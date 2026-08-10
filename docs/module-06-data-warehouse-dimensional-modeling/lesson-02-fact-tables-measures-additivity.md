# Lesson 02 – Fact Tables, Measures & Additivity

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- xác định fact table từ một business process;
- phân biệt transaction fact, periodic snapshot và accumulating snapshot;
- phân loại measure additive, semi-additive và non-additive;
- nhận diện factless fact table;
- thiết kế derived ratio không double count numerator/denominator;
- chọn grain phù hợp giữa detail và aggregate fact.

## 2. Source alignment

### Primary Databricks sources

- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Medallion Gold dimensional modeling: https://docs.databricks.com/aws/en/lakehouse/medallion
- Data modeling: https://docs.databricks.com/aws/en/transform/data-modeling

### Supplementary fundamentals

Fact-table types and measure additivity are vendor-neutral dimensional-modeling concepts. Databricks provides the platform in which these models are implemented but does not redefine their mathematical meaning.

## 3. Principles

### Principle 1 – Facts measure a process at a declared grain

Fact table design is not “put every numeric column in one table”.

A fact row represents an event/snapshot/milestone and carries measures meaningful at that grain.

### Principle 2 – Additivity is a semantic property

A numeric column is not automatically safe to `SUM` across all dimensions.

Examples:

- transaction amount: additive across transactions and time;
- account balance: additive across accounts, but not normally across time;
- conversion rate: usually non-additive.

### Principle 3 – Ratios should be derived from additive components

Prefer storing:

```text
drop_count
total_calls
```

then computing:

```text
drop_rate = SUM(drop_count) / SUM(total_calls)
```

rather than averaging precomputed percentages with unequal denominators.

### Principle 4 – Detail facts and aggregate facts answer different needs

A detailed transaction fact preserves drill-through and flexible aggregation. An aggregate fact can improve serving latency but loses detail. They can coexist if lineage and grain are explicit.

## 4. Fundamentals

### 4.1 Transaction fact

One row per discrete business event.

Telecom example:

```text
fact_billing_transaction
Grain: one logical billing transaction
```

Typical columns:

```text
transaction_id
date_key
customer_key
plan_key
amount
transaction_count
```

### 4.2 Periodic snapshot fact

One row per entity/process for a regular period.

Example:

```text
fact_subscription_daily
Grain: one subscription per calendar day
```

Measures might include:

```text
active_flag
balance
usage_gb
```

Snapshot facts are useful when business asks “state as of every day/week/month”.

### 4.3 Accumulating snapshot fact

One row per process instance, updated as milestones occur.

Example subscription onboarding:

```text
subscription_created_date
activated_date
first_usage_date
first_bill_date
cancelled_date
```

The row evolves until process completion.

### 4.4 Factless fact

A fact can record that an event/relationship occurred even with no numeric measure.

Example:

```text
customer_campaign_eligibility
customer_campaign_contact
```

Counting rows becomes the measure.

### 4.5 Additive measure

Can be summed across relevant dimensions.

```text
transaction_amount
call_duration_seconds
data_usage_mb
```

### 4.6 Semi-additive measure

Can be summed across some dimensions but not all.

Example daily balance:

```text
sum(balance) across customers at one date → meaningful
sum(balance) across dates → usually meaningless
```

### 4.7 Non-additive measure

Ratios/percentages/averages often cannot be directly summed.

```text
drop_rate
average_revenue_per_user
conversion_rate
```

Store or retain components where possible.

### 4.8 Degenerate identifiers in facts

Operational transaction identifiers such as `transaction_id` can remain directly in the fact without their own separate dimension when they have no descriptive attributes useful for analytics.

## 5. Worked example – Network-quality facts

Requirement:

> Rank towers by drop rate daily and allow drill-through to individual events when investigating incidents.

Two models:

### Detailed event fact

```text
fact_network_event
Grain: one deduplicated call-end/drop event
```

Measures:

```text
call_count = 1
drop_count = 1 or 0
duration_seconds
```

### Daily aggregate fact

```text
fact_network_daily
Grain: one tower/date
```

Measures:

```text
total_calls
drops
total_duration_seconds
```

Derived:

```text
drop_rate = drops / total_calls
```

The daily fact serves dashboards efficiently; the event fact supports root-cause drill-down.

## 6. Hands-on lab

For each process, classify fact type and measures.

### A. Billing

Design transaction fact and classify:

- `amount`;
- `transaction_count`;
- `refund_amount`;
- `avg_transaction_amount`.

### B. Subscription

Design a daily periodic snapshot with:

- active subscriber count;
- outstanding balance;
- data quota remaining.

Mark which measures are additive across customer/date.

### C. Activation funnel

Design an accumulating snapshot for:

```text
ordered → provisioned → activated → first_usage → first_bill
```

### D. Network quality

Build both detail fact and daily aggregate fact. Define reconciliation:

```text
SUM(daily.total_calls) == COUNT(detail call-end/drop events)
SUM(daily.drops) == SUM(detail.drop_count)
```

### Deliverables

- `lesson-02-facts.md`;
- table listing fact type/grain/measures/additivity;
- two reconciliation queries/pseudo-queries.

## 7. Knowledge check – MCQ

**Q1.** One row per billing transaction is:  
A. transaction fact; B. periodic snapshot; C. dimension; D. bridge only.

**Q2.** One row per subscription/day is:  
A. transaction fact; B. periodic snapshot; C. degenerate dimension; D. SCD0.

**Q3.** Account balance is commonly:  
A. additive across time; B. semi-additive; C. non-numeric only; D. dimension key.

**Q4.** Drop rate should ideally be aggregated by:  
A. averaging all stored percentages blindly; B. summing numerator/denominator then dividing; C. summing rates; D. max only.

**Q5.** An accumulating snapshot is useful for:  
A. milestone process lifecycle; B. only static descriptions; C. code versioning; D. schema enforcement.

**Q6.** Factless fact table can be useful to:  
A. record occurrence/coverage relationships; B. replace all dimensions; C. enforce PK in Delta automatically; D. store source code.

## 8. Tự luận / Interview

1. Transaction fact vs periodic snapshot khác nhau ở grain và use case nào?
2. Vì sao balance semi-additive?
3. Vì sao average-of-rates dễ sai?
4. Khi nào bạn tạo aggregate fact thay vì chỉ dùng transaction fact?
5. Factless fact table dùng cho business question nào?
6. Một accumulating snapshot có thể được update nhiều lần; điều đó khác transaction fact append-only ra sao?

## 9. Exit criteria

- [ ] Phân loại đúng 3 fact-table types.
- [ ] Giải thích additive/semi/non-additive bằng telecom examples.
- [ ] Thiết kế numerator/denominator cho drop rate.
- [ ] Viết reconciliation detail vs aggregate.
- [ ] Đạt ít nhất 5/6 MCQ.
