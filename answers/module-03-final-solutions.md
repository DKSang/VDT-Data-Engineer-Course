# Module 03 Final Assessment – Suggested Solutions

> Đây là **một reference solution**, không phải implementation duy nhất. Chấm theo contract/correctness/reasoning trước style.

# Phần A – MCQ

1B, 2C, 3B, 4B, 5B, 6B, 7B, 8A, 9B, 10B, 11B, 12B, 13B, 14B, 15A, 16B, 17B, 18B, 19A, 20B.

---

# Phần B – Coding

## B1/B2 – Parser, normalize, validation, quarantine

```python
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


class ValidationError(Exception):
    pass


class DuplicateConflictError(Exception):
    pass


def parse_bool(value) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        normalized = value.strip().lower()
        if normalized == "true":
            return True
        if normalized == "false":
            return False
    raise ValidationError(f"invalid boolean: {value!r}")


def parse_aware_datetime(value: str, field: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (TypeError, ValueError) as exc:
        raise ValidationError(f"{field} is not valid ISO-8601") from exc

    if parsed.tzinfo is None:
        raise ValidationError(f"{field} must include timezone")
    return parsed.astimezone(timezone.utc)


def normalize_event(raw: dict) -> dict:
    """Return canonical event without mutating raw input."""
    try:
        event_id = str(raw["event_id"]).strip()
        version = int(raw["version"])
        cell_id = str(raw["cell_id"]).strip().upper()
        customer_id = int(raw["customer_id"])
        duration_ms = int(raw["duration_ms"])
    except KeyError as exc:
        raise ValidationError(f"missing required field: {exc.args[0]}") from exc
    except (TypeError, ValueError) as exc:
        raise ValidationError("invalid primitive type") from exc

    event_time = parse_aware_datetime(raw["event_time"], "event_time")
    ingested_at = parse_aware_datetime(raw["ingested_at"], "ingested_at")
    dropped = parse_bool(raw["dropped"])

    event = {
        "event_id": event_id,
        "version": version,
        "cell_id": cell_id,
        "customer_id": customer_id,
        "event_time": event_time,
        "ingested_at": ingested_at,
        "duration_ms": duration_ms,
        "dropped": dropped,
    }

    errors = validate_event(event)
    if errors:
        raise ValidationError("; ".join(errors))

    return event


def validate_event(event: dict) -> list[str]:
    errors: list[str] = []

    if not event["event_id"]:
        errors.append("event_id must be non-empty")
    if event["version"] < 1:
        errors.append("version must be >= 1")
    if not event["cell_id"]:
        errors.append("cell_id must be non-empty")
    if event["customer_id"] <= 0:
        errors.append("customer_id must be > 0")
    if event["duration_ms"] < 0:
        errors.append("duration_ms must be >= 0")

    return errors


def iter_jsonl(path):
    path = Path(path)
    with path.open("r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            if not line.strip():
                continue
            try:
                raw = json.loads(line)
            except json.JSONDecodeError as exc:
                yield line_no, None, ValidationError(
                    f"invalid JSON: {exc.msg}"
                ), line.rstrip("\n")
                continue

            yield line_no, raw, None, line.rstrip("\n")


def process_events(path):
    accepted = []
    rejected = []

    for line_no, raw, parse_error, raw_text in iter_jsonl(path):
        if parse_error is not None:
            rejected.append({
                "line_no": line_no,
                "error_type": type(parse_error).__name__,
                "error_message": str(parse_error),
                "raw": raw_text[:500],
            })
            continue

        try:
            event = normalize_event(raw)
        except ValidationError as exc:
            rejected.append({
                "line_no": line_no,
                "error_type": type(exc).__name__,
                "error_message": str(exc),
                "raw": raw_text[:500],
            })
            continue

        accepted.append(event)

    return accepted, rejected
```

### Chấm điểm

Điểm tối đa cần có:

- raw input không mutate;
- bool strict;
- timestamps aware → UTC;
- parse error có line context;
- validation error không silently drop;
- không `except Exception: pass`.

---

## B3 – Deterministic dedup

Ta cần winner independent of input order.

```python
def canonical_payload(event: dict) -> tuple:
    return (
        event["event_id"],
        event["version"],
        event["cell_id"],
        event["customer_id"],
        event["event_time"],
        event["ingested_at"],
        event["duration_ms"],
        event["dropped"],
    )


def deduplicate_events(events):
    winner_by_id = {}

    for event in events:
        key = event["event_id"]
        current = winner_by_id.get(key)

        if current is None:
            winner_by_id[key] = event
            continue

        candidate_rank = (event["version"], event["ingested_at"])
        current_rank = (current["version"], current["ingested_at"])

        if candidate_rank > current_rank:
            winner_by_id[key] = event
        elif candidate_rank < current_rank:
            continue
        else:
            if canonical_payload(event) != canonical_payload(current):
                raise DuplicateConflictError(
                    f"conflicting duplicate for event_id={key}"
                )

    return [winner_by_id[k] for k in sorted(winner_by_id)]
```

Điểm quan trọng:

- business key explicit;
- rank explicit;
- tie conflict explicit;
- output deterministic;
- không phụ thuộc “last row wins” theo input order.

---

## B4 – Cell summary

```python
def summarize_cells(events):
    stats = {}

    for event in events:
        cell_id = event["cell_id"]
        bucket = stats.setdefault(
            cell_id,
            {
                "total_events": 0,
                "dropped_events": 0,
                "duration_sum_ms": 0,
            },
        )

        bucket["total_events"] += 1
        bucket["dropped_events"] += int(event["dropped"])
        bucket["duration_sum_ms"] += event["duration_ms"]

    result = []
    for cell_id in sorted(stats):
        b = stats[cell_id]
        total = b["total_events"]
        result.append({
            "cell_id": cell_id,
            "total_events": total,
            "dropped_events": b["dropped_events"],
            "drop_rate": b["dropped_events"] / total,
            "avg_duration_ms": b["duration_sum_ms"] / total,
        })

    return result
```

Output grain: **1 row / cell_id**.

---

## B5 – Suggested tests

```python
import copy
import pytest
from datetime import datetime, timezone


def test_normalize_does_not_mutate_input():
    raw = {
        "event_id": " e1 ",
        "version": 1,
        "cell_id": " hn-01 ",
        "customer_id": 1,
        "event_time": "2026-08-10T12:00:00+07:00",
        "ingested_at": "2026-08-10T12:00:01+07:00",
        "duration_ms": "10",
        "dropped": "false",
    }
    before = copy.deepcopy(raw)
    normalize_event(raw)
    assert raw == before


def test_negative_duration_rejected():
    raw = {
        "event_id": "e1",
        "version": 1,
        "cell_id": "HN-01",
        "customer_id": 1,
        "event_time": "2026-08-10T12:00:00+07:00",
        "ingested_at": "2026-08-10T12:00:01+07:00",
        "duration_ms": -1,
        "dropped": False,
    }
    with pytest.raises(ValidationError):
        normalize_event(raw)


def test_naive_timestamp_rejected():
    with pytest.raises(ValidationError):
        parse_aware_datetime("2026-08-10T12:00:00", "event_time")


def test_strict_bool():
    assert parse_bool("TRUE") is True
    assert parse_bool("false") is False
    with pytest.raises(ValidationError):
        parse_bool("yes")
```

Các tests khác nên cover:

- version winner;
- ingested_at tie-breaker;
- conflict payload;
- output sorting;
- malformed JSON;
- missing field;
- generator exhausted after consume;
- cell summary expected values.

---

# Phần C – Debugging & Reliability

## C1 – Mutable default

Bug:

```python
def reject(row, errors=[]):
```

Default list được tạo khi function definition chạy và có thể reuse qua calls.

Sửa:

```python
def reject(row, errors=None):
    if errors is None:
        errors = []
    errors.append(row)
    return errors
```

Hoặc tốt hơn trong pipeline: function trả rejection object thay vì quản lý hidden collection state.

---

## C2 – O(n²)

Nested loop scan mỗi event qua toàn bộ customers → O(events * customers) intuition và mutate input event.

Rewrite:

```python
customer_by_id = {
    c["customer_id"]: c
    for c in customers
}

result = []
for event in events:
    customer = customer_by_id.get(event["customer_id"])
    result.append({
        **event,
        "province": None if customer is None else customer["province"],
    })
```

Nếu customer ID phải unique, production code phải validate duplicate trước dict construction.

Complexity intuition: build map O(customers), loop events O(events), thay vì product scan.

---

## C3 – Bad retry

Ít nhất 5 vấn đề:

1. catch `Exception` quá rộng;
2. retry permanent validation/programming errors;
3. fixed delay không backoff/jitter;
4. không log attempts/context;
5. không biết write đã commit trước timeout hay chưa;
6. không idempotency key/upsert policy;
7. sau 10 failures code không rõ có re-raise hay silently continue tùy implementation;
8. retry count hard-coded.

Policy tốt hơn:

```text
classify exception
   ↓
transient only?
   ├── no → fail/quarantine
   └── yes → bounded retry + backoff/jitter
                  ↓
            idempotent write semantics
                  ↓
             final failure → raise + alert/log
```

---

## C4 – Time semantics

Nếu dùng `processed_at=12:10`, event xảy ra 12:00 sẽ bị gán sai sang processing window 12:10 thay vì event window 12:00–12:05. Điều này gây sai historical metric và late-arrival handling.

Rule:

- business/event-time window dùng `event_time`;
- `processed_at` dùng observability/latency/freshness;
- late events cần watermark/reprocessing policy ở streaming module sau.

---

# Phần D – Databricks/Python Boundary

## D1 – Artifact placement

1. `validation.py` → Git folder/workspace source file; ưu tiên source controlled.
2. `test_validation.py` → cùng Git folder/workspace project; Databricks workspace nhận pytest naming conventions.
3. `config.yaml` → source-controlled workspace/Git file nếu không chứa secret; secret phải qua secret/credential mechanism phù hợp.
4. sample CSV 20KB → có thể workspace file cho dev/demo; governed volume cũng được nếu muốn mô phỏng production path.
5. production raw 2TB/day → governed data storage/Unity Catalog Volume hoặc table/object storage pattern phù hợp, **không workspace files**.

Cần nêu workspace files có size/access/executor caveats và source files khác production data storage.

## D2 – Driver vs distributed

`collect()` đưa toàn bộ result từ Spark executors về driver process.

Risk:

- driver memory OOM;
- network transfer lớn;
- mất distributed parallelism khi sau đó loop Python.

High-level rewrite:

```python
result = (
    spark.table("prod.network_events")
         .filter("duration_ms >= 0")
)
```

Sau đó tiếp tục DataFrame transformations/write distributed.

`collect()` có thể chấp nhận khi result **đã được proven/bounded nhỏ**: tiny config/reference result, small aggregate for driver-only use, debugging sample có `limit()` hợp lý.

---

# Phần E – Oral rubric

## 1. Mutability

Đáp án tốt cần nói:

- assignment/reference;
- mutable alias side effects;
- raw record mutation example;
- immutable/value-oriented transform.

## 2. Collections

- list sequence;
- dict keyed lookup;
- set uniqueness/membership;
- O(n) list membership vs avg O(1) hash lookup intuition;
- correctness before optimization.

## 3. Generator

- lazy/one-pass/bounded memory;
- good for line/file streams;
- cannot replace distributed compute/global big joins.

## 4. pandas vs PySpark

- pandas local process memory;
- PySpark distributed Spark abstraction;
- driver conversion risk;
- same business semantics, different execution.

## 5. Retry/idempotency/determinism

- retry repeats operation;
- repeated side effect can duplicate;
- idempotency makes repeat safe;
- deterministic winner/order/state makes outcomes predictable;
- classify transient vs permanent errors.

---

# Grading notes

Không trừ nặng cho syntax nhỏ nếu logic rõ và code gần chạy được. Trừ nặng nếu:

- silently drops invalid rows;
- winner phụ thuộc input order dù đề yêu cầu deterministic;
- uses naive timestamps;
- catches all exceptions without policy;
- mutates input unexpectedly;
- materializes entire arbitrary input unnecessarily;
- treats PySpark DataFrame like pandas/list and calls `collect()` without bounding result.
