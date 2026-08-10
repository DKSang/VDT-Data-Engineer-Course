# Module 02 Final Assessment – SQL for Data Engineers

> Không xem `answers/module-02-final-solutions.md` trước khi hoàn thành.

## Quy định

- Reference engine: PostgreSQL.
- Thời gian gợi ý: **150 phút**.
- Mọi query phải ghi **expected output grain**.
- Với bài join/aggregate, phải ghi expected cardinality hoặc validation query.
- Không chấm chỉ dựa trên “query chạy được”; reasoning là một phần điểm.

---

# Phần A – MCQ Fundamentals (20 điểm)

Mỗi câu 1 điểm.

1. Grain mô tả: A. số column; B. ý nghĩa một row; C. index size; D. file format.
2. `WHERE` giữ predicate: A. TRUE; B. TRUE/UNKNOWN; C. FALSE; D. NULL.
3. Cách tìm NULL: A. `= NULL`; B. `IS NULL`; C. `== NULL`; D. `NULL()`.
4. `COUNT(email)` sẽ: A. đếm mọi rows; B. bỏ NULL email; C. distinct; D. luôn bằng `COUNT(*)`.
5. `HAVING` chủ yếu filter: A. raw rows trước grouping; B. groups sau aggregation; C. tables; D. indexes.
6. Fact N:1 dimension unique-key join thường giữ: A. fact grain; B. dimension grain; C. Cartesian grain; D. không xác định.
7. Join fan-out thường do: A. right relation nhiều match/key hơn expected; B. alias; C. SUM; D. ORDER BY.
8. Nếu chỉ hỏi “customer có transaction không”, operator semantics phù hợp: A. EXISTS; B. CROSS JOIN; C. FULL JOIN; D. ORDER BY.
9. `UNION ALL`: A. loại duplicate; B. giữ duplicate; C. join rows; D. aggregate.
10. `NOT IN` đặc biệt cần cẩn thận với: A. NULL; B. bigint; C. CTE; D. ORDER BY.
11. Window function khác GROUP BY vì: A. giữ row identity; B. không aggregate được; C. không sort; D. không partition.
12. `RANK` cho values `100,100,90`: A. 1,1,2; B. 1,1,3; C. 1,2,3; D. 0,0,1.
13. `ROW_NUMBER` latest-row cần tie-breaker để: A. deterministic ordering; B. tạo index; C. xóa source row; D. group.
14. Dedup cần trước hết: A. SELECT DISTINCT; B. business key + winner rule; C. LIMIT; D. index.
15. Watermark incremental là: A. stateful pattern; B. file format; C. join algorithm; D. constraint.
16. SCD Type 2: A. giữ history versions; B. overwrite only; C. không key; D. chỉ event stream.
17. `EXPLAIN ANALYZE`: A. chỉ estimate; B. thực thi query và thu actual metrics; C. create index; D. rollback tự động.
18. Index có thể không được dùng vì: A. planner estimate seq scan rẻ hơn; B. indexes bị SQL bỏ qua luôn; C. SELECT không support; D. PK sai.
19. Estimated rows lệch actual rất lớn ảnh hưởng: A. planner choices; B. column names; C. constraints tự động; D. syntax.
20. Thứ tự optimization đúng nhất: A. index trước correctness; B. correctness → measure → plan → change → remeasure; C. DISTINCT → LIMIT; D. rewrite ngẫu nhiên.

---

# Phần B – SQL Coding (40 điểm)

Mỗi bài 5 điểm. Dùng dataset `labs/module-02-sql`.

## B1 – Revenue by province/day

Trả:

```text
revenue_date
province
successful_txn_count
unique_paying_customers
successful_revenue
```

Chỉ `status='success'`.

Yêu cầu:

- ghi output grain;
- reconcile total với base successful revenue.

## B2 – Customers without successful payment

Trả customer chưa từng có successful transaction.

Yêu cầu:

- dùng `NOT EXISTS`;
- giải thích vì sao không cần join + DISTINCT.

## B3 – Latest customer status

Trả đúng 1 row/customer:

```text
customer_id
status
effective_from
recorded_at
```

Yêu cầu deterministic tie-breaker.

## B4 – Top 2 successful transactions/customer

Trả top 2 transaction amount mỗi customer, vẫn giữ transaction details.

Nếu tie amount, tie-break bằng `transaction_ts DESC, transaction_id DESC`.

## B5 – Day-over-day revenue

Trả:

```text
revenue_date
revenue
previous_day_revenue
absolute_change
pct_change
```

Dùng `LAG`. Xử lý denominator 0/NULL an toàn.

## B6 – Deduplicated network drop rate

Contract:

```text
business key = event_id
winner = highest payload_version
then latest ingested_at
then highest ingest_row_id
```

Sau dedup, tính call-drop rate/tower.

Yêu cầu validation rằng clean relation unique `event_id`.

## B7 – Active-plan revenue

Tính successful revenue theo current active plan.

Trước join, kiểm tra relation active subscription có nhiều hơn 1 row/customer hay không.

## B8 – Incremental candidate set

Giả sử:

```text
last_watermark = 2026-08-03 00:00:00
upper_bound    = 2026-08-06 00:00:00
```

Viết extraction query dựa `updated_at` với boundary convention rõ.

Mô tả:

- retry risk;
- target upsert/business key;
- một loại change watermark này có thể miss.

---

# Phần C – Debugging & Correctness (20 điểm)

Mỗi bài 5 điểm.

## C1 – Revenue suddenly triples

Một engineer thêm:

```sql
SELECT h.status, SUM(b.amount)
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY h.status;
```

Revenue tăng mạnh.

Trả lời:

1. Root cause.
2. Input grains.
3. Query chứng minh fan-out.
4. Relation cần tạo trước khi join.
5. Vì sao `DISTINCT` không phải fix tổng quát.

## C2 – LEFT JOIN loses customers

Query:

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id
WHERE b.status = 'success';
```

Business muốn giữ mọi customers.

Giải thích bug và sửa.

## C3 – Wrong end-date filter

Engineer viết:

```sql
WHERE transaction_ts BETWEEN '2026-08-01' AND '2026-08-05'
```

nhưng business muốn toàn bộ 01–05/08.

Sửa bằng half-open interval và giải thích.

## C4 – Dedup by DISTINCT

Engineer chạy:

```sql
SELECT DISTINCT * FROM network_events;
```

nhưng `e005` vẫn có nhiều versions.

Giải thích tại sao và thiết kế dedup contract đúng.

---

# Phần D – EXPLAIN & Performance Reasoning (10 điểm)

## D1 – Index experiment (5 điểm)

Query:

```sql
SELECT transaction_id, transaction_ts, amount
FROM billing_transactions
WHERE customer_id = 1001
  AND transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts < TIMESTAMP '2026-09-01'
ORDER BY transaction_ts;
```

1. Đề xuất candidate index.
2. Vì sao column order đó hợp lý?
3. Vì sao trên lab table nhỏ planner vẫn có thể chọn Seq Scan?
4. Cách dùng `EXPLAIN (ANALYZE, BUFFERS)` để kiểm chứng.

## D2 – Plan estimate (5 điểm)

Một plan node có:

```text
estimated rows = 100
actual rows = 100000
```

Trả lời:

1. Đây là signal gì?
2. Có thể ảnh hưởng join/plan decision như thế nào?
3. Statistics/selectivity liên quan ra sao?
4. Bạn sẽ kiểm tra gì tiếp theo?

---

# Phần E – VDT-style Oral Interview (10 điểm)

Record hoặc tự trả lời thành tiếng, tối đa 2 phút/câu.

1. Grain là gì và vì sao Data Engineer phải quan tâm?
2. `WHERE` vs `HAVING`.
3. `INNER JOIN` vs `LEFT JOIN`.
4. `ROW_NUMBER` vs `RANK`.
5. Dedup event stream bằng SQL như thế nào?
6. Full load vs incremental watermark.
7. SCD Type 1 vs Type 2.
8. Index là gì và trade-off?
9. Tại sao query có index vẫn Seq Scan?
10. Bạn debug một KPI revenue sai bằng quy trình nào?

---

# Rubric

| Phần | Điểm |
|---|---:|
| A – Fundamentals | 20 |
| B – Coding | 40 |
| C – Debugging | 20 |
| D – Performance | 10 |
| E – Oral interview | 10 |
| **Tổng** | **100** |

## Pass criteria

- **>=75/100** tổng.
- B – Coding phải >=28/40.
- Không được sai các fundamental sau:
  - NULL dùng `IS NULL`;
  - grain/cardinality;
  - WHERE vs HAVING;
  - LEFT JOIN row preservation;
  - deterministic dedup;
  - watermark có state/retry concerns.

## Strong-pass criteria

>=85/100 và có thể giải thích Part C/E mà không nhìn notes.