# Module 02 – SQL for Data Engineers

## Vì sao SQL đứng trước Python/Spark?

SQL là ngôn ngữ trung tâm của Data Engineering vì phần lớn pipeline cuối cùng vẫn phải trả lời các câu hỏi quan hệ: dữ liệu ở grain nào, join theo key nào, aggregate ra sao, xử lý NULL thế nào, chọn bản ghi mới nhất bằng quy tắc nào, và làm sao chứng minh query đúng trước khi tối ưu.

Một Data Engineer biết cú pháp nhưng không hiểu **relational model, logical query processing, grain, cardinality và query plan** rất dễ tạo pipeline chạy được nhưng sai dữ liệu.

Module này vì vậy không dạy SQL theo kiểu `SELECT → JOIN → GROUP BY` rồi kết thúc. Ta học theo ba lớp:

1. **Correctness** – query có trả đúng dữ liệu không?
2. **Reasoning** – có giải thích được vì sao đúng không?
3. **Performance** – khi dữ liệu lớn, engine thực thi ra sao và tối ưu bằng cách nào?

## Reference engine

Lab sử dụng **PostgreSQL** vì dễ chạy local, hỗ trợ SQL phong phú, window functions, CTE, indexes và `EXPLAIN`. Tuy nhiên principle trong module ưu tiên SQL chuẩn và relational reasoning để có thể chuyển sang Databricks SQL, Spark SQL, Microsoft Fabric Warehouse hoặc các analytical engines khác.

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
- Đọc `EXPLAIN` ở mức fresher: scan, join, sort, aggregate, estimated rows, actual rows.
- Giải thích index, composite index, selectivity, sargability và vì sao index không phải lúc nào cũng được dùng.
- Giải bài SQL interview mà không phụ thuộc vào việc học thuộc template.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm |
|---|---|---|
| 01 | Relational Thinking, Grain & Logical Query Processing | Trước khi viết SQL, ta đang thao tác với quan hệ nào và ở grain nào? |
| 02 | Filtering, NULL, CASE & Data Types | Vì sao query nhìn đúng cú pháp nhưng vẫn có thể lọc sai dữ liệu? |
| 03 | Aggregation, GROUP BY & HAVING | Làm sao aggregate đúng grain và không double-count? |
| 04 | JOINs, Cardinality & Set Operations | Join làm thay đổi số dòng như thế nào? |
| 05 | Subqueries, CTEs & EXISTS | Khi nào nên tách query thành các relation trung gian? |
| 06 | Window Functions | Làm analytics trên nhóm nhưng vẫn giữ từng row thế nào? |
| 07 | SQL Patterns for Data Engineering | Dedup, latest row, incremental, SCD và data-quality patterns viết ra sao? |
| 08 | Indexes, EXPLAIN & Query Performance | Tại sao query chậm và cách reasoning với query plan? |

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
1. Đọc Principles
2. Tự nói lại principle bằng lời của mình
3. Học Fundamentals
4. Chạy Worked Example
5. Làm lab KHÔNG xem answer
6. Làm MCQ
7. Trả lời interview questions bằng miệng
8. Chỉ chuyển bài khi đạt Exit Criteria
```

### Quy tắc SQL của module

- Không dùng `SELECT *` trong bài production-style nếu không có lý do.
- Luôn ghi rõ grain kỳ vọng của input/output.
- Với join, luôn dự đoán cardinality trước khi chạy.
- Với dedup, phải định nghĩa business key và tie-breaker.
- Với window function, phải hiểu `PARTITION BY`, `ORDER BY`, frame.
- Với performance, tối ưu sau khi correctness đã được chứng minh.

## Suggested pace

| Tuần | Nội dung |
|---|---|
| 1 | Lesson 01–02 + 20 bài query cơ bản |
| 2 | Lesson 03–04 + 20 bài aggregation/join |
| 3 | Lesson 05–06 + 20 bài CTE/window |
| 4 | Lesson 07–08 + Final Assessment + mock interview |

Không cần cố đạt số lượng bài thật lớn. Mục tiêu là với mỗi bài, bạn có thể giải thích **grain → relation → condition → cardinality → correctness → performance**.

## Reference anchors

Module tham chiếu chủ yếu tới PostgreSQL official documentation cho semantics của `SELECT`, window functions, CTE, indexes và `EXPLAIN`:

- PostgreSQL `SELECT`: https://www.postgresql.org/docs/current/sql-select.html
- Window functions: https://www.postgresql.org/docs/current/functions-window.html
- `EXPLAIN`: https://www.postgresql.org/docs/current/using-explain.html
- Multicolumn indexes: https://www.postgresql.org/docs/current/indexes-multicolumn.html

Các reference này dùng để xác nhận engine behavior; cách giải thích trong lesson được viết lại theo mục tiêu học Data Engineering và VDT interview.