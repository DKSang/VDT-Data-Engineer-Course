# Lesson 06 – Window Functions: Ranking, Running Metrics & Row Context

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích khác nhau giữa aggregation và window calculation.
- Dùng `PARTITION BY` và `ORDER BY` đúng semantics.
- Phân biệt `ROW_NUMBER`, `RANK`, `DENSE_RANK`.
- Dùng `LAG`/`LEAD` để so sánh row hiện tại với row trước/sau.
- Tạo running total và moving-style metrics bằng window aggregate.
- Giải thích window frame và vì sao default frame đôi khi gây surprise.
- Dùng subquery/CTE để filter theo kết quả window function.

---

## 2. Principles

### Principle 1 – Window functions preserve row identity

`GROUP BY` làm nhiều rows co lại thành một row/group.

Window function tính toán trên một tập rows liên quan nhưng vẫn giữ từng row trong output.

Ví dụ:

```text
Transaction rows vẫn còn nguyên
+ thêm revenue rank/customer running total/daily comparison
```

### Principle 2 – Partition defines peer universe; order defines sequence

`PARTITION BY customer_id` trả lời “tính riêng cho từng customer”.

`ORDER BY transaction_ts` trả lời “thứ tự thời gian trong customer đó”.

Nếu thiếu tie-breaker trong `ORDER BY`, kết quả như `ROW_NUMBER` có thể không deterministic khi nhiều rows có cùng sort key.

### Principle 3 – Ranking function must match business tie semantics

- `ROW_NUMBER`: mỗi row nhận số thứ tự riêng.
- `RANK`: ties cùng rank, rank sau bị gap.
- `DENSE_RANK`: ties cùng rank, không gap.

Không có function “tốt nhất”; có business semantics phù hợp hay không.

### Principle 4 – Understand the frame, not only the partition

Với window aggregate có `ORDER BY`, frame quyết định rows nào được đưa vào calculation cho current row.

Running sum khác whole-partition sum dù `PARTITION BY` giống nhau.

---

## 3. Fundamentals

### 3.1 Aggregate vs window

Aggregate:

```sql
SELECT customer_id, SUM(amount)
FROM billing_transactions
GROUP BY customer_id;
```

Output grain: 1 row/customer.

Window:

```sql
SELECT
    transaction_id,
    customer_id,
    amount,
    SUM(amount) OVER (PARTITION BY customer_id) AS customer_total
FROM billing_transactions;
```

Output grain vẫn 1 row/transaction.

### 3.2 `ROW_NUMBER`

```sql
ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY effective_from DESC, recorded_at DESC, status_history_id DESC
)
```

Pattern quan trọng để chọn một row/customer.

Tie-breaker giúp ordering deterministic.

### 3.3 `RANK` vs `DENSE_RANK`

Giả sử scores:

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

### 3.4 `LAG` và `LEAD`

```sql
LAG(revenue) OVER (ORDER BY revenue_date)
```

Lấy value của row trước trong ordering.

Use cases:

- day-over-day change;
- previous status;
- time gap between events;
- detect state transition.

### 3.5 Running total

```sql
SUM(daily_revenue) OVER (
    ORDER BY revenue_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

Viết frame rõ giúp reader hiểu intent.

### 3.6 Window frame

Các khái niệm chính:

- `ROWS` – frame theo physical rows trong ordering;
- `RANGE` – frame dựa trên peer/value semantics;
- `UNBOUNDED PRECEDING`;
- `CURRENT ROW`;
- `UNBOUNDED FOLLOWING`.

Không cần học thuộc mọi biến thể ngay. Nhưng phải biết `ORDER BY` trong window có thể làm aggregate trở thành running calculation thay vì whole partition.

### 3.7 Filter window result

Window functions logically được tính sau `WHERE`, nên pattern phổ biến:

```sql
WITH ranked AS (
    SELECT
        ...,
        ROW_NUMBER() OVER (...) AS rn
    FROM ...
)
SELECT *
FROM ranked
WHERE rn = 1;
```

Một số engines có `QUALIFY`, PostgreSQL không dùng `QUALIFY` trong core syntax; CTE/subquery là portable pattern hơn.

---

## 4. Worked example – Latest customer status

### Problem

`customer_status_history` có nhiều row/customer. Cần relation:

```text
latest_customer_status
Grain: 1 row/customer
```

Query:

```sql
WITH ranked_status AS (
    SELECT
        status_history_id,
        customer_id,
        status,
        effective_from,
        recorded_at,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                effective_from DESC,
                recorded_at DESC,
                status_history_id DESC
        ) AS rn
    FROM customer_status_history
)
SELECT
    customer_id,
    status,
    effective_from,
    recorded_at
FROM ranked_status
WHERE rn = 1;
```

### Why multiple tie-breakers?

Nếu source có hai status cùng `effective_from`, chỉ sort theo `effective_from` không đủ để chọn deterministic row.

`recorded_at` và technical id giúp đặt rule rõ hơn. Tuy nhiên business phải xác nhận tie-breaker thực sự đúng semantics; technical ordering không thay thế data contract.

### Validation

```sql
WITH latest AS (...)
SELECT customer_id, COUNT(*)
FROM latest
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

Kỳ vọng 0 rows.

---

## 5. Hands-on lab

Tạo `lesson-06.sql`.

### Part A – Ranking

1. Rank successful transactions theo amount toàn hệ thống bằng `RANK`.
2. Rank transaction trong từng customer bằng `ROW_NUMBER`.
3. Top 2 successful transactions/customer.
4. Top 2 towers theo số drop events; so sánh `RANK` và `DENSE_RANK` khi tie.

### Part B – Latest row

1. Latest customer status/customer.
2. Latest subscription/customer theo `updated_at`, có tie-breaker.
3. Latest ingested version/event_id từ `network_events`.

Chưa gọi bước 3 là “dedup chuẩn” cho đến khi bạn định nghĩa business tie-breaker ở Lesson 07.

### Part C – LAG/LEAD

1. Daily successful revenue.
2. Thêm previous-day revenue bằng `LAG`.
3. Tính absolute và percentage day-over-day change.
4. Với mỗi customer status row, dùng `LAG(status)` để tìm previous status.
5. Tính thời gian giữa hai status changes.

### Part D – Window aggregates

1. Cumulative successful revenue theo ngày.
2. Cumulative revenue riêng từng province.
3. Với mỗi transaction, hiển thị customer total và % contribution của transaction vào customer total.

### Challenge – session-like gap reasoning

Với `network_events`, dùng `LAG(event_ts)` theo `customer_id` để tính gap giữa events. Đánh dấu `new_session = 1` nếu gap > 30 phút.

Chưa cần tạo session_id hoàn chỉnh; mục tiêu là hiểu state dựa trên previous row.

---

## 6. Knowledge check – MCQ

**Q1.** Window function khác GROUP BY ở điểm quan trọng nào?  
A. Window luôn nhanh hơn; B. window giữ row identity; C. window không có ORDER BY; D. GROUP BY không aggregate.

**Q2.** `ROW_NUMBER` với ties:  
A. cùng số; B. vẫn gán số riêng theo ordering; C. luôn NULL; D. lỗi syntax.

**Q3.** `RANK` cho values `100,100,90`:  
A. `1,1,2`; B. `1,2,3`; C. `1,1,3`; D. `0,0,1`.

**Q4.** `LAG` thường dùng để:  
A. lấy row/value trước theo window ordering; B. join table; C. create index; D. delete rows.

**Q5.** Filter `rn = 1` từ `ROW_NUMBER` trong PostgreSQL portable pattern thường cần:  
A. CTE/subquery ngoài; B. WHERE cùng level luôn; C. GROUP BY; D. index bắt buộc.

**Q6.** Nếu `ROW_NUMBER ORDER BY effective_from DESC` có ties và không tie-breaker:  
A. luôn deterministic; B. row được chọn có thể không ổn định theo intent; C. tự dedup source; D. DB thêm business key.

---

## 7. Knowledge check – Tự luận / Interview

1. `GROUP BY` vs window function khác nhau ở grain output thế nào?
2. Khi nào chọn `ROW_NUMBER` thay vì `RANK`?
3. Vì sao top-N per group là bài window function điển hình?
4. Window frame là gì? Running total khác partition total thế nào?
5. Tại sao tie-breaker quan trọng trong dedup/latest-row?
6. Dùng `LAG` để phát hiện status transition như thế nào?
7. Nếu interviewer hỏi “latest row/customer”, hãy trình bày reasoning trước khi viết query.

---

## 8. Exit criteria

- [ ] Phân biệt rõ aggregate và window grain.
- [ ] Dùng đúng ROW_NUMBER/RANK/DENSE_RANK.
- [ ] Viết latest-status relation 1 row/customer.
- [ ] Dùng LAG cho day-over-day và status transition.
- [ ] Viết running total với frame explicit.
- [ ] Giải thích deterministic ordering/tie-breaker.
- [ ] Đạt ít nhất 5/6 MCQ.