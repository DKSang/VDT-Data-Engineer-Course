# Lesson 01 – Objects, Names, Types & Mutability

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích `a = b` là bind name tới object, không phải luôn tạo copy.
- Phân biệt identity, equality và type.
- Phân biệt mutable/immutable và dự đoán side effect do aliasing.
- Giải thích vì sao mutable default argument nguy hiểm trong pipeline code.
- Chọn cách copy phù hợp ở mức cơ bản: assignment, shallow copy, deep copy.
- Viết transformation không vô tình mutate input record.

---

## 2. Source alignment

### Primary Databricks sources

Databricks Academy – **Introduction to Python for Data Science and Data Engineering** dùng variables, data types và complex data types làm nền cho Python programming trong Databricks.

- https://customer-academy.databricks.com/learn/courses/969/introduction-to-python-for-data-science-and-data-engineering
- https://docs.databricks.com/aws/en/languages/python

### Supplementary prerequisite

Python Tutorial – names/objects/classes/data structures:

- https://docs.python.org/3/tutorial/

### Scope note

Bài này giải thích Python language semantics. Đây không phải behavior riêng của Databricks, nhưng là prerequisite trực tiếp trước khi viết Python/PySpark transformation.

---

## 3. Principles

### Principle 1 – Variable trong Python là name binding

Python không nên được hình dung theo kiểu “một biến là một hộp chứa giá trị”. Mental model hữu ích hơn:

```text
name ─────> object
```

Khi viết:

```python
b = a
```

`b` thường được bind tới **cùng object** mà `a` đang tham chiếu. Không có copy tự động.

### Principle 2 – Mutation quan trọng hơn syntax

Hai đoạn code có cùng output trong happy path nhưng khác mutation behavior có thể tạo pipeline bug khi function được reuse.

Một transformation tốt cần trả lời:

> Function có mutate input không?

Nếu có, đó phải là contract có chủ đích.

### Principle 3 – Data record nên được đối xử như value khi có thể

Trong ETL, record đi qua nhiều transformation. Nếu mỗi function âm thầm sửa dictionary dùng chung, lỗi phụ thuộc thứ tự gọi rất khó debug.

Ưu tiên:

```text
input record → new normalized record
```

thay vì nhiều function cùng mutate một object nếu không thật sự cần.

---

## 4. Fundamentals

### 4.1 Object, name, type

```python
customer_id = 1001
```

Ta có:

- một object số nguyên `1001`;
- type của object là `int`;
- name `customer_id` được bind tới object đó.

Một object có:

- **identity** – định danh object trong runtime;
- **type** – quy định operations/behavior;
- **value/state** – dữ liệu mà object biểu diễn.

### 4.2 `==` khác `is`

`==` hỏi:

> Hai object có value bằng nhau theo equality semantics không?

`is` hỏi:

> Hai name có trỏ đúng cùng một object không?

```python
a = [1, 2]
b = [1, 2]

print(a == b)  # True
print(a is b)  # False
```

Trong production code, `is` thường dùng cho singleton như `None`:

```python
if value is None:
    ...
```

Không dùng `is` để so sánh số/string dựa vào implementation accident.

### 4.3 Immutable types

Các type thường gặp:

- `int`
- `float`
- `bool`
- `str`
- `tuple` (bản thân tuple immutable, nhưng có thể chứa mutable object)
- `frozenset`

Ví dụ:

```python
x = 10
x = x + 1
```

Không mutate object `10`; name `x` được rebind sang object mới `11`.

### 4.4 Mutable types

Phổ biến:

- `list`
- `dict`
- `set`
- phần lớn user-defined objects

```python
record = {"customer_id": 1, "status": "active"}
alias = record
alias["status"] = "inactive"

print(record["status"])  # inactive
```

`record` và `alias` cùng trỏ một dictionary.

### 4.5 Aliasing trong pipeline

Một bug điển hình:

```python
def mask_customer(record):
    record["phone"] = "***"
    return record

raw = {"customer_id": 1, "phone": "0900000001"}
masked = mask_customer(raw)
```

Sau đó `raw` cũng mất số điện thoại gốc.

Nếu raw record cần giữ để audit/replay, đây là bug semantics.

Version rõ contract hơn:

```python
def mask_customer(record: dict) -> dict:
    return {
        **record,
        "phone": "***",
    }
```

### 4.6 Shallow copy

```python
original = {
    "customer_id": 1,
    "tags": ["vip", "prepaid"],
}

copied = original.copy()
copied["customer_id"] = 2
```

Top-level dictionary khác nhau, nhưng nested list vẫn shared:

```python
copied["tags"].append("risk")
print(original["tags"])
# ['vip', 'prepaid', 'risk']
```

Đây là **shallow copy**.

### 4.7 Deep copy

`copy.deepcopy()` đi sâu hơn vào object graph. Nhưng đừng dùng deep copy như reflex:

- tốn CPU/memory;
- có thể che giấu design không rõ mutation contract;
- với object phức tạp, behavior có thể không đúng kỳ vọng.

Data pipeline thường tốt hơn khi tạo output record mới có schema rõ.

### 4.8 Mutable default argument

Sai:

```python
def collect_error(error, errors=[]):
    errors.append(error)
    return errors
```

Default object được tạo khi function được định nghĩa, không phải mỗi lần gọi.

```python
collect_error("bad row 1")
collect_error("bad row 2")
```

Call thứ hai có thể thấy state của call trước.

Đúng hơn:

```python
def collect_error(error, errors=None):
    if errors is None:
        errors = []
    errors.append(error)
    return errors
```

### 4.9 Truthiness

Python cho phép object được evaluate trong boolean context:

```python
if not records:
    ...
```

`[]`, `{}`, `set()`, `""`, `0`, `None` đều falsy.

Nhưng trong data code cần cẩn thận:

```python
if not metric_value:
```

sẽ coi `0` là missing.

Nếu business semantics nói `0` là valid value:

```python
if metric_value is None:
```

### 4.10 Type conversion không đồng nghĩa validation

```python
int("10")
```

chuyển được string thành int, nhưng không chứng minh rằng giá trị hợp lệ cho domain.

Ví dụ `call_duration_seconds = -20` vẫn là integer nhưng sai business rule.

Pipeline cần tách:

```text
parse/type conversion
        ↓
semantic validation
```

---

## 5. Worked example – Normalize customer record mà không phá raw input

### Input

```python
raw = {
    "customer_id": "1001",
    "phone": " 0900000001 ",
    "province": " ha noi ",
    "balance": "0",
}
```

### Version dễ gây side effect

```python
def normalize(record):
    record["customer_id"] = int(record["customer_id"])
    record["phone"] = record["phone"].strip()
    record["province"] = record["province"].strip().title()
    record["balance"] = float(record["balance"])
    return record
```

Nếu gọi:

```python
clean = normalize(raw)
```

`raw` cũng bị thay đổi.

### Version value-oriented

```python
def normalize(record: dict) -> dict:
    return {
        "customer_id": int(record["customer_id"]),
        "phone": record["phone"].strip(),
        "province": record["province"].strip().title(),
        "balance": float(record["balance"]),
    }
```

Giờ raw record có thể giữ làm landing/audit copy.

### Validation thêm

```python
def validate(record: dict) -> list[str]:
    errors = []

    if record["customer_id"] <= 0:
        errors.append("customer_id must be positive")

    if record["balance"] < 0:
        errors.append("balance must be non-negative")

    return errors
```

Ta tách ba concern:

```text
raw input
  ↓ parse/normalize
clean typed record
  ↓ validate
accepted / rejected
```

---

## 6. Hands-on lab

Tạo file `lesson_01_mutability.py`.

### Nhiệm vụ A – Predict before run

Với mỗi đoạn dưới, **viết output dự đoán trước khi chạy**.

```python
a = [1, 2]
b = a
b.append(3)
print(a)
```

```python
a = {"x": [1]}
b = a.copy()
b["x"].append(2)
print(a)
```

```python
def f(items=[]):
    items.append(1)
    return items

print(f())
print(f())
```

### Nhiệm vụ B – Safe normalization

Viết:

```python
def normalize_event(record: dict) -> dict:
    ...
```

Input ví dụ:

```python
{
    "event_id": " e-001 ",
    "cell_id": " hni-01 ",
    "duration_ms": "1200",
    "dropped": "false"
}
```

Output:

```python
{
    "event_id": "e-001",
    "cell_id": "HNI-01",
    "duration_ms": 1200,
    "dropped": False
}
```

Yêu cầu:

1. Không mutate input.
2. `duration_ms < 0` phải raise `ValueError`.
3. Chỉ chấp nhận `true/false` không phân biệt hoa thường cho `dropped`.
4. Viết ít nhất 5 test case thủ công bằng `assert`.

### Nhiệm vụ C – Explain aliasing

Viết 5–8 câu giải thích tại sao shallow copy chưa đủ nếu record chứa nested mutable collections.

---

## 7. Knowledge check – MCQ

**Q1.** Sau `b = a` với `a` là list, điều gì đúng nhất?

A. Python luôn deep copy list.  
B. `b` được bind tới cùng object với `a`.  
C. `a` bị xóa.  
D. List trở thành immutable.

**Q2.** `is` phù hợp nhất cho trường hợp nào?

A. So sánh hai string có cùng nội dung.  
B. So sánh hai integer value.  
C. Kiểm tra `value is None`.  
D. So sánh hai list theo nội dung.

**Q3.** Vì sao `def f(items=[])` nguy hiểm?

A. List không cho append.  
B. Default list có thể được reuse giữa nhiều call.  
C. Function không return được.  
D. List trở thành tuple.

**Q4.** `if not metric:` có thể sai trong data validation vì:

A. `None` luôn truthy.  
B. `0` có thể là valid business value nhưng bị coi là falsy.  
C. String không có truthiness.  
D. Dict luôn truthy.

**Q5.** Shallow copy dictionary có nested list nghĩa là:

A. Nested list chắc chắn được deep copy.  
B. Top-level dict mới nhưng nested mutable object có thể vẫn shared.  
C. Không tạo object mới nào.  
D. Dictionary trở thành immutable.

---

## 8. Knowledge check – Tự luận / Interview

1. Giải thích mutable vs immutable bằng ví dụ pipeline cụ thể.
2. Tại sao silent mutation nguy hiểm với raw/bronze semantics?
3. Assignment, shallow copy và deep copy khác nhau thế nào?
4. Tại sao `0`, `None` và empty string phải được phân biệt theo business semantics?
5. Nếu interviewer hỏi “Python pass by value hay pass by reference?”, bạn sẽ trả lời thế nào để tránh simplification sai?
6. Viết một ví dụ bug do mutable default argument trong hàm collect rejected records.

---

## 9. Exit criteria

- [ ] Dự đoán đúng 3 aliasing examples trước khi chạy.
- [ ] Viết `normalize_event()` không mutate input.
- [ ] Có ít nhất 5 assertions.
- [ ] Giải thích được `==` vs `is`.
- [ ] Giải thích được shallow vs deep copy.
- [ ] Đạt ít nhất 4/5 MCQ.
