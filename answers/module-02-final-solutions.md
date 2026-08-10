# Module 02 Final Assessment – Suggested Solutions (Databricks-first)

> Đây là reference solution, không phải cách viết duy nhất. Alternative solution vẫn đúng nếu grain, semantics, Delta behavior và validation đúng.

---

# Phần A – MCQ

```text
1B  2A  3B  4B  5B
6A  7B  8A  9B 10A
11B 12B 13A 14A 15A
16A 17A 18B 19A 20A
```

---

# Phần B – SQL Coding

## B1 – Revenue by province/day

**Grain:** 1 row / revenue_date / province.

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
GROUP BY CAST(b.transaction_ts AS DATE), c.province
ORDER BY revenue_date, province;
```

Reconciliation:

```sql
WITH by_province AS (
  SELECT
    CAST(b.transaction_ts AS DATE) AS revenue_date,
    c.province,
    SUM(b.amount) AS revenue
  FROM billing_transactions b
  JOIN customers c
    ON c.customer_id = b.customer_id
  WHERE b.status = 'success'
  GROUP BY CAST(b.transaction_ts AS DATE), c.province
)
SELECT SUM(revenue) AS grouped_total
FROM by_province;

SELECT SUM(amount) AS base_total
FROM billing_transactions
WHERE status = 'success';
```

Nếu totals khác: kiểm tra customer uniqueness/orphan/filter mismatch.

## B2 – Customers without successful payment

**Grain:** 1 row/customer.

```sql
SELECT
  c.customer_id,
  c.full_name,
  c.province
FROM customers c
LEFT ANTI JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

Equivalent intent:

```sql
SELECT c.customer_id, c.full_name, c.province
FROM customers c
WHERE NOT EXISTS (
  SELECT 1
  FROM billing_transactions b
  WHERE b.customer_id = c.customer_id
    AND b.status = 'success'
);
```

Cả hai nói “không có matching successful transaction”.

## B3 – Latest customer status

**Grain:** 1 row/customer.

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

Validation:

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

## B4 – Top 2 successful transactions/customer

```sql
SELECT
  transaction_id,
  customer_id,
  transaction_ts,
  amount,
  status
FROM billing_transactions
WHERE status = 'success'
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id
  ORDER BY amount DESC, transaction_ts DESC, transaction_id DESC
) <= 2
ORDER BY customer_id, amount DESC, transaction_ts DESC;
```

`ROW_NUMBER` đảm bảo tối đa 2 rows/customer theo deterministic ordering.

## B5 – Day-over-day revenue

```sql
WITH daily AS (
  SELECT
    CAST(transaction_ts AS DATE) AS revenue_date,
    SUM(amount) AS revenue
  FROM billing_transactions
  WHERE status = 'success'
  GROUP BY CAST(transaction_ts AS DATE)
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
  CAST(revenue - previous_day_revenue AS DOUBLE)
    / NULLIF(CAST(previous_day_revenue AS DOUBLE), 0.0) AS pct_change
FROM with_prev
ORDER BY revenue_date;
```

Nếu business cần calendar liên tục kể cả ngày không transaction, phải join date/calendar relation.

## B6 – Deduplicated network drop rate

```sql
WITH clean AS (
  SELECT
    ingest_row_id,
    event_id,
    tower_id,
    customer_id,
    event_type,
    event_ts,
    ingested_at,
    signal_dbm,
    duration_seconds,
    payload_version
  FROM network_events
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY event_id
    ORDER BY payload_version DESC, ingested_at DESC, ingest_row_id DESC
  ) = 1
)
SELECT
  tower_id,
  count_if(event_type = 'call_drop') AS drops,
  count_if(event_type IN ('call_drop','call_end')) AS total_calls,
  CAST(count_if(event_type = 'call_drop') AS DOUBLE)
    / NULLIF(CAST(count_if(event_type IN ('call_drop','call_end')) AS DOUBLE), 0.0)
    AS drop_rate
FROM clean
GROUP BY tower_id
ORDER BY tower_id;
```

Uniqueness validation:

```sql
WITH clean AS (
  SELECT *
  FROM network_events
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY event_id
    ORDER BY payload_version DESC, ingested_at DESC, ingest_row_id DESC
  ) = 1
)
SELECT event_id, COUNT(*)
FROM clean
GROUP BY event_id
HAVING COUNT(*) > 1;
```

## B7 – Conditional metric styles

Example:

```sql
SELECT
  CAST(transaction_ts AS DATE) AS revenue_date,
  count_if(status = 'success') AS successful_count,
  COUNT(*) FILTER (WHERE status = 'failed') AS failed_count,
  SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) AS successful_revenue
FROM billing_transactions
GROUP BY CAST(transaction_ts AS DATE)
ORDER BY revenue_date;
```

Reasoning:

- `count_if` rõ nhất cho boolean count.
- `FILTER` đặt population cạnh aggregate.
- `CASE` portable và linh hoạt khi transformation phức tạp hơn.

## B8 – Safe type parsing

```sql
WITH raw AS (
  SELECT *
  FROM VALUES
    ('100'),
    ('25.5'),
    ('bad'),
    (CAST(NULL AS STRING))
  AS t(raw_value)
),
parsed AS (
  SELECT
    raw_value,
    try_cast(raw_value AS DECIMAL(14,2)) AS parsed_decimal
  FROM raw
)
SELECT
  raw_value,
  parsed_decimal,
  CASE
    WHEN raw_value IS NULL THEN 'missing'
    WHEN parsed_decimal IS NULL THEN 'malformed'
    ELSE 'valid'
  END AS parse_status
FROM parsed;
```

`try_cast` chỉ tạo safe parse result; classification mới làm parse failure observable.

---

# Phần C – Delta / Incremental / Debugging

## C1 – Delta MERGE current-state table

Example target:

```sql
CREATE OR REPLACE TABLE customer_current
USING DELTA
AS
SELECT
  customer_id,
  full_name,
  province,
  email,
  segment,
  updated_at
FROM customers;
```

Example updates:

```sql
CREATE OR REPLACE TEMP VIEW customer_updates AS
SELECT * FROM VALUES
  (1001,'Nguyen An','Ha Noi','an@example.com','premium',TIMESTAMP '2026-08-10 10:00:00'),
  (1009,'New Customer','Hue','new@example.com','mass',TIMESTAMP '2026-08-10 11:00:00')
AS t(customer_id,full_name,province,email,segment,updated_at);
```

MERGE:

```sql
MERGE INTO customer_current AS t
USING customer_updates AS s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET
  t.full_name = s.full_name,
  t.province = s.province,
  t.email = s.email,
  t.segment = s.segment,
  t.updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (
  customer_id, full_name, province, email, segment, updated_at
) VALUES (
  s.customer_id, s.full_name, s.province, s.email, s.segment, s.updated_at
);
```

Key:

```text
Target grain: 1 row/customer
Merge key: customer_id
```

Rerun same deterministic source: matched row updates again, new customer is now matched; no additional key should appear.

Validation:

```sql
SELECT customer_id, COUNT(*)
FROM customer_current
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

## C2 – Duplicate MERGE source

Problem:

```text
source row A customer_id=1001
source row B customer_id=1001
```

Both can match one target row. Winner semantics are undefined unless source is canonicalized.

Example fix:

```sql
WITH source_clean AS (
  SELECT *
  FROM customer_updates
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY updated_at DESC
  ) = 1
)
MERGE INTO customer_current t
USING source_clean s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET
  t.full_name = s.full_name,
  t.province = s.province,
  t.email = s.email,
  t.segment = s.segment,
  t.updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (
  customer_id, full_name, province, email, segment, updated_at
) VALUES (
  s.customer_id, s.full_name, s.province, s.email, s.segment, s.updated_at
);
```

Winner rule phải được business/source contract xác nhận; `updated_at DESC` ở đây chỉ là example.

## C3 – Revenue triples after history join

Root cause: history có nhiều rows/customer; each billing fact matches multiple history versions.

Proof:

```sql
SELECT
  b.transaction_id,
  COUNT(*) AS copies_after_join
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY b.transaction_id
HAVING COUNT(*) > 1;
```

Or:

```sql
SELECT
  COUNT(*) AS joined_rows,
  COUNT(DISTINCT b.transaction_id) AS distinct_transactions
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
WHERE b.status = 'success';
```

Correct relation depends on requirement:

- current/latest status → 1 row/customer relation using `QUALIFY`;
- status at transaction time → SCD/temporal validity join.

`DISTINCT` không solve business relationship; differing history rows are genuinely distinct physical rows.

## C4 – Watermark failure reasoning

One valid convention `(last, upper]`:

```sql
SELECT *
FROM billing_transactions
WHERE updated_at >  TIMESTAMP '2026-08-03 00:00:00'
  AND updated_at <= TIMESTAMP '2026-08-06 00:00:00';
```

Failure after target write but before checkpoint:

```text
retry reads same logical batch
plain append → duplicate risk
idempotent MERGE/upsert → safer if key/logic correct
```

Late/backdated risk: source changes whose update/event semantics fall behind committed watermark can be skipped unless overlap/CDC signal exists.

Hard delete: deleted row no longer exists to satisfy timestamp predicate; need delete/change signal, CDC/change feed, snapshot diff, or other source semantics.

AUTO CDC becomes better production primitive when ordered change feed/SCD handling/out-of-order events make hand-written MERGE/state logic complex.

---

# Phần D – EXPLAIN & Query Profile

## D1 – Plan reasoning

```sql
EXPLAIN FORMATTED
SELECT
  c.province,
  SUM(b.amount) AS revenue
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY c.province;
```

Likely conceptual operators to inspect:

```text
scans
filter
join
exchange/shuffle if distributed strategy requires
aggregate
```

Logical plan describes relational transformations. Physical plan chooses concrete execution operators/strategies.

Statistics/cardinality estimates influence:

```text
join order
join strategy/build side
cost estimates
some partition/exchange decisions
```

## D2 – Runtime incident

50× join output near slowest operator = **exploding join / row amplification signal**.

Check first:

```text
left grain
right grain
join key
expected matches per left row
right-key uniqueness
missing temporal condition
```

Query Profile evidence:

```text
input rows
output rows
operator time
shuffle/exchange
memory/I/O
```

AQE may adapt physical execution and Photon may execute supported operations efficiently, but neither changes a wrong business join relationship into the correct one.

Fix correctness first, then re-run and compare profile.

---

# Phần E – Oral Interview Rubric

Mỗi câu 1 điểm nếu có definition + example/failure mode.

### 1. Grain

Meaning of one row. It determines key/cardinality/aggregation correctness.

### 2. NULL / try_cast

`NULL` = missing/unknown semantics. `try_cast` turns malformed supported conversion into NULL so quality logic can classify/quarantine instead of hard-failing.

### 3. WHERE / HAVING / QUALIFY

```text
WHERE   → base rows
HAVING  → grouped aggregate results
QUALIFY → window-function results
```

### 4. INNER / LEFT / SEMI / ANTI

```text
INNER → matched pairs
LEFT  → preserve left + attach matches
SEMI  → left rows with match
ANTI  → left rows without match
```

### 5. ROW_NUMBER vs RANK

ROW_NUMBER unique sequence; RANK keeps ties + gap. Choose by tie semantics.

### 6. Dedup event

Business key + deterministic winner + `QUALIFY ROW_NUMBER` + uniqueness validation.

### 7. MERGE INTO

Delta upsert/delete primitive; key risks include ambiguous multiple source matches, wrong merge key, non-idempotent source semantics.

### 8. Watermark vs AUTO CDC

Watermark = manually managed incremental state. AUTO CDC is Lakeflow primitive for applying ordered change feeds/SCD1/2 patterns when CDC semantics warrant it.

### 9. EXPLAIN vs Query Profile

EXPLAIN = planned execution; Query Profile = runtime execution metrics/visualization.

### 10. Exploding join debug

Metric definition → input grains → join key/cardinality → prove amplification → fix relation → validate totals → inspect plan/profile → optimize/re-measure.