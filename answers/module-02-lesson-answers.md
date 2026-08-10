# Module 02 – Lesson Answer Key

> File này dùng để self-check sau khi đã hoàn thành lesson. Không thay thế việc chạy query và validation trên lab database.

## Lesson 01 – Relational Thinking

**MCQ:** 1B, 2B, 3B, 4A, 5B, 6A.

Điểm phải có trong tự luận:

- Grain = ý nghĩa của một row; mọi join/aggregate đều có thể đổi hoặc preserve grain.
- `customers → billing_transactions` là 1:N; join từ customer sang transaction tạo nhiều rows/customer.
- Primary key kỹ thuật có thể khác business key; `network_events.ingest_row_id` vs `event_id` là ví dụ.
- Correctness phải kiểm chứng bằng uniqueness/reconciliation/row-count checks, không phải `LIMIT 10`.
- Logical reasoning: FROM/JOIN → WHERE → GROUP/HAVING → SELECT/window-related output → DISTINCT/ORDER/LIMIT ở mức mental model.

## Lesson 02 – Filtering, NULL, CASE & Types

**MCQ:** 1C, 2B, 3A, 4B, 5B, 6B.

Điểm phải có:

- `NULL` tạo UNKNOWN trong comparison; `WHERE` chỉ giữ TRUE.
- `IS NULL`, không `= NULL`.
- Half-open interval `[start, end)` tránh lỗi cuối ngày và ghép batch boundaries tốt.
- Right-table predicate trong `WHERE` sau LEFT JOIN có thể loại unmatched rows.
- `NOT EXISTS` thường dễ reasoning hơn `NOT IN` khi NULL có thể xuất hiện.
- `COALESCE` không phải data-quality repair; nó thay output semantics.

## Lesson 03 – Aggregation

**MCQ:** 1B, 2A, 3B, 4B, 5A, 6B.

Điểm phải có:

- `COUNT(*)` đếm rows; `COUNT(column)` bỏ NULL; `COUNT(DISTINCT ...)` đếm distinct non-null values theo expression semantics.
- WHERE filter base rows; HAVING filter grouped result.
- Fact join history có thể multiply rows trước aggregate.
- Average-of-averages sai nếu group sizes khác nhau mà không weight.
- Reconciliation: sum grouped metric = global metric theo cùng population/filter.

## Lesson 04 – JOINs & Cardinality

**MCQ:** 1A, 2A, 3B, 4B, 5B, 6B.

Điểm phải có:

- Dự đoán matches per left row trước join.
- `LEFT JOIN` preserve left population.
- Fan-out cần sửa grain/relation hoặc temporal join condition; `DISTINCT` không phải fix mặc định.
- `EXISTS` = semi-join semantics; `NOT EXISTS` = anti-join semantics.
- `UNION ALL` giữ rows; `UNION` deduplicate set result.
- History/SCD join thường cần entity key + validity interval.

## Lesson 05 – Subqueries, CTEs & EXISTS

**MCQ:** 1A, 2A, 3A, 4B, 5B, 6A.

Điểm phải có:

- CTE nên có purpose/grain/key rõ.
- CTE không enforce uniqueness/correctness.
- `EXISTS` rõ khi business question là existence.
- Correlated subquery tham chiếu outer row.
- Không học thuộc assumption performance “CTE luôn chậm/nhanh”; kiểm chứng bằng plan của engine.

## Lesson 06 – Window Functions

**MCQ:** 1B, 2B, 3C, 4A, 5A, 6B.

Điểm phải có:

- Window giữ row identity; GROUP BY thay đổi grain.
- `ROW_NUMBER` chọn đúng một winner nếu ordering deterministic.
- `RANK`: ties có gap; `DENSE_RANK`: ties không gap.
- `LAG`/`LEAD` dùng cho previous/next state/value.
- Explicit frame giúp phân biệt running aggregate và whole-partition aggregate.
- Latest-row cần business ordering + tie-breaker, không chỉ “DESC timestamp” theo thói quen.

## Lesson 07 – Data Engineering SQL Patterns

**MCQ:** 1B, 2A, 3A, 4A, 5A, 6A.

Điểm phải có:

- Dedup bắt đầu bằng business key + winner rule.
- Event time/effective time/ingestion time có semantics khác nhau.
- Incremental = state management; cần boundaries, checkpoint/watermark, retry strategy.
- Idempotency là property của repeated execution; dedup là một kỹ thuật xử lý repeated/business duplicate records.
- Watermark có thể miss hard delete hoặc backdated change nếu source không expose signal phù hợp.
- SCD2 giữ historical versions và point-in-time join bằng validity interval.

## Lesson 08 – Indexes & EXPLAIN

**MCQ:** 1B, 2B, 3A, 4A, 5A, 6A, 7A.

Điểm phải có:

- Index giảm search work cho một số patterns nhưng tăng storage/write maintenance.
- Planner có thể chọn Seq Scan nếu estimated cheaper.
- Selectivity ảnh hưởng usefulness của access path.
- Composite index order phải dựa trên workload; không học thuộc luật tuyệt đối thiếu context.
- `EXPLAIN ANALYZE` chạy query và cho actual metrics.
- Estimated vs actual rows lệch lớn là cardinality-estimation signal.
- Nested Loop/Hash/Merge là physical join strategies; optimizer chọn dựa trên plan/cost/data.

## Self-check chuẩn trước khi qua Module 03

Bạn nên tự trả lời được, không nhìn notes:

1. Grain của một table/query result là gì?
2. Vì sao NULL làm `NOT IN` khó reasoning?
3. Làm sao chứng minh join không fan-out?
4. Latest-row/customer viết và validate thế nào?
5. Dedup event stream khác `SELECT DISTINCT` thế nào?
6. Watermark retry có thể tạo duplicate ra sao?
7. `ROW_NUMBER` vs `RANK`.
8. Tại sao index tồn tại nhưng planner không dùng?
9. `EXPLAIN ANALYZE` cung cấp bằng chứng gì?
10. Một query revenue sai, bạn debug theo thứ tự nào?