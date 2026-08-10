# Lesson 07 – Data Engineering SQL Patterns on Delta Lake

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Viết dedup có business key và deterministic winner rule bằng Databricks SQL.
- Phân biệt exact duplicate, business duplicate và legitimate versions.
- Tạo latest-record snapshot bằng `QUALIFY`.
- Reasoning về incremental candidate set, watermark, overlap và idempotency.
- Dùng Delta Lake `MERGE INTO` cho upsert/delete pattern ở mức thực hành.
- Giải thích vì sao source của `MERGE` phải có match semantics rõ và thường cần dedup trước.
- Phân biệt manual `MERGE` với Lakeflow **AUTO CDC** ở mức architecture awareness.
- Mô tả SCD Type 1/2 và point-in-time history semantics.
- Viết SQL data-quality checks trước khi publish Silver/Gold.

---

## 2. Source alignment

### Primary Databricks sources

- Delta Lake `MERGE INTO`  
  https://docs.databricks.com/aws/en/sql/language-manual/delta-merge-into
- Upsert into Delta with MERGE  
  https://docs.databricks.com/aws/en/delta/merge
- Incremental ETL / CDC patterns  
  https://docs.databricks.com/aws/en/ldp/transform
- AUTO CDC APIs / SCD processing  
  https://docs.databricks.com/aws/en/ldp/cdc

### Scope note

Module 02 học **SQL semantics + Delta DML**. Production ingestion, CDC ordering, streaming state và Lakeflow pipeline design sẽ được đào sâu ở Module 11.

Databricks khuyến nghị Lakeflow AUTO CDC cho nhiều CDC/SCD workloads thay vì tự viết logic phức tạp bằng MERGE. Module này vẫn dạy `MERGE` vì nó là SQL primitive quan trọng và giúp hiểu upsert semantics.

---

## 3. Principles

### Principle 1 – Dedup starts with a contract

Trước `DISTINCT`, `ROW_NUMBER`, `MERGE`, hãy trả lời:

```text
Business key?
What counts as the same logical record?
Winner rule?
Tie-breaker?
Do we need history or only current state?
```

### Principle 2 – Latest depends on the time/version semantics

“Latest” có thể theo:

```text
event time
source update time
payload version
effective time
ingestion time
```

Không mặc định `MAX(ingested_at)` là business latest.

### Principle 3 – Incremental processing is state management

Watermark query:

```sql
WHERE updated_at > last_watermark
  AND updated_at <= run_upper_bound
```

chỉ là phần extraction.

Một design đúng còn cần:

```text
state checkpoint
retry semantics
late/backdated updates
delete semantics
idempotent target write
```

### Principle 4 – MERGE correctness begins before MERGE

`MERGE INTO` không tự giải quyết ambiguous source duplicates.

Nếu nhiều source rows match cùng target row, update semantics có thể ambiguous/error. Source relation phải được chuẩn hóa tới đúng business grain trước khi merge.

### Principle 5 – SCD is temporal semantics, not only columns

SCD Type 2 phải cho phép trả lời:

> Attribute nào có hiệu lực tại timestamp T?

`effective_from/effective_to` chỉ hữu ích nếu intervals không overlap/gap ngoài rule cho phép.

---

## 4. Fundamentals

### 4.1 Duplicate taxonomy

**Exact duplicate**

Selected business payload giống nhau hoàn toàn.

**Business duplicate**

Cùng business key nhưng ingestion metadata khác.

**Versioned correction**

Cùng business key nhưng source version/payload khác; version mới có thể là correction hợp lệ.

Trong lab:

```text
e009 → repeated business event with later ingestion
e005 → newer payload_version changes signal value
```

### 4.2 Databricks dedup with QUALIFY

Contract:

```text
business key = event_id
winner = highest payload_version
then latest ingested_at
then highest ingest_row_id
```

```sql
SELECT
  ingest_row_id,
  event_id,
  tower_id,
  customer_id,
  event_type,
  event_ts,
  ingested_at,
  signal_dbm,
  duration_seconds,
  payload_version
FROM network_events
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY event_id
  ORDER BY
    payload_version DESC,
    ingested_at DESC,
    ingest_row_id DESC
) = 1;
```

Validation:

```sql
WITH clean AS (
  SELECT *
  FROM network_events
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY event_id
    ORDER BY payload_version DESC, ingested_at DESC, ingest_row_id DESC
  ) = 1
)
SELECT event_id, COUNT(*) AS n
FROM clean
GROUP BY event_id
HAVING COUNT(*) > 1;
```

Expected: 0 rows.

### 4.3 Incremental candidate set

Example run contract:

```text
last successful watermark = 2026-08-03 00:00
run upper bound           = 2026-08-06 00:00
interval                  = (last, upper]
```

```sql
SELECT *
FROM billing_transactions
WHERE updated_at >  TIMESTAMP '2026-08-03 00:00:00'
  AND updated_at <= TIMESTAMP '2026-08-06 00:00:00';
```

Boundary convention khác cũng hợp lệ nếu checkpoint logic nhất quán.

### 4.4 Overlap window

Một pragmatic strategy:

```text
read_from = last_watermark - overlap
```

rồi target dedup/upsert.

Trade-off:

```text
+ catch some late/backdated updates
- re-read more rows
- requires idempotent target semantics
```

### 4.5 Delta MERGE INTO

Create a current-state target:

```sql
CREATE OR REPLACE TABLE customer_current (
  customer_id BIGINT,
  full_name STRING,
  province STRING,
  email STRING,
  segment STRING,
  updated_at TIMESTAMP
) USING DELTA;
```

Upsert:

```sql
MERGE INTO customer_current AS t
USING customer_updates AS s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET
  t.full_name = s.full_name,
  t.province = s.province,
  t.email = s.email,
  t.segment = s.segment,
  t.updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (
  customer_id, full_name, province, email, segment, updated_at
) VALUES (
  s.customer_id, s.full_name, s.province, s.email, s.segment, s.updated_at
);
```

Key reasoning:

```text
Target grain: 1 row/customer
Merge key: customer_id
Source precondition: <=1 winning source row/customer for this logical batch
```

### 4.6 Pre-deduplicate source before MERGE

```sql
WITH source_clean AS (
  SELECT *
  FROM customer_updates
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY updated_at DESC
  ) = 1
)
MERGE INTO customer_current t
USING source_clean s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;
```

`UPDATE SET *` / `INSERT *` thuận tiện khi schemas aligned, nhưng explicit mapping thường dễ review hơn khi serving contract quan trọng.

### 4.7 Deletes

Nếu source cung cấp delete signal, MERGE có thể express delete branch.

Concept:

```sql
WHEN MATCHED AND s.operation = 'DELETE' THEN DELETE
```

Nhưng simple watermark trên surviving source rows **không tự phát hiện hard delete** nếu source không expose delete event/log.

### 4.8 SCD Type 1

Current-only state:

```text
customer_id | segment | updated_at
```

New value overwrites previous state.

Typical manual primitive: `MERGE` update/insert.

### 4.9 SCD Type 2

Historical versions:

```text
customer_sk
customer_id
segment
effective_from
effective_to
is_current
```

Point-in-time join:

```sql
fact.customer_id = dim.customer_id
AND fact.event_ts >= dim.effective_from
AND fact.event_ts < COALESCE(dim.effective_to, TIMESTAMP '9999-12-31 00:00:00')
```

Manual SCD2 SQL can become complex with out-of-order updates.

### 4.10 AUTO CDC awareness

Lakeflow Spark Declarative Pipelines provides **AUTO CDC** for change feeds and supports SCD Type 1/2 semantics.

Conceptual API inputs include:

```text
source
keys
sequence_by
apply_as_deletes / operation semantics
stored_as_scd_type
```

Why it matters:

```text
manual MERGE      → you own ordering/dedup/history logic
AUTO CDC          → pipeline primitive handles CDC sequencing/SCD workflow
```

Do not treat AUTO CDC as magic: business keys and sequence semantics still need a correct data contract.

### 4.11 Data-quality SQL patterns

**Uniqueness**

```sql
SELECT business_key, COUNT(*)
FROM table_name
GROUP BY business_key
HAVING COUNT(*) > 1;
```

**Completeness**

```sql
SELECT COUNT(*)
FROM table_name
WHERE required_column IS NULL;
```

**Accepted values**

```sql
SELECT status, COUNT(*)
FROM billing_transactions
WHERE status NOT IN ('success','failed','refunded')
GROUP BY status;
```

**Orphan relationship**

```sql
SELECT b.*
FROM billing_transactions b
LEFT ANTI JOIN customers c
  ON c.customer_id = b.customer_id;
```

**Reconciliation**

Compare counts/sums/distinct keys across source → clean → serving.

---

## 5. Worked example – Dedup network events → Silver Delta table

### Step 1 – Define Silver contract

```text
Table: silver_network_events
Grain: 1 row / logical event_id
Winner: payload_version DESC, ingested_at DESC, ingest_row_id DESC
```

### Step 2 – Create Silver table

```sql
CREATE OR REPLACE TABLE silver_network_events
USING DELTA
AS
SELECT
  ingest_row_id,
  event_id,
  tower_id,
  customer_id,
  event_type,
  event_ts,
  ingested_at,
  signal_dbm,
  duration_seconds,
  payload_version
FROM network_events
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY event_id
  ORDER BY payload_version DESC, ingested_at DESC, ingest_row_id DESC
) = 1;
```

### Step 3 – Validate

```sql
SELECT event_id, COUNT(*) AS n
FROM silver_network_events
GROUP BY event_id
HAVING COUNT(*) > 1;
```

Expected: 0 rows.

### Step 4 – Calculate KPI only after canonicalization

```sql
SELECT
  tower_id,
  count_if(event_type = 'call_drop') AS drops,
  count_if(event_type IN ('call_drop','call_end')) AS total_calls,
  CAST(count_if(event_type = 'call_drop') AS DOUBLE)
    / NULLIF(count_if(event_type IN ('call_drop','call_end')), 0) AS drop_rate
FROM silver_network_events
GROUP BY tower_id;
```

---

## 6. Hands-on lab

### Part A – Dedup / latest

1. List duplicate `event_id` + version counts.
2. Dedup by ingestion time only.
3. Dedup by official lab contract using `QUALIFY`.
4. Compare winners for `e005` / `e009`.
5. Add >=3 validation checks.
6. Compare tower drop-rate before vs after dedup.

### Part B – Incremental state

Given:

```text
last_watermark = 2026-08-03 00:00
upper_bound    = 2026-08-06 00:00
```

7. Write candidate extraction.
8. Explain retry after target write but before watermark commit.
9. Add 2-hour overlap and explain target requirement.
10. Explain why hard deletes can be missed.

### Part C – Delta MERGE

11. Create `customer_current` Delta table.
12. Create temporary/update relation with:

```text
one existing customer update
one new customer
```

13. MERGE update + insert.
14. Re-run the same MERGE and prove target does not gain duplicate business keys.
15. Create deliberately duplicated source rows for one customer; explain why pre-dedup is required.
16. Fix source using `QUALIFY ROW_NUMBER()` before MERGE.

### Part D – SCD / CDC awareness

17. Design SCD2 schema for customer segment.
18. Write point-in-time join condition.
19. Describe manual steps to close old version + insert new version.
20. Write a short comparison:

```text
manual MERGE/SCD2
vs
Lakeflow AUTO CDC
```

including keys, sequencing and out-of-order change concerns.

### Part E – Data quality

Write >=8 checks:

- duplicate business key;
- required NULL;
- malformed/invalid status;
- negative amount;
- orphan customer;
- impossible time order;
- SCD overlapping windows;
- revenue reconciliation.

---

## 7. Knowledge check – MCQ

**Q1.** Dedup bắt đầu bằng:  
A. DISTINCT; B. business key + winner rule; C. MERGE; D. Photon.

**Q2.** Databricks `QUALIFY` hữu ích cho dedup vì:  
A. filter ROW_NUMBER result trực tiếp; B. creates index; C. rewrites Delta log; D. deletes duplicates physically.

**Q3.** Multiple source rows match same target row in MERGE:  
A. always deterministic; B. can make update semantics ambiguous/error, source should be deduped; C. auto SCD2; D. ignored.

**Q4.** Watermark incremental pattern là:  
A. stateful; B. file format; C. join hint; D. catalog.

**Q5.** Plain append retry có thể:  
A. create duplicates; B. enable Photon; C. delete history; D. collect stats.

**Q6.** SCD Type 2:  
A. stores history versions; B. current only; C. no business key; D. only streaming.

**Q7.** AUTO CDC primarily helps with:  
A. change sequencing/SCD application in Lakeflow pipelines; B. B-tree index; C. SELECT aliases; D. CSV compression.

**Q8.** Simple watermark usually cannot infer:  
A. hard delete without delete signal; B. inserted row with timestamp; C. SELECT result; D. COUNT.

---

## 8. Tự luận / Interview

1. Exact duplicate vs business duplicate vs versioned correction.
2. Vì sao source của MERGE nên unique theo match key?
3. MERGE có làm pipeline automatically idempotent trong mọi trường hợp không? Vì sao?
4. Watermark có những failure modes nào?
5. Overlap window đổi complexity nào lấy reliability nào?
6. SCD1 vs SCD2 chọn theo requirement gì?
7. Manual MERGE vs AUTO CDC: khi nào bạn prefer mỗi approach?
8. AUTO CDC vẫn cần business contract gì?
9. Nếu fail sau MERGE nhưng trước checkpoint commit, retry sẽ thế nào?
10. 5 checks trước khi publish Gold table.

---

## 9. Exit criteria

- [ ] Dedup bằng QUALIFY có deterministic rule.
- [ ] Validate Silver relation unique business key.
- [ ] Viết incremental interval + retry reasoning.
- [ ] Thực hiện Delta MERGE update/insert.
- [ ] Pre-dedup MERGE source khi necessary.
- [ ] Giải thích delete limitation của watermark.
- [ ] Giải thích SCD1/SCD2 + point-in-time join.
- [ ] Phân biệt manual MERGE và AUTO CDC.
- [ ] Viết >=8 quality checks.
- [ ] Đạt >=7/8 MCQ.