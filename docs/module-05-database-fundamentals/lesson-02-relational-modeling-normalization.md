# Lesson 02 – Relational Modeling, Functional Dependencies & Normalization

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- xác định entity, attribute, relationship và grain;
- phân biệt natural key, surrogate key, candidate key;
- giải thích functional dependency ở mức practical;
- nhận diện insert/update/delete anomaly;
- giải thích 1NF, 2NF, 3NF bằng ví dụ cụ thể;
- biết khi nào denormalization hợp lý và trade-off của nó;
- chuyển một flat operational table thành schema quan hệ hợp lý.

## 2. Source alignment

### Primary Databricks sources

- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts

Databricks source dùng để đối chiếu modeling trong analytical layer; normalization fundamentals không phải core Databricks curriculum.

### Supplementary primary sources

- PostgreSQL Data Definition: https://www.postgresql.org/docs/18/ddl.html
- PostgreSQL Constraints: https://www.postgresql.org/docs/18/ddl-constraints.html

## 3. Principles

### Principle 1 – Model facts once when operational consistency matters

Nếu `plan_name`, `monthly_fee`, `plan_type` bị copy vào hàng triệu subscription rows, một plan update có thể tạo inconsistency nếu không update hết.

Normalization giảm duplication của facts có ownership rõ.

### Principle 2 – Every table needs a grain

Trước khi normalization, viết:

> Mỗi row đại diện cho ______.

Nếu một row vừa đại diện customer vừa subscription vừa latest payment, grain đã bị trộn.

### Principle 3 – Functional dependency drives decomposition

Nếu:

```text
plan_id → plan_name, monthly_fee, plan_type
```

thì plan attributes thuộc entity `plan`, không thuộc mỗi subscription row.

### Principle 4 – Denormalization is a workload decision, not a correction of bad modeling

Analytical serving có thể cố ý duplicate fields để giảm joins hoặc simplify consumption. Nhưng phải biết source-of-truth và refresh semantics.

## 4. Fundamentals

### 4.1 Entity and relationship

Telecom domain:

```text
Customer 1 ───< Subscription >─── 1 Plan
Customer 1 ───< BillingTransaction
Customer 1 ───< StatusHistory
```

Entity ≠ table tuyệt đối, nhưng table thường represent entity/relationship set.

### 4.2 Keys

**Natural/business key**: key có meaning từ business, ví dụ phone number hoặc upstream customer code.

**Surrogate key**: key do system tạo để identify row/version.

**Candidate key**: minimal set có thể identify entity uniquely theo business rule.

**Composite key**: nhiều columns cùng tạo identity.

### 4.3 Functional dependency

Notation:

```text
A → B
```

nghĩa là value của A xác định duy nhất B trong relation theo business rules.

Example:

```text
plan_id → plan_name
plan_id → monthly_fee
```

Nhưng:

```text
province ↛ customer_id
```

vì một province có nhiều customers.

### 4.4 Update anomaly

Flat table:

```text
subscription_id | customer_id | plan_id | plan_name | monthly_fee
```

Nếu plan fee đổi 300k → 320k, phải update nhiều rows. Miss một row → inconsistent current state.

### 4.5 Insert anomaly

Không thể tạo plan mới nếu schema chỉ lưu plan fields bên trong subscription rows và chưa có subscriber nào.

### 4.6 Delete anomaly

Xóa last subscription của một plan có thể vô tình xóa luôn knowledge về plan đó.

### 4.7 First Normal Form – 1NF

Practical interpretation:

- mỗi row/column position chứa atomic value theo schema;
- không nhét repeating group như `plan1, plan2, plan3` vào một row;
- relation có row identity rõ.

Bad:

```text
customer_id | phones = '090...,091...'
```

Nếu phones cần query/constraint như entities, tách child relation.

### 4.8 Second Normal Form – 2NF

Quan trọng khi key composite: non-key attribute phải phụ thuộc toàn bộ key, không chỉ một phần.

Example relation:

```text
(customer_id, plan_id) -> activation_date
customer_id -> customer_name
```

`customer_name` phụ thuộc chỉ một phần composite key, nên nên tách customer entity.

### 4.9 Third Normal Form – 3NF

Non-key attribute không nên phụ thuộc transitively vào key qua một non-key attribute.

Example:

```text
subscription_id → plan_id
plan_id → plan_name
```

Nếu `plan_name` đặt trong subscriptions, dependency là transitive.

### 4.10 Normalization vs analytics modeling

Operational normalized schema giúp update consistency.

Analytical schemas có thể intentionally denormalize hoặc chuyển sang fact/dimension design. Module 06 sẽ đi sâu dimensional modeling.

## 5. Worked example – Normalize a telecom flat table

Input:

```text
customer_id
customer_name
province
subscription_id
plan_id
plan_name
monthly_fee
subscription_status
last_payment_amount
last_payment_ts
```

Problems:

- customer repeated per subscription;
- plan repeated per subscription;
- “last payment” mixes a changing derived fact into subscription row;
- cannot retain full payment history.

Normalized direction:

```text
customers(customer_id, customer_name, province)
plans(plan_id, plan_name, monthly_fee)
subscriptions(subscription_id, customer_id, plan_id, status)
billing_transactions(transaction_id, customer_id, amount, transaction_ts)
```

Now each relation has clearer grain and ownership.

## 6. Hands-on lab

### Part A – Dependency map

For each relation, write likely FDs:

```text
customers
plans
subscriptions
billing_transactions
```

### Part B – Find anomalies

Given a denormalized CSV with customer + plan + payment fields, identify:

- 2 update anomalies;
- 2 insert anomalies;
- 2 delete anomalies.

### Part C – Normalize

Transform this relation:

```text
customer_id
customer_name
email
subscription_id
plan_id
plan_name
monthly_fee
payment_1_amount
payment_2_amount
```

into 1NF, then explain decomposition toward 3NF.

### Part D – Denormalization decision

A Gold table used only for BI needs:

```text
customer_id
province
current_plan_name
monthly_fee
monthly_revenue
```

Argue whether intentional denormalization is acceptable. State refresh/freshness risk.

### Challenge – historical plan price

If plan price can change over time and billing must preserve historical charged price, where should charged amount live?

Explain why current `plans.monthly_fee` alone cannot reconstruct historical billing truth.

## 7. Knowledge check – MCQ

**Q1.** Grain answers:  
A. what one row represents  
B. number of indexes  
C. file size  
D. transaction isolation

**Q2.** `plan_id → plan_name` is:  
A. functional dependency  
B. deadlock  
C. index scan  
D. transaction

**Q3.** Repeating plan fields across subscriptions can cause:  
A. update anomaly  
B. stronger integrity automatically  
C. zero storage  
D. no trade-off

**Q4.** 2NF matters especially with:  
A. composite keys  
B. only one-column tables  
C. no attributes  
D. indexes only

**Q5.** 3NF targets:  
A. transitive dependency of non-key attributes  
B. WAL flush  
C. lock order  
D. query timeout

**Q6.** Denormalization can be valid when:  
A. intentionally optimized for workload with clear source-of-truth  
B. we do not understand keys  
C. constraints are hard  
D. duplicates appear accidentally

## 8. Tự luận / Interview

1. Normalization solves what class of problems?
2. 1NF/2NF/3NF: explain with one telecom example each.
3. Natural key vs surrogate key.
4. What is a functional dependency?
5. Why can analytics intentionally denormalize?
6. Why is `SELECT DISTINCT` not normalization?
7. How would you model multiple phone numbers per customer?
8. Current plan price and historical charged price should be modeled differently why?

## 9. Exit criteria

- [ ] identify grain for every lab relation;
- [ ] write at least 5 functional dependencies;
- [ ] identify insert/update/delete anomalies;
- [ ] normalize one flat relation to 3NF-level practical design;
- [ ] explain one valid denormalization trade-off;
- [ ] >=5/6 MCQ.
