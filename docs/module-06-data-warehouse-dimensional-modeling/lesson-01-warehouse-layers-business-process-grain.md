# Lesson 01 – Warehouse Layers, Business Process & Grain

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- phân biệt operational model, warehouse core và analytical mart;
- giải thích vai trò Bronze/Silver/Gold trong Databricks mà không đồng nhất chúng với OLTP/DWH/data mart;
- chọn một **business process** cụ thể trước khi thiết kế schema;
- viết grain statement chính xác;
- nhận diện mixed-grain table và các metric sai do grain không rõ;
- chuyển business question thành candidate facts/dimensions.

## 2. Source alignment

### Primary Databricks sources

- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Medallion architecture: https://docs.databricks.com/aws/en/lakehouse/medallion
- Data modeling: https://docs.databricks.com/aws/en/transform/data-modeling

### Databricks Academy

- Get Started with Databricks for Data Engineering
- Get Started Days: Data Engineering + SQL Analytics and BI

### Scope note

Databricks documents how data warehousing and dimensional marts fit into Silver/Gold. The concepts **business process** and **grain-first dimensional design** are vendor-neutral fundamentals added to make the model defensible.

## 3. Principles

### Principle 1 – Business process before tables

Do not start with:

> “I need a customer dimension.”

Start with:

> “I need to analyze billing transactions.”

A business process produces measurable events. Tables are a design response to that process.

### Principle 2 – Declare grain before choosing measures

Every fact design begins with a sentence:

> One row represents ______.

Examples:

- one billing transaction;
- one subscription per customer per day;
- one tower per calendar day;
- one customer lifecycle milestone.

If a table mixes these meanings, downstream aggregation becomes ambiguous.

### Principle 3 – Medallion layer and data model are different axes

Medallion asks:

> How refined/reliable/business-ready is this data?

Dimensional modeling asks:

> What analytical business process, grain, facts and dimensions does this dataset represent?

Therefore a Gold layer can contain several dimensional marts, aggregate tables or other business-facing datasets.

### Principle 4 – Preserve detailed truth before presentation optimization

Databricks guidance places validated detailed records in Silver and business-facing dimensional/aggregated models in Gold. Gold should be rebuildable from trusted lower layers rather than becoming the only copy of business truth.

## 4. Fundamentals

### 4.1 Operational vs analytical modeling

Operational models optimize:

- inserts/updates;
- transaction consistency;
- narrow lookups;
- normalized state.

Analytical models optimize:

- business questions;
- joins analysts repeatedly perform;
- stable metric definitions;
- historical analysis;
- aggregation.

A schema correct for OLTP is not automatically convenient for BI.

### 4.2 Warehouse core vs data mart

A warehouse core integrates data across sources and business domains. On Databricks, Silver can contain a normalized integrated warehouse.

A Gold data mart presents a business perspective such as:

```text
Billing Mart
Network Quality Mart
Subscriber Mart
```

### 4.3 Business process

A business process is an activity worth measuring.

Telecom examples:

```text
customer pays bill
customer activates subscription
call terminates
call drops
network tower reports daily quality
```

Do not confuse process with entity. “Customer” is an entity/context; “billing transaction” is a measurable process.

### 4.4 Grain

Bad grain statement:

> “Billing data.”

Good grain statement:

> “One row per source billing transaction after deterministic deduplication.”

Even better:

```text
Business key: transaction_id
Event time: transaction_ts
One row: one logical billing transaction
```

### 4.5 Mixed grain

Bad table:

```text
customer_id
transaction_id
monthly_revenue
transaction_amount
```

If `monthly_revenue` repeats on every transaction row, summing it produces double counting.

This is a mixed-level measure: transaction-level rows contain a customer-month aggregate.

### 4.6 Grain validation questions

Before building a fact:

```text
What creates a new row?
Can the same business event appear twice?
Which key identifies the row?
What time dimension applies?
Can a measure be safely summed across rows?
What happens when source data is corrected?
```

## 5. Worked example – Billing mart

Requirement:

> Finance needs daily revenue by province, plan and customer segment, while analysts must still drill down to individual transactions.

### Step 1 – Process

Billing transaction.

### Step 2 – Grain

One row / logical billing transaction.

### Step 3 – Candidate facts

```text
amount
transaction_count = 1
```

### Step 4 – Candidate dimensions

```text
date
customer
plan
payment method (attribute or small dimension depending design)
transaction type
```

### Step 5 – Critical history question

When customer segment changes, should an old transaction report using:

A. the segment at transaction time; or
B. the customer’s segment today?

This determines SCD/history design. The schema cannot answer this correctly without an explicit requirement.

## 6. Hands-on lab

Use the telecom domain and complete a design sheet for three processes:

### A. Billing transaction

Write:

```text
Business process:
Fact grain:
Business key:
Event timestamp:
Measures:
Dimensions:
History questions:
```

### B. Daily network quality

Requirement:

> NOC wants daily call-drop rate by tower/province/technology.

Decide whether the fact should be:

- one event/call; or
- one tower/day aggregate.

Explain trade-off in drill-down and storage.

### C. Subscription lifecycle

Compare two possible grains:

```text
one subscription state-change event
one customer-subscription/day snapshot
```

Explain which questions each supports naturally.

### Deliverables

- `lesson-01-modeling.md`
- three grain statements;
- one diagram showing Silver integrated data → Gold marts;
- at least five grain validation rules.

## 7. Knowledge check – MCQ

**Q1.** First step in dimensional design should usually be:  
A. create dimensions; B. choose business process; C. create index; D. choose dashboard color.

**Q2.** Grain describes:  
A. table size; B. meaning of one fact row; C. Delta version; D. warehouse size.

**Q3.** Gold layer on Databricks:  
A. must be one aggregate table; B. can contain dimensional data marts and aggregates; C. must remain raw; D. cannot contain business logic.

**Q4.** A transaction row containing repeated monthly revenue has risk of:  
A. double counting; B. deadlock only; C. syntax error always; D. no issue.

**Q5.** “Customer” is usually best understood initially as:  
A. a business process; B. contextual entity/dimension candidate; C. transaction fact; D. SQL warehouse.

**Q6.** Silver and Gold primarily express:  
A. normalized vs star exclusively; B. refinement/business-readiness layers; C. database indexes; D. Python versions.

Answers: see `answers/module-06-lesson-answers.md`.

## 8. Knowledge check – Tự luận / Interview

1. Tại sao phải chọn business process trước khi chọn fact table?
2. Grain sai có thể làm KPI đúng cú pháp nhưng sai số như thế nào?
3. Medallion architecture và dimensional modeling khác nhau ở câu hỏi thiết kế nào?
4. Một billing fact ở transaction grain hỗ trợ drill-down tốt hơn daily aggregate thế nào?
5. Khi nào bạn vẫn muốn Gold aggregate fact bên cạnh transaction fact?
6. Một requirement nào buộc bạn phải hỏi về historical dimension state?

## 9. Exit criteria

- [ ] Viết được grain cho 3 telecom processes.
- [ ] Phân biệt operational entity với measurable business process.
- [ ] Giải thích Silver warehouse vs Gold mart.
- [ ] Phát hiện được mixed-grain measure.
- [ ] Đạt ít nhất 5/6 MCQ.
