# Module 02 Final Assessment – Databricks SQL for Data Engineers

> Không xem `answers/module-02-final-solutions.md` trước khi hoàn thành.

## Quy định

- **Primary engine:** Databricks SQL / Databricks Runtime + Delta tables.
- Setup: `labs/module-02-sql/databricks-setup.sql`.
- PostgreSQL không phải reference engine của bài thi này.
- Thời gian gợi ý: **180 phút**.
- Mọi bài coding phải ghi expected output grain.
- Với join/dedup/MERGE phải ghi business key + cardinality/winner assumption.
- Query chạy được nhưng reasoning sai không đạt full score.

---

# Phần A – Fundamentals & Databricks SQL (20 điểm)

Mỗi câu 1 điểm.

1. Grain mô tả: A. số column; B. ý nghĩa một row; C. warehouse size; D. Delta version.
2. `WHERE` giữ predicate: A. TRUE; B. TRUE/UNKNOWN; C. FALSE; D. NULL.
3. Tìm NULL đúng: A. `= NULL`; B. `IS NULL`; C. `== NULL`; D. `NULL()`.
4. `try_cast('bad' AS INT)` trong supported cast context: A. 0; B. NULL; C. `'bad'`; D. always hard error.
5. `HAVING` filter: A. base rows; B. groups after aggregation; C. window results; D. files.
6. `QUALIFY` filter chủ yếu: A. window-function results; B. source files; C. GROUP BY keys; D. catalog objects.
7. `LEFT SEMI JOIN` trả: A. matched pairs all columns; B. left rows có match; C. right rows; D. unmatched left rows.
8. `LEFT ANTI JOIN` trả: A. left rows không match; B. matched pairs; C. right rows; D. Cartesian result.
9. `UNION ALL`: A. remove duplicate; B. preserve duplicate rows; C. anti join; D. aggregate.
10. `ROW_NUMBER` latest-row cần tie-breaker để: A. deterministic winner; B. create Delta table; C. enable Photon; D. collect stats.
11. Dedup bắt đầu bằng: A. DISTINCT; B. business key + winner rule; C. MERGE; D. EXPLAIN.
12. Multiple source rows match one target row in `MERGE`: A. always safe; B. can be ambiguous/error and should be resolved upstream; C. auto SCD2; D. ignored.
13. Watermark incremental pattern là: A. stateful; B. file format; C. query profile; D. catalog.
14. SCD Type 2: A. stores historical versions; B. current only; C. removes business key; D. only for streaming.
15. Simple watermark usually cannot infer: A. hard delete without delete signal; B. row with updated timestamp; C. SELECT output; D. count.
16. `EXPLAIN` primarily provides: A. planned execution information; B. runtime UI only; C. data-quality result; D. Delta restore.
17. Query Profile primarily adds: A. runtime operator metrics/visualization; B. schema enforcement; C. Python type checking; D. SCD table.
18. Exploding join should first trigger: A. scale compute; B. cardinality/business-semantics check; C. DISTINCT; D. cache everything.
19. AQE: A. can adapt physical execution using runtime statistics; B. fixes wrong join key; C. replaces SQL; D. creates business keys.
20. Photon: A. native vectorized execution engine for supported workloads; B. data catalog; C. CDC source; D. SQL parser only.

---

# Phần B – SQL Coding (40 điểm)

Mỗi bài 5 điểm.

## B1 – Revenue by province/day

Return:

```text
revenue_date
province
successful_txn_count
unique_paying_customers
successful_revenue
```

Requirements:

- Databricks-compatible syntax;
- output grain;
- reconciliation with base successful revenue.

## B2 – Customers without successful payment

Return customers with no successful transaction.

Requirements:

- use `LEFT ANTI JOIN`;
- explain equivalent `NOT EXISTS` semantics.

## B3 – Latest customer status

Return exactly one row/customer:

```text
customer_id
status
effective_from
recorded_at
```

Requirements:

- use `QUALIFY ROW_NUMBER()`;
- deterministic tie-breaker;
- uniqueness validation.

## B4 – Top 2 successful transactions/customer

Use `ROW_NUMBER` + `QUALIFY`.

Tie-break:

```text
amount DESC
transaction_ts DESC
transaction_id DESC
```

## B5 – Day-over-day revenue

Return:

```text
revenue_date
revenue
previous_day_revenue
absolute_change
pct_change
```

Use `LAG`. Handle denominator zero/NULL.

## B6 – Deduplicated network drop rate

Contract:

```text
business key = event_id
winner = highest payload_version
then latest ingested_at
then highest ingest_row_id
```

After dedup, calculate per-tower:

```text
drops
total_calls
drop_rate
```

Use `count_if` where appropriate.

## B7 – Conditional metric styles

Produce per-day:

```text
successful_count
failed_count
successful_revenue
```

Use at least **two** of:

```text
count_if
aggregate FILTER
CASE
```

Explain which form communicates intent best for each metric.

## B8 – Safe type parsing

Using a `VALUES` relation with:

```text
'100'
'25.5'
'bad'
NULL
```

Return:

```text
raw_value
parsed_decimal
parse_status = valid / malformed / missing
```

Use `try_cast`.

---

# Phần C – Delta / Incremental / Debugging (20 điểm)

Mỗi bài 5 điểm.

## C1 – Delta MERGE current-state table

Create/assume:

```text
customer_current
Grain: 1 row/customer
```

Given `customer_updates` with one existing update + one new customer:

1. write `MERGE INTO`;
2. define merge key;
3. explain rerun/idempotency behavior;
4. provide uniqueness validation.

## C2 – Duplicate MERGE source

`customer_updates` contains 2 rows for the same `customer_id`.

1. Explain why this is unsafe/ambiguous.
2. Pre-dedup source using `QUALIFY ROW_NUMBER()`.
3. State winner rule.
4. Then MERGE.

## C3 – Revenue triples after history join

Bad query:

```sql
SELECT h.status, SUM(b.amount)
FROM billing_transactions b
JOIN customer_status_history h
  ON h.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY h.status;
```

Answer:

1. root cause;
2. grain/cardinality;
3. SQL proving fan-out;
4. correct relation needed before join;
5. why `DISTINCT` is not general fix.

## C4 – Watermark failure reasoning

Given:

```text
last_watermark = 2026-08-03 00:00
upper_bound    = 2026-08-06 00:00
```

1. write incremental candidate query;
2. define boundary convention;
3. explain fail-after-target-write-before-checkpoint scenario;
4. explain one late/backdated risk;
5. explain hard-delete limitation;
6. state when AUTO CDC would be a better production primitive.

---

# Phần D – EXPLAIN & Query Profile (10 điểm)

## D1 – Plan reasoning (5 điểm)

For revenue-by-province query:

1. Write `EXPLAIN FORMATTED` skeleton.
2. Name likely conceptual operators to inspect: scan/filter/join/aggregate/exchange/sort as applicable.
3. Explain logical plan vs physical plan.
4. State what statistics/cardinality estimates influence.

## D2 – Runtime incident (5 điểm)

Query Profile shows a join whose output rows are 50× larger than its inputs and most execution time is near that operator.

Answer:

1. what signal is this?
2. correctness checks first;
3. what inputs/keys/grains to inspect;
4. what Query Profile metrics matter;
5. why AQE/Photon/more compute do not fix a wrong join relationship.

---

# Phần E – VDT-style Oral Interview (10 điểm)

Tối đa 2 phút/câu.

1. Grain là gì? Vì sao DE phải quan tâm?
2. NULL và `try_cast` liên quan data quality thế nào?
3. `WHERE` vs `HAVING` vs `QUALIFY`.
4. INNER vs LEFT vs SEMI vs ANTI JOIN.
5. `ROW_NUMBER` vs `RANK`.
6. Dedup event trên Databricks SQL như thế nào?
7. `MERGE INTO` giải quyết vấn đề gì? Failure mode quan trọng?
8. Watermark incremental vs AUTO CDC.
9. EXPLAIN vs Query Profile.
10. Exploding join: cách debug từ correctness đến performance.

---

# Rubric

| Phần | Điểm |
|---|---:|
| A – Fundamentals | 20 |
| B – SQL Coding | 40 |
| C – Delta/Debugging | 20 |
| D – Performance | 10 |
| E – Oral | 10 |
| **Total** | **100** |

## Pass criteria

- **>=75/100** total.
- Part B >=28/40.
- Part C >=12/20.
- Không được sai các fundamentals sau:
  - `IS NULL` semantics;
  - grain/cardinality;
  - `HAVING` vs `QUALIFY`;
  - deterministic dedup;
  - MERGE source uniqueness reasoning;
  - watermark retry/delete limitations;
  - EXPLAIN vs Query Profile distinction.

## Strong pass

>=85/100 và trả lời Part E không nhìn notes.