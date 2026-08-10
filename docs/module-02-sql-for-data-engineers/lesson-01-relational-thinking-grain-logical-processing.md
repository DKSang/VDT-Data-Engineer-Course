# Lesson 01 – Relational Thinking, Grain & Logical Query Processing

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích table/relation, row/tuple, column/attribute theo cách hữu ích cho Data Engineering.
- Xác định **grain** của bảng và grain của output trước khi viết query.
- Phân biệt primary key, candidate key, business key và foreign key.
- Dự đoán tác động của duplicate và key không unique lên kết quả downstream.
- Giải thích logical query processing order và dùng nó để debug SQL.
- Viết query có validation check thay vì chỉ nhìn vài row đầu rồi kết luận đúng.

---

## 2. Principles

### Principle 1 – Grain before query

Trước khi viết SQL, hãy hoàn thành câu:

> Mỗi row của output đại diện cho ______.

Ví dụ:

- 1 row / customer;
- 1 row / province / day;
- 1 row / tower / 5-minute window;
- 1 row / billing transaction.

Nếu không nói được grain, bạn chưa đủ thông tin để biết `GROUP BY`, `JOIN` hay dedup có đúng hay không.

### Principle 2 – SQL transforms relations, not files

Hãy nghĩ query như chuỗi biến đổi các relation trung gian. Mỗi bước có:

- schema;
- grain;
- row count/cardinality;
- key kỳ vọng.

Tư duy này quan trọng hơn việc viết query ngắn.

### Principle 3 – Uniqueness is a data contract

Một cột có tên `customer_id` không có nghĩa nó tự động unique. Uniqueness phải đến từ constraint hoặc được kiểm chứng.

Khi join với bảng mà key phía bên phải không unique, row phía trái có thể bị nhân lên.

### Principle 4 – Correctness must be testable

Một query đáng tin phải có cách kiểm tra:

- expected row count;
- uniqueness;
- null rate;
- reconciliation total;
- anti-join để tìm missing keys.

---

## 3. Fundamentals

### 3.1 Relation và row

Trong thực hành, table là một representation của relation. Ta quan tâm:

- **columns** mô tả thuộc tính;
- **rows** mô tả các bản ghi ở một grain;
- **keys** giúp nhận diện/ghép record;
- **constraints** bảo vệ assumptions.

SQL result cũng là một relation tạm thời mà query tiếp theo có thể sử dụng.

### 3.2 Grain

Ví dụ bảng `billing_transactions`:

```text
transaction_id | customer_id | transaction_ts | amount
```

Grain:

> 1 row / billing transaction.

Nếu muốn doanh thu theo customer, output grain chuyển thành:

> 1 row / customer.

Do đó cần aggregation.

```sql
SELECT customer_id, SUM(amount) AS revenue
FROM billing_transactions
WHERE status = 'success'
GROUP BY customer_id;
```

### 3.3 Keys

**Primary key:** key được database enforce để nhận diện row.

**Candidate key:** một tập column có thể unique về mặt logic.

**Business/natural key:** key đến từ nghiệp vụ, ví dụ `event_id` do upstream sinh.

**Surrogate key:** key kỹ thuật do hệ thống sinh, ví dụ `ingest_row_id`.

**Foreign key:** ràng buộc quan hệ giữa child và parent.

Trong `network_events`, `ingest_row_id` là primary key nhưng `event_id` mới là business identifier cần dùng cho dedup.

### 3.4 Cardinality

Các quan hệ thường gặp:

```text
1:1
1:N
N:1
N:M
```

`customers → billing_transactions` là 1:N.

Nếu join customer với transaction, output grain không còn 1 row/customer mà gần với 1 row/transaction có customer attributes.

### 3.5 Logical query processing

SQL được **viết** thường theo thứ tự:

```sql
SELECT ...
FROM ...
WHERE ...
GROUP BY ...
HAVING ...
ORDER BY ...
```

Nhưng để reasoning, hãy nghĩ gần với thứ tự logic:

```text
FROM / JOIN
   ↓
WHERE
   ↓
GROUP BY + aggregate
   ↓
HAVING
   ↓
SELECT
   ↓
DISTINCT
   ↓
ORDER BY
   ↓
LIMIT/FETCH
```

Window functions được tính sau `WHERE/GROUP BY/HAVING` và trước final ordering, nên không thể thông thường dùng alias window trực tiếp trong `WHERE` cùng query level; ta cần subquery/CTE.

### 3.6 `SELECT *` và schema drift

`SELECT *` hữu ích khi khám phá dữ liệu, nhưng production pipeline nên chọn column rõ ràng khi schema contract quan trọng.

Nếu upstream thêm một column cực lớn hoặc nhạy cảm, `SELECT *` có thể làm thay đổi cost, schema output hoặc security exposure mà code không thể hiện intent.

---

## 4. Worked example – Từ transaction grain sang customer grain

### Business question

> Tổng doanh thu thành công của mỗi customer từ 01/08/2026 đến hết 05/08/2026 là bao nhiêu?

### Bước 1 – Input grain

`billing_transactions`: 1 row / transaction.

### Bước 2 – Filter semantics

Chỉ transaction `success`.

Dùng half-open interval để tránh lỗi timestamp boundary:

```sql
transaction_ts >= TIMESTAMP '2026-08-01'
AND transaction_ts < TIMESTAMP '2026-08-06'
```

### Bước 3 – Output grain

1 row / customer.

### Query

```sql
SELECT
    customer_id,
    COUNT(*) AS successful_txn_count,
    SUM(amount) AS revenue
FROM billing_transactions
WHERE status = 'success'
  AND transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-08-06'
GROUP BY customer_id
ORDER BY revenue DESC;
```

### Validation

Reconcile tổng:

```sql
SELECT SUM(amount)
FROM billing_transactions
WHERE status = 'success'
  AND transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-08-06';
```

Tổng này phải bằng tổng `revenue` của result customer-level.

Đây là mindset quan trọng: **aggregate query + reconciliation query**.

---

## 5. Hands-on lab

Chạy `labs/module-02-sql/schema.sql` và `seed.sql`.

Tạo `lesson-01.sql` và hoàn thành:

1. Viết comment mô tả grain của cả 7 bảng.
2. Kiểm tra key nào unique thực sự bằng `GROUP BY ... HAVING COUNT(*) > 1`.
3. Chứng minh `event_id` trong `network_events` có duplicate.
4. Tính số billing transaction/customer.
5. Tính tổng successful revenue/customer.
6. So sánh row count trước và sau khi join `customers` với `billing_transactions`.
7. Giải thích tại sao join đó không còn customer grain.
8. Viết một validation query đảm bảo output customer-level chỉ có tối đa 1 row/customer.

### Challenge

Tạo query trả:

```text
province | customer_count | successful_revenue
```

Trước khi code, ghi:

```text
Input grain:
Join relationship:
Output grain:
Potential double-count risk:
```

### Deliverables

- `lesson-01.sql`;
- `notes.md` có 5–10 dòng mô tả grain/cardinality;
- screenshot hoặc copy output của query phát hiện duplicate `event_id`.

---

## 6. Knowledge check – MCQ

**Q1.** Grain tốt nhất mô tả điều gì?  
A. Số column; B. Ý nghĩa của một row; C. Kích thước file; D. Index type.

**Q2.** `customers` 1:N `billing_transactions`. Join trực tiếp hai bảng thường tạo output gần grain nào?  
A. 1 row/customer; B. 1 row/transaction có customer attributes; C. 1 row/province; D. luôn N:M.

**Q3.** Một column tên `event_id` có đảm bảo unique không?  
A. Có; B. Chỉ khi được constraint hoặc kiểm chứng; C. Chỉ với TEXT; D. Chỉ trong warehouse.

**Q4.** `WHERE` logic xảy ra trước hay sau `GROUP BY`?  
A. Trước; B. Sau; C. Đồng thời; D. Không liên quan.

**Q5.** Validation nào kiểm tra output 1 row/customer?  
A. `ORDER BY`; B. `GROUP BY customer_id HAVING COUNT(*) > 1`; C. `LIMIT 10`; D. `SELECT *`.

**Q6.** Surrogate key khác business key ở điểm quan trọng nào?  
A. Surrogate key thường do hệ thống kỹ thuật sinh; B. luôn là string; C. không unique; D. không join được.

---

## 7. Knowledge check – Tự luận / Interview

1. “Grain” là gì? Giải thích bằng `billing_transactions` và `customers`.
2. Tại sao một query có kết quả nhìn hợp lý nhưng vẫn có thể sai vì join fan-out?
3. Primary key và business key có thể khác nhau như thế nào trong event ingestion?
4. Giải thích logical query processing mà không đọc cú pháp SQL.
5. Vì sao `LIMIT 10` không phải cách kiểm tra correctness?
6. Bạn sẽ chứng minh bảng dimension phải unique theo key bằng SQL nào?
7. Khi nào `SELECT *` chấp nhận được, khi nào nguy hiểm trong pipeline?

---

## 8. Exit criteria

- [ ] Mô tả đúng grain của 7 bảng lab.
- [ ] Phát hiện được duplicate `event_id` bằng SQL.
- [ ] Dự đoán cardinality trước khi join.
- [ ] Giải thích logical query order không nhìn tài liệu.
- [ ] Có ít nhất 2 validation query cho bài aggregate.
- [ ] Đạt ít nhất 5/6 MCQ.