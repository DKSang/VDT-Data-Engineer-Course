# Lesson 03 – Dimensions, Natural Keys & Surrogate Keys

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- phân biệt fact và dimension theo analytical role;
- phân biệt natural/business key với surrogate key;
- giải thích vì sao surrogate key hữu ích cho history/SCD2;
- thiết kế role-playing, degenerate và junk dimensions ở mức thực dụng;
- xử lý unknown member và late-arriving dimension;
- xác định attributes nào nên nằm trong dimension thay vì fact.

## 2. Source alignment

### Primary Databricks sources

- Data modeling: https://docs.databricks.com/aws/en/transform/data-modeling
- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Table constraints: https://docs.databricks.com/aws/en/tables/constraints

### Scope note

Databricks supports star/snowflake models and informational PK/FK relationships in Unity Catalog. Detailed surrogate-key dimensional design is a vendor-neutral modeling fundamental.

## 3. Principles

### Principle 1 – Dimensions provide business context

Facts answer:

> What happened and how much?

Dimensions answer:

> Who, what, where, when, how, which category?

A useful dimension contains descriptive attributes analysts repeatedly use for filtering, grouping and labeling.

### Principle 2 – Natural identity and warehouse identity are different

`customer_id = 1001` identifies a business customer.

`customer_key = 74291` can identify **one warehouse version** of that customer.

This separation becomes critical for SCD2.

### Principle 3 – Facts should point to the dimension version relevant to the event

If customer 1001 was `mass` in January and `premium` in June, an old January billing fact should not silently change segment when today’s customer profile changes—unless business explicitly wants current-state reporting.

### Principle 4 – Unknown is better than orphan

When a fact arrives before its dimension member, losing the fact or leaving an unresolvable foreign key is often worse than mapping temporarily to an explicit unknown member and correcting later.

## 4. Fundamentals

### 4.1 Dimension example

```text
dim_customer
customer_key       surrogate key
customer_id        natural/business key
full_name
province
segment
effective_from
effective_to
is_current
```

### 4.2 Natural/business key

Comes from source/business identity:

```text
customer_id
plan_code
tower_id
```

Risks:

- source key can be reused;
- formats can change;
- multiple source systems can collide;
- one business key can have multiple historical versions.

### 4.3 Surrogate key

Warehouse-generated identity independent of source key.

Benefits:

- represents SCD2 versions separately;
- insulates facts from source-key changes;
- allows multi-source conformance;
- gives explicit unknown/not-applicable members.

Do not claim surrogate key alone solves entity resolution; source/business mapping is still required.

### 4.4 Role-playing dimensions

One physical logical dimension used in several roles.

`dim_date` can appear as:

```text
transaction_date_key
activation_date_key
cancellation_date_key
```

The semantic role changes even if dimension structure is shared.

### 4.5 Degenerate dimension

A business identifier kept directly in fact with no separate descriptive dimension.

Example:

```text
transaction_id
invoice_number
```

### 4.6 Junk dimension

Combines several low-cardinality flags/codes that would otherwise clutter the fact.

Example candidate attributes:

```text
payment_method
fraud_flag
channel
promo_flag
```

Use only when it improves model clarity; do not create junk dimensions mechanically.

### 4.7 Unknown member

Common explicit member:

```text
customer_key = 0
customer_id = NULL
segment = 'Unknown'
```

Then early-arriving facts can use key 0 until actual dimension mapping is available.

### 4.8 Date dimension

A date dimension adds stable business attributes:

```text
date_key
calendar_date
year
quarter
month
month_name
week_of_year
day_of_week
is_weekend
```

Fiscal calendars and holidays can also live here if business requires them.

## 5. Worked example – Customer history

Source customer:

```text
customer_id = 1001
segment = mass
```

Later:

```text
customer_id = 1001
segment = premium
```

SCD2 representation:

```text
customer_key | customer_id | segment | from       | to         | current
101          | 1001        | mass    | 2026-01-01 | 2026-06-01 | false
205          | 1001        | premium | 2026-06-01 | NULL       | true
```

Billing transaction on 2026-03-10 maps to key 101.
Billing transaction on 2026-07-10 maps to key 205.

The natural key stays `1001`; surrogate key identifies the historical version.

## 6. Hands-on lab

### A. Design `dim_customer`

Include:

- surrogate key;
- natural key;
- descriptive attributes;
- SCD metadata;
- explicit unknown row.

### B. Design `dim_plan`

Decide whether monthly fee belongs in dimension or fact depending requirement:

- “current catalog fee”;
- “actual amount charged at transaction time”.

Explain why those are different business semantics.

### C. Design `dim_date`

Generate at least 2025-01-01 through 2027-12-31.

### D. Role-playing

Show how subscription fact references date dimension as:

```text
start_date_key
end_date_key
```

### E. Late-arriving customer

A transaction for `customer_id=9999` arrives before customer dimension row.

Design:

1. initial fact key;
2. detection query;
3. later correction strategy.

## 7. Knowledge check – MCQ

**Q1.** Natural key usually comes from:  
A. business/source identity; B. query profile; C. warehouse cluster size; D. file statistics.

**Q2.** Surrogate key is especially useful for:  
A. distinguishing SCD2 versions; B. replacing all business rules; C. Photon enablement; D. Python imports.

**Q3.** `transaction_id` with no descriptive table can be:  
A. degenerate dimension; B. periodic snapshot; C. bridge only; D. SCD3.

**Q4.** Same `dim_date` used as order date and ship date is:  
A. role-playing dimension; B. junk dimension; C. factless fact; D. source system.

**Q5.** Early-arriving fact with missing dimension can map temporarily to:  
A. unknown member; B. random valid key; C. delete fact; D. NULL always without policy.

**Q6.** A surrogate key:  
A. automatically performs entity resolution; B. is warehouse-controlled identity; C. must equal natural key; D. only works in PostgreSQL.

## 8. Tự luận / Interview

1. Natural key và surrogate key khác nhau tại sao trong SCD2?
2. Tại sao fact nên lưu actual charged amount thay vì lookup current plan fee?
3. Unknown member giải quyết vấn đề gì?
4. Role-playing dimension là gì?
5. Khi nào không cần tạo riêng dimension cho transaction number?
6. Databricks informational PK/FK khác enforced database constraints ở điểm nào cần lưu ý khi modeling?

## 9. Exit criteria

- [ ] Thiết kế `dim_customer` với natural + surrogate key.
- [ ] Giải thích point-in-time fact mapping.
- [ ] Có unknown-member strategy.
- [ ] Thiết kế role-playing date usage.
- [ ] Đạt ít nhất 5/6 MCQ.
