# Lesson 05 – Files, CSV, JSON, Time & Data Contracts

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Dùng `pathlib` và context manager để thao tác file an toàn.
- Đọc/ghi CSV và JSON/JSONL bằng standard library ở mức production-minded.
- Phân biệt schema parsing với business validation.
- Chuẩn hóa timestamp thành timezone-aware datetime.
- Phân biệt event time, ingestion/processing time trong Python record.
- Thiết kế một data contract đơn giản cho source file.
- Quarantine bad records thay vì silently drop.
- Biết vị trí file phù hợp trên Databricks: workspace files cho code/small dev files, Unity Catalog Volumes/object storage cho data phù hợp hơn.

---

## 2. Source alignment

### Primary Databricks sources

- Work with files on Databricks: https://docs.databricks.com/aws/en/files/
- Workspace files: https://docs.databricks.com/aws/en/files/workspace
- Databricks for Python developers: https://docs.databricks.com/aws/en/languages/python

Databricks hỗ trợ OSS Python file APIs, pandas và Spark với nhiều location; workspace files chủ yếu phù hợp source code/small development files, còn production data thường nên nằm ở governed storage như Unity Catalog Volumes/cloud object storage.

### Supplementary prerequisite

Python Standard Library:

- `pathlib`: https://docs.python.org/3/library/pathlib.html
- `csv`: https://docs.python.org/3/library/csv.html
- `json`: https://docs.python.org/3/library/json.html
- `datetime`: https://docs.python.org/3/library/datetime.html

### Scope note

Bài này dùng local files để học semantics. Module 11 sẽ học ingestion patterns và Databricks-native ingestion sâu hơn.

---

## 3. Principles

### Principle 1 – File format không tự bảo đảm schema

CSV/JSON có thể parse được nhưng vẫn sai:

```text
customer_id = "abc"
amount = -100
observed_at = "tomorrow"
```

Pipeline cần phân lớp:

```text
bytes/text
   ↓ parse syntax
Python values
   ↓ normalize types
canonical record
   ↓ validate contract/business rules
accepted / quarantined
```

### Principle 2 – Timezone là data semantics

Timestamp không timezone dễ gây bug khi source ở nhiều vùng hoặc daylight-saving context.

Đối với event timestamp dùng để correlate/aggregate, ưu tiên canonical UTC internally, giữ timezone/source metadata nếu cần audit.

### Principle 3 – Bad data phải trace được

Không làm:

```python
try:
    ...
except:
    continue
```

vì bạn mất:

- raw row;
- line number;
- error reason;
- source.

Quarantine tốt cần context.

### Principle 4 – Data location phải phù hợp workload

Databricks workspace files rất tiện cho source code và small development files, nhưng không phải mặc định cho distributed production data. Chọn location theo size, governance, executor access và lifecycle.

---

## 4. Fundamentals

### 4.1 `pathlib.Path`

```python
from pathlib import Path

input_path = Path("data") / "network_events.jsonl"
```

Lợi ích:

- code portable hơn nối string path thủ công;
- API rõ cho exists/is_file/mkdir/glob/read_text.

### 4.2 Context manager

```python
with input_path.open("r", encoding="utf-8") as f:
    for line in f:
        ...
```

Context manager bảo đảm resource cleanup kể cả khi exception xảy ra.

### 4.3 Encoding

Luôn explicit khi text semantics quan trọng:

```python
open(path, encoding="utf-8")
```

Không dựa vào machine default nếu pipeline cần reproducible behavior.

### 4.4 CSV

```python
import csv

with open("customers.csv", newline="", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        ...
```

CSV reader trả string values. Bạn phải parse type.

Ví dụ:

```python
customer_id = int(row["customer_id"])
```

### 4.5 CSV caveats

- delimiter/quote/escape;
- header drift;
- empty string vs NULL;
- numeric/date type không native;
- newline;
- duplicate headers;
- embedded commas/newlines.

CSV “simple” cho tới khi source không còn simple.

### 4.6 JSON vs JSONL

JSON document:

```json
[
  {"event_id": "e1"},
  {"event_id": "e2"}
]
```

JSONL/NDJSON:

```text
{"event_id":"e1"}
{"event_id":"e2"}
```

JSONL phù hợp line-oriented streaming/batch append hơn vì có thể parse record-by-record.

### 4.7 Parsing JSONL với line context

```python
import json


def iter_jsonl(path):
    with open(path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            try:
                yield line_no, json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"invalid JSON at line {line_no}"
                ) from exc
```

Trong pipeline fault-tolerant hơn, có thể yield rejection object thay vì stop toàn job, tùy strictness/SLA.

### 4.8 Schema contract đơn giản

Ta không cần framework để hiểu data contract.

```python
REQUIRED_FIELDS = {
    "event_id",
    "cell_id",
    "event_time",
    "duration_ms",
}
```

Validate presence:

```python
missing = REQUIRED_FIELDS - record.keys()
if missing:
    raise ValueError(f"missing fields: {sorted(missing)}")
```

Nhưng contract còn gồm:

- type;
- nullability;
- range;
- semantics/unit;
- key uniqueness;
- timestamp timezone;
- schema version.

### 4.9 Parse vs validate

```python
duration_ms = int(record["duration_ms"])
```

parse type.

```python
if duration_ms < 0:
    raise ValueError("duration_ms must be >= 0")
```

business/domain validation.

Tách hai bước giúp error message chính xác.

### 4.10 Datetime

```python
from datetime import datetime, timezone

dt = datetime.fromisoformat("2026-08-10T12:30:00+00:00")
```

Check aware:

```python
if dt.tzinfo is None:
    raise ValueError("timestamp must include timezone")
```

Convert UTC:

```python
canonical = dt.astimezone(timezone.utc)
```

### 4.11 Event time vs processed_at

Record có thể giữ cả:

```python
{
    "event_time": "2026-08-10T12:00:00Z",
    "processed_at": "2026-08-10T12:03:15Z"
}
```

Không dùng `processed_at` để tính network event theo window nghiệp vụ nếu metric phải phản ánh thời điểm event xảy ra.

### 4.12 Quarantine record

```python
{
    "source": "network_events.jsonl",
    "line_no": 42,
    "raw": "{...}",
    "error_type": "ValidationError",
    "error_message": "duration_ms must be >= 0",
    "quarantined_at": "..."
}
```

Không nhất thiết log toàn PII/raw payload nếu data nhạy cảm; security policy vẫn áp dụng.

### 4.13 Atomic write intuition

Không nên ghi trực tiếp final file nếu process có thể fail giữa chừng.

Pattern local đơn giản:

```text
write temp
   ↓ fsync/close
rename/replace final
```

Trong distributed lakehouse, transaction semantics do storage/table layer giải quyết khác; Module 10 học Delta Lake.

### 4.14 File locations trên Databricks

Mental model:

```text
Workspace files
  → source code, notebooks, YAML, small dev/test files

Unity Catalog Volumes / cloud object storage
  → governed data/files cho workloads phù hợp

Driver ephemeral storage
  → temporary local processing, không coi là durable data store
```

Không hard-code `/dbfs/...` như universal best practice. Databricks file guidance hiện phân biệt nhiều storage locations và access methods.

---

## 5. Worked example – Validate telecom JSONL

### Contract

```text
event_id      required string non-empty
cell_id       required string non-empty
event_time    required ISO8601 timezone-aware
duration_ms   integer >= 0
dropped       boolean
```

### Parser

```python
from datetime import datetime, timezone


def parse_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized == "true":
            return True
        if normalized == "false":
            return False
    raise ValueError(f"invalid boolean: {value!r}")


def normalize_event(raw):
    event_time = datetime.fromisoformat(
        raw["event_time"].replace("Z", "+00:00")
    )
    if event_time.tzinfo is None:
        raise ValueError("event_time must include timezone")

    duration_ms = int(raw["duration_ms"])
    if duration_ms < 0:
        raise ValueError("duration_ms must be >= 0")

    return {
        "event_id": str(raw["event_id"]).strip(),
        "cell_id": str(raw["cell_id"]).strip().upper(),
        "event_time": event_time.astimezone(timezone.utc),
        "duration_ms": duration_ms,
        "dropped": parse_bool(raw["dropped"]),
    }
```

### Acceptance rule

Không `except: continue`. Thay vào đó thu rejection với reason.

---

## 6. Hands-on lab

### A – CSV loader

Đọc `customers.csv` và output canonical records:

```python
{
    "customer_id": int,
    "province": str,
    "created_at": datetime
}
```

Yêu cầu:

- timezone-aware;
- duplicate customer ID phải bị phát hiện;
- empty province → quarantine.

### B – JSONL validator

Viết:

```python
def process_jsonl(path):
    ...
```

Output hai iterables/list nhỏ cho sample lab:

```text
accepted
rejected
```

Rejected record phải có line number và reason.

### C – Contract document

Tạo `contracts/network_event_contract.md` gồm:

- fields;
- types;
- nullability;
- unit;
- key;
- event-time semantics;
- accepted enum/range;
- schema version.

### D – Databricks mapping

Viết 10 câu trả lời:

1. file source code nên nằm đâu?
2. sample 10KB CSV cho demo có thể ở đâu?
3. production raw files 500GB/day nên tránh workspace files vì sao?
4. distributed executors cần access data location như thế nào?

---

## 7. Knowledge check – MCQ

**Q1.** CSV parser thường trả numeric field dưới dạng gì trước khi explicit convert?

A. int luôn  
B. string  
C. Spark Column  
D. tuple bắt buộc

**Q2.** Vì sao timezone-aware timestamp quan trọng?

A. Để string dài hơn.  
B. Để thời điểm có offset/zone semantics rõ và normalize được nhất quán.  
C. Vì UTC luôn local time.  
D. Vì datetime naive không thể print.

**Q3.** `except: continue` trong ingestion nguy hiểm nhất vì:

A. làm file lớn hơn.  
B. silently mất record/error context.  
C. JSON tự chuyển XML.  
D. tăng uniqueness.

**Q4.** Workspace files trên Databricks phù hợp nhất mặc định cho:

A. production raw dataset hàng TB.  
B. source code/notebooks/small dev files.  
C. Kafka broker storage.  
D. HDFS NameNode.

**Q5.** Parse `"-10"` thành integer thành công có nghĩa record valid?

A. Có.  
B. Không; type parse đúng nhưng domain rule có thể cấm số âm.  
C. Có nếu JSON.  
D. Chỉ khi dùng pandas.

---

## 8. Tự luận / Interview

1. JSON và JSONL khác nhau thế nào cho ingestion?
2. Parse validation và business validation khác nhau ra sao?
3. Event time vs processing time dùng vào metric thế nào?
4. Quarantine record cần metadata gì?
5. Vì sao workspace files không phải nơi mặc định cho production data lớn?
6. Bạn thiết kế data contract cho network event gồm những field/property nào?

---

## 9. Exit criteria

- [ ] CSV loader parse type/time đúng.
- [ ] Duplicate business key bị phát hiện.
- [ ] JSONL validator có quarantine context.
- [ ] Viết data contract riêng.
- [ ] Giải thích được Databricks file-location trade-off.
- [ ] Đạt ít nhất 4/5 MCQ.
