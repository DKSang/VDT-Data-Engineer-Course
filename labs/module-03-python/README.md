# Module 03 Lab – Telecom Python ETL

## Mục tiêu

Xây một mini ETL local/bounded bằng Python để luyện **correctness, modularity, validation, testing và reliability** trước khi cùng bài toán được chuyển sang Spark ở Module 09.

## Dataset

```text
data/
├── customers.csv
└── network_events.jsonl
```

Dataset cố tình chứa:

- whitespace/case không đồng nhất;
- duplicate event business key;
- late-arriving event;
- invalid negative duration;
- malformed/empty field;
- timestamp có timezone;
- boolean ở cả string/native form.

## Target structure

Bạn tự hoàn thiện cấu trúc sau:

```text
labs/module-03-python/
├── data/
│   ├── customers.csv
│   └── network_events.jsonl
├── src/
│   └── telecom_etl/
│       ├── __init__.py
│       ├── models.py
│       ├── parsing.py
│       ├── validation.py
│       ├── transforms.py
│       └── pipeline.py
├── tests/
│   ├── test_parsing.py
│   ├── test_validation.py
│   └── test_transforms.py
├── output/                 # local only; do not commit generated large files
├── practice-set.md
└── README.md
```

## Business contract

### Customer

| Field | Type | Rule |
|---|---|---|
| customer_id | int | > 0, unique |
| phone | str | non-empty; do not print full value in logs |
| province | str | non-empty, normalized title/uppercase convention |
| created_at | datetime | timezone-aware |

### Network event

| Field | Type | Rule |
|---|---|---|
| event_id | str | non-empty; source event business ID |
| version | int | >= 1 |
| cell_id | str | normalized uppercase |
| customer_id | int | > 0 |
| event_time | datetime | timezone-aware, normalize UTC |
| ingested_at | datetime | timezone-aware, normalize UTC |
| duration_ms | int | >= 0 |
| dropped | bool | strict boolean semantics |

## Dedup rule

Business key:

```text
event_id
```

Winner:

```text
highest version
then latest ingested_at as deterministic tie-breaker
```

Nếu hai rows có cùng event_id + version + ingested_at nhưng payload khác nhau, pipeline phải coi là data-quality conflict thay vì silently pick một row.

## Required outputs

### 1. `clean_events.jsonl`

Canonical accepted events sau normalize + validate + dedup.

### 2. `rejected_events.jsonl`

Mỗi rejection cần ít nhất:

```text
source
line_no
error_type
error_message
raw_record_or_safe_excerpt
quarantined_at
```

Không log/ghi PII không cần thiết.

### 3. `cell_quality_summary.csv`

Grain: `1 row / cell_id`

Fields:

```text
cell_id
total_events
dropped_events
drop_rate
avg_duration_ms
```

### 4. `run_summary.json`

```json
{
  "input_rows": 0,
  "accepted_before_dedup": 0,
  "accepted_after_dedup": 0,
  "rejected_rows": 0,
  "duplicate_versions_removed": 0
}
```

## Pipeline stages

```text
raw lines
   ↓
parse JSON
   ↓
normalize types/time/string
   ↓
validate contract
   ├── invalid → quarantine
   ↓
accepted records
   ↓
deduplicate by event_id/version/ingested_at
   ↓
write canonical output
   ↓
aggregate quality metrics
```

## Engineering constraints

- Không mutate raw input dictionary trong normalizer.
- File reader phải iterator/generator-based.
- Không dùng `except Exception: pass`.
- I/O và transformation phải tách functions/modules.
- Tests không phụ thuộc real clock.
- Output order phải deterministic để dễ test.
- Không dùng pandas cho core parsing/dedup pipeline; pandas chỉ được dùng optional để verify summary.
- Không dùng PySpark trong Module 03.

## Suggested commands

Local environment example:

```bash
python -m venv .venv
# activate environment theo OS
python -m pip install pytest pandas
pytest -q
```

`pytest` và pandas là dependencies của lab; production packaging/dependency management sẽ học sâu ở module DevOps/production.

## Databricks adaptation exercise

Sau khi local lab pass:

1. Đưa `src/` + `tests/` vào một Databricks Git folder hoặc workspace source structure.
2. Tạo thin notebook import `telecom_etl.pipeline`.
3. Không upload production-size data vào workspace files; sample nhỏ chỉ dùng development/test.
4. Chạy unit tests trong Databricks workspace nếu có environment phù hợp.
5. Viết một đoạn 10–15 câu: phần nào của local pipeline sẽ được thay bằng PySpark DataFrame khi scale tăng và phần nào giữ nguyên semantics.

## Definition of done

- >= 20 tests pass.
- Invalid rows không bị silently drop.
- Dedup deterministic.
- Re-run cùng input tạo cùng canonical outputs.
- Không có mutable global state.
- Có README giải thích design/failure policies.
