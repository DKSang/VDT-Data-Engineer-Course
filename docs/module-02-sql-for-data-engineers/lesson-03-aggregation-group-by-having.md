# Lesson 03 – Aggregation, GROUP BY, HAVING & Grain Control

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Chuyển input grain thành output grain bằng aggregation có chủ đích.
- Giải thích khác nhau giữa `WHERE` và `HAVING`.
- Dùng `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` đúng semantics.
- Phân biệt `COUNT(*)`, `COUNT(column)` và `COUNT(DISTINCT column)`.
- Dùng conditional aggregation để tạo metric.
- Nhận diện double-counting trước/sau join.
- Viết reconciliation query cho aggregate result.

---

## 2. Principles

### Principle 1 – GROUP BY is a grain-changing operator

Nếu input là 1 row/transaction và `GROUP BY customer_id`, output trở thành 1 row/customer.

Hãy nói grain trước khi code:

```text
Input grain: 1 row / transaction
Output grain: 1 row / customer / day
```

Sau đó `GROUP BY` phải phản ánh đúng grain mới.

### Principle 2 – Aggregate only after deciding what a metric means

“Revenue” có thể nghĩa:

- tất cả amount;
- chỉ `success`;
- success trừ refund;
- recognized revenue theo accounting period.

SQL không tự biết business definition. Metric definition phải rõ trước query.

### Principle 3 – Join before aggregate can multiply facts

Nếu join một fact table với relation không unique theo key, các fact rows bị nhân lên trước `SUM`, tạo metric sai nhưng vẫn chạy hợp lệ.

### Principle 4 – Every important aggregate needs reconciliation

Nếu tính revenue by province, hãy kiểm tra tổng revenue của các province có bằng global revenue theo cùng filter không.

---

## 3. Fundamentals

### 3.1 Aggregate functions

```sql
COUNT(*)
COUNT(column)
COUNT(DISTINCT column)
SUM(amount)
AVG(amount)
MIN(amount)
MAX(amount)
```

Khác biệt quan trọng:

```sql
COUNT(*)
```

đếm rows.

```sql
COUNT(email)
```

chỉ đếm rows có `email IS NOT NULL`.

### 3.2 GROUP BY

```sql
SELECT
    customer_id,
    SUM(amount) AS revenue
FROM billing_transactions
GROUP BY customer_id;
```

Mọi non-aggregated selected expression phải phù hợp với grouping semantics.

### 3.3 WHERE vs HAVING

`WHERE` filter rows **trước** aggregation.

`HAVING` filter groups **sau** aggregation.

```sql
SELECT customer_id, SUM(amount) AS revenue
FROM billing_transactions
WHERE status = 'success'
GROUP BY customer_id
HAVING SUM(amount) >= 300000;
```

Ở đây:

- `WHERE` loại failed/refunded transactions trước tính revenue;
- `HAVING` chỉ giữ customer có aggregate revenue >= 300k.

### 3.4 Conditional aggregation

```sql
SELECT
    customer_id,
    SUM(CASE WHEN status = 'success' THEN amount ELSE 0 END) AS success_amount,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) AS failed_count
FROM billing_transactions
GROUP BY customer_id;
```

PostgreSQL còn có `FILTER`, nhưng `CASE` portable hơn giữa nhiều SQL engine.

### 3.5 Ratio metrics

Ví dụ call-drop rate:

```text
drop rate = drop events / (drop + normal end events)
```

Query:

```sql
SELECT
    tower_id,
    SUM(CASE WHEN event_type = 'call_drop' THEN 1 ELSE 0 END)::numeric
      / NULLIF(
          SUM(CASE WHEN event_type IN ('call_drop','call_end') THEN 1 ELSE 0 END),
          0
        ) AS call_drop_rate
FROM network_events
GROUP BY tower_id;
```

Nhưng dataset có duplicate event, nên metric này chưa chắc đúng. Đây là bài học: **aggregation correct syntax không đồng nghĩa correct data**. Dedup sẽ học ở Lesson 07.

### 3.6 Average of averages trap

Nếu group A có 10 rows average 100, group B có 1000 rows average 50:

```text
(100 + 50) / 2
```

không phải overall average đúng.

Cần weighted reasoning hoặc aggregate từ base data.

### 3.7 Distinct as warning sign

`COUNT(DISTINCT customer_id)` có thể hoàn toàn đúng. Nhưng `SELECT DISTINCT` được thêm chỉ để “xóa duplicate sau join” thường là dấu hiệu bạn chưa hiểu cardinality.

Đừng dùng `DISTINCT` như thuốc chữa join sai.

---

## 4. Worked example – Daily province revenue

### Requirement

Tính successful revenue theo ngày và province.

### Grain reasoning

```text
billing_transactions: 1 row / transaction
customers:            1 row / customer
relationship:         many transactions -> one customer
output:               1 row / transaction_date / province
```

Vì `customers.customer_id` unique, join N:1 không nhân transaction nếu data contract giữ đúng.

```sql
SELECT
    b.transaction_ts::date AS revenue_date,
    c.province,
    COUNT(*) AS transaction_count,
    COUNT(DISTINCT b.customer_id) AS paying_customers,
    SUM(b.amount) AS revenue
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY
    b.transaction_ts::date,
    c.province
ORDER BY revenue_date, c.province;
```

### Reconciliation

```sql
WITH by_province AS (
    SELECT
        b.transaction_ts::date AS revenue_date,
        c.province,
        SUM(b.amount) AS revenue
    FROM billing_transactions b
    JOIN customers c ON c.customer_id = b.customer_id
    WHERE b.status = 'success'
    GROUP BY b.transaction_ts::date, c.province
)
SELECT SUM(revenue)
FROM by_province;
```

So sánh với:

```sql
SELECT SUM(amount)
FROM billing_transactions
WHERE status = 'success';
```

Nếu khác, cần điều tra missing customer, duplicate dimension key hoặc filter không đồng nhất.

---

## 5. Hands-on lab

Tạo `lesson-03.sql`.

### Core exercises

1. Revenue theo `transaction_type`.
2. Revenue theo ngày.
3. Revenue theo province/ngày.
4. Số successful/failed/refunded transaction bằng conditional aggregation.
5. Customer có successful revenue >= 200k dùng `HAVING`.
6. Đếm số customer có email và thiếu email theo province.
7. Tính average successful transaction amount theo payment method.
8. Tính call-drop rate/tower, trước mắt chưa dedup.
9. Tìm tower có ít nhất 2 call end/drop events và drop rate > 30%.
10. Viết reconciliation cho revenue by province.

### Double-count experiment

Tạo CTE `status_history` rồi join trực tiếp:

```sql
billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
```

Sau đó `SUM(b.amount)`.

So sánh với base successful revenue.

Trả lời:

- Vì sao total bị tăng?
- `customer_status_history` có grain gì?
- Join relationship thực tế là gì?
- Sửa bằng cách nào nếu business muốn latest customer status?

Chưa cần viết final solution bằng window function; chỉ cần mô tả relation cần tạo trước join.

### Challenge

Tạo daily metric gồm:

```text
date
successful_revenue
successful_txn_count
failed_txn_count
unique_paying_customers
avg_successful_txn_value
```

Ghi rõ mỗi metric có denominator/population nào.

---

## 6. Knowledge check – MCQ

**Q1.** `COUNT(email)` khác `COUNT(*)` vì:  
A. chỉ đếm email unique; B. bỏ row có email NULL; C. nhanh hơn luôn; D. chỉ dùng với GROUP BY.

**Q2.** `WHERE` và `HAVING` khác nhau chính ở:  
A. WHERE trước grouping, HAVING sau grouping; B. không khác; C. HAVING trước FROM; D. WHERE chỉ cho string.

**Q3.** Nếu join fact với history table nhiều row/key rồi `SUM(fact.amount)`, rủi ro chính là:  
A. syntax error; B. double-count; C. NULL tự mất; D. index hỏng.

**Q4.** `SELECT DISTINCT` sau join sai:  
A. luôn là fix chuẩn; B. có thể che giấu lỗi cardinality; C. bắt buộc cho DE; D. làm key unique tại source.

**Q5.** Overall average từ average từng group có thể sai vì:  
A. group size khác nhau; B. AVG không support number; C. GROUP BY random; D. NULL luôn thành zero.

**Q6.** Aggregate validation tốt cho revenue by province là:  
A. `LIMIT 10`; B. reconcile tổng các province với global total cùng filter; C. sort DESC; D. đổi alias.

---

## 7. Knowledge check – Tự luận / Interview

1. Giải thích `COUNT(*)`, `COUNT(column)`, `COUNT(DISTINCT column)` bằng NULL.
2. Cho ví dụ `HAVING` đúng và một trường hợp đáng lẽ nên dùng `WHERE`.
3. Vì sao average-of-averages nguy hiểm?
4. Tại sao fact + SCD/history join dễ double-count?
5. Conditional aggregation khác filter toàn query như thế nào?
6. Khi nhìn một KPI `drop_rate = 3%`, bạn cần hỏi numerator và denominator gì?
7. `DISTINCT` khi nào đúng về business và khi nào chỉ đang che bug?

---

## 8. Exit criteria

- [ ] Ghi đúng input/output grain cho mọi aggregate lab.
- [ ] Phân biệt WHERE/HAVING không nhầm.
- [ ] Tạo được ít nhất 3 conditional metrics trong một query.
- [ ] Tự tạo và giải thích join double-count bug.
- [ ] Có reconciliation query cho revenue.
- [ ] Đạt ít nhất 5/6 MCQ.