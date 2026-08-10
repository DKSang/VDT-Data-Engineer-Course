# Module 03 Final Assessment – Python for Data Engineers

> Không xem `answers/module-03-final-solutions.md` trước khi hoàn thành.

## Điều kiện làm bài

- Thời gian gợi ý: 150 phút.
- Không dùng AI/code generator trong lần làm đầu.
- Có thể dùng Python official docs/Databricks docs để tra API nhỏ, nhưng không copy solution.
- Coding phải có test.
- Mọi transformation phải ghi input/output contract.

---

# Phần A – Fundamentals MCQ (20 điểm)

Mỗi câu 1 điểm.

1. Sau `b = a` với `a` là list: A. deep copy; B. cùng object reference; C. tuple; D. immutable.
2. `is` phù hợp nhất để: A. compare string content; B. compare numeric value; C. check `x is None`; D. sort list.
3. Mutable default argument nguy hiểm vì: A. syntax error; B. object default có thể reuse giữa calls; C. list không append; D. Databricks cấm.
4. Membership repeated trên large collection phù hợp nhất thường: A. list; B. set/dict; C. float; D. generator luôn O(1).
5. Dict comprehension với duplicate key: A. giữ mọi versions tự động; B. value sau có thể overwrite value trước; C. raises luôn; D. tạo list.
6. Pure transformation hữu ích nhất vì: A. không có output; B. dễ test/reason/reuse; C. luôn nhanh hơn Spark; D. không cần validation.
7. Generator: A. materialize toàn bộ ngay; B. produce values theo demand; C. distributed tự động; D. reset tự động.
8. `list(generator)` thường: A. materialize remaining values; B. giữ hoàn toàn lazy; C. tạo Spark DF; D. reset generator.
9. `for line in file` hữu ích cho file lớn vì: A. multi-thread luôn; B. có thể process tuần tự không cần list toàn file; C. file object không iterable; D. tự parse JSON.
10. CSV `DictReader` numeric field trước explicit parse thường là: A. int; B. string; C. Spark Column; D. bool.
11. Timestamp đại diện event thực nên ưu tiên: A. naive datetime; B. timezone-aware/canonical UTC; C. only string without zone; D. local machine time.
12. `except: continue` trong ingestion nguy hiểm vì: A. tạo duplicate; B. silently mất error/data context; C. tăng type safety; D. retry too much.
13. pandas phù hợp nhất mặc định cho: A. 5TB fact join; B. bounded/local dataset; C. Kafka broker; D. distributed shuffle.
14. PySpark DataFrame là: A. Python list; B. distributed dataset abstraction do Spark quản lý; C. pandas alias; D. CSV reader.
15. `collect()` trên large Spark DF có risk: A. kéo dữ liệu về driver; B. auto repartition; C. auto index; D. convert Delta.
16. ValidationError thường nên: A. retry vô hạn; B. quarantine/fail theo policy, không xem là transient; C. sleep 60s rồi retry; D. ignore.
17. Exception chaining dùng `raise X from exc` để: A. xóa cause; B. giữ root cause relation; C. retry; D. serialize JSON.
18. Unit test deterministic nên: A. gọi real clock/network bắt buộc; B. inject/fake dependencies; C. random không seed; D. share global mutable state.
19. Databricks workspace unit test files thường theo convention: A. `test_*.py`/`*_test.py`; B. `.csv`; C. only notebooks; D. `.sql` only.
20. Reusable Python business logic trên Databricks nên ưu tiên khi phù hợp: A. copy vào mọi notebook; B. `.py` modules + imports + tests; C. screenshots; D. global notebook state.

---

# Phần B – Coding (40 điểm)

Dùng dataset `labs/module-03-python/data/network_events.jsonl`.

## B1 – Parser + normalizer (10 điểm)

Viết:

```python
def iter_jsonl(path): ...
def normalize_event(raw: dict) -> dict: ...
```

Requirements:

- generator-based;
- không mutate raw input;
- `cell_id` trim + uppercase;
- `duration_ms` int >= 0;
- strict boolean accepts bool hoặc case-insensitive `true/false`;
- `event_time`, `ingested_at` phải timezone-aware và normalize UTC;
- `version` integer >= 1;
- errors phải có line context.

## B2 – Validation + quarantine (8 điểm)

Viết:

```python
def validate_event(event: dict) -> list[str]: ...
def process_events(path): ...
```

`process_events` trả accepted + rejected cho sample dataset.

Rejected item phải chứa:

```text
line_no
error_type
error_message
safe raw/context
```

Không silently drop.

## B3 – Deterministic dedup (8 điểm)

Business key: `event_id`.

Winner:

1. highest `version`;
2. nếu version tie → latest `ingested_at`;
3. nếu key/version/ingested_at giống nhưng payload khác → raise conflict/data-quality error.

Viết function không phụ thuộc input order.

## B4 – Cell summary (6 điểm)

Từ canonical events sau dedup, output grain `1 row / cell_id`:

```text
cell_id
total_events
dropped_events
drop_rate
avg_duration_ms
```

Output sort deterministic theo `cell_id`.

## B5 – Tests (8 điểm)

Viết tối thiểu 12 tests, bắt buộc có:

- input not mutated;
- invalid negative duration;
- naive timestamp rejected;
- strict boolean;
- duplicate winner deterministic;
- duplicate conflict detected;
- generator one-pass;
- cell summary deterministic.

---

# Phần C – Debugging & Reliability (20 điểm)

Mỗi câu 5 điểm.

## C1 – Mutable state bug

Phân tích và sửa:

```python
def reject(row, errors=[]):
    errors.append(row)
    return errors
```

Giải thích lifecycle của default object.

## C2 – Accidental O(n²)

Phân tích:

```python
for event in events:
    for customer in customers:
        if event["customer_id"] == customer["customer_id"]:
            event["province"] = customer["province"]
```

Rewrite không mutate event và reasoning complexity.

## C3 – Bad retry

```python
for _ in range(10):
    try:
        write_record(record)
        break
    except Exception:
        time.sleep(1)
```

Nêu ít nhất 5 vấn đề và thiết kế retry policy tốt hơn.

## C4 – Time semantics

Một event có:

```text
event_time    = 12:00
processed_at  = 12:10
```

Dashboard cần call-drop rate cho window 12:00–12:05. Nếu dùng processed_at để assign window, bug gì xảy ra? Đề xuất rule.

---

# Phần D – Databricks/Python Boundary (10 điểm)

## D1 – Artifact placement (5 điểm)

Phân loại và giải thích:

1. `validation.py`
2. `test_validation.py`
3. `config.yaml`
4. sample CSV 20KB
5. production raw files 2TB/day

Chọn giữa Git folder/workspace files/governed data storage và nêu caveats.

## D2 – Driver vs distributed (5 điểm)

Phân tích:

```python
rows = spark.table("prod.network_events").collect()
result = []
for row in rows:
    if row.duration_ms >= 0:
        result.append(row)
```

Trả lời:

- code đưa data về đâu?
- tại sao không scale?
- rewrite ở high-level bằng DataFrame API thế nào?
- khi nào `collect()` có thể chấp nhận?

---

# Phần E – VDT-style Oral Interview (10 điểm)

Record câu trả lời 8–10 phút, không nhìn script.

Mỗi câu 2 điểm:

1. Python mutable vs immutable và một pipeline bug thật.
2. List/dict/set trade-offs và complexity intuition.
3. Generator vs list và khi generator không thay được Spark.
4. pandas vs PySpark; driver-memory boundary.
5. Retry, idempotency và deterministic processing liên quan nhau thế nào?

---

# Rubric

| Phần | Điểm |
|---|---:|
| A – MCQ | 20 |
| B – Coding | 40 |
| C – Debugging | 20 |
| D – Databricks boundary | 10 |
| E – Oral | 10 |
| **Tổng** | **100** |

## Pass criteria

- >= 75/100 tổng.
- Coding >= 30/40.
- Không được sai fundamental nghiêm trọng:
  - aliasing/mutable default;
  - generator vs materialization;
  - naive timestamp cho event semantics;
  - silent exception swallowing;
  - pandas/local vs PySpark/distributed boundary;
  - retry mà không reasoning idempotency.
