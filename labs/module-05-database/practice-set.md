# Module 05 – Database Fundamentals Practice Set

> Làm sau từng lesson. Với bài có SQL experiment, lưu cả hypothesis và observed behavior.

## Level 1 – Workload & Modeling

### P01
Phân loại 10 workload sau thành OLTP/OLAP/mixed và nêu lý do theo latency, concurrency, read/write pattern.

### P02
Thiết kế schema normalized cho customer, subscription, plan, payment.

### P03
Cho flat table `customer_subscription_plan_payment`, tìm 3 update anomalies.

### P04
Viết 5 functional dependencies trong telecom schema.

### P05
Giải thích natural key vs surrogate key bằng `network_events`.

### P06
Thiết kế relation cho customer có nhiều email addresses mà vẫn giữ grain rõ.

### P07
Cho composite key `(customer_id, plan_id)`, tìm một partial dependency example và normalize.

### P08
Cho transitive dependency `subscription_id -> plan_id -> plan_name`, giải thích 3NF issue.

## Level 2 – Constraints & Integrity

### P09
Tạo table có PK, FK, UNIQUE, NOT NULL, CHECK.

### P10
Viết 5 INSERT cố tình vi phạm từng loại constraint.

### P11
Tạo staging table không constraints; viết validation query tìm duplicate key.

### P12
Viết anti-join tìm orphan `customer_id`.

### P13
Thiết kế `CHECK` cho billing amount/status/date rules.

### P14
Giải thích khi nào `ON DELETE CASCADE` đúng và khi nào nguy hiểm.

### P15
Cho business key có thể đổi theo thời gian; giải thích vì sao surrogate key hữu ích nhưng không thay business uniqueness rule.

### P16
So sánh enforced PostgreSQL PK/FK với informational Databricks PK/FK.

## Level 3 – Transactions & ACID

### P17
Viết atomic transfer transaction.

### P18
Tạo failure ở statement 2 và chứng minh ROLLBACK không để partial state.

### P19
Viết example cho từng chữ A/C/I/D bằng failure scenario.

### P20
Giải thích WAL bằng sequence: change buffer → WAL → commit → data-page flush → crash recovery.

### P21
Tại sao transaction log không đồng nghĩa trực tiếp với business CDC stream?

### P22
Pipeline target commit thành công nhưng checkpoint ngoài DB chưa update. Phân tích retry duplicate risk.

## Level 4 – MVCC / Isolation / Locks

### P23
Two-session Read Committed experiment: cùng transaction A đọc row hai lần, B update ở giữa.

### P24
Repeat P23 với Repeatable Read và giải thích snapshot difference.

### P25
Demonstrate `SELECT ... FOR UPDATE` blocking behavior.

### P26
Reproduce deadlock bằng lock rows theo thứ tự ngược nhau.

### P27
Đề xuất lock ordering policy để ngăn pattern P26.

### P28
Viết retry pseudocode cho serialization failure.

### P29
Giải thích dirty read, non-repeatable read, phantom read, serialization anomaly.

### P30
Multi-table ETL extract dưới Read Committed có thể đọc “mixed business moments” thế nào?

## Level 5 – Indexes

### P31
Tạo B-tree index cho `billing_big(customer_id, transaction_ts)` và giải thích workload.

### P32
So sánh plan trước/sau single-column và composite index.

### P33
Index low-cardinality `status`; giải thích vì sao planner có thể vẫn Seq Scan.

### P34
Tìm use case hợp lý cho GIN.

### P35
Tìm use case hợp lý cho BRIN trong network event table cực lớn theo event time.

### P36
Benchmark bulk insert với ít index vs nhiều index; ghi environment và kết luận có giới hạn.

## Level 6 – Planner & Statistics

### P37
Capture `EXPLAIN (ANALYZE, BUFFERS)` cho PK lookup, status filter, range query, join, aggregate.

### P38
Tính error factor `actual_rows / estimated_rows` cho các plan nodes quan trọng.

### P39
Tạo skewed data rồi so sánh plan trước/sau `ANALYZE`.

### P40
Tìm một Nested Loop và một Hash Join trong lab nếu planner chọn tự nhiên; giải thích vì sao.

### P41
Giải thích vì sao `Seq Scan` không đồng nghĩa “query chưa tối ưu”.

### P42
Một node estimated 100 nhưng actual 5,000,000. Liệt kê 5 hướng điều tra.

## Level 7 – PostgreSQL ↔ Databricks

### P43
Điền comparison matrix: WAL / Delta log / snapshot / concurrency / constraints / transaction scope.

### P44
Trên Delta, test `CHECK` và `NOT NULL` trong disposable table.

### P45
Khai báo informational PK nếu môi trường hỗ trợ; chứng minh declaration không phải dữ liệu validation.

### P46
Tạo 3 Delta table versions và inspect history.

### P47
Vẽ optimistic concurrency flow: read → write → validate → commit/conflict.

### P48
Thiết kế CDC contract cho `subscriptions`: business key, source sequence, delete, retry, reconciliation.

### P49
Giải thích vì sao source ACID không guarantee target exactly-once.

### P50 – VDT mock system case

Scenario:

> Production PostgreSQL lưu thuê bao và billing. Team muốn dashboard trên Databricks cập nhật dưới 5 phút. Production DB đang peak traffic; dữ liệu có update/delete; dashboard cần revenue và active subscriber count đáng tin.

Trả lời:

1. OLTP workload risk nếu query trực tiếp?
2. Chọn snapshot, timestamp incremental hay CDC? Vì sao?
3. Business keys nào cần?
4. Source transaction consistency concern?
5. Delete semantics?
6. Retry/idempotency?
7. Constraint enforcement khác nhau source/Delta?
8. Reconciliation metrics?
9. Khi nào cần backfill?
10. 3 failure scenarios và recovery.

# Completion rubric

- 30/50: foundation usable nhưng cần review.
- 40/50: đủ database fundamentals cho fresher DE.
- 45+/50: strong foundation; ưu tiên speed + interview explanation.

Một bài không được tính hoàn thành nếu chỉ có đáp án mà không có reasoning/experiment evidence khi đề yêu cầu.
