# Lesson 08 – EXPLAIN, Query Profile & Performance on Databricks

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Phân biệt logical plan, physical plan và runtime metrics.
- Dùng Databricks `EXPLAIN` ở mức fresher, gồm `FORMATTED` / `COST` awareness.
- Dùng **Query Profile** để tìm expensive operators, full scans, exploding joins và shuffle-heavy stages.
- Giải thích vì sao query performance chủ yếu là giảm unnecessary work.
- Nhận biết statistics/cardinality estimates ảnh hưởng optimizer decisions.
- Hiểu Adaptive Query Execution (AQE) ở mức mental model.
- Hiểu Photon ở mức role/coverage awareness.
- Tối ưu projection/filter/join relation trước khi nghĩ tới compute scaling.
- Biết ranh giới giữa Module 02 query tuning và deep Spark/Delta optimization ở Module 09–10.

---

## 2. Source alignment

### Primary Databricks sources

- `EXPLAIN`  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-qry-explain
- Query Profile  
  https://docs.databricks.com/aws/en/sql/user/queries/query-profile
- Query performance insights  
  https://docs.databricks.com/aws/en/sql/user/queries/query-insights
- Performance efficiency best practices  
  https://docs.databricks.com/aws/en/lakehouse-architecture/performance-efficiency/best-practices
- Adaptive Query Execution  
  https://docs.databricks.com/aws/en/optimizations/aqe
- Photon  
  https://docs.databricks.com/aws/en/compute/photon

### Supplementary

Legacy PostgreSQL `EXPLAIN` / B-tree index exercises are optional local practice only. Traditional row-store index tuning is **not** a Module 02 pass requirement.

---

## 3. Principles

### Principle 1 – Performance is work avoided

Fast query thường làm ít work hơn:

```text
scan fewer rows/files
read fewer columns
filter earlier when semantics allow
avoid exploding joins
shuffle less data
aggregate less intermediate data
reuse efficient table layout/statistics
```

### Principle 2 – Correctness before speed

Workflow:

```text
prove correctness
→ measure
→ inspect plan/profile
→ form hypothesis
→ change one thing
→ remeasure
```

Query sai chạy 100 ms vẫn là query sai.

### Principle 3 – EXPLAIN is a model; Query Profile is runtime evidence

`EXPLAIN` cho plan optimizer dự định dùng.

Query Profile cho execution DAG/metrics của query đã chạy.

Cả hai bổ sung nhau.

### Principle 4 – An exploding join is not merely a tuning issue

Nếu join output rows tăng 100×:

1. kiểm tra cardinality/business semantics;
2. nếu explosion là intended, mới optimize execution;
3. nếu unintended, fix relation/key/window before tuning compute.

### Principle 5 – Optimizer decisions depend on information

Statistics, estimated cardinalities, filters và relation sizes ảnh hưởng join strategy/order.

Bad information → bad estimate → potentially bad plan.

---

## 4. Fundamentals

### 4.1 `EXPLAIN`

Basic:

```sql
EXPLAIN
SELECT
  c.province,
  SUM(b.amount) AS revenue
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY c.province;
```

Databricks supports modes such as:

```sql
EXPLAIN FORMATTED
SELECT ...;
```

and:

```sql
EXPLAIN COST
SELECT ...;
```

Mode availability/output can evolve by Runtime. Read the current official `EXPLAIN` docs rather than memorizing every field.

### 4.2 Logical vs physical plan

Logical plan expresses relational operations:

```text
scan
filter
join
aggregate
sort
```

Physical plan chooses concrete execution operators/strategies.

Course rule:

> Do not infer physical execution only from SQL syntax.

### 4.3 Query Profile

After query execution, Query Profile can visualize execution and expose metrics such as:

```text
operator time
rows processed/produced
memory
I/O
shuffle
slowest operators
```

Useful diagnostics include:

```text
full table scan
exploding join
large shuffle
expensive sort/aggregate
```

### 4.4 Exploding join

Example:

```sql
SELECT
  b.transaction_id,
  h.status
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id;
```

If a customer has many history rows, one fact can produce many output rows.

Query Profile may reveal row amplification at join operator.

Correctness check:

```sql
SELECT
  COUNT(*) AS joined_rows,
  COUNT(DISTINCT b.transaction_id) AS distinct_transactions
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id;
```

### 4.5 Full scan

Full scan is not automatically bad.

Scanning an entire small table can be cheaper than elaborate pruning/access paths.

But if query needs one day out of years of data, full scan is a signal to inspect:

```text
filter predicate
partition/table layout
statistics/data skipping
function/cast around filter column
unnecessary columns
```

Deep Delta layout optimization is Module 10.

### 4.6 Projection matters

Avoid unnecessarily wide reads:

```sql
SELECT *
FROM very_wide_table;
```

when only 4 columns are used downstream.

Columnar engines benefit when projection lets them avoid reading unused columns.

### 4.7 Statistics

Optimizer estimates relation size/cardinality from metadata/statistics.

Databricks best-practice guidance includes keeping table statistics useful so optimizer can choose better join type/order/build side.

Awareness command:

```sql
ANALYZE TABLE table_name COMPUTE STATISTICS;
```

Exact recommendations differ by managed table/runtime features; Module 10 will revisit predictive optimization/statistics.

### 4.8 Shuffle

Distributed join/aggregate may need to redistribute rows across workers by key.

Mental model:

```text
local partitions
  ↓ exchange/shuffle by key
new partitions
  ↓ join/aggregate
```

Large shuffle can dominate runtime/network/memory.

Do not try to hand-tune Spark partitions in Module 02; just learn to identify shuffle as work.

### 4.9 Adaptive Query Execution (AQE)

AQE can revise execution decisions using runtime statistics.

Databricks documents behaviors such as:

```text
coalesce shuffle partitions
handle skewed partitions
change some join strategies at runtime
propagate empty relation optimizations
```

Mental model:

> initial physical plan is not always final plan.

### 4.10 Photon

Photon is Databricks' native vectorized execution engine for supported SQL/DataFrame workloads.

At fresher level, know:

```text
Catalyst/optimizer plans query
Photon can execute supported operators efficiently in native columnar engine
coverage can be inspected in query/profile insights depending on environment
```

Do not treat Photon as replacement for good query semantics.

### 4.11 Query performance insights

Databricks can surface recommendations/signals such as:

```text
exploding joins
filter/table-layout opportunities
Photon coverage
other expensive-query patterns
```

Availability/details can depend on workspace/compute. Use them as evidence, not autopilot.

---

## 5. Worked example – Revenue query review

### Baseline

```sql
SELECT
  c.province,
  SUM(b.amount) AS revenue
FROM billing_transactions b
JOIN customers c
  ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY c.province
ORDER BY revenue DESC;
```

### Step 1 – Correctness

```text
billing grain: transaction
customer grain: customer
expected join: N:1
output grain: province
```

Validate customer uniqueness before trusting aggregate.

### Step 2 – EXPLAIN

```sql
EXPLAIN FORMATTED
SELECT ...;
```

Identify conceptual operators:

```text
scan
filter
join
aggregate
sort
```

### Step 3 – Execute + Query Profile

Inspect:

```text
which operator takes most time?
rows read vs rows produced?
shuffle/exchange?
join row amplification?
full scan?
```

### Step 4 – Compare a bad join

Run history join only by `customer_id` and compare Query Profile row counts.

The best optimization may simply be:

> create the correct 1-row/customer or point-in-time relation before joining.

---

## 6. Hands-on lab

Create `lesson-08.sql` and `lesson-08-notes.md` or notebook equivalents.

### Part A – EXPLAIN

Run `EXPLAIN FORMATTED` for:

1. simple filtered scan;
2. revenue aggregate;
3. billing → customer join;
4. window + QUALIFY;
5. intentionally exploding history join.

For each, record:

```text
logical purpose
main physical operators
join/exchange/aggregate nodes observed
```

### Part B – Query Profile

Execute at least 4 queries and inspect Query Profile.

Record:

```text
slowest operator
input rows
output rows
shuffle/I/O signal
memory signal if shown
full scan/exploding join insight if shown
```

### Part C – Exploding join experiment

Compare:

```text
billing JOIN all history
```

vs:

```text
billing JOIN latest-status relation
```

Measure:

```text
joined row count
revenue reconciliation
profile row amplification
```

### Part D – Projection/filter experiment

Compare conceptually:

```sql
SELECT * FROM billing_transactions;
```

with a query selecting only needed columns + selective date/status filters.

On tiny sample, runtime difference may be negligible. Explain why production-scale work could differ.

### Part E – Statistics awareness

If your environment permits, inspect table statistics/optimizer information and try `ANALYZE TABLE` on a practice copy. Do not make this lab depend on workspace-specific privileges.

### Part F – AQE / Photon observation

Using plan/profile or environment UI, note whether AQE/Photon-related information is visible. Write 5–10 lines explaining what they optimize and what they **do not** fix (for example, wrong join keys).

### Challenge – performance incident write-up

Write one page:

```text
Business query:
Correctness assumptions:
Observed symptom:
EXPLAIN evidence:
Query Profile evidence:
Root-cause hypothesis:
Change:
Trade-off:
Re-measure result:
```

---

## 7. Knowledge check – MCQ

**Q1.** `EXPLAIN` primarily gives:  
A. planned query execution information; B. data-quality score; C. Delta delete history; D. certification result.

**Q2.** Query Profile primarily adds:  
A. runtime operator metrics/visualization; B. Python compiler; C. SCD2 table; D. catalog grants.

**Q3.** Exploding join should first trigger:  
A. more compute; B. cardinality/business-semantics check; C. DISTINCT; D. Photon off.

**Q4.** Large shuffle means roughly:  
A. data redistribution across workers; B. CSV parsing; C. local variable copy; D. Delta time travel.

**Q5.** AQE:  
A. can adapt parts of physical execution using runtime stats; B. fixes wrong business key; C. replaces SQL; D. disables optimization.

**Q6.** Photon:  
A. native vectorized execution for supported workloads; B. data catalog; C. CDC source; D. Python package manager.

**Q7.** Statistics help optimizer mainly with:  
A. cardinality/selectivity/cost decisions; B. column names; C. Git commit; D. event-time correctness.

**Q8.** Best optimization order:  
A. correctness → measure → evidence → change → remeasure; B. scale compute immediately; C. DISTINCT first; D. random rewrite.

---

## 8. Tự luận / Interview

1. EXPLAIN vs Query Profile khác nhau thế nào?
2. Vì sao full scan không luôn là bug?
3. Exploding join vừa là correctness vừa performance problem như thế nào?
4. Shuffle là gì ở mental-model level?
5. Statistics ảnh hưởng optimizer ra sao?
6. AQE có thể thay đổi điều gì? Không thể sửa điều gì?
7. Photon giúp gì và tại sao vẫn cần query tuning?
8. Nếu dashboard query chậm, bạn debug theo thứ tự nào?
9. Vì sao SELECT fewer columns có thể quan trọng trong columnar engine?
10. Khi nào nên defer optimization sang Module Spark/Delta thay vì tune trong SQL module?

---

## 9. Exit criteria

- [ ] Chạy >=5 EXPLAIN queries.
- [ ] Đọc được scan/filter/join/aggregate/exchange ở high level.
- [ ] Dùng Query Profile cho >=4 queries nếu environment hỗ trợ.
- [ ] Phát hiện và sửa exploding join.
- [ ] Giải thích shuffle/AQE/Photon/statistics ở fresher level.
- [ ] Không coi PostgreSQL index tuning là Databricks optimization core.
- [ ] Hoàn thành performance incident write-up.
- [ ] Đạt >=7/8 MCQ.