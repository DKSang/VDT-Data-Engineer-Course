# Module 02 – Databricks SQL Practice Set

> Primary engine: **Databricks SQL / Databricks Runtime + Delta tables**. Run `databricks-setup.sql` first.

Với mọi bài từ P11 trở đi, ghi:

```text
Expected output grain:
Input relation(s):
Business key:
Join/cardinality assumption:
Validation query:
```

---

## Level 1 – SQL Fundamentals on Databricks

### P01
Liệt kê customer ở `HCM` hoặc `Da Nang`, sort theo `registered_at` mới nhất.

### P02
Customer thiếu `email` hoặc `birth_date`; tạo `missing_reason` bằng `CASE`.

### P03
Lấy successful transactions ngày 01/08/2026 bằng half-open range.

### P04
Đếm customers/province, gồm present/missing email.

### P05
Tổng amount theo `status` và `transaction_type`.

### P06
Customer có total successful revenue >= 200000 bằng `HAVING`.

### P07
Viết daily status counts bằng cả:

```text
SUM(CASE ...)
count_if(...)
aggregate FILTER
```

### P08 – `try_cast`
Tạo `VALUES` có strings `100`, `25.5`, `bad`, `NULL`; parse numeric bằng `try_cast` và classify valid/malformed/missing.

### P09
So sánh `NULL = NULL`, `equal_null(NULL,NULL)` và `IS NULL` về intent.

### P10
Dùng `SELECT * EXCEPT (email)` rồi giải thích vì sao đây không tự động là serving-contract best practice.

---

## Level 2 – JOIN / CTE / Window / QUALIFY

### P11
Revenue/day/province, reconcile global successful total.

### P12
Customer có successful payment bằng `LEFT SEMI JOIN`; viết lại bằng `EXISTS`.

### P13
Customer không successful payment bằng `LEFT ANTI JOIN`; viết lại bằng `NOT EXISTS`.

### P14
Join billing với status history chỉ theo customer; đo fan-out factor.

### P15
Top 2 successful transactions/customer bằng `ROW_NUMBER` + `QUALIFY`.

### P16
Rank customers by successful revenue within province.

### P17
Latest status/customer bằng `QUALIFY` với deterministic tie-breaker.

### P18
Daily revenue + previous day + percentage change bằng `LAG`.

### P19
Derive `effective_to` bằng `LEAD(effective_from)` cho status history.

### P20
Cumulative successful revenue/day với explicit window frame.

---

## Level 3 – Data Engineering SQL on Delta

### P21 – Event dedup
Dedup `network_events` theo:

```text
business key = event_id
highest payload_version
latest ingested_at
highest ingest_row_id
```

Dùng `QUALIFY`; validate clean output unique.

### P22 – Metric before/after dedup
Tính call-drop rate/tower trước và sau dedup bằng `count_if`. Giải thích sự khác nhau.

### P23 – Incremental candidate set
Dùng `updated_at` giữa watermark + upper bound. Mô tả checkpoint/retry risk.

### P24 – Overlap strategy
Read lại 2 giờ trước watermark; mô tả vì sao target cần idempotent upsert/dedup.

### P25 – Delta MERGE current state
Tạo Delta table `customer_current`; MERGE một update + một new customer.

Yêu cầu:

- target grain;
- merge key;
- rerun same input;
- uniqueness validation.

### P26 – MERGE source duplicate
Tạo source có 2 rows cùng `customer_id`. Giải thích ambiguity; pre-dedup source bằng `QUALIFY` rồi MERGE.

### P27 – SCD2 awareness
Thiết kế customer-segment SCD2 schema và point-in-time join. So sánh manual MERGE/history logic với Lakeflow AUTO CDC.

### P28 – Data-quality gate
Viết >=8 checks cho Silver/Gold:

```text
unique business key
required NULL
accepted values
negative amount
orphan relationship
impossible time order
history overlap
revenue reconciliation
```

---

## Level 4 – Databricks Query Performance

### P29 – EXPLAIN + Query Profile
Chọn revenue-by-province query.

1. Run `EXPLAIN FORMATTED`.
2. Execute query.
3. Open Query Profile nếu environment hỗ trợ.
4. Record:

```text
scan/filter/join/aggregate/exchange operators
slowest operator
input/output rows
shuffle/I/O signal
```

5. Explain logical SQL vs physical plan.

### P30 – Exploding join diagnosis
Run intentionally bad join:

```sql
billing_transactions
JOIN customer_status_history
  ON customer_id
```

Then compare with latest-status relation.

Deliverables:

```text
base rows
bad joined rows
fixed joined rows
revenue before/after
Query Profile row amplification if available
root cause
```

### P31 – Projection/filter experiment
Compare a wide `SELECT *` scan with a query selecting only needed columns + date/status filters. On tiny data, do not claim performance improvement from timing alone; reason about work avoided at scale.

### P32 – AQE / Photon / statistics awareness
Write 1 page answering:

- What does AQE adapt?
- What is shuffle?
- What does Photon execute?
- Why statistics matter?
- Which problems none of these can fix if business join key is wrong?

---

## Level 5 – VDT Mock Cases

### P33 – Network Operations case
Requirement:

> Top 3 towers with highest deduplicated call-drop rate in each province/day. Require at least 2 call-end/drop events/tower.

Must include:

1. assumptions;
2. dedup contract;
3. output grain;
4. CTEs with clear names;
5. `count_if` metrics;
6. rank + `QUALIFY`;
7. validation/reconciliation;
8. 3 production risks.

### P34 – Customer dimension incremental case
Given daily customer updates with occasional duplicates:

1. define business key;
2. pre-dedup batch;
3. `MERGE INTO` current-state Delta table;
4. explain retry behavior;
5. explain how hard delete would be captured or missed;
6. state when AUTO CDC is a better production primitive.

### P35 – Query incident case
Dashboard revenue query becomes 8× slower after adding status history.

Your answer must contain:

```text
correctness check
cardinality hypothesis
EXPLAIN evidence to inspect
Query Profile evidence to inspect
fix
remeasure plan
```

---

# Completion rubric

- 24/35: usable SQL foundation.
- 29/35: ready to move on, review weak Databricks-specific items.
- 32+/35: strong fresher SQL foundation with Databricks-native practice.

A problem is **not complete** if the query runs but you cannot explain grain/cardinality/correctness or why the Databricks feature is appropriate.