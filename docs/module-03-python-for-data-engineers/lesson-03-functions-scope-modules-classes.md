# Lesson 03 – Functions, Scope, Modules & Classes

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Viết function nhỏ với contract rõ: input, output, side effect, failure.
- Giải thích positional/keyword/default arguments ở mức thực dụng.
- Tránh mutable default arguments và hidden global state.
- Hiểu local/enclosing/global/built-in scope ở mức cần thiết.
- Tách reusable logic khỏi notebook/script thành `.py` module.
- Biết khi nào dùng function, dataclass/class và khi nào không cần OOP.
- Thiết kế code dễ unit test trước khi chạy trên Databricks.

---

## 2. Source alignment

### Primary Databricks sources

Databricks Academy – Introduction to Python for Data Science and Data Engineering:

- functions;
- classes;
- libraries.

https://customer-academy.databricks.com/learn/courses/969/introduction-to-python-for-data-science-and-data-engineering

Databricks Documentation – Python modules / workspace files:

- https://docs.databricks.com/aws/en/files/workspace-modules
- https://docs.databricks.com/aws/en/files/workspace
- https://docs.databricks.com/aws/en/notebooks/share-code

Databricks khuyến khích modularize code thành Python files và import thay vì phụ thuộc vào notebook-to-notebook `%run` cho reusable logic.

### Supplementary prerequisite

Python Tutorial:

- https://docs.python.org/3/tutorial/controlflow.html#defining-functions
- https://docs.python.org/3/tutorial/modules.html
- https://docs.python.org/3/tutorial/classes.html

---

## 3. Principles

### Principle 1 – Function là unit nhỏ nhất của reasoning/test

Một function tốt trả lời được:

```text
Input?
Output?
Side effects?
Failure conditions?
```

Nếu không thể mô tả contract trong vài câu, function có thể đang làm quá nhiều việc.

### Principle 2 – Tách pure transformation khỏi I/O

Khó test:

```text
read file → parse → validate → call API → log → write DB
```

trong một function.

Dễ test hơn:

```text
read_records()       # I/O
parse_record()       # pure-ish
validate_record()    # pure
transform_record()   # pure
write_records()      # I/O
```

### Principle 3 – Notebook không phải nơi chứa toàn bộ business logic

Notebook thuận tiện cho interactive development, nhưng reusable logic nên sống trong source files/modules khi code bắt đầu trưởng thành. Databricks workspace files và Git folders hỗ trợ pattern này.

### Principle 4 – OOP chỉ dùng khi state/behavior thật sự cần được đóng gói

Data Engineer fresher thường cần function + simple data structures nhiều hơn hierarchy class phức tạp.

Class nên giải quyết vấn đề cụ thể, không phải để “code trông enterprise”.

---

## 4. Fundamentals

### 4.1 Function contract

Ví dụ:

```python
def normalize_msisdn(value: str) -> str:
    """Normalize Vietnamese mobile number to a canonical local form."""
    cleaned = value.strip().replace(" ", "")
    if not cleaned:
        raise ValueError("msisdn is empty")
    return cleaned
```

Contract cần nói rõ:

- input type/kỳ vọng;
- output semantics;
- invalid input xử lý thế nào.

Type hints giúp communication/tooling; chúng không tự validate runtime data.

### 4.2 Return value vs side effect

Pure-ish:

```python
def net_amount(amount: float, tax_rate: float) -> float:
    return amount * (1 - tax_rate)
```

Side-effecting:

```python
def append_error(path, message):
    with open(path, "a") as f:
        f.write(message)
```

Side effect không xấu, nhưng phải đặt boundary rõ vì khó retry/test hơn.

### 4.3 Positional và keyword arguments

```python
def build_key(customer_id: int, event_date: str, *, source: str) -> str:
    return f"{source}:{customer_id}:{event_date}"
```

`source` keyword-only giúp call site rõ:

```python
build_key(1001, "2026-08-10", source="network")
```

Không cần lạm dụng advanced parameter syntax, nhưng keyword arguments rất hữu ích khi function có nhiều boolean/config parameters.

### 4.4 Default argument

Default immutable:

```python
def parse_amount(value: str, currency: str = "VND"):
    ...
```

Với collection optional:

```python
def validate(record, rules=None):
    if rules is None:
        rules = []
```

### 4.5 Scope – LEGB intuition

Python resolve name theo:

```text
Local → Enclosing → Global → Built-in
```

Tránh global mutable state kiểu:

```python
REJECTED = []

def validate(row):
    if ...:
        REJECTED.append(row)
```

Vì:

- test phụ thuộc execution order;
- notebook re-run cell có thể giữ state khó đoán;
- concurrent/retry behavior không rõ.

Tốt hơn trả kết quả hoặc inject dependency/state rõ.

### 4.6 First-class functions ở mức DE

Function có thể truyền như object:

```python
def apply_rules(record, rules):
    return [rule(record) for rule in rules]
```

Pattern này giúp xây validation pipeline nhỏ mà không cần class hierarchy.

### 4.7 Modules

`telecom/normalization.py`

```python
def normalize_cell_id(value: str) -> str:
    return value.strip().upper()
```

`pipeline.py`

```python
from telecom.normalization import normalize_cell_id
```

Lợi ích:

- reuse;
- test độc lập;
- review diff dễ hơn;
- notebook nhỏ hơn;
- chuẩn bị tốt cho job/pipeline deployment.

### 4.8 `if __name__ == "__main__"`

```python
def main():
    ...

if __name__ == "__main__":
    main()
```

Giúp file vừa import được như module, vừa chạy như script.

### 4.9 Package

Một cấu trúc đơn giản:

```text
src/
  telecom_etl/
    __init__.py
    parsing.py
    validation.py
    transforms.py
  main.py

tests/
  test_parsing.py
  test_validation.py
```

Không cần packaging phức tạp ở fresher level, nhưng phải hiểu separation.

### 4.10 Class

Dùng class khi object có state + behavior liên quan.

```python
class Watermark:
    def __init__(self, value):
        self.value = value

    def advance(self, new_value):
        if new_value < self.value:
            raise ValueError("watermark cannot move backward")
        self.value = new_value
```

Nhưng một record đơn giản không nhất thiết phải thành class.

### 4.11 Dataclass

Cho config/typed record local, `dataclass` giúp giảm boilerplate:

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class PipelineConfig:
    source: str
    batch_size: int
    strict: bool = True
```

`frozen=True` tạo contract gần immutable, hữu ích cho configuration.

### 4.12 Dependency injection ở mức đơn giản

Thay vì function tự gọi clock/API/global logger, truyền dependency:

```python
def process(record, now_fn):
    return {
        **record,
        "processed_at": now_fn(),
    }
```

Test có thể truyền deterministic clock.

---

## 5. Worked example – Refactor một notebook-style ETL

### Trước

```python
errors = []

with open("events.jsonl") as f:
    for line in f:
        row = json.loads(line)
        row["cell_id"] = row["cell_id"].upper()
        if row["duration_ms"] < 0:
            errors.append(row)
        else:
            # write somewhere
            pass
```

Vấn đề:

- I/O + parse + normalize + validate + write lẫn nhau;
- global state;
- khó test transformation;
- không có contract.

### Sau

```python
def parse_event(line: str) -> dict:
    return json.loads(line)


def normalize_event(row: dict) -> dict:
    return {
        **row,
        "cell_id": row["cell_id"].strip().upper(),
        "duration_ms": int(row["duration_ms"]),
    }


def validate_event(row: dict) -> list[str]:
    errors = []
    if row["duration_ms"] < 0:
        errors.append("duration_ms must be non-negative")
    return errors
```

Giờ mỗi function có thể test độc lập.

---

## 6. Hands-on lab

### A – Refactor

Cho một script 50–80 dòng tự viết đọc CSV, normalize và aggregate. Refactor thành tối thiểu:

```text
read_*
parse_*
normalize_*
validate_*
aggregate_*
main
```

### B – Module layout

Tạo:

```text
lesson03/
  telecom_etl/
    __init__.py
    normalization.py
    validation.py
  main.py
```

`main.py` phải import function từ module, không copy code.

### C – Config dataclass

Tạo:

```python
@dataclass(frozen=True)
class PipelineConfig:
    input_path: str
    reject_path: str
    strict: bool = True
```

Giải thích vì sao config immutable có lợi.

### D – Unit-testable clock

Viết function add `processed_at` nhận `now_fn` dependency. Test bằng lambda trả fixed datetime.

---

## 7. Knowledge check – MCQ

**Q1.** Lợi ích lớn nhất của tách pure transformation khỏi I/O?

A. Làm code dài hơn.  
B. Dễ test/reuse/reasoning hơn.  
C. Python chạy distributed tự động.  
D. Không cần exceptions.

**Q2.** Global mutable state trong notebook có risk gì?

A. Không thể tạo list.  
B. Re-run/execution order có thể làm state khó đoán và test phụ thuộc nhau.  
C. Python cấm global.  
D. Luôn thread-safe.

**Q3.** Databricks workspace modules hữu ích vì:

A. Cho phép modularize Python source và import reusable code.  
B. Thay thế Spark.  
C. Tạo index PostgreSQL.  
D. Không cần Git.

**Q4.** Class nên dùng khi:

A. Mọi dictionary phải đổi thành class.  
B. Có state/behavior cần đóng gói rõ hoặc abstraction mang giá trị.  
C. Muốn code dài hơn.  
D. Function bị cấm.

**Q5.** Type hint `x: int` nghĩa là:

A. Python tự động reject mọi non-int ở runtime trong mọi trường hợp.  
B. Là annotation phục vụ communication/tooling; không thay thế runtime validation.  
C. x trở thành immutable.  
D. x luôn non-null.

---

## 8. Tự luận / Interview

1. Pure function là gì và tại sao hữu ích cho DE?
2. Tại sao notebook monolith khó test/deploy?
3. Khi nào bạn chọn class thay vì function?
4. Type hints khác runtime validation thế nào?
5. Dependency injection đơn giản giúp test time/API logic thế nào?
6. Hãy đề xuất module structure cho pipeline ingest + validate + transform telecom events.

---

## 9. Exit criteria

- [ ] Refactor script thành ít nhất 5 functions có contract rõ.
- [ ] Tạo module import được.
- [ ] Không dùng global mutable list cho errors/state.
- [ ] Có immutable config dataclass.
- [ ] Test deterministic timestamp thành công.
- [ ] Đạt ít nhất 4/5 MCQ.
