# Lesson 06 – Window Functions & QUALIFY on Databricks

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Phân biệt aggregation và window calculation theo output grain.
- Dùng `PARTITION BY`, `ORDER BY`, window frame.
- Phân biệt `ROW_NUMBER`, `RANK`, `DENSE_RANK`.
- Dùng `LAG`/`LEAD` cho previous/next state.
- Tạo running/cumulative metrics.
- Dùng Databricks **`QUALIFY`** để filter window results.
- Viết deterministic latest-row/dedup candidate với tie-breaker rõ.
- Nhận biết named `WINDOW` clause ở mức thực dụng.

---

## 2. Source alignment

### Primary Databricks sources

- Window Functions  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-window-functions
- QUALIFY  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-qualify
- SELECT / WINDOW clause  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select

### Databricks-specific point

`QUALIFY` filter trực tiếp results của window functions. Đây là syntax quan trọng cần biết khi viết Databricks SQL; portable CTE/subquery pattern vẫn hữu ích khi chuyển engine.

---

## 3. Principles

### Principle 1 – Window preserves row identity

`GROUP BY`:

```text
many transaction rows → 1 row/customer
```

Window:

```text
transaction rows remain
+ per-customer rank/total/previous value
```

### Principle 2 – Partition defines group context; order defines sequence

```sql
PARTITION BY customer_id
ORDER BY transaction_ts
```

nghĩa là:

> sequence riêng trong từng customer theo transaction time.

### Principle 3 – Tie semantics are business semantics

- `ROW_NUMBER`: unique ordinal.
- `RANK`: ties same rank + gaps.
- `DENSE_RANK`: ties same rank, no gaps.

Nếu requirement là “tối đa 2 rows/customer”, `ROW_NUMBER` thường phù hợp hơn `RANK` khi ties có thể tạo >2 rows.

### Principle 4 – Determinism needs a complete ordering rule

```sql
ORDER BY effective_from DESC
```

không đủ nếu two rows cùng `effective_from`.

Cần business-valid tie-breaker:

```text
effective_from DESC
recorded_at DESC
status_history_id DESC
```

### Principle 5 – Frame controls window aggregate population

`PARTITION BY` chưa đủ để hiểu running total.

Window frame nói rows nào trong partition tham gia current-row calculation.

---

## 4. Fundamentals

### 4.1 Aggregate vs window

Aggregate:

```sql
SELECT customer_id, SUM(amount) AS revenue
FROM billing_transactions
GROUP BY customer_id;
```

Window:

```sql
SELECT
  transaction_id,
  customer_id,
  amount,
  SUM(amount) OVER (PARTITION BY customer_id) AS customer_total
FROM billing_transactions;
```

### 4.2 ROW_NUMBER

```sql
ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY effective_from DESC, recorded_at DESC, status_history_id DESC
)
```

Core DE use cases:

- latest row/entity;
- deterministic dedup winner;
- top-N per group;
- version selection.

### 4.3 RANK / DENSE_RANK

Values:

```text
100, 100, 90
```

`RANK`:

```text
1, 1, 3
```

`DENSE_RANK`:

```text
1, 1, 2
```

### 4.4 LAG / LEAD

```sql
LAG(revenue) OVER (ORDER BY revenue_date)
LEAD(effective_from) OVER (PARTITION BY customer_id ORDER BY effective_from)
```

Use cases:

- day-over-day;
- previous status;
- derive `effective_to`;
- gap/session reasoning;
- detect changes.

### 4.5 Window aggregate + frame

```sql
SUM(daily_revenue) OVER (
  ORDER BY revenue_date
  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS cumulative_revenue
```

Course rule:

> Với cumulative/moving metric quan trọng, viết frame explicit để intent review được.

### 4.6 Databricks QUALIFY

Portable form:

```sql
WITH ranked AS (
  SELECT
    h.*,
    ROW_NUMBER() OVER (...) AS rn
  FROM customer_status_history h
)
SELECT *
FROM ranked
WHERE rn = 1;
```

Databricks-native form:

```sql
SELECT
  h.*
FROM customer_status_history h
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY effective_from DESC, recorded_at DESC, status_history_id DESC
) = 1;
```

Hoặc alias window expression trong `SELECT` rồi reference alias trong `QUALIFY` nếu query form cho phép.

`QUALIFY` yêu cầu có ít nhất một window function trong SELECT list hoặc QUALIFY condition.

### 4.7 QUALIFY is not HAVING

```text
HAVING  → filter grouped aggregate result
QUALIFY → filter window-function result
```

Đây là distinction rất dễ hỏi khi interview SQL trên analytical engine.

### 4.8 Named WINDOW clause awareness

Khi nhiều expressions reuse cùng partition/order spec, named window có thể giảm lặp.

Concept:

```sql
SELECT
  ...,
  LAG(amount) OVER w,
  SUM(amount) OVER w
FROM ...
WINDOW w AS (PARTITION BY customer_id ORDER BY transaction_ts);
```

Không bắt buộc dùng nếu làm query khó đọc hơn.

---

## 5. Worked example – Latest customer status bằng QUALIFY

### Requirement

Relation output:

```text
Grain: 1 row / customer
Winner: latest effective_from
Tie 1: latest recorded_at
Tie 2: greatest status_history_id
```

```sql
SELECT
  customer_id,
  status,
  effective_from,
  recorded_at
FROM customer_status_history
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY
    effective_from DESC,
    recorded_at DESC,
    status_history_id DESC
) = 1;
```

### Validation

```sql
WITH latest AS (
  SELECT
    customer_id,
    status,
    effective_from,
    recorded_at
  FROM customer_status_history
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY effective_from DESC, recorded_at DESC, status_history_id DESC
  ) = 1
)
SELECT customer_id, COUNT(*) AS n
FROM latest
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Expected: 0 rows.

---

## 6. Hands-on lab

### Part A – Ranking

1. Rank successful transactions by amount globally bằng `RANK`.
2. `ROW_NUMBER` transaction trong từng customer.
3. Top 2 successful transactions/customer bằng `QUALIFY`.
4. Top towers/drop-count với `RANK` vs `DENSE_RANK`.

### Part B – Latest row

5. Latest status/customer bằng CTE form.
6. Viết lại bằng `QUALIFY`.
7. Latest subscription/customer.
8. Latest ingested version/event_id.
9. Với mỗi bài, thêm deterministic tie-breaker.

### Part C – LAG/LEAD

10. Daily revenue + previous-day revenue.
11. Absolute / percentage day-over-day change.
12. Previous customer status bằng `LAG`.
13. Derive `effective_to` bằng `LEAD(effective_from)`.
14. Tìm time gap giữa status changes.

### Part D – Window aggregate

15. Cumulative successful revenue/day.
16. Cumulative revenue/province.
17. Transaction contribution % vào customer total.

### Part E – Databricks-specific

18. Viết một query dùng `HAVING` và một query dùng `QUALIFY`; giải thích population được filter ở hai stage khác nhau.
19. Nếu convenient, thử named `WINDOW` để reuse same partition/order spec.

### Challenge – session boundary

Với `network_events`, dùng `LAG(event_ts)` theo customer, đánh dấu `new_session = 1` nếu gap > 30 phút.

---

## 7. Knowledge check – MCQ

**Q1.** Window function thường:  
A. collapse rows; B. preserve row identity; C. delete rows; D. create table.

**Q2.** `QUALIFY` trong Databricks filter:  
A. window results; B. pre-FROM rows; C. table history; D. Delta versions.

**Q3.** `HAVING` chủ yếu filter:  
A. window output; B. grouped aggregate result; C. input files; D. join hints.

**Q4.** `ROW_NUMBER` với ties:  
A. same number; B. unique ordinal according to ordering; C. null; D. syntax error.

**Q5.** `RANK` for 100,100,90:  
A. 1,1,2; B. 1,1,3; C. 1,2,3; D. 0,0,1.

**Q6.** Latest-row tie-breaker cần để:  
A. deterministic/business-defined winner; B. Photon on; C. cluster table; D. SUM faster.

**Q7.** Running total phụ thuộc thêm vào:  
A. window frame; B. only GROUP BY; C. MERGE; D. ANTI JOIN.

---

## 8. Tự luận / Interview

1. `GROUP BY` vs window khác nhau ở grain thế nào?
2. `HAVING` vs `QUALIFY`.
3. Vì sao QUALIFY giúp latest-row query ngắn hơn?
4. `ROW_NUMBER` vs `RANK`: tie semantics.
5. Vì sao ordering không đầy đủ làm dedup nondeterministic?
6. Window frame là gì?
7. `LEAD` hỗ trợ SCD/history reasoning như thế nào?

---

## 9. Exit criteria

- [ ] Dùng đúng ROW_NUMBER/RANK/DENSE_RANK.
- [ ] Viết latest-row bằng QUALIFY.
- [ ] Phân biệt HAVING/QUALIFY.
- [ ] Dùng LAG/LEAD.
- [ ] Viết running total frame explicit.
- [ ] Giải thích deterministic ordering.
- [ ] Đạt >=6/7 MCQ.