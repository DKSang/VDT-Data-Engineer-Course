# Module 02 – SQL for Data Engineers

> **Databricks-first module.** Databricks SQL / Databricks Runtime là canonical engine cho syntax, semantics và Data Engineering SQL patterns trong module này. PostgreSQL chỉ còn là optional local practice engine.

## 1. Source alignment

### Primary Databricks sources

- Databricks SQL Language Reference  
  https://docs.databricks.com/aws/en/sql/language-manual
- Query / SELECT / JOIN / CTE / Set Operators  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-query  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-join  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-cte
- NULL semantics & SQL data type rules  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-null-semantics  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-datatype-rules
- Window Functions & QUALIFY  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-window-functions  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-select-qualify
- MERGE / Delta Lake upsert  
  https://docs.databricks.com/aws/en/sql/language-manual/delta-merge-into  
  https://docs.databricks.com/aws/en/delta/merge
- EXPLAIN & Query Profile  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-explain  
  https://docs.databricks.com/aws/en/sql/user/queries/query-profile
- Query performance / AQE  
  https://docs.databricks.com/aws/en/lakehouse-architecture/performance-efficiency/best-practices  
  https://docs.databricks.com/aws/en/optimizations/aqe

### Databricks Academy alignment

- **Get Started with Databricks for Data Engineering**: course chính thức giả định working knowledge of SQL (`SELECT`, `WHERE`, `GROUP BY`, aggregates, `INSERT`, `UPDATE`, `DELETE`) rồi dùng SQL để tạo/sửa Delta tables và làm pipeline medallion.
- **Get Started with SQL Analytics and BI on Databricks**: dùng Databricks SQL để thao tác dữ liệu và analytical workload.

Module 02 vì vậy đi sâu hơn mức prerequisite: không chỉ viết query chạy được mà phải hiểu grain, cardinality, correctness, Delta DML và query execution.

---

## 2. Mục tiêu

Hoàn thành module, bạn phải có thể:

- Xác định **grain** và key của relation trước khi viết query.
- Reasoning với `SELECT`, `WHERE`, `GROUP BY`, `HAVING`, `JOIN`, set operators và CTE theo Databricks SQL semantics.
- Xử lý `NULL`, type coercion và cast an toàn bằng `CAST` / `try_cast`.
- Dùng `LEFT SEMI JOIN`, `LEFT ANTI JOIN`, `EXISTS`/`NOT EXISTS` đúng intent.
- Dùng `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `LEAD`, window frames và **`QUALIFY`**.
- Viết các DE patterns: dedup, latest row, incremental candidate set, data-quality checks.
- Dùng **`MERGE INTO`** trên Delta table và hiểu điều kiện source phải được deduplicate trước khi merge.
- Phân biệt manual `MERGE` với **AUTO CDC** trong Lakeflow Spark Declarative Pipelines ở mức awareness.
- Đọc `EXPLAIN` trên Databricks và sử dụng **Query Profile** để tìm full scan, exploding join, shuffle và expensive operators.
- Hiểu vai trò của statistics, AQE, Photon và table-layout/filtering ở mức fresher.

## 3. Lesson map

| Lesson | Chủ đề | Databricks trọng tâm |
|---|---|---|
| 01 | Relational Thinking, Grain & Query Semantics | Query / SELECT / relation reasoning |
| 02 | Filtering, NULL, CASE & Data Types | NULL semantics, type rules, `CAST`, `try_cast` |
| 03 | Aggregation, GROUP BY & HAVING | aggregate correctness, grain, reconciliation |
| 04 | JOINs, Cardinality & Set Operations | INNER/OUTER/SEMI/ANTI/CROSS, set operators |
| 05 | Subqueries, CTEs & EXISTS | named relations, recursive CTE awareness |
| 06 | Window Functions & QUALIFY | ranking, analytic functions, frames, `QUALIFY` |
| 07 | DE SQL Patterns on Delta | dedup, incremental, `MERGE INTO`, SCD/CDC awareness |
| 08 | EXPLAIN, Query Profile & Performance | physical plan, exploding joins, scans, shuffle, AQE, Photon |

## 4. Primary lab environment

**Ưu tiên:** Databricks Free Edition / workspace có SQL warehouse hoặc serverless compute.

Chạy:

```text
labs/module-02-sql/databricks-setup.sql
```

File này tạo telecom dataset bằng Delta tables trong schema hiện tại.

Optional local practice:

```text
labs/module-02-sql/schema.sql
labs/module-02-sql/seed.sql
```

hai file trên dành cho PostgreSQL. Nếu syntax/behavior khác nhau, Databricks official docs là source of truth của course.

## 5. Telecom dataset

```text
customers
plans
subscriptions
billing_transactions
cell_towers
network_events
customer_status_history
```

Dataset cố ý chứa:

- `network_events.event_id` duplicate/versioned;
- late-arriving event;
- history table nhiều row/customer;
- NULL attributes;
- fact ↔ dimension cardinality để luyện join fan-out.

## 6. Quy tắc làm bài

Trước query quan trọng, ghi:

```text
Input grain:
Output grain:
Business key:
Join cardinality assumption:
Validation:
```

Databricks-specific rules:

- `QUALIFY` được ưu tiên khi filter trực tiếp kết quả window function và làm intent rõ hơn.
- Dùng `LEFT SEMI JOIN` / `LEFT ANTI JOIN` khi muốn diễn đạt existence/non-existence bằng join syntax.
- Dùng `try_cast` khi malformed input nên trở thành `NULL` để đưa vào quality/quarantine flow; dùng `CAST` khi invalid input phải fail fast.
- `MERGE INTO` chỉ dùng khi source-to-target match semantics rõ; source duplicate match phải được xử lý trước.
- Không dùng `DISTINCT` để che join fan-out hoặc business duplicate.
- Performance: correctness → measurement → `EXPLAIN`/Query Profile → hypothesis → change → remeasure.

## 7. Suggested pace

| Tuần | Nội dung |
|---|---|
| 1 | Lesson 01–02 + SQL fundamentals |
| 2 | Lesson 03–04 + aggregation/join/cardinality |
| 3 | Lesson 05–06 + CTE/window/QUALIFY |
| 4 | Lesson 07–08 + Delta MERGE + Query Profile + Final Assessment |

## 8. Ranh giới với các module sau

Module 02 chỉ dùng đủ Spark/Delta execution concepts để SQL reasoning đúng.

Chưa đào sâu:

- Spark Job/Stage/Task, shuffle internals → Module 09;
- Delta internals, liquid clustering, optimization sâu → Module 10;
- Lakeflow ingestion / AUTO CDC production patterns → Module 11;
- production orchestration/observability → Module 13–14.

> **SQL ở đây là Data Engineering SQL trên Databricks, không phải PostgreSQL course có thêm vài link Databricks.**