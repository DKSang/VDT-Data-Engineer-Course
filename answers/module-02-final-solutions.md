# Module 02 Final Assessment – Suggested Solutions

> Đây là **suggested solutions**, không phải cách viết duy nhất. Một query khác vẫn đúng nếu grain, semantics và validation đúng.

---

# Phần A – MCQ

```text
1B  2A  3B  4B  5B
6A  7A  8A  9B  10A
11A 12B 13A 14B 15A
16A 17B 18A 19A 20B
```

---

# Phần B – SQL Coding

## B1 – Revenue by province/day

**Grain:** 1 row / revenue_date / province.

```sql
SELECT
    b.transaction_ts::date AS revenue_date,
    c.province,
    COUNT(*) AS successful_txn_count,
    COUNT(DISTINCT b.customer_id) AS unique_paying_customers,
    SUM(b.amount) AS successful_revenue
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY
    b.transaction_ts::date,
    c.province
ORDER BY revenue_date, province;
```

Reconciliation:

```sql
WITH x AS (
    SELECT
        b.transaction_ts::date AS revenue_date,
        c.province,
        SUM(b.amount) AS revenue
    FROM billing_transactions b
    JOIN customers c ON c.customer_id = b.customer_id
    WHERE b.status = 'success'
    GROUP BY b.transaction_ts::date, c.province
)
SELECT SUM(revenue) FROM x;

SELECT SUM(amount)
FROM billing_transactions
WHERE status = 'success';
```

Hai totals phải bằng nhau nếu mọi billing customer đều match dimension đúng 1 row.

## B2 – Customers without successful payment

**Grain:** 1 row/customer.

```sql
SELECT
    c.customer_id,
    c.full_name,
    c.province
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM billing_transactions b
    WHERE b.customer_id = c.customer_id
      AND b.status = 'success'
);
```

Không cần join + DISTINCT vì output chỉ cần relation `customers` và một existence predicate.

## B3 – Latest customer status

**Grain:** 1 row/customer.

```sql
WITH ranked AS (
    SELECT
        h.*,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                effective_from DESC,
                recorded_at DESC,
                status_history_id DESC
        ) AS rn
    FROM customer_status_history h
)
SELECT
    customer_id,
    status,
    effective_from,
    recorded_at
FROM ranked
WHERE rn = 1;
```

Validation:

```sql
WITH latest AS (
    -- query above
)
SELECT customer_id, COUNT(*)
FROM latest
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Expected 0 rows.

## B4 – Top 2 successful transactions/customer

Output grain: transaction rows selected by rank rule.

```sql
WITH ranked AS (
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                amount DESC,
                transaction_ts DESC,
                transaction_id DESC
        ) AS rn
    FROM billing_transactions b
    WHERE status = 'success'
)
SELECT *
FROM ranked
WHERE rn <= 2
ORDER BY customer_id, rn;
```

`ROW_NUMBER` phù hợp vì requirement muốn tối đa 2 rows/customer, kể cả khi amount tie.

## B5 – Day-over-day revenue

**Grain:** 1 row/day.

```sql
WITH daily AS (
    SELECT
        transaction_ts::date AS revenue_date,
        SUM(amount) AS revenue
    FROM billing_transactions
    WHERE status = 'success'
    GROUP BY transaction_ts::date
),
with_prev AS (
    SELECT
        revenue_date,
        revenue,
        LAG(revenue) OVER (ORDER BY revenue_date) AS previous_day_revenue
    FROM daily
)
SELECT
    revenue_date,
    revenue,
    previous_day_revenue,
    revenue - previous_day_revenue AS absolute_change,
    (revenue - previous_day_revenue)
        / NULLIF(previous_day_revenue, 0) AS pct_change
FROM with_prev
ORDER BY revenue_date;
```

Lưu ý: nếu calendar day không có transaction thì relation `daily` không sinh row ngày đó. Nếu business cần continuous calendar, phải join với calendar dimension/date series.

## B6 – Deduplicated network drop rate

```sql
WITH ranked AS (
    SELECT
        n.*,
        ROW_NUMBER() OVER (
            PARTITION BY event_id
            ORDER BY
                payload_version DESC,
                ingested_at DESC,
                ingest_row_id DESC
        ) AS rn
    FROM network_events n
),
dedup AS (
    SELECT *
    FROM ranked
    WHERE rn = 1
)
SELECT
    tower_id,
    SUM(CASE WHEN event_type = 'call_drop' THEN 1 ELSE 0 END)::numeric
      / NULLIF(
          SUM(CASE WHEN event_type IN ('call_drop','call_end') THEN 1 ELSE 0 END),
          0
        ) AS call_drop_rate
FROM dedup
GROUP BY tower_id
ORDER BY tower_id;
```

Uniqueness validation:

```sql
WITH dedup AS (...)
SELECT event_id, COUNT(*)
FROM dedup
GROUP BY event_id
HAVING COUNT(*) > 1;
```

Expected 0 rows.

## B7 – Active-plan revenue

Check assumption trước:

```sql
SELECT customer_id, COUNT(*)
FROM subscriptions
WHERE status = 'active'
  AND ended_at IS NULL
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Nếu 0 rows:

```sql
WITH active_subscriptions AS (
    SELECT customer_id, plan_id
    FROM subscriptions
    WHERE status = 'active'
      AND ended_at IS NULL
)
SELECT
    p.plan_name,
    SUM(b.amount) AS successful_revenue
FROM billing_transactions b
JOIN active_subscriptions s
  ON s.customer_id = b.customer_id
JOIN plans p
  ON p.plan_id = s.plan_id
WHERE b.status = 'success'
GROUP BY p.plan_name
ORDER BY successful_revenue DESC;
```

Nếu assumption không đúng, business rule phải xác định subscription nào là current winner thay vì tiếp tục aggregate.

## B8 – Incremental candidate set

Một convention hợp lệ:

```text
(last_watermark, upper_bound]
```

```sql
SELECT *
FROM billing_transactions
WHERE updated_at >  TIMESTAMP '2026-08-03 00:00:00'
  AND updated_at <= TIMESTAMP '2026-08-06 00:00:00';
```

Một convention `[last, upper)` cũng hợp lệ nếu checkpoint semantics nhất quán và target idempotent.

**Retry risk:** append lại cùng candidate rows tạo duplicate.

**Target business/upsert key:** `transaction_id` cho dataset này.

**Potential miss:** hard delete không tạo row/update timestamp, hoặc backdated update có `updated_at` không tăng theo contract.

---

# Phần C – Debugging & Correctness

## C1 – Revenue triples

Root cause: `customer_status_history` nhiều row/customer. Billing fact join history chỉ bằng customer_id nên mỗi transaction match nhiều status rows.

Fan-out proof:

```sql
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT b.transaction_id) AS distinct_transactions
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
WHERE b.status = 'success';
```

Hoặc per transaction:

```sql
SELECT
    b.transaction_id,
    COUNT(*) AS copies_after_join
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
GROUP BY b.transaction_id
HAVING COUNT(*) > 1;
```

Fix: tạo relation history đúng grain theo business requirement, ví dụ latest-status 1 row/customer hoặc point-in-time status 1 version/fact timestamp.

`DISTINCT` không phải fix vì rows khác status/history fields có thể không identical, và ngay cả khi distinct loại được rows, nó không chứng minh business relationship đúng.

## C2 – LEFT JOIN loses customers

`WHERE b.status='success'` loại unmatched rows vì `b.status` là NULL → predicate không TRUE.

Nếu intent là attach successful transactions nhưng preserve mọi customer:

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

## C3 – End-date filter

```sql
WHERE transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-08-06'
```

Half-open interval bao toàn bộ ngày 01–05 và tránh phụ thuộc precision cuối ngày.

## C4 – DISTINCT dedup

`e005` versions khác `payload_version`, `signal_dbm`, `ingested_at`; `DISTINCT *` đúng khi rows giống toàn bộ selected columns, không phải khi business key trùng.

Dedup contract phải nêu:

```text
business key: event_id
winner: max payload_version
then max ingested_at
then max ingest_row_id
```

sau đó dùng `ROW_NUMBER`.

---

# Phần D – EXPLAIN & Performance

## D1 – Candidate index

```sql
CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts);
```

Reasoning:

- equality predicate trên customer;
- range + ordering theo transaction time;
- index key order phản ánh query pattern.

Lab nhỏ có thể Seq Scan vì planner estimate scan vài pages rẻ hơn index traversal/random heap access.

Kiểm chứng:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...;
```

So sánh plan trước/sau và scale-up table lớn.

## D2 – Estimate mismatch

`100 estimated` vs `100000 actual` = severe cardinality-estimation error.

Hệ quả có thể:

- chọn nested loop khi input thực rất lớn;
- memory allocation/aggregate strategy không phù hợp;
- join order/cost decision kém.

Kiểm tra tiếp:

- statistics freshness;
- data distribution/skew;
- correlated predicates;
- selectivity assumption;
- expression/cast;
- extended statistics nếu relevant;
- plan nodes upstream tạo mismatch từ đâu.

---

# Phần E – Oral Interview Rubric

Mỗi câu 1 điểm nếu câu trả lời có **definition + example/trade-off** thay vì chỉ đọc keyword.

### 1. Grain

Một row đại diện điều gì. Grain quyết định key, aggregate và join cardinality.

### 2. WHERE vs HAVING

WHERE filter rows trước aggregation; HAVING filter groups sau aggregation.

### 3. INNER vs LEFT

INNER chỉ match; LEFT preserve population phía trái và attach matches nếu có.

### 4. ROW_NUMBER vs RANK

ROW_NUMBER unique sequence; RANK giữ ties và tạo gap. Chọn theo tie semantics.

### 5. Dedup stream

Business key + deterministic winner + validation; thường dùng ROW_NUMBER, không DISTINCT *.

### 6. Full vs incremental

Full đơn giản/state-light nhưng expensive scale; incremental ít data hơn nhưng cần state, retry, late/delete semantics.

### 7. SCD1 vs SCD2

Type1 overwrite current; Type2 giữ historical versions + validity intervals.

### 8. Index

Search structure giảm read work cho workloads phù hợp, đổi lại storage/write maintenance.

### 9. Index nhưng Seq Scan

Low selectivity, small table hoặc cost estimate khiến scan tuần tự rẻ hơn.

### 10. Debug wrong revenue

Bắt đầu metric definition → input grain → filters → joins/cardinality → aggregate → reconciliation → source quality. Không bắt đầu bằng optimization.