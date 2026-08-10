# Module 05 – Database Fundamentals

> **Classification:** Supplementary prerequisite. Databricks does not replace the need to understand relational database fundamentals. This module uses PostgreSQL official documentation for RDBMS internals and Databricks official documentation to compare those concepts with Delta Lake and lakehouse transaction semantics.

## Why this module exists

Data Engineers frequently move data **from operational databases into analytical systems**. If you only know SQL syntax, you can still make serious mistakes:

- extract inconsistent snapshots;
- misunderstand primary/foreign-key guarantees;
- create source queries that lock or overload OLTP systems;
- assume all isolation levels behave the same;
- design indexes without workload reasoning;
- trust a query plan without understanding cardinality estimates;
- assume Delta Lake and PostgreSQL provide identical transaction scopes.

This module builds the mental model underneath those problems.

## Source alignment

### Databricks canonical sources

- ACID guarantees on Databricks: https://docs.databricks.com/aws/en/lakehouse/acid
- Delta Lake: https://docs.databricks.com/aws/en/delta
- Isolation levels and write conflicts: https://docs.databricks.com/aws/en/optimizations/isolation/
- Transactions: https://docs.databricks.com/aws/en/transactions
- Constraints on Databricks: https://docs.databricks.com/aws/en/tables/constraints
- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts

### Supplementary primary sources

PostgreSQL official documentation is the primary source for RDBMS internals in this module:

- Data definition and constraints: https://www.postgresql.org/docs/18/ddl.html
- Concurrency control / MVCC: https://www.postgresql.org/docs/18/mvcc.html
- Transaction isolation: https://www.postgresql.org/docs/18/transaction-iso.html
- WAL: https://www.postgresql.org/docs/18/wal-intro.html
- Indexes: https://www.postgresql.org/docs/18/indexes.html
- EXPLAIN: https://www.postgresql.org/docs/18/using-explain.html
- Planner statistics: https://www.postgresql.org/docs/18/planner-stats.html

## Learning outcomes

Hoàn thành Module 05, bạn phải có thể:

- phân biệt OLTP và OLAP theo workload, không chỉ theo tên sản phẩm;
- mô hình hóa entity/relationship/key và giải thích normalization/denormalization trade-off;
- dùng `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, `CHECK` như integrity contracts;
- giải thích Atomicity, Consistency, Isolation, Durability bằng failure scenario;
- giải thích vì sao WAL cho phép commit bền vững mà không cần flush toàn bộ data pages ở mỗi commit;
- mô tả MVCC, snapshot, lock, deadlock và transaction retry;
- phân biệt dirty read, non-repeatable read, phantom read và serialization anomaly;
- hiểu B-tree/hash/GIN/BRIN ở mức chọn access path phù hợp;
- đọc `EXPLAIN (ANALYZE, BUFFERS)` ở mức scan/join/sort/aggregate/rows/loops;
- giải thích cardinality estimation và vai trò statistics;
- so sánh PostgreSQL transaction model với Delta Lake/Databricks transaction model;
- biết rằng PK/FK/UNIQUE trên Databricks có thể là informational thay vì enforced;
- thiết kế extraction từ OLTP sang lakehouse mà tôn trọng consistency, load và change semantics.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm |
|---|---|---|
| 01 | Database Workloads & Architecture | OLTP khác OLAP/lakehouse ở workload và system goals nào? |
| 02 | Relational Modeling & Normalization | Làm sao thiết kế schema giảm update anomaly mà vẫn phục vụ workload? |
| 03 | Keys, Constraints & Data Integrity | Integrity nên được bảo vệ ở database, pipeline hay cả hai? |
| 04 | Transactions, ACID & WAL | Một commit thực sự có nghĩa gì khi process/server crash? |
| 05 | Concurrency, MVCC & Isolation | Hai transaction đồng thời thấy dữ liệu nào và có thể sai ra sao? |
| 06 | Indexes & Access Paths | Khi nào index giảm work và khi nào lại tăng cost? |
| 07 | Planner, Statistics & EXPLAIN | Database chọn plan bằng dữ liệu/statistics nào và ta debug ra sao? |
| 08 | PostgreSQL ↔ Delta/Databricks | Những concept nào chuyển được, những guarantee nào không giống nhau? |

## Lab environment

Primary lab: **PostgreSQL 18**.

```text
labs/module-05-database/
├── README.md
├── postgres-setup.sql
├── concurrency-lab.md
├── databricks-contrast.sql
└── practice-set.md
```

Telecom case study tiếp tục dùng các entity:

```text
customers
plans
subscriptions
billing_transactions
network_events
customer_status_history
```

Nhưng Module 05 thêm các bài transaction/concurrency/index/planner để quan sát behavior mà Module 02 không tập trung.

## How to study

Với mỗi lesson:

```text
Source alignment
    ↓
Principle
    ↓
Fundamental mental model
    ↓
Worked example
    ↓
Hands-on experiment
    ↓
Explain observed behavior
    ↓
MCQ + oral interview
```

Không chấp nhận câu trả lời kiểu “vì database làm thế”. Bạn phải giải thích bằng:

```text
state
snapshot
constraint
transaction boundary
access path
cardinality
cost
failure mode
```

## Suggested pace

- Week 1: Lesson 01–03 + schema design lab
- Week 2: Lesson 04–05 + two-session concurrency experiments
- Week 3: Lesson 06–07 + scale data to >=100k rows + EXPLAIN
- Week 4: Lesson 08 + final assessment + oral review

## Exit criteria for the module

Không qua Module 05 nếu chưa trả lời được không nhìn notes:

1. ACID là gì bằng một money-transfer example?
2. Read Committed vs Repeatable Read khác snapshot scope thế nào?
3. MVCC giúp reader/writer concurrency như thế nào?
4. Index vì sao vừa tăng read performance vừa tăng write cost?
5. Estimated rows sai 1000x có thể phá plan thế nào?
6. PostgreSQL PK/FK và Databricks PK/FK khác enforcement ra sao?
7. Delta optimistic concurrency khác row-lock intuition thế nào?
8. Khi extract từ OLTP, làm sao tránh vừa overload source vừa đọc inconsistent business state?
