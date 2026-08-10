# Lesson 02 – Filtering, NULL, CASE & Databricks Data Types

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Reasoning đúng với `NULL` và three-valued logic.
- Viết filter thời gian theo boundary rõ ràng.
- Dùng `CASE`, `COALESCE`, `NULLIF` đúng business semantics.
- Phân biệt implicit type resolution với explicit cast.
- Biết khi nào dùng `CAST` và khi nào dùng Databricks `try_cast`.
- Hiểu Databricks type promotion / least-common-type ở mức thực dụng.
- Giữ đúng row-preservation intent khi filter sau `LEFT JOIN`.

---

## 2. Source alignment

### Primary Databricks sources

- SQL Language Reference – NULL semantics / data types  
  https://docs.databricks.com/aws/en/sql/language-manual
- SQL data type rules  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-datatype-rules
- `CAST` / `try_cast`  
  https://docs.databricks.com/aws/en/sql/language-manual/functions/cast  
  https://docs.databricks.com/aws/en/sql/language-manual/functions/try_cast
- `IS NULL`  
  https://docs.databricks.com/aws/en/sql/language-manual/functions/isnullop
- Null-safe comparison `equal_null` / `<=>`  
  https://docs.databricks.com/aws/en/sql/language-manual/functions/equal_null

### Scope note

Databricks có ANSI/type-coercion behavior phụ thuộc context/configuration. Course không khuyến khích dựa vào implicit conversion “tình cờ chạy được”; production transformations nên làm type intent explicit.

---

## 3. Principles

### Principle 1 – NULL is absence/unknown, not zero

```text
NULL != 0
NULL != ''
NULL != false
```

Nếu business cần phân biệt:

```text
unknown
not applicable
known zero
```

schema/transformation phải giữ được khác biệt đó.

### Principle 2 – WHERE keeps TRUE

Comparison với `NULL` thường không tạo `TRUE`/`FALSE` mà tạo `UNKNOWN`.

`WHERE` chỉ giữ rows có predicate `TRUE`.

### Principle 3 – Cast policy is part of data-quality policy

Hai chiến lược khác nhau:

```text
invalid value must stop pipeline → CAST / fail fast
invalid value should be quarantined → try_cast → NULL + quality check
```

`try_cast` không “fix data”; nó cho phép pipeline biểu diễn parse failure thành `NULL` để xử lý có chủ đích.

### Principle 4 – Prefer explicit time boundaries

Pipeline theo ngày/giờ nên dùng interval kiểu:

```text
[start, end)
```

để các batches nối nhau không overlap và không phụ thuộc timestamp precision cuối ngày.

### Principle 5 – Preserve outer-join intent

Predicate ở `WHERE` trên right side của `LEFT JOIN` có thể loại unmatched rows. Predicate placement là semantics, không chỉ style.

---

## 4. Fundamentals

### 4.1 Three-valued logic

```sql
SELECT NULL = 10;     -- NULL / UNKNOWN
SELECT NULL <> 10;    -- NULL / UNKNOWN
SELECT NULL = NULL;   -- NULL / UNKNOWN
```

Tìm missing value:

```sql
WHERE email IS NULL
```

không phải:

```sql
WHERE email = NULL
```

### 4.2 Null-safe equality in Databricks

Databricks hỗ trợ null-safe comparison.

```sql
SELECT equal_null(NULL, NULL);  -- true
```

và operator `<=>` có semantics tương tự cho null-safe equality.

Không dùng null-safe equality thay `IS NULL` một cách máy móc; chọn theo intent.

### 4.3 NOT IN + NULL trap

Nếu set phía phải có `NULL`, anti-membership có thể trở thành UNKNOWN.

Với anti-join business question, thường ưu tiên:

```sql
WHERE NOT EXISTS (...)
```

hoặc Databricks-native:

```sql
LEFT ANTI JOIN
```

sẽ học ở Lesson 04.

### 4.4 `COALESCE`

```sql
COALESCE(email, 'missing')
```

trả expression đầu tiên không NULL.

Nhưng:

```sql
COALESCE(birth_date, DATE '1900-01-01')
```

có thể biến “unknown” thành dữ liệu giả và làm metric sai.

### 4.5 `NULLIF`

Tránh denominator zero:

```sql
numerator / NULLIF(denominator, 0)
```

Nếu denominator = 0 → result NULL thay vì chia 0.

### 4.6 `CASE`

```sql
CASE
  WHEN amount >= 500000 THEN 'high'
  WHEN amount >= 100000 THEN 'medium'
  ELSE 'low'
END
```

Order condition quan trọng: nhánh đầu tiên match thắng.

### 4.7 Databricks type rules

Databricks có:

- type promotion;
- implicit downcasting trong một số context;
- implicit crosscasting khi intent đủ rõ;
- least-common-type resolution cho expressions/set operations.

Mental rule cho course:

> Nếu correctness phụ thuộc type, cast explicit.

Ví dụ money:

```sql
CAST(amount AS DECIMAL(14,2))
```

không dựa vào `DOUBLE` nếu cần exact decimal arithmetic.

### 4.8 `CAST` vs `try_cast`

Strict:

```sql
SELECT CAST('123' AS INT);   -- 123
SELECT CAST('abc' AS INT);   -- error in strict/ANSI behavior
```

Tolerant:

```sql
SELECT try_cast('123' AS INT); -- 123
SELECT try_cast('abc' AS INT); -- NULL
```

Data-quality pattern:

```sql
SELECT
  raw_amount,
  try_cast(raw_amount AS DECIMAL(14,2)) AS parsed_amount,
  CASE
    WHEN raw_amount IS NOT NULL
     AND try_cast(raw_amount AS DECIMAL(14,2)) IS NULL
    THEN 'invalid_amount'
  END AS quality_issue
FROM staging;
```

### 4.9 Time boundaries

Toàn bộ ngày 05/08:

```sql
WHERE event_ts >= TIMESTAMP '2026-08-05 00:00:00'
  AND event_ts <  TIMESTAMP '2026-08-06 00:00:00'
```

### 4.10 LEFT JOIN predicate placement

Preserve all customers and attach only successful transactions:

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

Potential bug:

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id
WHERE b.status = 'success';
```

Unmatched rows có `b.status = NULL` nên không pass `WHERE`.

---

## 5. Worked example – Parse-quality pattern

Giả sử staging có:

```text
raw_amount STRING
```

Requirement:

- parse được → DECIMAL;
- malformed → không làm query chết;
- malformed phải được nhìn thấy bởi quality check.

```sql
WITH parsed AS (
  SELECT
    raw_amount,
    try_cast(raw_amount AS DECIMAL(14,2)) AS amount
  FROM VALUES
    ('100000'),
    ('25000.50'),
    ('bad'),
    (NULL)
  AS t(raw_amount)
)
SELECT
  raw_amount,
  amount,
  CASE
    WHEN raw_amount IS NULL THEN 'missing'
    WHEN amount IS NULL THEN 'malformed'
    ELSE 'valid'
  END AS parse_status
FROM parsed;
```

Điểm chính:

> `try_cast` là error-tolerant parsing primitive; quality classification mới là business/data-engineering logic.

---

## 6. Hands-on lab

### Core

1. Customer thiếu email/birth date.
2. Count NULL theo province.
3. Successful revenue trong `[2026-08-01, 2026-08-06)`.
4. Transaction value band bằng `CASE`.
5. Safe ratio bằng `NULLIF`.
6. LEFT JOIN preserve all customers; so với phiên bản filter sai trong `WHERE`.

### Databricks-specific

7. Chạy và giải thích:

```sql
SELECT try_cast('42' AS INT), try_cast('bad' AS INT);
```

8. So sánh `CAST` và `try_cast` trên malformed values.
9. Thử type introspection:

```sql
SELECT typeof(1), typeof(1.0), typeof(NULL);
```

10. Tạo `VALUES` dataset chứa numeric strings + invalid strings; parse bằng `try_cast`; thống kê valid/malformed/missing.
11. So sánh:

```sql
NULL = NULL
```

với:

```sql
equal_null(NULL, NULL)
```

và giải thích intent.

### Challenge

Thiết kế Bronze → Silver rule cho field `duration_seconds` nhận STRING:

```text
null input
valid non-negative integer
malformed string
negative integer
```

Viết query classification và nói row nào nên quarantine.

---

## 7. Knowledge check – MCQ

**Q1.** `WHERE` giữ row khi predicate là:  
A. TRUE; B. TRUE hoặc UNKNOWN; C. FALSE; D. NULL.

**Q2.** Tìm missing email:  
A. `email = NULL`; B. `email IS NULL`; C. `email == NULL`; D. `NOT email`.

**Q3.** Databricks `try_cast('bad' AS INT)` chủ yếu:  
A. error luôn; B. trả NULL nếu cast combination hợp lệ nhưng value malformed; C. trả 0; D. trả STRING.

**Q4.** Khi invalid amount phải làm pipeline fail fast, lựa chọn phù hợp hơn:  
A. `try_cast` rồi bỏ qua; B. strict `CAST`/validation fail; C. COALESCE 0; D. DISTINCT.

**Q5.** Half-open interval toàn ngày Aug-05 kết thúc:  
A. `<= Aug-05`; B. `< Aug-06`; C. `< Aug-05`; D. `= Aug-05`.

**Q6.** Right-side filter trong `WHERE` sau LEFT JOIN có thể:  
A. preserve unmatched chắc chắn; B. loại unmatched rows; C. dedup; D. cluster table.

**Q7.** `equal_null(NULL,NULL)` khác `NULL = NULL` ở chỗ:  
A. null-safe comparison trả true; B. giống hệt; C. delete NULL; D. cast NULL.

---

## 8. Tự luận / Interview

1. `NULL` khác zero như thế nào trong metric?
2. `try_cast` nên dùng ở Bronze→Silver khi nào?
3. Tại sao “parse failure thành NULL” chưa đủ để gọi là data quality?
4. Implicit cast tiện nhưng có rủi ro gì?
5. `LEFT JOIN` + WHERE right-side predicate phá semantics ra sao?
6. Khi nào dùng null-safe equality thay `IS NULL`?
7. Vì sao `[start,end)` phù hợp incremental batches?

---

## 9. Exit criteria

- [ ] Không dùng `= NULL`.
- [ ] Giải thích TRUE/FALSE/UNKNOWN.
- [ ] Phân biệt `CAST` và `try_cast`.
- [ ] Viết quality classification cho malformed value.
- [ ] Viết đúng half-open timestamp filter.
- [ ] Giải thích LEFT JOIN predicate placement.
- [ ] Đạt >=6/7 MCQ.