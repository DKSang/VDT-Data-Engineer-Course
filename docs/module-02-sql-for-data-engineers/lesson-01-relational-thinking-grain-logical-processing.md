# Lesson 01 – Relational Thinking, Grain & Databricks Query Semantics

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Xác định grain, business key và expected uniqueness của một table/query result.
- Reasoning query như chuỗi relations, không như chuỗi text SQL.
- Phân biệt **logical reasoning order** với **physical execution plan**.
- Đọc cấu trúc `Query` / `SELECT` của Databricks SQL.
- Dự đoán join/aggregate có preserve hay thay đổi grain.
- Viết validation query cho uniqueness, row count và reconciliation.
- Biết khi nào `SELECT *` / `* EXCEPT (...)` phù hợp trong Databricks.

---

## 2. Source alignment

### Primary Databricks sources

- SQL Language Reference  
  https://docs.databricks.com/aws/en/sql/language-manual
- Query  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-query
- SELECT (subselect)  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select
- SELECT clause / star clause  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-column-list

### Scope note

Databricks docs định nghĩa syntax/semantics. Khái niệm **grain** là Data Engineering reasoning layer mà course thêm vào để kiểm tra correctness trước khi dùng Spark/Delta/Lakeflow.

---

## 3. Principles

### Principle 1 – Grain before query

Trước khi code, hoàn thành câu:

> Mỗi row của relation này đại diện cho ______.

Ví dụ:

```text
customers             → 1 row / customer
billing_transactions  → 1 row / transaction
network_events raw    → 1 row / ingested event version
Gold revenue          → 1 row / date / province
```

Nếu không nói được grain, bạn chưa thể chứng minh `JOIN`, `GROUP BY` hay dedup là đúng.

### Principle 2 – A query creates relations

Hãy nghĩ:

```text
source relation
   ↓ filter
filtered relation
   ↓ join
joined relation
   ↓ aggregate/window
serving relation
```

Mỗi relation trung gian có:

```text
schema
row meaning / grain
key
expected row count
quality assumptions
```

### Principle 3 – Logical SQL semantics != physical execution

Ta có thể reasoning logic gần với:

```text
FROM / JOIN
→ WHERE
→ GROUP BY / aggregate
→ HAVING
→ window calculation
→ QUALIFY
→ SELECT / DISTINCT
→ ORDER BY / LIMIT
```

Nhưng Databricks optimizer có thể tạo physical plan khác để thực thi hiệu quả hơn.

Không dùng “logical order” để đoán physical operator. Muốn biết physical plan → Lesson 08: `EXPLAIN` + Query Profile.

### Principle 4 – Uniqueness is an assumption until proven

Tên `customer_id` không làm cột tự unique.

Trong analytical/Delta workloads, correctness phải được bảo vệ bằng:

- data contract;
- validation query;
- constraint nếu environment hỗ trợ và semantics phù hợp;
- quality checks trong pipeline.

### Principle 5 – Select only what the contract needs

Databricks SQL hỗ trợ `*` và `* EXCEPT (...)`, nhưng production pipeline vẫn cần schema intent rõ.

`SELECT *` có thể kéo thêm column mới, PII hoặc payload lớn khi source schema thay đổi.

---

## 4. Fundamentals

### 4.1 Relation / row / attribute

Thực dụng cho DE:

- **relation/table result**: tập rows có schema;
- **row**: một observation ở một grain;
- **column**: attribute/expression;
- **key**: tập column nhận diện entity/event/version theo semantics.

SQL query cũng tạo một relation mà CTE/query khác có thể dùng.

### 4.2 Key taxonomy

**Business key**

Đến từ nghiệp vụ:

```text
customer_id
transaction_id
event_id
```

**Surrogate/technical key**

Do platform/pipeline sinh:

```text
ingest_row_id
customer_sk
```

**Composite key**

Nhiều fields cùng xác định grain:

```text
(revenue_date, province)
(customer_id, effective_from)
```

### 4.3 Grain-changing operators

`WHERE` thường preserve grain của rows còn lại.

`JOIN` có thể:

- preserve left/fact grain;
- remove rows;
- fan-out rows;
- tạo Cartesian explosion.

`GROUP BY` đổi grain.

Window function thường preserve row identity.

### 4.4 Databricks query structure

Databricks `SELECT` có thể gồm:

```sql
SELECT ...
FROM ...
WHERE ...
GROUP BY ...
HAVING ...
QUALIFY ...
```

Toàn `Query` còn có thể chứa:

```text
CTE
set operators
ORDER BY
WINDOW
LIMIT / OFFSET
SQL Pipeline Syntax
```

Module này tập trung classic query syntax; SQL Pipeline Syntax chỉ awareness.

### 4.5 Star projection

Exploration:

```sql
SELECT *
FROM customers;
```

Databricks cho phép loại bớt field khỏi star projection:

```sql
SELECT * EXCEPT (email)
FROM customers;
```

Nhưng trong production Gold interface, explicit columns thường làm data contract dễ review hơn.

### 4.6 Validation patterns

**Uniqueness**

```sql
SELECT customer_id, COUNT(*) AS n
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

**Duplicate business event**

```sql
SELECT event_id, COUNT(*) AS versions
FROM network_events
GROUP BY event_id
HAVING COUNT(*) > 1;
```

**Reconciliation**

Aggregate theo dimension rồi so tổng với base metric.

---

## 5. Worked example – Transaction grain → customer grain

### Requirement

> Tổng successful revenue/customer từ 01/08 đến hết 05/08/2026.

### Reasoning

```text
Input grain:  1 row / billing transaction
Filter:       status = success; time [Aug-01, Aug-06)
Output grain: 1 row / customer
Business key: customer_id
```

```sql
SELECT
  customer_id,
  COUNT(*) AS successful_txn_count,
  SUM(amount) AS revenue
FROM billing_transactions
WHERE status = 'success'
  AND transaction_ts >= TIMESTAMP '2026-08-01 00:00:00'
  AND transaction_ts <  TIMESTAMP '2026-08-06 00:00:00'
GROUP BY customer_id
ORDER BY revenue DESC;
```

### Validation 1 – output uniqueness

```sql
WITH result AS (
  SELECT customer_id, SUM(amount) AS revenue
  FROM billing_transactions
  WHERE status = 'success'
    AND transaction_ts >= TIMESTAMP '2026-08-01 00:00:00'
    AND transaction_ts <  TIMESTAMP '2026-08-06 00:00:00'
  GROUP BY customer_id
)
SELECT customer_id, COUNT(*)
FROM result
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Expected: 0 rows.

### Validation 2 – reconciliation

Tổng `revenue` của customer-level output phải bằng base successful amount với cùng filter.

---

## 6. Hands-on lab

Primary setup:

```text
labs/module-02-sql/databricks-setup.sql
```

Tạo `lesson-01.sql` hoặc notebook tương đương.

### Core

1. Ghi grain của 7 tables.
2. Xác định business key và technical key nếu có.
3. Check uniqueness cho `customers.customer_id`, `plans.plan_id`.
4. Chứng minh `network_events.event_id` có nhiều versions.
5. Tính transaction count/customer.
6. Tính successful revenue/customer.
7. Join `customers` → `billing_transactions`; so row count trước/sau và giải thích grain output.
8. Tạo revenue by province và reconcile với base successful revenue.

### Databricks-specific

9. Chạy:

```sql
SELECT * EXCEPT (email)
FROM customers;
```

Giải thích vì sao syntax này tiện cho exploration nhưng không tự thay thế explicit serving contract.

10. Với một query aggregate, chạy `EXPLAIN` và chỉ quan sát rằng physical plan khác logical SQL structure. Chưa cần phân tích sâu.

### Deliverables

```text
lesson-01.sql / notebook
notes.md
```

Mỗi query quan trọng phải có header:

```text
Input grain:
Output grain:
Key:
Cardinality assumption:
Validation:
```

---

## 7. Knowledge check – MCQ

**Q1.** Grain mô tả:  
A. số columns; B. ý nghĩa của một row; C. compute size; D. Delta version.

**Q2.** `GROUP BY customer_id` trên transaction relation thường tạo grain:  
A. transaction; B. customer; C. partition; D. file.

**Q3.** Business key và technical key:  
A. luôn giống nhau; B. có thể khác nhau; C. không dùng trong DE; D. chỉ cho OLTP.

**Q4.** Logical query reasoning có phải physical execution order của Databricks không?  
A. luôn đúng; B. không, optimizer chọn physical plan; C. chỉ với Delta; D. chỉ với SQL Warehouse.

**Q5.** Validation phù hợp cho “1 row/customer”:  
A. `LIMIT 10`; B. `GROUP BY customer_id HAVING COUNT(*) > 1`; C. `ORDER BY`; D. `SELECT *`.

**Q6.** `SELECT * EXCEPT (email)` trong Databricks chủ yếu:  
A. loại column khỏi star projection; B. anti join; C. delete column khỏi table; D. dedup.

---

## 8. Tự luận / Interview

1. Grain là gì và vì sao nó quan trọng hơn việc query “chạy được”? 
2. Vì sao `event_id` duplicate không đồng nghĩa exact duplicate?
3. Logical relation pipeline khác physical query plan thế nào?
4. Khi nào `SELECT *` chấp nhận được? Khi nào nguy hiểm?
5. Cách chứng minh join N:1 thực sự không fan-out?
6. Nếu Gold table có grain `date/province`, key logic là gì?

---

## 9. Exit criteria

- [ ] Mô tả đúng grain của 7 tables.
- [ ] Phân biệt business/technical/composite key.
- [ ] Có >=2 validation query cho aggregate/join.
- [ ] Giải thích logical vs physical execution.
- [ ] Dùng được Databricks star `EXCEPT` và hiểu scope.
- [ ] Đạt >=5/6 MCQ.