# Lesson 07 – Exceptions, Logging, Testing & Reliable Scripts

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Phân biệt syntax error, runtime exception, validation error và transient failure ở mức thiết kế pipeline.
- Dùng `try/except/else/finally` có chủ đích và catch exception cụ thể.
- Thiết kế retry boundary thay vì retry mọi lỗi.
- Dùng exception chaining để giữ root cause.
- Ghi log có context nhưng tránh secret/PII.
- Tách transformation logic để unit test dễ dàng.
- Viết `pytest`-style tests cho parser/normalizer/validator.
- Hiểu cách Databricks workspace phát hiện và chạy Python unit tests.
- Giải thích idempotency và deterministic output ở mức Python script.

---

## 2. Source alignment

### Primary Databricks sources

- Python unit testing in the workspace: https://docs.databricks.com/aws/en/files/python-unit-tests
- Test Databricks notebooks: https://docs.databricks.com/aws/en/notebooks/test-notebooks
- Databricks for Python developers: https://docs.databricks.com/aws/en/languages/python
- Work with Python modules: https://docs.databricks.com/aws/en/files/workspace-modules

Databricks workspace hiện hỗ trợ discovery/run/track Python unit tests theo pytest naming conventions như `test_*.py` và `*_test.py`. Databricks cũng khuyến nghị reusable functions/tests tách khỏi notebooks khi phù hợp.

### Supplementary prerequisite

- Python Errors and Exceptions: https://docs.python.org/3/tutorial/errors.html
- Python logging: https://docs.python.org/3/library/logging.html
- Python unittest: https://docs.python.org/3/library/unittest.html

---

## 3. Principles

### Principle 1 – Catch only what you can handle

Bad pattern:

```python
try:
    process(row)
except Exception:
    pass
```

Đây không phải fault tolerance. Đây là mất observability.

Catch exception khi bạn có policy rõ:

```text
retry?
quarantine?
convert exception?
cleanup?
abort?
```

### Principle 2 – Permanent error khác transient error

Ví dụ:

```text
invalid duration = -20
```

retry 10 lần không làm record đúng hơn.

Ngược lại:

```text
remote service timeout
```

có thể transient và retry có backoff hợp lý.

### Principle 3 – Test business semantics trước integration

Transformation nhỏ:

```python
normalize_event(raw) -> normalized
```

phải test không cần cluster, database hay network.

Sau đó mới integration-test boundary.

### Principle 4 – Logs phải giúp reconstruct failure

Một log hữu ích trả lời:

- pipeline/job nào?
- source nào?
- batch/run ID?
- record/key nào nếu an toàn?
- stage nào?
- error type?
- retry attempt?

Nhưng không log access token, password, full PII payload vô nguyên tắc.

### Principle 5 – Retry safe cần idempotency

Nếu write đã commit nhưng client timeout trước khi nhận ACK, retry có thể duplicate. Reliable script cần nghĩ tới idempotency key/upsert/checkpoint/transaction boundary, không chỉ `for attempt in range(3)`.

---

## 4. Fundamentals

### 4.1 Exception hierarchy intuition

Không cần thuộc toàn bộ hierarchy. Cần nhận biết nhóm thường gặp:

- `ValueError`: value parse/domain không hợp lệ;
- `TypeError`: operation/type misuse;
- `KeyError`: required mapping key thiếu;
- `FileNotFoundError` / `OSError`: filesystem;
- `json.JSONDecodeError`: malformed JSON;
- custom exceptions cho domain/pipeline boundary.

### 4.2 Catch specific exception

```python
try:
    duration_ms = int(raw["duration_ms"])
except (KeyError, ValueError) as exc:
    raise ValidationError("invalid duration_ms") from exc
```

Ta chuyển low-level error thành domain-level error nhưng vẫn giữ cause chain.

### 4.3 Exception chaining

```python
raise ValidationError("invalid event") from exc
```

giữ root cause trong traceback.

Rất hữu ích khi pipeline có nhiều abstraction layer.

### 4.4 `else`

```python
try:
    value = parse(raw)
except ValueError:
    quarantine(raw)
else:
    write(value)
```

`else` giúp tránh catch nhầm exception từ `write()` nếu mục tiêu try chỉ là parse.

### 4.5 `finally`

Cleanup action cần chạy dù success/failure:

```python
resource = acquire()
try:
    ...
finally:
    resource.close()
```

Với file, context manager thường tốt hơn.

### 4.6 Custom exceptions

```python
class PipelineError(Exception):
    pass

class ValidationError(PipelineError):
    pass

class TransientSourceError(PipelineError):
    pass
```

Không cần tạo hàng chục class. Mục tiêu là policy differentiation.

### 4.7 Retry boundary

Pseudo-code:

```python
def call_with_retry(operation, *, max_attempts=3):
    for attempt in range(1, max_attempts + 1):
        try:
            return operation()
        except TransientSourceError:
            if attempt == max_attempts:
                raise
            sleep(backoff(attempt))
```

Không retry `ValidationError`.

### 4.8 Exponential backoff intuition

Retry ngay lập tức hàng nghìn clients có thể tạo retry storm.

Backoff tăng dần + jitter thường dùng cho transient remote failures.

Implementation chi tiết phụ thuộc service/library; principle là giảm synchronized pressure.

### 4.9 Logging

```python
import logging

logger = logging.getLogger(__name__)
```

Log structured context ở mức tối thiểu:

```python
logger.info(
    "processed batch",
    extra={
        "source": "network_events",
        "accepted": accepted_count,
        "rejected": rejected_count,
    },
)
```

Tùy logging stack, structured formatting có thể dùng JSON handler/logger adapter.

### 4.10 Log levels

- DEBUG – detailed diagnostics;
- INFO – normal lifecycle milestone;
- WARNING – abnormal nhưng recoverable;
- ERROR – operation failed;
- CRITICAL – severe system-level failure.

Không biến mọi row invalid thành ERROR nếu invalid rows là expected quarantine flow; có thể aggregate metrics + sample warnings.

### 4.11 Unit test anatomy

```python
def test_normalize_cell_id():
    assert normalize_cell_id(" hn-01 ") == "HN-01"
```

### 4.12 Test happy + edge + failure

Cho `parse_bool()`:

```text
"true"  -> True
"FALSE" -> False
"yes"   -> raises ValueError
None     -> raises ValueError
```

### 4.13 Test exceptions

Pytest style:

```python
import pytest

with pytest.raises(ValueError):
    normalize_duration("-1")
```

### 4.14 Deterministic tests

Không gọi real clock/network/random nếu test semantics không cần.

Inject:

- fixed clock;
- fake source;
- temp path;
- seeded random.

### 4.15 Tests on Databricks

Databricks workspace hỗ trợ test files theo pytest naming convention và UI để run/track tests. Reusable Python functions có thể để trong source file cùng Git folder/workspace files, rồi test riêng.

Mental model:

```text
notebook
  → orchestration / exploration / demo

.py modules
  → reusable business logic

test_*.py
  → unit tests
```

### 4.16 Idempotent script

Một batch script chạy lại cùng input nên có outcome predictable.

Non-idempotent example:

```python
output.append(records)
```

mỗi retry thêm duplicate.

Possible policies:

- deterministic overwrite partition;
- upsert by key;
- write temp + atomic replace;
- checkpoint committed batch IDs.

Chi tiết distributed/table idempotency học ở modules ingestion/Delta.

---

## 5. Worked example – Reliable event normalization

```python
class ValidationError(Exception):
    pass


def normalize_event(raw):
    try:
        duration = int(raw["duration_ms"])
    except KeyError as exc:
        raise ValidationError("missing duration_ms") from exc
    except ValueError as exc:
        raise ValidationError("duration_ms is not an integer") from exc

    if duration < 0:
        raise ValidationError("duration_ms must be >= 0")

    return {
        **raw,
        "duration_ms": duration,
        "cell_id": raw["cell_id"].strip().upper(),
    }
```

Process loop:

```python
for line_no, raw in source:
    try:
        event = normalize_event(raw)
    except ValidationError as exc:
        rejects.write({
            "line_no": line_no,
            "reason": str(exc),
        })
        continue

    sink.write(event)
```

Không catch sink failure như validation failure. Boundary rõ giúp policy đúng.

---

## 6. Hands-on lab

### A – Exception taxonomy

Tạo:

```python
class PipelineError(Exception): ...
class ValidationError(PipelineError): ...
class SourceUnavailableError(PipelineError): ...
class SinkWriteError(PipelineError): ...
```

Viết bảng policy:

| Error | Retry? | Quarantine? | Abort batch? |
|---|---|---|---|

### B – Unit tests

Viết ít nhất 12 tests:

- 5 happy/normalization;
- 4 invalid input;
- 2 immutability/no input mutation;
- 1 deterministic output ordering.

### C – Fake transient source

Viết fake callable fail 2 lần rồi success. Implement retry max 3 attempts.

Test:

- succeeds on third attempt;
- max 2 attempts → raises;
- ValidationError không retry.

Không cần sleep thật trong unit test; inject sleeper.

### D – Logging review

Cho log sau:

```text
ERROR failed request token=abc123 customer_phone=090...
```

Viết lại logging policy an toàn hơn và nêu field nào không nên log.

### E – Databricks test layout

Tạo folder:

```text
src/telecom_etl/
  normalization.py
  validation.py

tests/
  test_normalization.py
  test_validation.py
```

Tuân theo pytest naming convention Databricks workspace nhận diện.

---

## 7. Knowledge check – MCQ

**Q1.** Invalid business record `duration_ms=-1` nên:

A. retry vô hạn.  
B. thường validation/quarantine theo policy, không coi là transient.  
C. restart cluster.  
D. convert thành 1 tự động.

**Q2.** `raise NewError(...) from exc` dùng để:

A. xóa root cause.  
B. giữ exception chain/cause khi chuyển abstraction.  
C. retry tự động.  
D. log secret.

**Q3.** Vì sao catch `Exception` quá rộng thường có hại?

A. Python không hỗ trợ.  
B. Có thể nuốt programming/system failures không thuộc policy đang xử lý.  
C. Làm tuple immutable.  
D. Không chạy trong Databricks.

**Q4.** Databricks workspace test discovery dùng naming convention gần:

A. `test_*.py` / `*_test.py`.  
B. chỉ `.sql`.  
C. chỉ notebook tên Test.  
D. `.csv`.

**Q5.** Retry safe cần suy nghĩ thêm về:

A. idempotency/duplicate side effects.  
B. font size.  
C. list sorting duy nhất.  
D. notebook title.

---

## 8. Tự luận / Interview

1. Permanent vs transient error khác nhau thế nào?
2. Khi nào retry có thể làm tình hình tệ hơn?
3. Exception chaining hữu ích ra sao?
4. Vì sao test pure transformation trước integration?
5. Log context nào cần cho pipeline failure? Context nào không nên log?
6. Idempotency liên quan retry như thế nào?
7. Vì sao Databricks recommendation tách reusable functions/tests khỏi notebook hợp với software engineering principle?

---

## 9. Exit criteria

- [ ] Có exception taxonomy + policy table.
- [ ] >= 12 unit tests.
- [ ] Retry test không sleep thật.
- [ ] Validation error không retry.
- [ ] Logging policy không lộ secret/PII.
- [ ] Tests tuân pytest naming convention.
- [ ] Đạt ít nhất 4/5 MCQ.
