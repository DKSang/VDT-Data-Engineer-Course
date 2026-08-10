# Module 03 – Python Practice Set

> Không xem answer key trước khi hoàn thành. Mỗi bài phải ghi **input contract, output contract, failure behavior** trước khi code.

## Level 1 – Core Python semantics

### 1. Mutation prediction
Cho 5 đoạn code có list/dict alias. Dự đoán output trước khi chạy và giải thích object sharing.

### 2. Safe copy
Viết `mask_customer(record)` trả record mới, không mutate input, kể cả nested `contact` dictionary.

### 3. Mutable default bug
Sửa function `collect(error, errors=[])` và viết test chứng minh bug cũ.

### 4. Truthiness
Viết validator phân biệt `None`, `0`, `""`, `False` cho metric `dropped_count`.

### 5. Required vs optional field
Viết `get_required(record, key)` và `get_optional(record, key, default=None)`; giải thích vì sao không dùng `.get()` cho mọi field.

## Level 2 – Collections & complexity

### 6. Preserve-order dedup
Dedup list event IDs nhưng giữ first-seen order.

### 7. Duplicate-key-safe dict
Build `customer_by_id`; raise nếu duplicate ID.

### 8. Nested-loop refactor
Cho events + towers; refactor O(n*m) scan thành lookup dict.

### 9. Group metrics
Tính `total`, `dropped`, `drop_rate` theo cell bằng dict aggregation.

### 10. Composite key
Dùng tuple `(customer_id, date)` làm key để aggregate daily event counts.

## Level 3 – Functions & modules

### 11. Function contract
Viết `normalize_phone()` với docstring, type hint, ValueError rule.

### 12. Pure transform
Refactor function đang mutate input thành pure-ish function trả object mới.

### 13. Module split
Tách script 100 lines thành `parsing`, `validation`, `transforms`, `pipeline`.

### 14. Frozen config
Tạo immutable `PipelineConfig` dataclass và test mutation bị chặn.

### 15. Inject clock
Viết function thêm `processed_at` bằng injected `now_fn`, không gọi clock trực tiếp trong logic test.

## Level 4 – Iterators & generators

### 16. JSONL generator
Viết `iter_jsonl(path)` trả `(line_no, record)`.

### 17. Generator composition
Compose `iter_jsonl → normalize → validate → batch` mà không materialize toàn dataset.

### 18. One-pass demonstration
Viết test chứng minh generator exhausted sau lần consume đầu.

### 19. Batching
Viết generator chia input thành batches size N, xử lý final partial batch.

### 20. Memory discussion
So sánh `readlines()` với line iterator cho file 20GB trong 10 câu.

## Level 5 – Files & time

### 21. Customer CSV
Parse `customers.csv`; enforce positive unique ID, non-empty province, aware timestamp.

### 22. Event normalizer
Parse `network_events.jsonl` thành canonical types; normalize `cell_id`, UTC time, bool.

### 23. Quarantine
Bad row phải tạo rejection object với line/source/error/context.

### 24. Late-arrival report
Tính `ingestion_delay_seconds = ingested_at - event_time`; report rows delay > 5 minutes.

### 25. Contract validator
Viết validator required fields + nullability + range cho network event.

## Level 6 – pandas boundary

### 26. pandas quality profile
Load sample data bằng pandas; report shape, dtypes, nulls, duplicate IDs.

### 27. Cell summary
Tạo `cell_id,total_events,dropped_events,drop_rate,avg_duration_ms`.

### 28. pandas vs Python
Implement cùng summary bằng pure Python và pandas; assert same business results.

### 29. Scale decision
Viết memo chọn pandas/PySpark cho 50MB, 30GB/day và 5TB historical data.

### 30. Driver-risk review
Giải thích risk của `spark.table(...).collect()` rồi loop Python, và đề xuất distributed rewrite ở mức high-level.

## Bonus – Reliability/interview

### B1. Exception taxonomy
Phân loại `ValidationError`, source timeout, disk-full, malformed JSON, programming bug thành retry/quarantine/abort.

### B2. Fake retry
Fake source fail 2 lần rồi success; test retry không sleep thật.

### B3. Idempotency
Thiết kế output strategy để chạy cùng input 2 lần không duplicate canonical result.

### B4. Conflict dedup
Hai rows cùng `event_id/version/ingested_at` nhưng payload khác nhau: xử lý thế nào và vì sao?

### B5. 5-minute oral defense
Không nhìn note, trả lời:

1. mutable vs immutable;
2. list/dict/set trade-off;
3. generator vs list;
4. event time vs processing time;
5. pandas vs PySpark;
6. retry vs idempotency;
7. notebook vs module.
