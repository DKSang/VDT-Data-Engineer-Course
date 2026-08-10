# Module 02 – Lesson Answer Key (Databricks-first)

> Self-check sau khi đã làm lab. Answer key không thay thế việc chạy query, validation và đọc official Databricks docs.

## Lesson 01 – Relational Thinking & Query Semantics

**MCQ:** `1B, 2B, 3B, 4B, 5B, 6A`

Điểm phải có:

- Grain = ý nghĩa một row.
- Business key có thể khác technical key.
- Logical SQL reasoning không phải physical execution order; optimizer quyết định physical plan.
- Join/aggregate phải được kiểm tra bằng cardinality/uniqueness/reconciliation.
- `SELECT * EXCEPT (...)` là projection convenience, không thay explicit serving contract.

## Lesson 02 – NULL, Types & try_cast

**MCQ:** `1A, 2B, 3B, 4B, 5B, 6B, 7A`

Điểm phải có:

- `WHERE` giữ TRUE; comparison với NULL có UNKNOWN semantics.
- Dùng `IS NULL`, không `= NULL`.
- `try_cast` biến malformed supported casts thành NULL để pipeline có thể classify/quarantine; nó không tự sửa quality.
- Strict `CAST` phù hợp khi invalid input phải fail.
- Half-open interval `[start,end)` phù hợp batch boundaries.
- Right-side predicate trong `WHERE` có thể phá LEFT JOIN row preservation.
- Null-safe comparison khác ordinary `=` khi NULL tham gia.

## Lesson 03 – Aggregation

**MCQ:** `1B, 2A, 3A, 4A, 5A, 6B, 7A`

Điểm phải có:

- `GROUP BY` thay đổi grain.
- `WHERE` filter base rows; `HAVING` filter groups.
- `count_if` đếm true conditions.
- Aggregate `FILTER` giới hạn rows đi vào aggregate expression.
- Join fan-out trước SUM gây double-count.
- `DISTINCT` không phải generic join repair.
- Average-of-averages cần weighting nếu group sizes khác.
- `ROLLUP/CUBE/GROUPING SETS` tạo multi-grain result nên phải interpret subtotal rows rõ.

## Lesson 04 – JOINs & Set Operations

**MCQ:** `1A, 2B, 3B, 4A, 5B, 6B, 7B`

Điểm phải có:

- Fact N:1 unique dimension thường preserve fact grain.
- `LEFT SEMI JOIN` = left rows có match.
- `LEFT ANTI JOIN` = left rows không match.
- History equality join có thể fan-out.
- `UNION ALL` giữ duplicates; `UNION` default duplicate removal.
- Exploding join trước hết là cardinality/correctness investigation, sau đó mới performance.
- Temporal join cần business key + validity interval.

## Lesson 05 – Subqueries & CTEs

**MCQ:** `1A, 2B, 3A, 4B, 5A, 6A`

Điểm phải có:

- CTE là named relation, không tự enforce uniqueness.
- Mỗi CTE cần purpose/grain/key.
- `EXISTS`/SEMI JOIN express presence; `NOT EXISTS`/ANTI JOIN express absence.
- Không kết luận CTE/subquery performance từ syntax alone.
- Recursive CTE có base step + recursive step + termination reasoning; feature/runtime applicability phải được kiểm tra.

## Lesson 06 – Window Functions & QUALIFY

**MCQ:** `1B, 2A, 3B, 4B, 5B, 6A, 7A`

Điểm phải có:

- Window giữ row identity; GROUP BY collapse grain.
- `QUALIFY` filter window-function results.
- `HAVING` filter grouped aggregate result.
- `ROW_NUMBER` tạo unique ordinal; `RANK` ties + gaps; `DENSE_RANK` ties no gaps.
- Deterministic latest-row/dedup cần complete ordering/tie-breaker.
- Window frame quyết định population của running/moving aggregate.
- `LEAD` hữu ích để derive next effective boundary.

## Lesson 07 – Data Engineering SQL on Delta

**MCQ:** `1B, 2A, 3B, 4A, 5A, 6A, 7A, 8A`

Điểm phải có:

- Dedup bắt đầu bằng business key + winner/tie-breaker.
- `QUALIFY ROW_NUMBER()` chọn canonical row nhưng không xóa duplicate raw data.
- MERGE source phải có unambiguous match semantics; pre-dedup source khi nhiều source rows có thể match cùng target.
- Watermark = state management; checkpoint/retry/late/delete semantics là một phần design.
- Plain append retry có thể duplicate; MERGE/upsert chỉ idempotent nếu key/logic/input semantics đúng.
- SCD2 giữ history versions + validity intervals.
- AUTO CDC là Lakeflow primitive cho sequencing/SCD application; vẫn cần keys/sequence contract.
- Watermark không tự capture hard delete nếu không có delete signal.

## Lesson 08 – EXPLAIN, Query Profile & Performance

**MCQ:** `1A, 2A, 3B, 4A, 5A, 6A, 7A, 8A`

Điểm phải có:

- `EXPLAIN` = planned logical/physical execution information; Query Profile = runtime execution evidence/metrics.
- Exploding join phải kiểm tra cardinality/business semantics trước khi scale compute.
- Shuffle = redistribution of data across workers/partitions.
- AQE có thể adapt parts of physical execution from runtime statistics; không sửa wrong business logic.
- Photon là native vectorized execution engine for supported workloads; không thay correctness/query design.
- Statistics ảnh hưởng estimates/cost/join decisions.
- Full scan không luôn là bug; context/table size/filter intent quan trọng.
- Optimization loop: correctness → measure → evidence → hypothesis/change → remeasure.

---

# Self-check trước khi rời Module 02

Không nhìn notes, hãy trả lời:

1. Grain là gì? Business key khác technical key?
2. `CAST` vs `try_cast`.
3. `WHERE` vs `HAVING` vs `QUALIFY`.
4. INNER/LEFT/SEMI/ANTI JOIN.
5. Làm sao prove join không fan-out?
6. `ROW_NUMBER` vs `RANK`.
7. Dedup event bằng `QUALIFY` cần contract gì?
8. Vì sao MERGE source duplicate nguy hiểm?
9. Watermark miss hard delete thế nào?
10. Manual MERGE vs AUTO CDC.
11. EXPLAIN vs Query Profile.
12. AQE/Photon giúp gì và không giúp gì?

Nếu chưa trả lời được bằng ví dụ telecom mà không đọc notes, chưa nên coi Module 02 hoàn thành.