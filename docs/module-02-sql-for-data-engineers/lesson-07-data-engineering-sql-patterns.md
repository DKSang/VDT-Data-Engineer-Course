# Lesson 07 – SQL Patterns for Data Engineering

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Viết dedup có business key và deterministic tie-breaker.
- Phân biệt exact duplicate, business duplicate và multiple valid versions.
- Tạo latest-record snapshot từ history/event table.
- Reasoning về incremental extraction bằng watermark.
- Giải thích idempotency và upsert/MERGE ở mức principle.
- Mô tả SCD Type 1 và Type 2 bằng SQL transformations.
- Viết data-quality SQL checks cho uniqueness, completeness, referential integrity và reconciliation.

---

## 2. Principles

### Principle 1 – Dedup requires a definition of sameness

Không có câu “xóa duplicate” nếu chưa trả lời:

```text
Duplicate theo key nào?
Hai rows khác payload có còn là duplicate không?
Giữ bản nào?
Tie-breaker nào đáng tin?
Có cần giữ lịch sử các versions không?
```

### Principle 2 – Latest is a business rule, not `MAX(timestamp)` alone

“Latest” có thể theo:

- event time;
- source update time;
- ingestion time;
- effective time;
- version number.

Chọn sai timestamp có thể biến late-arriving data thành record cũ hoặc mới sai semantics.

### Principle 3 – Incremental processing is state management

Incremental load không chỉ là:

```sql
WHERE updated_at > last_watermark
```

Nó đòi hỏi hiểu:

- state/watermark lưu ở đâu;
- boundary `>` hay `>=`;
- late/backdated changes;
- retry sau partial failure;
- delete capture;
- idempotency.

### Principle 4 – History tables need explicit validity semantics

SCD/history tốt phải cho phép trả lời:

> Giá trị nào có hiệu lực tại thời điểm T?

Không chỉ “row mới nhất hôm nay là gì?”.

---

## 3. Fundamentals

### 3.1 Duplicate taxonomy

**Exact duplicate:** mọi business fields giống nhau.

**Business duplicate:** cùng business key nhưng ingestion metadata khác.

**Versioned event:** cùng business key nhưng payload version khác; có thể là correction hợp lệ.

Trong lab:

```text
e009: duplicate business event với later ingestion
e005: cùng event_id nhưng payload_version mới hơn và signal khác
```

Vì vậy rule “giữ ingested_at mới nhất” và rule “giữ payload_version cao nhất” có thể cho cùng hoặc khác kết quả tùy data contract.

### 3.2 Dedup with ROW_NUMBER

Ví dụ giả định business rule:

> Một `event_id` chỉ đại diện một event logic. Giữ `payload_version` cao nhất; nếu tie, giữ `ingested_at` mới nhất; nếu vẫn tie, giữ `ingest_row_id` lớn nhất.

```sql
WITH ranked AS (
    SELECT
        n.*,
        ROW_NUMBER() OVER (
            PARTITION BY event_id
            ORDER BY
                payload_version DESC,
                ingested_at DESC,
                ingest_row_id DESC
        ) AS rn
    FROM network_events n
)
SELECT *
FROM ranked
WHERE rn = 1;
```

### 3.3 Latest row per entity

Pattern:

```sql
ROW_NUMBER() OVER (
    PARTITION BY entity_key
    ORDER BY business_effective_time DESC, tie_breaker DESC
)
```

Nhưng trước khi áp dụng, xác nhận liệu bảng là snapshot hay history mà downstream cần point-in-time.

### 3.4 Incremental candidate set

Simple watermark:

```sql
SELECT ...
FROM source
WHERE updated_at > :last_watermark
  AND updated_at <= :current_run_upper_bound;
```

Tách upper bound của run giúp định nghĩa một batch ổn định.

Một biến thể an toàn hơn khi timestamp resolution/tie có rủi ro là composite cursor:

```text
(updated_at, primary_key)
```

với ordering lexicographic.

### 3.5 Reprocessing overlap

Một strategy thực dụng:

```text
last successful watermark - overlap window
```

rồi dedup/upsert ở target.

Trade-off:

- đọc lại một ít dữ liệu;
- đổi lại khả năng bắt late update tốt hơn.

Không giải quyết delete nếu source không expose delete semantics.

### 3.6 Idempotency

Một pipeline idempotent cho cùng logical input/run không tạo thêm kết quả sai khi chạy lại.

Ví dụ anti-pattern:

```sql
INSERT INTO target
SELECT * FROM source_delta;
```

Retry có thể append duplicate.

Idempotent strategy có thể gồm:

- overwrite partition deterministically;
- upsert theo business key;
- delete+insert bounded partition;
- transactional MERGE nếu engine hỗ trợ và semantics đúng.

### 3.7 SCD Type 1

Giữ only-current state, update attributes in place.

Concept:

```text
customer_id | province | segment
```

Khi segment đổi, old value bị thay.

Phù hợp khi không cần historical analytical state.

### 3.8 SCD Type 2

Giữ versions:

```text
customer_sk
customer_id
segment
effective_from
effective_to
is_current
```

Khi attribute thay đổi:

1. close current version;
2. insert new version.

Point-in-time join:

```sql
fact.customer_id = dim.customer_id
AND fact.event_ts >= dim.effective_from
AND fact.event_ts < COALESCE(dim.effective_to, TIMESTAMP '9999-12-31')
```

Boundary convention cần nhất quán để tránh overlap/gap.

### 3.9 Data-quality SQL patterns

**Uniqueness**

```sql
SELECT key, COUNT(*)
FROM table_name
GROUP BY key
HAVING COUNT(*) > 1;
```

**Completeness**

```sql
SELECT COUNT(*)
FROM table_name
WHERE required_col IS NULL;
```

**Referential integrity / orphan**

```sql
SELECT f.*
FROM fact f
LEFT JOIN dim d ON d.key = f.key
WHERE d.key IS NULL;
```

**Accepted values**

```sql
SELECT status, COUNT(*)
FROM table_name
WHERE status NOT IN ('success','failed','refunded')
GROUP BY status;
```

**Reconciliation**

Compare row count/sum/count-distinct across source/target or levels of aggregation.

---

## 4. Worked example – Deduplicate network events then calculate drop rate

### Step 1 – Define contract

```text
Business key: event_id
Winner: highest payload_version
Tie 1: latest ingested_at
Tie 2: highest ingest_row_id
```

### Step 2 – Build dedup relation

```sql
WITH deduped_events AS (
    SELECT *
    FROM (
        SELECT
            n.*,
            ROW_NUMBER() OVER (
                PARTITION BY event_id
                ORDER BY
                    payload_version DESC,
                    ingested_at DESC,
                    ingest_row_id DESC
            ) AS rn
        FROM network_events n
    ) x
    WHERE rn = 1
)
SELECT
    tower_id,
    SUM(CASE WHEN event_type = 'call_drop' THEN 1 ELSE 0 END)::numeric
    / NULLIF(
        SUM(CASE WHEN event_type IN ('call_drop','call_end') THEN 1 ELSE 0 END),
        0
      ) AS drop_rate
FROM deduped_events
GROUP BY tower_id;
```

### Step 3 – Validate

```sql
WITH deduped_events AS (...)
SELECT event_id, COUNT(*)
FROM deduped_events
GROUP BY event_id
HAVING COUNT(*) > 1;
```

Expected: 0 rows.

Compare:

```text
raw event rows
raw distinct event_id
clean event rows
```

Clean rows should equal expected unique business events under the contract.

---

## 5. Hands-on lab

Tạo `lesson-07.sql`.

### Part A – Dedup

1. Liệt kê duplicate `event_id` và số versions.
2. Dedup theo latest `ingested_at` only.
3. Dedup theo `payload_version DESC, ingested_at DESC`.
4. So sánh winner của `e005` và `e009`.
5. Viết 3 validation checks cho dedup output.
6. Tính drop rate trước/sau dedup và giải thích chênh lệch.

### Part B – Latest snapshot

1. Latest customer status/customer.
2. Latest subscription/customer.
3. Kiểm tra relation output unique theo customer.
4. Join latest status với customer revenue mà không fan-out.

### Part C – Incremental extraction

Giả sử:

```text
last_watermark = 2026-08-03 00:00:00
current_upper_bound = 2026-08-06 00:00:00
```

1. Trích billing rows trong interval `(last, upper]` hoặc `[last, upper)` theo convention bạn chọn.
2. Viết comment giải thích boundary.
3. Mô phỏng retry: chạy query hai lần. Nếu append target hai lần thì lỗi gì?
4. Thiết kế target upsert key.
5. Mô tả cách bắt late update có `updated_at` cũ hơn watermark.
6. Mô tả vì sao watermark có thể miss delete.

### Part D – SCD reasoning

Thiết kế table:

```text
dim_customer_segment_history
```

có:

- surrogate key;
- business key;
- segment;
- effective_from;
- effective_to;
- is_current.

Viết pseudo-SQL hoặc SQL transaction cho update khi customer 1001 đổi `mass → premium` lúc `2026-08-10 12:00`.

Sau đó viết point-in-time join từ `billing_transactions.transaction_ts` vào dimension.

### Part E – Data quality

Viết ít nhất 8 checks:

- duplicate key;
- required NULL;
- orphan FK;
- invalid status;
- negative amount;
- event `ingested_at < event_ts`;
- impossible subscription dates;
- reconciliation successful revenue.

### Challenge – Idempotent daily load

Mô tả một design cho bảng:

```text
gold_daily_revenue
Grain: revenue_date / province
```

Nếu job ngày `2026-08-05` fail sau khi ghi một phần rồi retry, làm sao tránh duplicate/partial output?

Đưa ra ít nhất 2 strategies và trade-off.

---

## 6. Knowledge check – MCQ

**Q1.** Dedup cần gì trước tiên?  
A. DISTINCT; B. định nghĩa business key và winner/tie-breaker; C. index; D. LIMIT.

**Q2.** “Latest row” chỉ dựa `MAX(ingested_at)` có thể sai vì:  
A. latest business semantics có thể theo effective/source version khác ingestion; B. timestamp không sort; C. SQL không có MAX; D. row_number lỗi.

**Q3.** Watermark incremental load là một dạng:  
A. state management; B. encryption; C. indexing; D. schema normalization.

**Q4.** Retry một plain append incremental batch có thể:  
A. tạo duplicate; B. tự rollback lịch sử; C. tạo index; D. không ảnh hưởng.

**Q5.** SCD Type 2 dùng để:  
A. giữ history versions; B. chỉ giữ current; C. dedup Kafka; D. sort file.

**Q6.** Watermark dựa update timestamp thường không tự capture:  
A. hard delete không có delete signal; B. inserts; C. rows có timestamp; D. select.

---

## 7. Knowledge check – Tự luận / Interview

1. “Duplicate” có những nghĩa nào trong event pipeline?
2. Tại sao ingestion time và event time không thay thế nhau?
3. Thiết kế tie-breaker tốt cho dedup cần data contract gì?
4. Watermark incremental có failure modes nào?
5. Idempotency khác dedup như thế nào?
6. SCD Type 1 vs Type 2: chọn dựa trên requirement gì?
7. Temporal join vào SCD2 dùng điều kiện nào?
8. Nếu job fail sau target write nhưng trước watermark commit thì điều gì xảy ra khi retry?
9. Tại sao overlap window + upsert là một strategy thực dụng?
10. Viết 5 SQL checks bạn muốn chạy trước khi publish Gold table.

---

## 8. Exit criteria

- [ ] Dedup network events bằng rule deterministic.
- [ ] Chứng minh output unique theo business key.
- [ ] Giải thích latest theo event/effective/ingestion time.
- [ ] Thiết kế incremental boundaries + retry strategy.
- [ ] Giải thích watermark miss delete/late update.
- [ ] Mô tả được SCD1/SCD2 và point-in-time join.
- [ ] Viết >=8 data-quality SQL checks.
- [ ] Đạt ít nhất 5/6 MCQ.