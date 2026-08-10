# Lesson 08 – Indexes, EXPLAIN & Query Performance

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích vì sao index tăng tốc một số reads nhưng có storage/write cost.
- Hiểu B-tree index ở mức mental model đủ cho fresher interview.
- Reasoning về composite index dựa trên query predicates/order, không học thuộc “index mọi column”.
- Giải thích selectivity và vì sao planner có thể chọn sequential scan dù có index.
- Đọc `EXPLAIN`/`EXPLAIN ANALYZE` ở mức: scan, rows, cost, join, sort, aggregate, loops.
- Nhận diện estimation error lớn giữa estimated rows và actual rows.
- Hiểu nested loop/hash join/merge join ở mức principle.
- Viết predicate dễ tận dụng index/partition pruning hơn khi có thể.
- Tối ưu sau khi query đã đúng.

---

## 2. Principles

### Principle 1 – Performance is work avoided

Query nhanh hơn thường vì engine phải làm ít work hơn:

- đọc ít rows/pages/files;
- scan ít columns;
- shuffle/sort ít hơn;
- join relation nhỏ hơn;
- tránh repeated work;
- dùng metadata/index để thu hẹp search space.

Không bắt đầu optimization bằng “thêm RAM” hoặc “thêm index” nếu chưa biết work nằm ở đâu.

### Principle 2 – Index is a trade-off

Index cần:

- disk/storage;
- maintenance khi insert/update/delete;
- vacuum/maintenance/statistics tùy engine;
- planning complexity.

Read-heavy lookup có thể hưởng lợi mạnh; write-heavy table với quá nhiều indexes có thể bị phạt.

### Principle 3 – The planner chooses a plan, not the query author

SQL mô tả result mong muốn. Optimizer/planner chọn physical operators dựa trên query structure, statistics, indexes và cost model.

Ta không suy ra chắc chắn plan chỉ từ syntax; ta xem `EXPLAIN`.

### Principle 4 – Correctness before optimization

Query sai nhưng chạy 50ms không có giá trị. Thứ tự:

```text
Correctness
   ↓
Measurement
   ↓
Plan reasoning
   ↓
Optimization
   ↓
Re-measure
```

---

## 3. Fundamentals

### 3.1 Why an index helps

Không có index phù hợp, engine có thể phải scan nhiều/all rows để tìm match.

B-tree index duy trì keys theo cấu trúc có thứ tự, phù hợp cho equality và range lookups trên các operator/type được hỗ trợ.

Mental model:

```text
Table heap/data pages
      ↑
Index entries: key → row location/reference
```

Index không phải “bản sao miễn phí”; nó là structure riêng phải duy trì.

### 3.2 Selectivity

Predicate rất selective:

```sql
WHERE transaction_id = 3001
```

có thể trả 1 row trong hàng triệu rows → index lookup hấp dẫn.

Predicate kém selective:

```sql
WHERE status = 'success'
```

nếu 95% rows là success → đọc qua index rồi quay về table có thể không tốt hơn scan tuần tự.

Vì vậy “có index” không đồng nghĩa “planner sẽ dùng index”.

### 3.3 Composite index

Ví dụ workload:

```sql
WHERE customer_id = ?
  AND transaction_ts >= ?
  AND transaction_ts < ?
ORDER BY transaction_ts
```

Một candidate:

```sql
CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts);
```

Với B-tree composite indexes, order của key columns ảnh hưởng mạnh tới cách index thu hẹp scan. PostgreSQL hiện đại còn có optimizer techniques như skip scan trong một số trường hợp, nên không học thuộc một câu tuyệt đối kiểu “không có leftmost column thì index vô dụng”. Hãy nhìn workload và `EXPLAIN`.

### 3.4 Sargability – practical idea

“Sargable” là cách nói thực dụng cho predicate mà engine có thể dùng search/access structure hiệu quả.

Ví dụ thường dễ tận dụng timestamp index hơn:

```sql
WHERE transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-09-01'
```

so với việc biến đổi column trong predicate:

```sql
WHERE DATE(transaction_ts) >= DATE '2026-08-01'
```

Tuy nhiên expression index hoặc engine-specific optimization có thể thay đổi plan; dùng `EXPLAIN` để xác nhận, không biến “sargable” thành luật tuyệt đối.

### 3.5 EXPLAIN

PostgreSQL:

```sql
EXPLAIN
SELECT ...;
```

cho estimated plan.

```sql
EXPLAIN ANALYZE
SELECT ...;
```

thực sự chạy query rồi hiển thị actual timing/rows cùng estimates.

**Cảnh báo:** vì `EXPLAIN ANALYZE` thực thi statement, với query có side effects như write operation, effects vẫn có thể xảy ra nếu bạn không kiểm soát transaction.

### 3.6 Plan tree

Plan là tree. Đọc thường từ nodes dưới lên để hiểu data flow.

Các nodes cần nhận biết:

```text
Seq Scan
Index Scan
Index Only Scan
Bitmap Index/Heap Scan
Sort
Aggregate / HashAggregate
Nested Loop
Hash Join
Merge Join
```

### 3.7 Estimated rows vs actual rows

Một signal mạnh:

```text
estimated rows = 100
actual rows    = 1,000,000
```

Planner đã đánh giá cardinality sai lớn. Điều này có thể dẫn tới join strategy/memory/cost decision kém.

Statistics giúp planner estimate row counts/selectivity.

### 3.8 Join algorithms – mental models

**Nested Loop**

```text
for each row in outer:
    find matching rows in inner
```

Tốt khi outer nhỏ và inner có efficient lookup/index; có thể tệ nếu lặp scan lớn.

**Hash Join**

```text
build hash table from one input
scan other input and probe hash
```

Phù hợp equality joins khi build side vừa khả năng memory/cost model.

**Merge Join**

```text
inputs sorted by join key
walk both ordered streams
```

Có thể tốt khi inputs đã sorted/indexed hoặc sorting cost hợp lý.

Không cần tự chọn algorithm trong hầu hết SQL; cần hiểu plan mà optimizer chọn.

### 3.9 Indexing for analytical DE workloads

Trong Data Warehouse/lakehouse, traditional row-store indexes không phải trung tâm duy nhất. Performance còn phụ thuộc:

- partition pruning;
- columnar storage;
- file statistics/data skipping;
- clustering/sorting;
- predicate pushdown;
- broadcast/shuffle strategies.

Mental model “avoid unnecessary work” sẽ chuyển tốt sang Spark/Databricks ở Module 09–10.

---

## 4. Worked example – Customer transaction lookup

### Query

```sql
SELECT
    transaction_id,
    transaction_ts,
    amount,
    status
FROM billing_transactions
WHERE customer_id = 1001
  AND transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-09-01'
ORDER BY transaction_ts;
```

### Candidate index

```sql
CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts);
```

### Experiment

Run before and after index:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...;
```

Với lab nhỏ vài rows, planner có thể vẫn chọn `Seq Scan` vì scan table nhỏ rẻ hơn index lookup. **Đó không phải failure của index.**

Để học plan thực tế hơn, generate thêm 100k–1M synthetic rows ở challenge.

### What to inspect

- scan type;
- estimated rows;
- actual rows;
- rows removed by filter;
- sort node;
- planning/execution time;
- buffers;
- index condition vs filter.

---

## 5. Hands-on lab

Tạo `lesson-08.sql` và `lesson-08-notes.md`.

### Part A – Baseline EXPLAIN

Chạy `EXPLAIN (ANALYZE, BUFFERS)` cho:

1. lookup transaction by `transaction_id`;
2. filter `customer_id`;
3. date range;
4. `status = 'success'`;
5. customer + date range;
6. join billing → customer;
7. aggregate revenue by province.

Ghi plan nodes chính, estimated rows, actual rows.

### Part B – Index experiments

Tạo lần lượt:

```sql
CREATE INDEX idx_billing_ts
ON billing_transactions(transaction_ts);

CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts);

CREATE INDEX idx_network_event_ts
ON network_events(event_ts);
```

Sau mỗi index:

- chạy lại EXPLAIN;
- index có được dùng không?
- nếu không, giải thích candidate reasons;
- table size có quá nhỏ để thấy benefit không?

### Part C – Predicate experiment

So sánh:

```sql
WHERE transaction_ts::date = DATE '2026-08-01'
```

và:

```sql
WHERE transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-08-02'
```

Xem plan. Không được kết luận universal từ dataset nhỏ; ghi nhận kết quả engine hiện tại.

### Part D – Cardinality estimate

Với mỗi plan, ghi:

```text
Plan node:
Estimated rows:
Actual rows:
Error factor:
```

Tìm node có estimation lệch nhất.

### Part E – Scale-up challenge

Dùng `generate_series` PostgreSQL tạo ít nhất 100,000 synthetic billing rows vào một table copy.

Ví dụ skeleton:

```sql
CREATE TABLE billing_big AS
SELECT ...
FROM generate_series(1, 100000) g;
```

Bạn tự thiết kế distribution sao cho:

- một column high-cardinality;
- `status` low-cardinality;
- customer distribution không hoàn toàn đều.

Sau đó thử:

- no index;
- single-column index;
- composite index;
- selective vs non-selective predicate.

### Challenge – Performance review

Viết 1 trang review cho query:

```text
Business purpose
Correctness assumptions
Input sizes
Current plan
Main work/cost
Potential optimization
Expected trade-off
Evidence after change
```

---

## 6. Knowledge check – MCQ

**Q1.** Planner có thể bỏ qua index vì:  
A. index luôn bắt buộc; B. sequential scan được estimated rẻ hơn cho query/data hiện tại; C. SQL cấm index; D. SELECT không dùng index.

**Q2.** `EXPLAIN ANALYZE`:  
A. không chạy query; B. thực thi query để thu actual metrics; C. tạo index; D. chỉ syntax check.

**Q3.** Estimated rows lệch actual rows rất lớn có thể ảnh hưởng:  
A. planner decisions; B. column names; C. SQL grammar; D. primary key definition tự động.

**Q4.** Composite B-tree index `(customer_id, transaction_ts)` đặc biệt hợp với workload:  
A. filter customer + time range; B. chỉ `status`; C. random text search; D. không WHERE.

**Q5.** Index trade-off gồm:  
A. storage + write maintenance; B. chỉ lợi ích; C. xóa constraints; D. tăng duplicate.

**Q6.** Optimization tốt nên bắt đầu sau:  
A. đo/hiểu correctness và workload; B. thêm mọi index; C. đổi DB ngay; D. SELECT DISTINCT.

**Q7.** Hash join mental model:  
A. build hash trên một input rồi probe input kia; B. sort files only; C. nested loop luôn; D. index B-tree bắt buộc.

---

## 7. Knowledge check – Tự luận / Interview

1. Vì sao index không phải lúc nào cũng nhanh hơn sequential scan?
2. Selectivity là gì?
3. Composite index column order ảnh hưởng như thế nào?
4. `EXPLAIN` khác `EXPLAIN ANALYZE` thế nào và có rủi ro gì?
5. Bạn đọc plan tree theo cách nào?
6. Estimated rows vs actual rows lệch 1000x gợi ý điều gì?
7. Nested loop, hash join, merge join khác nhau ở mental model nào?
8. Vì sao applying function lên indexed column có thể làm access path kém thuận lợi hơn?
9. Tại sao lab nhỏ có thể không dùng index dù index hợp lý ở production scale?
10. Mental model nào từ lesson này chuyển sang Spark optimization tốt nhất?

---

## 8. Exit criteria

- [ ] Chạy EXPLAIN/EXPLAIN ANALYZE cho >=7 queries.
- [ ] Đọc được Seq Scan/Index Scan/Sort/Aggregate/Hash Join hoặc Nested Loop nếu xuất hiện.
- [ ] So sánh estimated vs actual rows.
- [ ] Thử single/composite index và giải thích plan thay đổi hoặc không thay đổi.
- [ ] Hiểu selectivity và index trade-off.
- [ ] Hoàn thành scale-up >=100k rows.
- [ ] Viết performance review dựa trên evidence.
- [ ] Đạt ít nhất 6/7 MCQ.

## Reference anchors

- PostgreSQL EXPLAIN: https://www.postgresql.org/docs/current/using-explain.html
- Planner statistics: https://www.postgresql.org/docs/current/planner-stats.html
- Multicolumn indexes: https://www.postgresql.org/docs/current/indexes-multicolumn.html