# Lesson 05 – Subqueries, CTEs & Reusable Relations in Databricks SQL

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Dùng scalar subquery, derived table và correlated subquery đúng intent.
- Dùng CTE để chia query thành relations trung gian có grain/key rõ.
- So sánh `EXISTS`/`NOT EXISTS` với Databricks SEMI/ANTI JOIN.
- Không coi CTE là optimization trick mặc định.
- Nhận biết `WITH RECURSIVE` trong Databricks Runtime/SQL hiện đại ở mức awareness.
- Viết query nhiều bước theo Data Engineering pipeline reasoning.

---

## 2. Source alignment

### Primary Databricks sources

- Query / CTE  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-query  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-cte
- JOIN / SEMI / ANTI  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-join
- EXPLAIN  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-explain

### Version note

Databricks hỗ trợ recursive CTE với `WITH RECURSIVE` ở các runtime/version hiện hành được ghi trong official docs. Luôn đọc `Applies to` trước khi dùng feature version-sensitive.

---

## 3. Principles

### Principle 1 – Decompose by relation meaning

CTE tốt:

```text
successful_billing
revenue_by_customer
latest_status
active_subscriptions
```

CTE kém:

```text
t1
step2
abc
```

Tên nên mô tả **meaning**, không chỉ thứ tự.

### Principle 2 – Every intermediate relation has a contract

Với mỗi CTE:

```text
Purpose:
Grain:
Business key:
Filters:
Expected uniqueness:
```

Nếu CTE tên `latest_customer_status` nhưng vẫn 3 rows/customer, tên không làm query đúng.

### Principle 3 – Existence should stay existence

Nếu câu hỏi là “có match hay không”, `EXISTS`, `LEFT SEMI JOIN`, `NOT EXISTS`, `LEFT ANTI JOIN` thường rõ hơn join + `DISTINCT`.

### Principle 4 – Syntax does not guarantee execution strategy

Không học thuộc:

```text
CTE always materializes
CTE always inlines
correlated subquery always slow
JOIN always faster than EXISTS
```

Databricks optimizer quyết định plan. Khi performance quan trọng → `EXPLAIN` / Query Profile.

---

## 4. Fundamentals

### 4.1 Scalar subquery

```sql
SELECT
  transaction_id,
  amount,
  (SELECT AVG(amount)
   FROM billing_transactions
   WHERE status = 'success') AS global_success_avg
FROM billing_transactions;
```

Scalar context yêu cầu một scalar result.

### 4.2 Derived table

```sql
SELECT *
FROM (
  SELECT customer_id, SUM(amount) AS revenue
  FROM billing_transactions
  WHERE status = 'success'
  GROUP BY customer_id
) r
WHERE revenue >= 200000;
```

Subquery trong `FROM` là relation có thể join/filter tiếp.

### 4.3 Correlated EXISTS

```sql
SELECT c.customer_id, c.full_name
FROM customers c
WHERE EXISTS (
  SELECT 1
  FROM billing_transactions b
  WHERE b.customer_id = c.customer_id
    AND b.status = 'success'
);
```

Logical meaning:

> với customer hiện tại, có ít nhất một matching transaction không?

### 4.4 CTE pipeline

```sql
WITH successful_billing AS (
  SELECT
    transaction_id,
    customer_id,
    amount
  FROM billing_transactions
  WHERE status = 'success'
),
revenue_by_customer AS (
  SELECT
    customer_id,
    COUNT(*) AS txn_count,
    SUM(amount) AS revenue
  FROM successful_billing
  GROUP BY customer_id
)
SELECT *
FROM revenue_by_customer
WHERE revenue >= 200000;
```

### 4.5 CTE + validation

Không chỉ viết result:

```sql
WITH active_subscriptions AS (...)
SELECT customer_id, COUNT(*)
FROM active_subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Nếu business assumption là 1 current subscription/customer, check này phải trả 0 rows.

### 4.6 EXISTS vs LEFT SEMI JOIN

Databricks-native equivalent intent:

```sql
SELECT c.*
FROM customers c
LEFT SEMI JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

`EXISTS` thường đọc tự nhiên trong predicate logic; SEMI JOIN thường đọc tự nhiên khi thinking in relations. Chọn form rõ intent và team convention.

### 4.7 Recursive CTE awareness

Recursive CTE hữu ích cho:

- hierarchy;
- parent-child traversal;
- graph/dependency chain;
- bill-of-materials-like structures.

Concept:

```text
base case
UNION ALL
recursive step referencing CTE
termination / recursion limit
```

VDT fresher chỉ cần hiểu use case và danger of non-termination/explosion, chưa cần luyện graph SQL sâu.

---

## 5. Worked example – Revenue by active plan

### Relations

```text
active_subscriptions
Grain: 1 row / active subscription

successful_billing
Grain: 1 row / successful transaction

final
Grain: 1 row / plan
```

```sql
WITH active_subscriptions AS (
  SELECT customer_id, plan_id
  FROM subscriptions
  WHERE status = 'active'
    AND ended_at IS NULL
),
successful_billing AS (
  SELECT customer_id, amount
  FROM billing_transactions
  WHERE status = 'success'
)
SELECT
  p.plan_name,
  SUM(b.amount) AS successful_revenue
FROM successful_billing b
JOIN active_subscriptions s
  ON s.customer_id = b.customer_id
JOIN plans p
  ON p.plan_id = s.plan_id
GROUP BY p.plan_name
ORDER BY successful_revenue DESC;
```

### Correctness gate

Trước khi tin final:

```sql
WITH active_subscriptions AS (
  SELECT customer_id, plan_id
  FROM subscriptions
  WHERE status = 'active'
    AND ended_at IS NULL
)
SELECT customer_id, COUNT(*) AS active_rows
FROM active_subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Nếu có rows → final join có thể fan-out. CTE không tự đảm bảo grain.

---

## 6. Hands-on lab

### Part A – Subqueries

1. Successful transaction có amount > global successful average.
2. Customer revenue > average revenue/customer.
3. Tower drop count > average drop count/tower.

### Part B – Existence

4. Customer có successful payment bằng `EXISTS`.
5. Viết lại bằng `LEFT SEMI JOIN`.
6. Customer có active subscription nhưng không successful payment bằng `NOT EXISTS`.
7. Viết lại bằng `LEFT ANTI JOIN`.
8. So row count/output semantics của hai form.

### Part C – CTE pipeline

9. Viết >=3 CTE:

```text
successful_billing
revenue_by_customer
customer_revenue_with_profile
```

Output:

```text
customer_id
full_name
province
successful_txn_count
revenue
revenue_band
```

10. Mỗi CTE phải có comment `grain/key`.
11. Thêm validation CTE/query để prove final 1 row/customer.

### Part D – Data-quality relation

12. Tạo `duplicate_network_event_ids` chứa:

```text
event_id
row_count
max_payload_version
latest_ingested_at
```

### Challenge – Recursive CTE awareness

Tạo một tiny `VALUES` hierarchy:

```text
node_id | parent_id
```

Nếu runtime hỗ trợ recursive CTE, thử traverse từ root. Nếu environment không support version đó, chỉ viết pseudo-SQL và giải thích base/recursive step.

---

## 7. Knowledge check – MCQ

**Q1.** CTE tốt nên đại diện:  
A. relation trung gian có meaning/grain rõ; B. mỗi line SQL; C. index; D. file partition.

**Q2.** CTE có tự enforce uniqueness không?  
A. Có; B. Không; C. chỉ Delta; D. chỉ SQL Warehouse.

**Q3.** Business question “có transaction không?” phù hợp với:  
A. EXISTS hoặc SEMI JOIN; B. CROSS JOIN; C. CUBE; D. MERGE bắt buộc.

**Q4.** “CTE luôn materialize” là:  
A. universal rule; B. assumption không nên dùng; xem optimizer/plan; C. Databricks guarantee; D. Delta constraint.

**Q5.** Recursive CTE cần:  
A. base + recursive step + termination reasoning; B. index; C. Photon off; D. MERGE.

**Q6.** `NOT EXISTS` và LEFT ANTI JOIN chủ yếu diễn đạt:  
A. absence of match; B. full outer result; C. ranking; D. aggregation.

---

## 8. Tự luận / Interview

1. Vì sao CTE tăng readability nhưng không đảm bảo correctness?
2. CTE contract nên chứa gì?
3. EXISTS vs SEMI JOIN khác nhau về cách diễn đạt thế nào?
4. Tại sao không đoán performance từ syntax alone?
5. Recursive CTE phù hợp use case nào?
6. Query nhiều CTE vẫn double-count bằng cách nào?

---

## 9. Exit criteria

- [ ] Mỗi CTE có purpose/grain/key.
- [ ] Dùng EXISTS/NOT EXISTS.
- [ ] Dùng SEMI/ANTI JOIN tương đương intent.
- [ ] Viết >=3-step CTE pipeline có validation.
- [ ] Hiểu recursive CTE awareness/version sensitivity.
- [ ] Không phát biểu performance universal từ syntax.
- [ ] Đạt >=5/6 MCQ.