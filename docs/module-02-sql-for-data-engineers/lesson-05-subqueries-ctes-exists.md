# Lesson 05 – Subqueries, CTEs & EXISTS

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Dùng scalar subquery, derived table và correlated subquery đúng mục đích.
- Dùng CTE để chia query thành các relations trung gian có grain rõ.
- Biết khi nào `EXISTS`/`NOT EXISTS` diễn đạt intent tốt hơn join.
- Phân biệt readability với performance assumption: CTE không phải “optimization trick” mặc định.
- Viết query nhiều bước theo pipeline reasoning: filter → aggregate → rank → final select.
- Tránh repeated logic và ambiguous grain trong query dài.

---

## 2. Principles

### Principle 1 – Decompose by meaning, not by line count

Một CTE tốt nên đại diện cho một relation có tên và grain rõ:

```text
successful_billing
revenue_by_customer
latest_status
active_subscriptions
```

Đừng chia query thành 10 CTE chỉ vì mỗi CTE ngắn hơn.

### Principle 2 – Each intermediate relation needs a contract

Với mỗi CTE, bạn nên nói được:

```text
Purpose:
Grain:
Key:
Filters:
Expected uniqueness:
```

### Principle 3 – EXISTS answers existence

Nếu business question là “có hay không”, dùng relation semantics của existence. Join chỉ để check existence có thể nhân rows rồi lại cần DISTINCT.

### Principle 4 – Readability first, planner behavior second

Modern SQL engines có thể inline/materialize CTE khác nhau tùy engine/version/query. Đừng học thuộc câu “CTE luôn chậm” hoặc “CTE luôn materialize”. Hãy dùng `EXPLAIN` để xác nhận khi performance quan trọng.

---

## 3. Fundamentals

### 3.1 Scalar subquery

Trả một value:

```sql
SELECT
    customer_id,
    amount,
    (SELECT AVG(amount)
     FROM billing_transactions
     WHERE status = 'success') AS global_avg
FROM billing_transactions;
```

Nếu subquery trả nhiều hơn một row trong ngữ cảnh scalar, query lỗi.

### 3.2 Derived table

Subquery trong `FROM` tạo relation:

```sql
SELECT *
FROM (
    SELECT customer_id, SUM(amount) AS revenue
    FROM billing_transactions
    WHERE status = 'success'
    GROUP BY customer_id
) r
WHERE r.revenue >= 200000;
```

### 3.3 Correlated subquery

Subquery tham chiếu outer row:

```sql
SELECT c.customer_id
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM billing_transactions b
    WHERE b.customer_id = c.customer_id
      AND b.status = 'success'
);
```

Logical meaning: với mỗi customer, hỏi có row phù hợp tồn tại không.

Engine có thể rewrite thành plan hiệu quả; không nên suy luận runtime chỉ từ syntax.

### 3.4 CTE

```sql
WITH successful_billing AS (
    SELECT *
    FROM billing_transactions
    WHERE status = 'success'
),
revenue_by_customer AS (
    SELECT
        customer_id,
        SUM(amount) AS revenue
    FROM successful_billing
    GROUP BY customer_id
)
SELECT *
FROM revenue_by_customer
WHERE revenue >= 200000;
```

CTE ở đây giúp expose pipeline logic.

### 3.5 CTE naming

Tên tốt:

```text
successful_transactions
revenue_by_customer
customer_with_plan
```

Tên kém:

```text
t1
cte2
temp
abc
```

Trong interview, tên relation rõ giúp interviewer theo reasoning.

### 3.6 `IN` vs `EXISTS`

Cả hai có thể biểu đạt membership/existence. Nhưng cần chú ý NULL semantics, đặc biệt `NOT IN`.

Khi relation phụ có thể chứa NULL và intent là anti-join, `NOT EXISTS` thường dễ reasoning an toàn hơn.

### 3.7 Recursive CTE – awareness level

Recursive CTE dùng cho hierarchy/graph-like traversal như org tree, category tree hoặc dependency chain.

Module này chỉ cần nhận biết, không bắt buộc luyện sâu cho VDT fresher DE.

---

## 4. Worked example – Revenue from active-plan customers

### Business question

> Tổng successful revenue theo plan hiện tại là bao nhiêu?

Ta chia thành relations:

```text
active_subscriptions
Grain: 1 row / current subscription

successful_billing
Grain: 1 row / successful transaction

billing_with_active_plan
Grain: transaction, nếu mỗi customer chỉ có 1 active subscription theo rule hiện tại
```

```sql
WITH active_subscriptions AS (
    SELECT
        subscription_id,
        customer_id,
        plan_id
    FROM subscriptions
    WHERE status = 'active'
      AND ended_at IS NULL
),
successful_billing AS (
    SELECT
        transaction_id,
        customer_id,
        amount
    FROM billing_transactions
    WHERE status = 'success'
)
SELECT
    p.plan_name,
    SUM(b.amount) AS revenue
FROM successful_billing b
JOIN active_subscriptions s
  ON s.customer_id = b.customer_id
JOIN plans p
  ON p.plan_id = s.plan_id
GROUP BY p.plan_name
ORDER BY revenue DESC;
```

### Validation question

Trước khi tin query, kiểm tra:

```sql
SELECT customer_id, COUNT(*)
FROM subscriptions
WHERE status = 'active'
  AND ended_at IS NULL
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Nếu trả rows, active-subscription relation không unique/customer; join có thể fan-out.

CTE không cứu correctness nếu grain assumption sai.

---

## 5. Hands-on lab

Tạo `lesson-05.sql`.

### Part A – Subquery

1. Transaction có amount lớn hơn average successful amount.
2. Customer có successful revenue lớn hơn average revenue/customer.
3. Tower có số `call_drop` lớn hơn average drop count/tower.

### Part B – EXISTS

1. Customer có ít nhất một successful transaction.
2. Customer có active subscription nhưng chưa successful transaction.
3. Tower có event nhưng không có `call_drop`.
4. Plan đang được ít nhất một customer sử dụng.

Viết mỗi bài bằng `EXISTS`/`NOT EXISTS`. Sau đó thử viết bằng join và so sánh clarity/cardinality.

### Part C – CTE pipeline

Viết query gồm ít nhất 3 CTE:

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

Rule revenue band:

- `<100k`: low;
- `100k–<500k`: medium;
- `>=500k`: high.

### Part D – Data-quality CTE

Tạo CTE:

```text
duplicate_network_event_ids
```

chứa `event_id`, row_count, max payload_version, latest ingested_at cho event bị duplicate.

### Challenge

Viết query trả province có:

- ít nhất 2 customers;
- ít nhất 1 successful transaction;
- total revenue cao hơn average revenue/province.

Bắt buộc chia thành các CTE có comment grain.

---

## 6. Knowledge check – MCQ

**Q1.** CTE tốt nhất nên đại diện cho:  
A. một relation trung gian có purpose/grain rõ; B. mỗi dòng SQL; C. một index; D. một transaction DB.

**Q2.** Business question “customer nào có ít nhất một payment?” phù hợp tự nhiên với:  
A. EXISTS; B. CROSS JOIN; C. ORDER BY; D. UNION ALL bắt buộc.

**Q3.** `NOT IN` nguy hiểm hơn khi subquery có:  
A. NULL; B. integer; C. primary key; D. ORDER BY.

**Q4.** CTE có đảm bảo input bên trong unique không?  
A. Có; B. Không, uniqueness vẫn phải kiểm chứng; C. chỉ PostgreSQL; D. chỉ khi tên có `unique`.

**Q5.** Nhận định “CTE luôn materialize và luôn chậm” là:  
A. universal SQL law; B. không nên mặc định, phụ thuộc engine/planner/query; C. luôn đúng; D. đúng với mọi cloud DW.

**Q6.** Scalar subquery trong scalar context phải:  
A. trả đúng một value/row theo yêu cầu context; B. luôn 100 rows; C. dùng GROUP BY; D. có JOIN.

---

## 7. Knowledge check – Tự luận / Interview

1. Khi nào CTE tăng readability nhưng không làm query đúng hơn?
2. `EXISTS` khác join + DISTINCT ở semantics và reasoning thế nào?
3. Correlated subquery là gì?
4. Vì sao query nhiều CTE vẫn có thể double-count?
5. Khi nào bạn chọn derived table thay vì CTE?
6. Hãy mô tả một query 4 bước như pipeline relations mà không viết SQL.
7. Tại sao không nên tối ưu query dựa trên assumption “syntax X luôn nhanh hơn syntax Y” mà chưa xem plan?

---

## 8. Exit criteria

- [ ] Mỗi CTE lab có comment grain/key.
- [ ] Viết được semi-join và anti-join bằng EXISTS.
- [ ] Không dùng `NOT IN` thiếu suy nghĩ khi relation có thể chứa NULL.
- [ ] Viết được query pipeline >=3 CTE mà mỗi bước có purpose rõ.
- [ ] Tự kiểm tra uniqueness trước join CTE.
- [ ] Đạt ít nhất 5/6 MCQ.