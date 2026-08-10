# Lesson 04 – JOINs, Cardinality & Set Operations

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích `INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS` join theo row-preservation semantics.
- Dự đoán cardinality trước khi join.
- Nhận diện one-to-one, one-to-many, many-to-one và accidental many-to-many.
- Phân biệt join key kỹ thuật với business join condition theo thời gian.
- Dùng semi-join/anti-join reasoning với `EXISTS`/`NOT EXISTS`.
- Phân biệt `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT`.
- Debug missing keys và fan-out bằng validation queries.

---

## 2. Principles

### Principle 1 – JOIN is a cardinality operation

Đừng hỏi trước “cú pháp LEFT JOIN là gì?”. Hãy hỏi:

> Mỗi row phía trái có thể match bao nhiêu row phía phải?

Nếu câu trả lời là “không biết”, query chưa đủ an toàn để aggregate.

### Principle 2 – Keys must be validated on the side expected to be unique

Nếu bạn tin `customers.customer_id` unique, database constraint có thể bảo vệ assumption đó. Nếu join với staging/dimension không có constraint, hãy kiểm tra uniqueness bằng query trước.

### Principle 3 – Outer join means row preservation

`LEFT JOIN` nói rằng relation trái là population cần giữ. Mọi predicate sau đó phải tôn trọng intent đó.

### Principle 4 – Time-aware joins are different from equality joins

History/SCD table thường không thể join chỉ bằng:

```sql
ON fact.customer_id = dim.customer_id
```

mà còn cần điều kiện hiệu lực:

```text
fact_time >= effective_from
fact_time < effective_to
```

Nếu bỏ temporal predicate, một fact có thể match nhiều versions.

---

## 3. Fundamentals

### 3.1 INNER JOIN

Chỉ giữ pairs có match.

```sql
SELECT ...
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id;
```

Nếu `customers.customer_id` unique, đây là many-to-one từ transaction sang customer.

### 3.2 LEFT JOIN

Giữ mọi row trái, kể cả không match.

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id;
```

Customer không transaction vẫn tồn tại với columns của `b` là NULL.

### 3.3 FULL JOIN

Giữ unmatched từ cả hai phía. Hữu ích trong reconciliation/migration compare, nhưng ít dùng hơn trong pipeline thường ngày.

### 3.4 CROSS JOIN

Cartesian product:

```text
rows_out = rows_left × rows_right
```

Có use case hợp lệ như tạo calendar × entity grid, nhưng accidental cross join có thể bùng nổ dữ liệu.

### 3.5 Cardinality checklist

Trước mỗi join, ghi:

```text
Left grain:
Right grain:
Join key:
Expected right uniqueness:
Expected matches per left row:
Expected output grain:
```

Ví dụ:

```text
Left: billing transaction
Right: customer
Key: customer_id
Right uniqueness: exactly 1
Matches per fact: 1
Output grain: transaction
```

### 3.6 Join fan-out

Nếu join `billing_transactions` với `customer_status_history` chỉ theo customer:

```text
transaction 3002
   × status active
   × status inactive
   × status active
```

Một transaction biến thành 3 rows.

Sau `SUM(amount)`, revenue bị nhân.

### 3.7 Semi-join

Câu hỏi:

> Customer nào có ít nhất một successful transaction?

Ta chỉ cần existence, không cần columns transaction.

```sql
SELECT c.*
FROM customers c
WHERE EXISTS (
    SELECT 1
    FROM billing_transactions b
    WHERE b.customer_id = c.customer_id
      AND b.status = 'success'
);
```

Đây là semantics của semi-join.

### 3.8 Anti-join

Customer chưa có successful transaction:

```sql
SELECT c.*
FROM customers c
WHERE NOT EXISTS (
    SELECT 1
    FROM billing_transactions b
    WHERE b.customer_id = c.customer_id
      AND b.status = 'success'
);
```

### 3.9 Set operations

`UNION ALL`: nối rows, giữ duplicate.

`UNION`: nối rồi loại duplicate.

`INTERSECT`: rows xuất hiện ở cả hai sets.

`EXCEPT`: rows ở set trái nhưng không ở set phải.

Trong data pipelines, `UNION ALL` thường đúng hơn khi ghép partitions/batches vì duplicate elimination phải là quyết định business riêng, không nên vô tình phát sinh do operator.

---

## 4. Worked example – Active customer revenue without fan-out

### Problem

Muốn doanh thu theo **latest current status** của customer.

Sai:

```sql
SELECT h.status, SUM(b.amount)
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY h.status;
```

Vì history có nhiều row/customer.

### Relation cần tạo trước

Ta cần relation:

```text
latest_customer_status
Grain: 1 row / customer
```

Có thể tạo bằng window function ở Lesson 06/07. Logic khái niệm:

```sql
WITH latest_status AS (
    -- one row per customer
    ...
)
SELECT
    s.status,
    SUM(b.amount) AS revenue
FROM billing_transactions b
JOIN latest_status s
  ON s.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY s.status;
```

Bài học: **fix join fan-out bằng cách sửa relation/grain**, không phải thêm `DISTINCT` ở cuối.

---

## 5. Hands-on lab

Tạo `lesson-04.sql`.

### Part A – Join behavior

1. `customers INNER JOIN billing_transactions`: row count bao nhiêu?
2. `customers LEFT JOIN billing_transactions`: customer nào không có transaction?
3. Chứng minh unmatched row có right-side columns NULL.
4. `billing_transactions JOIN customers`: chứng minh row count không đổi nếu mọi FK match và right key unique.
5. Join `billing_transactions` với `customer_status_history` chỉ theo `customer_id`; đo fan-out factor:

```text
joined_row_count / base_fact_row_count
```

### Part B – Cardinality validation

Viết query kiểm tra:

```sql
GROUP BY key
HAVING COUNT(*) > 1
```

cho:

- `customers.customer_id`;
- `plans.plan_id`;
- `network_events.event_id`;
- `customer_status_history.customer_id`.

Giải thích tại sao duplicate có nghĩa khác nhau ở từng bảng.

### Part C – Semi/anti join

1. Customer có ít nhất một successful transaction.
2. Customer không có successful transaction.
3. Tower chưa có `call_drop`.
4. Province có customer nhưng chưa phát sinh successful revenue.

### Part D – Set operations

1. Tạo hai tập customer: `Ha Noi` và `HCM`; nối bằng `UNION ALL`.
2. Tạo hai tập: customer có successful payment và customer có active subscription; tìm giao bằng `INTERSECT`.
3. Tìm active subscription customer nhưng chưa successful payment bằng `EXCEPT` hoặc `NOT EXISTS`.
4. So sánh `UNION` vs `UNION ALL` khi hai sets overlap.

### Challenge – temporal join reasoning

Không cần code hoàn chỉnh SCD. Hãy viết pseudo-SQL join transaction với status có hiệu lực tại `transaction_ts`:

```text
b.customer_id = h.customer_id
AND b.transaction_ts >= h.effective_from
AND b.transaction_ts < next_effective_from
```

Giải thích vì sao chỉ equality key chưa đủ.

---

## 6. Knowledge check – MCQ

**Q1.** Join fact N rows với dimension unique key 1 row/key thường giữ grain nào?  
A. Fact grain; B. Dimension grain; C. random; D. Cartesian.

**Q2.** Fan-out xảy ra khi:  
A. một left row match nhiều right rows ngoài intent; B. dùng alias; C. SUM NULL; D. ORDER BY.

**Q3.** Nếu chỉ cần biết “có tồn tại transaction không”, pattern tự nhiên là:  
A. CROSS JOIN; B. EXISTS; C. FULL JOIN bắt buộc; D. DISTINCT *.

**Q4.** `UNION ALL`:  
A. loại duplicate; B. giữ duplicate; C. chỉ numeric; D. join bằng key.

**Q5.** Fix đúng cho fact join history bị multiply là:  
A. luôn `SELECT DISTINCT`; B. tạo relation history đúng grain/temporal condition trước join; C. tăng LIMIT; D. ORDER BY.

**Q6.** `LEFT JOIN` biểu diễn intent:  
A. chỉ giữ match; B. preserve rows phía trái; C. Cartesian; D. aggregate.

---

## 7. Knowledge check – Tự luận / Interview

1. Phân biệt 1:N và N:1 từ góc nhìn query direction.
2. Tại sao join fan-out nguy hiểm hơn syntax error?
3. Semi-join là gì? Khi nào `EXISTS` rõ nghĩa hơn join + DISTINCT?
4. `UNION` vs `UNION ALL`: khi nào duplicate removal là bug?
5. Temporal join cần thêm thông tin gì ngoài entity key?
6. Cách debug một dashboard revenue đột nhiên tăng gấp 3 sau khi thêm dimension customer status?
7. Bạn kiểm tra missing foreign keys bằng SQL thế nào?

---

## 8. Exit criteria

- [ ] Với mỗi join lab, ghi được expected cardinality trước khi chạy.
- [ ] Tự tạo và đo fan-out factor.
- [ ] Dùng được `EXISTS` và `NOT EXISTS`.
- [ ] Phân biệt `UNION`/`UNION ALL` không nhầm.
- [ ] Giải thích temporal join concept.
- [ ] Đạt ít nhất 5/6 MCQ.