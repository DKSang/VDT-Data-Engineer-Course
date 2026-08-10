# Lesson 02 – Filtering, NULL, CASE & Data Types

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Viết filter đúng với timestamp, text, numeric và NULL.
- Giải thích SQL three-valued logic: `TRUE`, `FALSE`, `UNKNOWN`.
- Phân biệt `= NULL` và `IS NULL`.
- Dùng `CASE`, `COALESCE`, `NULLIF` để biểu diễn business rules rõ ràng.
- Tránh implicit cast và type mismatch gây bug/cost.
- Viết date range theo half-open interval.
- Nhận diện predicate có thể làm mất row ngoài ý muốn sau `LEFT JOIN`.

---

## 2. Principles

### Principle 1 – NULL means unknown/missing, not zero or empty string

`NULL` không phải `0`, không phải `''`, không phải `'unknown'`. Nó biểu diễn absence/unknown ở tầng SQL.

Nếu business muốn phân biệt “không có dữ liệu”, “không áp dụng”, “0 thật”, schema và transformation phải thể hiện rõ.

### Principle 2 – Filters encode business semantics

`WHERE status = 'success'` không chỉ là syntax. Nó là một quyết định nghiệp vụ: refunded/failed/pending có được tính doanh thu không?

Mọi filter quan trọng nên có business definition đi kèm.

### Principle 3 – Prefer explicit boundaries and types

Timestamp filtering nên rõ inclusive/exclusive. Type conversion nên có chủ đích. Query càng “magic” nhờ implicit behavior càng khó debug khi chuyển engine.

### Principle 4 – Preserve outer-join intent

Một `LEFT JOIN` có thể vô tình biến thành inner-like behavior nếu bạn filter column phía right trong `WHERE` mà không xử lý NULL.

---

## 3. Fundamentals

### 3.1 Three-valued logic

Trong SQL, boolean expression có thể là:

```text
TRUE
FALSE
UNKNOWN
```

Ví dụ:

```sql
SELECT NULL = 10;      -- UNKNOWN
SELECT NULL <> 10;     -- UNKNOWN
SELECT NULL = NULL;    -- UNKNOWN
```

`WHERE` chỉ giữ row khi predicate là `TRUE`; `FALSE` và `UNKNOWN` đều bị loại.

Do đó:

```sql
WHERE email = NULL
```

không phải cách tìm email thiếu.

Đúng:

```sql
WHERE email IS NULL
```

### 3.2 `NOT IN` + NULL trap

Giả sử subquery trả một giá trị `NULL`:

```sql
WHERE customer_id NOT IN (1, 2, NULL)
```

Các phép so sánh có thể trở thành `UNKNOWN`, khiến kết quả khác trực giác.

Trong anti-join logic, thường nên reasoning kỹ với `NOT EXISTS`.

### 3.3 `COALESCE`

Trả expression đầu tiên không NULL:

```sql
COALESCE(email, 'missing@example.invalid')
```

Nhưng đừng lạm dụng để che giấu quality issue. `COALESCE` thay presentation/value semantics; nó không sửa nguồn dữ liệu.

### 3.4 `NULLIF`

`NULLIF(a, b)` trả `NULL` nếu `a = b`.

Pattern tránh divide-by-zero:

```sql
successful_calls::numeric / NULLIF(total_calls, 0)
```

### 3.5 `CASE`

```sql
CASE
    WHEN amount >= 500000 THEN 'high'
    WHEN amount >= 100000 THEN 'medium'
    ELSE 'low'
END
```

Thứ tự condition quan trọng: SQL xét từ trên xuống và lấy nhánh đầu tiên match.

### 3.6 Data types

Một số nhóm type quan trọng:

- integer/bigint;
- numeric/decimal;
- floating point;
- text/varchar;
- date;
- timestamp;
- boolean.

Tiền nên dùng fixed-precision numeric/decimal thay vì floating point khi cần exact arithmetic.

### 3.7 Date/timestamp boundaries

Tránh:

```sql
WHERE transaction_ts BETWEEN '2026-08-01' AND '2026-08-05'
```

nếu ý muốn bao gồm toàn bộ ngày 05/08, vì literal cuối có thể tương ứng đầu ngày.

Dùng half-open interval:

```sql
WHERE transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-08-06'
```

Pattern `[start, next_start)` ghép các khoảng liên tiếp mà không overlap.

### 3.8 Predicate placement với `LEFT JOIN`

Muốn giữ mọi customer và chỉ attach successful transactions:

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

Nếu viết:

```sql
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id
WHERE b.status = 'success';
```

row không match có `b.status = NULL`, predicate trở thành UNKNOWN và bị loại. Kết quả mất tính “giữ mọi customer”.

---

## 4. Worked example – Customer contact quality

### Requirement

Phân loại customer theo contact quality:

- `valid_email`: có email;
- `missing_email`: email NULL;
- đồng thời gắn age group nếu birth date tồn tại.

```sql
SELECT
    customer_id,
    full_name,
    CASE
        WHEN email IS NULL THEN 'missing_email'
        ELSE 'valid_email'
    END AS email_quality,
    CASE
        WHEN birth_date IS NULL THEN 'unknown_age'
        WHEN birth_date > DATE '2002-01-01' THEN 'young'
        WHEN birth_date > DATE '1998-01-01' THEN 'mid'
        ELSE 'older'
    END AS age_group
FROM customers;
```

### Principle check

Đừng `COALESCE(birth_date, DATE '1900-01-01')` rồi tính tuổi, vì “unknown birth date” sẽ bị biến thành “rất già” — technical convenience làm thay đổi business meaning.

---

## 5. Hands-on lab

Tạo `lesson-02.sql`.

1. Liệt kê customer thiếu email.
2. Đếm NULL `segment`, NULL `birth_date`, NULL `email`.
3. Tính successful revenue trong đúng 5 ngày 01–05/08/2026 bằng half-open interval.
4. Tạo transaction category bằng `CASE`: `<50k`, `50k–<200k`, `>=200k`.
5. Tính `call_drop_rate = drop_count / total_call_end_or_drop`, không lỗi khi denominator = 0.
6. Viết một query `LEFT JOIN` giữ mọi customer kể cả người không có successful transaction.
7. Viết phiên bản sai đặt filter ở `WHERE`, so sánh row count và giải thích.
8. Tạo cột `contact_channel` theo rule: email nếu có, nếu không là `'no_email'`.
9. Tìm transaction có `payment_method IS NULL`; quyết định có nên thay bằng `'unknown'` trong serving layer và giải thích.

### Challenge – NULL anti-join

Tạo một temporary table/list có `customer_id` và một giá trị NULL. So sánh:

```sql
NOT IN (...)
```

với:

```sql
NOT EXISTS (...)
```

Ghi kết luận về NULL semantics.

---

## 6. Knowledge check – MCQ

**Q1.** `NULL = NULL` trả về gì theo SQL semantics?  
A. TRUE; B. FALSE; C. UNKNOWN; D. 0.

**Q2.** Cách đúng để tìm email thiếu?  
A. `email = NULL`; B. `email IS NULL`; C. `email == NULL`; D. `NOT email`.

**Q3.** `WHERE` giữ row khi predicate là:  
A. TRUE; B. TRUE hoặc UNKNOWN; C. FALSE; D. NULL.

**Q4.** Half-open interval cho toàn bộ ngày 05/08 nên kết thúc ở:  
A. `<= '2026-08-05'`; B. `< '2026-08-06'`; C. `< '2026-08-05'`; D. `= '2026-08-05'`.

**Q5.** Filter right-table trong `WHERE` sau `LEFT JOIN` có thể:  
A. giữ chắc mọi row trái; B. loại unmatched rows; C. tạo index; D. bỏ duplicate tự động.

**Q6.** `COALESCE` nên được hiểu là:  
A. data-quality validator; B. chọn giá trị đầu tiên không NULL; C. dedup engine; D. join algorithm.

---

## 7. Knowledge check – Tự luận / Interview

1. Tại sao SQL cần three-valued logic?
2. Vì sao `NOT IN` có NULL dễ tạo bug?
3. Khi nào `COALESCE` hợp lý và khi nào nó che giấu data-quality issue?
4. Giải thích khác nhau giữa filter trong `ON` và filter trong `WHERE` với `LEFT JOIN`.
5. Vì sao tiền không nên mặc định dùng floating-point?
6. Tại sao `[start, end)` thuận lợi cho pipeline chạy theo partition thời gian?
7. Cho một ví dụ business nơi NULL khác hoàn toàn với zero.

---

## 8. Exit criteria

- [ ] Giải thích được TRUE/FALSE/UNKNOWN.
- [ ] Không dùng `= NULL`.
- [ ] Viết đúng half-open timestamp filter.
- [ ] Chứng minh được một `LEFT JOIN` bị phá bởi filter sai vị trí.
- [ ] Giải thích `NOT IN` vs `NOT EXISTS` khi có NULL.
- [ ] Đạt ít nhất 5/6 MCQ.