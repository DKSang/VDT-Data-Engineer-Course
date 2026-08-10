# Module 02 – SQL Practice Set

> Làm sau từng lesson hoặc dùng để ôn cuối module. Không xem solution file trước Final Assessment.

Với mọi bài từ P11 trở đi, ghi:

```text
Expected output grain:
Input relation(s):
Join cardinality assumption:
Validation query:
```

---

## Level 1 – Fundamentals

### P01
Liệt kê customer ở `HCM` hoặc `Da Nang`, sort theo `registered_at` mới nhất.

### P02
Liệt kê customer thiếu `email` hoặc `birth_date`, tạo column `missing_reason` bằng CASE.

### P03
Lấy successful transactions trong ngày 01/08/2026 bằng half-open timestamp range.

### P04
Đếm customers theo province, gồm count email present và missing.

### P05
Tổng amount theo `status` và `transaction_type`.

### P06
Customer có tổng successful revenue >= 200000.

### P07
Đếm transaction/customer kể cả customer không có transaction.

### P08
Customer chưa từng có failed transaction bằng `NOT EXISTS`.

### P09
Tìm `event_id` duplicate.

### P10
Tìm active subscriptions và join plan name.

---

## Level 2 – JOIN / Aggregation / Window

### P11
Revenue theo day/province, validate global total.

### P12
Tìm province có average successful transaction value lớn nhất.

### P13
Tìm customer có successful revenue cao hơn average revenue/customer.

### P14
Top 2 successful transactions/customer bằng `ROW_NUMBER`.

### P15
Rank customers theo successful revenue trong từng province.

### P16
Daily revenue + previous day + percentage change.

### P17
Latest status/customer với deterministic tie-breaker.

### P18
Dùng `LAG` tìm customer status transitions (`previous_status → current_status`).

### P19
Tạo cumulative successful revenue theo ngày.

### P20
Tính tỷ trọng mỗi transaction trong total successful revenue của chính customer đó.

---

## Level 3 – Data Engineering SQL

### P21 – Join fan-out investigation
Join billing với status history chỉ theo customer_id. Đo:

```text
base fact rows
joined rows
distinct transaction ids
fan-out factor
```

Sau đó mô tả fix.

### P22 – Event dedup
Dedup `network_events` theo contract:

```text
event_id
highest payload_version
latest ingested_at
highest ingest_row_id
```

Validate clean output unique.

### P23 – Before/after quality metric
Tính call-drop rate/tower trước dedup và sau dedup. Giải thích tower nào thay đổi và tại sao.

### P24 – Incremental extraction
Tạo candidate batch bằng `updated_at` giữa hai watermarks. Mô tả retry/idempotency strategy.

### P25 – Incremental overlap
Giả sử overlap 2 giờ trước watermark. Viết candidate query và mô tả target dedup/upsert cần làm gì.

### P26 – Point-in-time dimension design
Thiết kế CTE tạo `effective_to` cho `customer_status_history` bằng `LEAD(effective_from)`.

Sau đó join billing transaction vào status có hiệu lực tại `transaction_ts`.

### P27 – SCD Type 2 integrity checks
Viết checks phát hiện:

- nhiều current rows/business key;
- `effective_to <= effective_from`;
- overlapping validity windows.

### P28 – Daily Gold table
Tạo query cho:

```text
gold_daily_revenue
Grain: revenue_date / province
```

Kèm 5 validation checks.

### P29 – EXPLAIN experiment
Tạo `billing_big` >=100k rows. So sánh plan:

- no index;
- index on `customer_id`;
- composite `(customer_id, transaction_ts)`.

Ghi estimated vs actual rows.

### P30 – VDT mock SQL case
Requirement:

> Team Network Operations cần danh sách 3 tower có call-drop rate cao nhất mỗi province trong ngày, chỉ tính deduplicated call-end/drop events. Mỗi tower phải có ít nhất 2 calls trong sample window. Output cần total_calls, drops, drop_rate và rank.

Yêu cầu:

1. Viết requirement assumptions.
2. Define dedup contract.
3. Define output grain.
4. Query theo các CTE có tên rõ.
5. Top 3/tỉnh bằng window rank.
6. Validation uniqueness.
7. Reconcile numerator/denominator.
8. Nêu 3 vấn đề production-scale mà lab nhỏ chưa thể hiện.

---

# Completion rubric

- 20/30: SQL foundation usable.
- 25/30: đủ nền để chuyển Module 03 nhưng nên review câu sai.
- 28+/30: strong SQL foundation cho fresher; chuyển trọng tâm sang speed + interview explanation.

Không tính một bài là hoàn thành nếu query chạy nhưng bạn không giải thích được grain/cardinality/correctness.