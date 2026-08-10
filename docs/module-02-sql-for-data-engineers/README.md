# Module 02 – SQL for Data Engineers

## Official Databricks sources

### Primary

Databricks SQL là canonical SQL reference của module:

- Databricks SQL Language Reference  
  https://docs.databricks.com/aws/en/sql/language-manual
- Window Functions  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-window-functions
- Data Engineering Concepts  
  https://docs.databricks.com/aws/en/data-engineering/concepts
- Query Data on Databricks  
  https://docs.databricks.com/aws/en/query

### Databricks Academy alignment

SQL là prerequisite xuyên suốt Data Engineer learning content. Các course như Lakeflow Connect và Lakeflow Jobs giả định người học đã có SQL ở mức thực dụng/intermediate, vì vậy module này được đặt trước Spark/Lakeflow để xây nền chắc hơn mức prerequisite đó.

### Supplementary prerequisite / lab engine

Lab vẫn sử dụng **PostgreSQL** để có môi trường local nhẹ, dễ quan sát indexes và `EXPLAIN`. PostgreSQL docs chỉ dùng để giải thích behavior riêng của PostgreSQL planner/index implementation; SQL concept và terminology chung của khóa ưu tiên Databricks SQL reference.

---

## Vì sao SQL đứng trước Python/Spark?

SQL là ngôn ngữ trung tâm của Data Engineering vì phần lớn pipeline cuối cùng vẫn phải trả lời các câu hỏi quan hệ: dữ liệu ở grain nào, join theo key nào, aggregate ra sao, xử lý NULL thế nào, chọn bản ghi mới nhất bằng quy tắc nào, và làm sao chứng minh query đúng trước khi tối ưu.

Một Data Engineer biết cú pháp nhưng không hiểu **relational model, logical query processing, grain, cardinality và query plan** rất dễ tạo pipeline chạy được nhưng sai dữ liệu.

Module này vì vậy không dạy SQL theo kiểu `SELECT → JOIN → GROUP BY` rồi kết thúc. Ta học theo ba lớp:

1. **Correctness** – query có trả đúng dữ liệu không?
2. **Reasoning** – có giải thích được vì sao đúng không?
3. **Performance** – khi dữ liệu lớn, engine thực thi ra sao và tối ưu bằng cách nào?

## Reference engine vs canonical language reference

- **Canonical language/semantics:** Databricks SQL Language Reference.
- **Local execution engine:** PostgreSQL.
- **Mục tiêu portability:** viết và reasoning theo relational/SQL fundamentals, sau đó nhận diện dialect-specific differences khi chuyển sang Databricks SQL/Spark SQL/Fabric Warehouse.

Khi syntax hoặc behavior khác nhau giữa PostgreSQL và Databricks SQL, lesson phải ghi rõ engine scope thay vì giả định hai hệ giống hệt nhau.

## Learning outcomes

Hoàn thành Module 02, bạn phải có thể:

- Giải thích relation, row, attribute, key, functional dependency ở mức thực dụng.
- Xác định **grain** trước khi viết aggregate hoặc join.
- Giải thích logical processing order của một `SELECT` query.
- Xử lý đúng `NULL` và three-valued logic.
- Viết filter, projection, conditional logic và type conversion rõ ràng.
- Dùng `GROUP BY`, `HAVING`, conditional aggregation và tránh double-counting.
- Phân tích cardinality khi `JOIN`; phát hiện join fan-out và accidental many-to-many.
- Chọn `EXISTS`, `IN`, subquery, CTE hoặc join theo mục tiêu thay vì thói quen.
- Sử dụng `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `LEAD` và window aggregate.
- Viết các pattern DE quan trọng: latest-row, dedup, top-N, running totals, incremental candidate set, SCD Type 1/2 reasoning.
- Đọc `EXPLAIN` ở mức fresher trên PostgreSQL lab: scan, join, sort, aggregate, estimated rows, actual rows.
- Giải thích index, composite index, selectivity, sargability và vì sao index không phải lúc nào cũng được dùng.
- Chuyển một solution SQL sang tư duy tương thích với Databricks SQL/Spark SQL mà không phụ thuộc PostgreSQL-specific shortcut.
- Giải bài SQL interview mà không phụ thuộc vào việc học thuộc template.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm | Databricks source alignment |
|---|---|---|---|
| 01 | Relational Thinking, Grain & Logical Query Processing | Trước khi viết SQL, ta đang thao tác với relation nào và ở grain nào? | SQL language reference |
| 02 | Filtering, NULL, CASE & Data Types | Vì sao query nhìn đúng cú pháp nhưng vẫn có thể lọc sai dữ liệu? | SQL fundamentals / NULL semantics |
| 03 | Aggregation, GROUP BY & HAVING | Làm sao aggregate đúng grain và không double-count? | Aggregate/data engineering concepts |
| 04 | JOINs, Cardinality & Set Operations | Join làm thay đổi số dòng như thế nào? | Join/data engineering concepts |
| 05 | Subqueries, CTEs & EXISTS | Khi nào nên tách query thành các relation trung gian? | SQL query language |
| 06 | Window Functions | Làm analytics trên nhóm nhưng vẫn giữ từng row thế nào? | Databricks Window Functions |
| 07 | SQL Patterns for Data Engineering | Dedup, latest row, incremental, SCD và data-quality patterns viết ra sao? | Data Engineering concepts / SQL |
| 08 | Indexes, EXPLAIN & Query Performance | Tại sao query chậm và cách reasoning với query plan? | Supplementary PostgreSQL engine lab |

## Telecom SQL dataset

Module dùng một dataset viễn thông giả lập với các bảng:

```text
customers
plans
cell_towers
subscriptions
billing_transactions
network_events
customer_status_history
```

Các bài tập xuyên suốt gồm:

- doanh thu theo ngày/tỉnh/gói cước;
- active subscribers tại một thời điểm;
- latest status của mỗi customer;
- phát hiện duplicate network event;
- top cell tower theo call-drop rate;
- so sánh doanh thu ngày hiện tại với ngày trước;
- incremental extraction dựa trên watermark;
- phân tích join fan-out;
- đọc execution plan của query lớn.

Schema và seed data nằm tại [`labs/module-02-sql`](../../labs/module-02-sql/README.md).

## Cách học mỗi lesson

```text
1. Xem Source alignment
2. Đọc Principles
3. Tự nói lại principle bằng lời của mình
4. Học Fundamentals
5. Chạy Worked Example
6. Làm lab KHÔNG xem answer
7. Làm MCQ
8. Trả lời interview questions bằng miệng
9. Chỉ chuyển bài khi đạt Exit Criteria
```

### Quy tắc SQL của module

- Không dùng `SELECT *` trong bài production-style nếu không có lý do.
- Luôn ghi rõ grain kỳ vọng của input/output.
- Với join, luôn dự đoán cardinality trước khi chạy.
- Với dedup, phải định nghĩa business key và tie-breaker.
- Với window function, phải hiểu `PARTITION BY`, `ORDER BY`, frame.
- Nếu dùng syntax PostgreSQL-specific, ghi chú tương đương/khác biệt với Databricks SQL khi cần.
- Với performance, tối ưu sau khi correctness đã được chứng minh.

## Suggested pace

| Tuần | Nội dung |
|---|---|
| 1 | Lesson 01–02 + 20 bài query cơ bản |
| 2 | Lesson 03–04 + 20 bài aggregation/join |
| 3 | Lesson 05–06 + 20 bài CTE/window |
| 4 | Lesson 07–08 + Final Assessment + mock interview |

Không cần cố đạt số lượng bài thật lớn. Mục tiêu là với mỗi bài, bạn có thể giải thích **grain → relation → condition → cardinality → correctness → performance**.

## Engine-specific reference anchors

Các nguồn dưới đây chỉ là **supplementary PostgreSQL lab references**, không còn là canonical curriculum sources:

- PostgreSQL `SELECT`: https://www.postgresql.org/docs/current/sql-select.html
- Window functions: https://www.postgresql.org/docs/current/functions-window.html
- `EXPLAIN`: https://www.postgresql.org/docs/current/using-explain.html
- Multicolumn indexes: https://www.postgresql.org/docs/current/indexes-multicolumn.html

Nếu behavior giữa PostgreSQL và Databricks SQL khác nhau, official Databricks documentation quyết định cách khóa mô tả Databricks behavior.
