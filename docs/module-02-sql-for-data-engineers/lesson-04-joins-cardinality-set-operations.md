# Lesson 04 – JOINs, Cardinality & Set Operations on Databricks

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích `INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS` join theo row-preservation semantics.
- Dùng Databricks `LEFT SEMI JOIN` và `LEFT ANTI JOIN` đúng intent.
- Dự đoán matches per left row trước khi join.
- Phát hiện accidental many-to-many và join fan-out.
- Phân biệt entity-key join với temporal/effective-time join.
- Dùng `UNION`, `UNION ALL`, `INTERSECT`, `EXCEPT` đúng semantics.
- Viết validation cho duplicate key, orphan key và exploding join.

---

## 2. Source alignment

### Primary Databricks sources

- JOIN  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-join
- Set operators  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-setops
- Query Profile – exploding join diagnostics  
  https://docs.databricks.com/aws/en/sql/user/queries/query-profile

### Scope note

Databricks SQL exposes semi/anti joins directly in the JOIN syntax. Course vẫn dạy `EXISTS`/`NOT EXISTS` vì chúng là relational patterns quan trọng và portable; learner phải hiểu hai cách diễn đạt cùng business intent.

---

## 3. Principles

### Principle 1 – JOIN is a cardinality operator

Trước khi code, trả lời:

```text
Left grain:
Right grain:
Join key:
Right key expected unique?
Matches per left row?
Rows nào cần preserve?
```

Nếu “matches per left row” không rõ, aggregate sau join chưa đáng tin.

### Principle 2 – Row preservation defines outer-join intent

`LEFT JOIN` nói rằng population phía trái phải được giữ.

Nếu downstream filter làm mất unmatched rows, query đã đổi semantics.

### Principle 3 – Existence does not require row multiplication

Nếu câu hỏi chỉ là:

> entity có match hay không?

thì semi/anti join hoặc `EXISTS`/`NOT EXISTS` thường đúng intent hơn inner join + `DISTINCT`.

### Principle 4 – History requires time-aware matching

History relation nhiều row/entity thường cần validity condition, không chỉ equality key.

### Principle 5 – Exploding join is both correctness and performance risk

Databricks Query Profile có thể surface exploding join vì output rows tăng mạnh so với input. Trước khi coi đây là performance issue, hãy hỏi: **cardinality đó có đúng business semantics không?**

---

## 4. Fundamentals

### 4.1 INNER JOIN

```sql
SELECT b.transaction_id, c.province
FROM billing_transactions b
INNER JOIN customers c
  ON c.customer_id = b.customer_id;
```

Nếu `customers.customer_id` unique và mọi transaction có match, output giữ fact grain.

### 4.2 LEFT JOIN

```sql
SELECT c.customer_id, b.transaction_id
FROM customers c
LEFT JOIN billing_transactions b
  ON b.customer_id = c.customer_id;
```

Customer không có transaction vẫn tồn tại với right-side NULLs.

### 4.3 RIGHT / FULL JOIN

`RIGHT`: preserve right relation.

`FULL`: preserve unmatched rows ở cả hai phía.

`FULL JOIN` hữu ích cho reconciliation/source-vs-target compare.

### 4.4 CROSS JOIN

```text
rows_out ≈ rows_left × rows_right
```

Hợp lệ cho use case như entity × calendar grid; nguy hiểm nếu accidental.

### 4.5 Databricks LEFT SEMI JOIN

Trả **chỉ columns/rows phía trái có ít nhất một match**.

```sql
SELECT c.*
FROM customers c
LEFT SEMI JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

Business meaning:

> customers có ít nhất một successful transaction.

Không fan-out left rows vì output là left relation membership.

### 4.6 Databricks LEFT ANTI JOIN

Trả rows phía trái **không có match**.

```sql
SELECT c.*
FROM customers c
LEFT ANTI JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

Tương đương business intent của `NOT EXISTS` anti-join pattern.

### 4.7 Fan-out

Sai nếu business muốn current status nhưng join toàn history:

```sql
SELECT b.transaction_id, h.status
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id;
```

Một transaction/customer có thể match nhiều history rows.

Proof:

```sql
SELECT
  b.transaction_id,
  COUNT(*) AS copies_after_join
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
GROUP BY b.transaction_id
HAVING COUNT(*) > 1;
```

### 4.8 Temporal join

Nếu cần status có hiệu lực tại transaction time:

```text
b.customer_id = h.customer_id
AND b.transaction_ts >= h.effective_from
AND b.transaction_ts < h.effective_to
```

Nếu `effective_to` chưa tồn tại, có thể derive bằng `LEAD` ở Lesson 06/07.

### 4.9 Set operations

Databricks hỗ trợ:

```text
UNION [ALL | DISTINCT]
INTERSECT [ALL | DISTINCT]
EXCEPT [ALL | DISTINCT]
```

`UNION` mặc định DISTINCT semantics.

`UNION ALL` giữ duplicate rows.

Hai sides cần cùng số columns và compatible/least-common types.

Pipeline rule:

> Khi ghép partitions/batches, `UNION ALL` thường phản ánh raw semantics tốt hơn; dedup nên là explicit business step.

---

## 5. Worked example – Customers without successful payment

### Version A – LEFT ANTI JOIN

```sql
SELECT c.customer_id, c.full_name, c.province
FROM customers c
LEFT ANTI JOIN billing_transactions b
  ON b.customer_id = c.customer_id
 AND b.status = 'success';
```

### Version B – NOT EXISTS

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

### Reasoning

Cả hai nói về **absence of match**.

Không cần:

```sql
LEFT JOIN ...
WHERE b.customer_id IS NULL
```

mặc dù pattern đó cũng có thể đúng nếu viết cẩn thận.

### Validation

Output grain phải vẫn là 1 row/customer nếu input customers unique.

---

## 6. Hands-on lab

### Part A – Cardinality

1. `billing_transactions JOIN customers`: dự đoán và đo row count.
2. `customers LEFT JOIN billing_transactions`: customer nào không transaction?
3. Join billing → status history chỉ equality key; đo fan-out factor.
4. Viết uniqueness checks cho right-side keys trước joins.

### Part B – Semi/anti joins

5. Customer có successful transaction bằng `LEFT SEMI JOIN`.
6. Viết cùng bài bằng `EXISTS`; so outputs.
7. Customer không successful transaction bằng `LEFT ANTI JOIN`.
8. Viết cùng bài bằng `NOT EXISTS`; so outputs.
9. Tower có event nhưng chưa `call_drop` bằng anti join/existence reasoning.

### Part C – Set operations

10. Ghép Ha Noi + HCM customer sets bằng `UNION ALL`.
11. Tạo overlapping sets rồi so `UNION` vs `UNION ALL`.
12. Customers vừa có successful payment vừa có active subscription bằng `INTERSECT`.
13. Active subscription customers chưa successful payment bằng `EXCEPT` và bằng ANTI JOIN.

### Part D – Exploding join

14. Tạo intentionally exploding join với `customer_status_history`.
15. Nếu chạy trên Databricks SQL warehouse/serverless, mở Query Profile và ghi:

```text
input rows
output rows
join operator
rows amplification
```

### Challenge – point-in-time reasoning

Viết pseudo/partial SQL để join mỗi billing transaction vào status có hiệu lực tại `transaction_ts`. Giải thích cách ngăn một fact match hai overlapping history windows.

---

## 7. Knowledge check – MCQ

**Q1.** Fact N:1 dimension unique join thường:  
A. preserve fact grain; B. change to dimension grain; C. Cartesian; D. dedup.

**Q2.** `LEFT SEMI JOIN` trả:  
A. columns từ cả hai sides; B. left rows có match; C. only right rows; D. unmatched left rows.

**Q3.** `LEFT ANTI JOIN` trả:  
A. matched pairs; B. left rows không match; C. right rows; D. intersection.

**Q4.** Join history nhiều row/entity chỉ bằng entity key có risk:  
A. fan-out; B. automatic SCD; C. type promotion; D. time travel.

**Q5.** `UNION ALL`:  
A. loại duplicate; B. giữ duplicate; C. anti join; D. aggregate.

**Q6.** Databricks `UNION` mặc định:  
A. ALL; B. DISTINCT-style duplicate removal; C. CROSS; D. LEFT SEMI.

**Q7.** Query Profile cảnh báo exploding join nên được hiểu đầu tiên là:  
A. chỉ performance, không correctness; B. kiểm tra cardinality/business semantics trước; C. add index; D. use DISTINCT.

---

## 8. Tự luận / Interview

1. Semi join khác inner join về output semantics thế nào?
2. Anti join và `NOT EXISTS` diễn đạt cùng loại câu hỏi nào?
3. Vì sao exploding join có thể làm KPI sai?
4. Temporal join cần gì ngoài business key?
5. `UNION` vs `UNION ALL`: duplicate removal khi nào là bug?
6. Cách kiểm tra orphan foreign/business key trong analytical table?
7. Nếu Query Profile thấy join output gấp 100x input, bạn debug gì trước?

---

## 9. Exit criteria

- [ ] Dự đoán cardinality trước mọi join lab.
- [ ] Dùng được LEFT SEMI và LEFT ANTI JOIN.
- [ ] Dùng được EXISTS/NOT EXISTS tương đương intent.
- [ ] Đo được fan-out factor.
- [ ] Phân biệt UNION/UNION ALL/INTERSECT/EXCEPT.
- [ ] Giải thích temporal join.
- [ ] Đạt >=6/7 MCQ.