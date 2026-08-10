# Lesson 03 – Aggregation, GROUP BY, HAVING & Databricks Aggregate Patterns

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Chuyển input grain → output grain bằng aggregation có chủ đích.
- Phân biệt `WHERE` và `HAVING` theo Databricks SQL semantics.
- Dùng `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`, `COUNT(DISTINCT ...)` đúng nghĩa.
- Dùng Databricks aggregate `FILTER` và `count_if` khi phù hợp.
- Nhận diện double-counting do join trước aggregation.
- Viết ratio metric có denominator rõ.
- Reconcile aggregate result với base population.
- Nhận biết `GROUPING SETS` / `ROLLUP` / `CUBE` ở mức awareness.

---

## 2. Source alignment

### Primary Databricks sources

- `GROUP BY`  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-groupby
- `HAVING`  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-having
- `count_if`  
  https://docs.databricks.com/aws/en/sql/language-manual/functions/count_if
- SQL built-in functions  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-functions

### Scope note

Databricks hỗ trợ advanced grouping (`GROUPING SETS`, `ROLLUP`, `CUBE`) và aggregate `FILTER`. Module này ưu tiên metric correctness trước; advanced grouping chỉ cần hiểu use case, không học syntax exhaustive.

---

## 3. Principles

### Principle 1 – GROUP BY changes grain

```text
Input:  1 row / transaction
GROUP BY customer_id
Output: 1 row / customer
```

Hoặc:

```text
GROUP BY CAST(transaction_ts AS DATE), province
→ 1 row / day / province
```

Nếu `GROUP BY` không phản ánh output grain, metric chưa có contract rõ.

### Principle 2 – Metric definition comes before function choice

“Revenue” có thể là:

```text
all amount
successful amount only
successful minus refunds
recognized revenue in accounting period
```

`SUM(amount)` không tự quyết định business semantics.

### Principle 3 – Aggregate after cardinality reasoning

Fact × history join có thể multiply fact rows trước `SUM`.

Query vẫn chạy và kết quả vẫn “có vẻ hợp lý”, nên double-count nguy hiểm hơn syntax error.

### Principle 4 – Reconciliation is part of the query design

Một Gold metric quan trọng nên có independent check:

```text
sum(grouped output) == base total under same population/filter
```

---

## 4. Fundamentals

### 4.1 Core aggregate functions

```sql
COUNT(*)
COUNT(email)
COUNT(DISTINCT customer_id)
SUM(amount)
AVG(amount)
MIN(amount)
MAX(amount)
```

Semantics:

- `COUNT(*)`: rows;
- `COUNT(expr)`: non-NULL values;
- `COUNT(DISTINCT expr)`: distinct non-NULL expression values.

### 4.2 WHERE vs HAVING

```sql
SELECT
  customer_id,
  SUM(amount) AS revenue
FROM billing_transactions
WHERE status = 'success'
GROUP BY customer_id
HAVING SUM(amount) >= 200000;
```

`WHERE` chọn base rows.

`HAVING` chọn aggregate groups.

### 4.3 Conditional aggregation – portable form

```sql
SELECT
  customer_id,
  SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) AS success_amount,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count
FROM billing_transactions
GROUP BY customer_id;
```

### 4.4 Databricks aggregate FILTER

Databricks aggregate functions có thể nhận `FILTER (WHERE ...)`.

```sql
SELECT
  customer_id,
  SUM(amount) FILTER (WHERE status = 'success') AS success_amount,
  COUNT(*) FILTER (WHERE status = 'failed') AS failed_count
FROM billing_transactions
GROUP BY customer_id;
```

`FILTER` giúp metric population explicit ngay cạnh aggregate.

### 4.5 `count_if`

```sql
SELECT
  customer_id,
  count_if(status = 'success') AS success_count,
  count_if(status = 'failed') AS failed_count
FROM billing_transactions
GROUP BY customer_id;
```

Dùng khi intent chính là đếm TRUE conditions.

### 4.6 Ratio metrics

Call-drop rate:

```sql
WITH tower_metric AS (
  SELECT
    tower_id,
    count_if(event_type = 'call_drop') AS drops,
    count_if(event_type IN ('call_drop','call_end')) AS total_calls
  FROM network_events
  GROUP BY tower_id
)
SELECT
  tower_id,
  drops,
  total_calls,
  CAST(drops AS DOUBLE) / NULLIF(total_calls, 0) AS drop_rate
FROM tower_metric;
```

Nhưng raw `network_events` có duplicate versions → metric chưa canonical. Dedup ở Lesson 07.

### 4.7 Average-of-averages trap

Nếu group sizes khác nhau:

```text
AVG(group_avg)
```

không nhất thiết bằng overall average.

Muốn overall metric, aggregate base numerator/denominator hoặc dùng weighted formulation.

### 4.8 DISTINCT is not a join repair tool

`COUNT(DISTINCT customer_id)` có thể đúng theo business metric.

Nhưng:

```sql
SELECT DISTINCT ...
```

thêm sau fan-out chỉ để “hết duplicate” là warning sign.

### 4.9 Advanced grouping awareness

Databricks hỗ trợ:

```text
GROUPING SETS
ROLLUP
CUBE
GROUP BY ALL
```

Use case: tính nhiều subtotal/granularity từ cùng input.

Module này không yêu cầu nhớ syntax chi tiết; cần biết chúng là **multi-grain aggregations** và output phải được interpret cẩn thận.

---

## 5. Worked example – Daily province revenue

### Requirement

Successful revenue theo ngày/province.

```text
billing_transactions: 1 row / transaction
customers:            1 row / customer
join:                 N:1 nếu customer key unique
output:               1 row / date / province
```

```sql
SELECT
  CAST(b.transaction_ts AS DATE) AS revenue_date,
  c.province,
  COUNT(*) AS successful_txn_count,
  COUNT(DISTINCT b.customer_id) AS unique_paying_customers,
  SUM(b.amount) AS successful_revenue
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY
  CAST(b.transaction_ts AS DATE),
  c.province
ORDER BY revenue_date, province;
```

### Databricks alternative metrics

```sql
SELECT
  CAST(transaction_ts AS DATE) AS revenue_date,
  SUM(amount) FILTER (WHERE status = 'success') AS successful_revenue,
  count_if(status = 'failed') AS failed_count,
  count_if(status = 'refunded') AS refunded_count
FROM billing_transactions
GROUP BY CAST(transaction_ts AS DATE)
ORDER BY revenue_date;
```

### Reconciliation

Grouped successful revenue phải reconcile với:

```sql
SELECT SUM(amount)
FROM billing_transactions
WHERE status = 'success';
```

Nếu khác sau join dimension, kiểm tra:

- orphan keys;
- dimension duplicates;
- filter mismatch;
- join condition.

---

## 6. Hands-on lab

### Core

1. Revenue theo `transaction_type`.
2. Revenue/day.
3. Revenue/day/province.
4. Customer có successful revenue >= 200k bằng `HAVING`.
5. Average successful amount/payment method.
6. Reconcile revenue by province với base total.

### Databricks-specific

7. Viết cùng một conditional metric bằng:

```text
SUM(CASE...)
aggregate FILTER
count_if
```

và giải thích khi nào mỗi form rõ hơn.

8. Tạo daily metric:

```text
successful_revenue
successful_count
failed_count
refunded_count
unique_paying_customers
```

9. Thử một `ROLLUP` hoặc `GROUPING SETS` đơn giản cho province/date và xác định rows subtotal.

### Fan-out experiment

10. Join billing với `customer_status_history` chỉ theo `customer_id`, sau đó `SUM(amount)`.
11. Đo:

```text
base successful rows
joined rows
base revenue
joined revenue
```

12. Mô tả relation đúng cần tạo trước khi aggregate.

### Challenge

Tạo KPI network per tower:

```text
total_call_events
drops
drop_rate
avg_signal_dbm
```

Sau đó ghi rõ vì sao result trên raw events chưa publish được nếu business key duplicate.

---

## 7. Knowledge check – MCQ

**Q1.** `GROUP BY customer_id` thường:  
A. preserve transaction grain; B. đổi output sang customer grain; C. create Delta version; D. broadcast table.

**Q2.** `WHERE` vs `HAVING`:  
A. WHERE base rows, HAVING groups; B. giống nhau; C. HAVING trước FROM; D. WHERE chỉ string.

**Q3.** `count_if(status='failed')`:  
A. đếm TRUE values; B. sum amount; C. dedup; D. anti join.

**Q4.** Aggregate `FILTER` trong Databricks:  
A. filter rows đưa vào aggregate function; B. filter toàn table physically bắt buộc; C. create view; D. window only.

**Q5.** Fact join history nhiều version rồi SUM có risk:  
A. fan-out/double-count; B. syntax fail chắc chắn; C. NULL auto zero; D. MERGE.

**Q6.** `SELECT DISTINCT` sau join fan-out:  
A. luôn fix; B. có thể che bug cardinality; C. required Databricks pattern; D. tương đương GROUP BY ALL.

**Q7.** Overall average từ unweighted average-of-averages có thể sai vì:  
A. group sizes khác nhau; B. Databricks không có AVG; C. Delta không numeric; D. window frame.

---

## 8. Tự luận / Interview

1. `GROUP BY` thay đổi grain thế nào?
2. `FILTER` vs `CASE` conditional aggregation khác nhau chủ yếu ở đâu?
3. `count_if` phù hợp với metric nào?
4. Vì sao KPI phải định nghĩa numerator/denominator trước SQL?
5. Cách chứng minh join làm revenue double-count?
6. `ROLLUP`/`CUBE` tạo thách thức gì cho output grain?
7. Reconciliation query nên độc lập ở mức nào với query chính?

---

## 9. Exit criteria

- [ ] Ghi input/output grain cho mọi aggregate lab.
- [ ] Phân biệt WHERE/HAVING.
- [ ] Dùng được CASE, FILTER và count_if.
- [ ] Tự tạo và đo join fan-out.
- [ ] Có reconciliation query.
- [ ] Nhận biết grouping sets/rollup/cube.
- [ ] Đạt >=6/7 MCQ.