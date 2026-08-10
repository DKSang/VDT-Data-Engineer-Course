# Lesson 02 – Collections, Control Flow & Complexity

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Chọn `list`, `tuple`, `dict`, `set` theo semantics thay vì theo thói quen.
- Giải thích complexity cơ bản của lookup/append/membership ở mức interview.
- Dùng loop/comprehension rõ ràng nhưng không biến comprehension thành code khó đọc.
- Nhận ra nested loop có thể thay bằng hash lookup.
- Xử lý missing key, duplicate key và ordering có chủ đích.
- Viết aggregation nhỏ bằng Python mà vẫn giữ grain rõ như khi viết SQL.

---

## 2. Source alignment

### Primary Databricks source

Databricks Academy – **Introduction to Python for Data Science and Data Engineering** bao phủ complex data types, control flow và loops.

- https://customer-academy.databricks.com/learn/courses/969/introduction-to-python-for-data-science-and-data-engineering

### Supplementary prerequisite

Python Tutorial – Data Structures / Control Flow:

- https://docs.python.org/3/tutorial/datastructures.html
- https://docs.python.org/3/tutorial/controlflow.html

### Scope note

Complexity trong bài ở mức fresher/interview: reasoning O(1), O(n), O(n²) gần đúng theo data structure behavior phổ biến. Không biến Module 03 thành DSA module; Module 04 sẽ đào sâu hơn.

---

## 3. Principles

### Principle 1 – Data structure là một quyết định semantics

Không hỏi “list hay dict cái nào nhanh hơn?” trước khi hỏi:

> Dữ liệu đang đại diện cái gì?

- sequence có thứ tự → list/tuple;
- lookup theo key → dict;
- uniqueness/membership → set;
- fixed record positional rất nhỏ → tuple có thể hợp lý, nhưng named structure thường rõ hơn.

### Principle 2 – Tối ưu lớn nhất thường đến từ thay thuật toán

Tối ưu syntax trong vòng lặp ít giá trị hơn việc đổi:

```text
scan list mỗi record: O(n²)
```

thành:

```text
build dict/set một lần + lookup: O(n)
```

### Principle 3 – Grain vẫn tồn tại ngoài SQL

Khi Python aggregate records, vẫn phải nói rõ:

```text
input grain  = 1 row / event
output grain = 1 row / cell
```

Nếu không, bug double-count hay overwrite vẫn xảy ra như SQL.

---

## 4. Fundamentals

### 4.1 List

Đặc tính:

- ordered;
- mutable;
- cho duplicate;
- truy cập theo index;
- append cuối thường hiệu quả;
- membership `x in list` thường phải scan.

Ví dụ:

```python
events = ["e1", "e2", "e2"]
```

List đúng khi sequence và duplicate có ý nghĩa.

### 4.2 Tuple

- ordered;
- immutable container;
- có thể dùng làm dictionary key nếu các phần tử hashable.

Ví dụ composite key:

```python
key = (customer_id, event_date)
```

Trong DE, tuple hữu ích cho compound key tạm thời nhưng named structures thường dễ maintain hơn cho record phức tạp.

### 4.3 Dictionary

```python
customer_by_id = {
    1001: {"province": "HN"},
    1002: {"province": "HCM"},
}
```

Dùng khi cần mapping key → value.

Lookup trung bình thường gần O(1), nhưng điều quan trọng hơn là semantics: key phải có uniqueness rule.

Nếu input có duplicate business key:

```python
customer_by_id[row["customer_id"]] = row
```

row sau overwrite row trước. Đây có thể là bug nếu winner rule chưa được định nghĩa.

### 4.4 Set

```python
seen_event_ids = set()
```

Phù hợp:

- membership;
- uniqueness;
- set operations.

Dedup đơn giản:

```python
if event_id in seen_event_ids:
    ...
else:
    seen_event_ids.add(event_id)
```

Nhưng lưu ý: `event_id` unique có thật sự là business rule không? Nếu source versioned event, dedup theo event_id có thể làm mất version mới.

### 4.5 Complexity mental model

| Operation | list | dict | set |
|---|---:|---:|---:|
| append cuối | thường O(1) amortized | – | – |
| lookup theo index | O(1) | – | – |
| membership | O(n) | trung bình O(1) theo key | trung bình O(1) |
| insert/lookup theo key | – | trung bình O(1) | trung bình O(1) |

Không học bảng này như guarantee tuyệt đối; mục tiêu là nhận biết khi code đang scan dữ liệu lặp lại không cần thiết.

### 4.6 `for`, `if`, `break`, `continue`

Control flow nên thể hiện business rule rõ.

```python
for event in events:
    if event["event_id"] is None:
        continue

    if event["duration_ms"] < 0:
        rejected.append(event)
        continue

    accepted.append(event)
```

Nhiều `continue` có thể làm happy path thẳng hơn nested `if` nhiều tầng.

### 4.7 Enumeration và parallel iteration

```python
for i, row in enumerate(rows, start=1):
    ...
```

hữu ích cho line number/error context.

```python
for key, value in mapping.items():
    ...
```

Không loop qua key rồi lookup value lại nếu `.items()` rõ hơn.

### 4.8 Comprehension

Rõ:

```python
active_ids = [
    c["customer_id"]
    for c in customers
    if c["status"] == "active"
]
```

Không rõ:

```python
result = [complex_fn(x) for x in rows if cond1(x) and cond2(x) if cond3(x)]
```

Rule: comprehension tốt khi mapping/filter đơn giản. Nếu có nhiều branch, logging, side effect, error handling → dùng loop thường dễ đọc hơn.

### 4.9 Dict/set comprehension

```python
plan_by_id = {p["plan_id"]: p for p in plans}
```

Trước khi dùng, phải hỏi:

> `plan_id` có unique không?

Nếu không chắc, validate:

```python
plan_by_id = {}
for plan in plans:
    key = plan["plan_id"]
    if key in plan_by_id:
        raise ValueError(f"duplicate plan_id: {key}")
    plan_by_id[key] = plan
```

### 4.10 `dict.get()` và missing semantics

```python
province = customer.get("province")
```

`get()` tránh `KeyError`, nhưng có thể che lỗi schema.

- optional field → `.get()` hợp lý;
- required field → `record["customer_id"]` + validation có thể tốt hơn vì fail rõ.

### 4.11 Avoid accidental O(n²)

Chậm:

```python
for event in events:
    for cell in cells:
        if event["cell_id"] == cell["cell_id"]:
            ...
```

Nếu `events = 1,000,000`, `cells = 10,000`, nested scan cực tệ.

Tốt hơn:

```python
cell_by_id = {c["cell_id"]: c for c in cells}

for event in events:
    cell = cell_by_id.get(event["cell_id"])
    ...
```

Đây chính là hash-join intuition ở local Python. Sau này Spark join cũng giải quyết cùng lớp vấn đề nhưng ở distributed scale.

---

## 5. Worked example – Aggregate call-drop metrics

### Input grain

`1 record / network event`

```python
events = [
    {"cell_id": "HN-01", "dropped": False},
    {"cell_id": "HN-01", "dropped": True},
    {"cell_id": "HCM-02", "dropped": False},
]
```

### Output grain

`1 record / cell_id`

Ta cần:

- total calls;
- dropped calls;
- drop rate.

```python
stats = {}

for event in events:
    cell_id = event["cell_id"]

    if cell_id not in stats:
        stats[cell_id] = {
            "total_calls": 0,
            "dropped_calls": 0,
        }

    stats[cell_id]["total_calls"] += 1
    stats[cell_id]["dropped_calls"] += int(event["dropped"])

result = []
for cell_id, values in stats.items():
    result.append({
        "cell_id": cell_id,
        **values,
        "drop_rate": values["dropped_calls"] / values["total_calls"],
    })
```

### Correctness questions

1. `dropped` có thể `None` không?
2. Duplicate event có được tính hai lần không?
3. Cell không có event có cần output không?
4. `drop_rate` có thể chia zero không?

Python code vẫn cần data semantics giống SQL.

---

## 6. Hands-on lab

### A – Replace nested scan

Cho:

```python
customers = [...]
subscriptions = [...]
```

Viết hai phiên bản enrich subscription với province:

1. nested loop;
2. dictionary lookup.

Đo thời gian với synthetic data:

- 10k customers;
- 100k subscriptions.

Viết kết luận về complexity.

### B – Safe mapping

Tạo `customer_by_id`, nhưng trước khi insert phải phát hiện duplicate `customer_id` và raise lỗi.

### C – Dedup preserving order

Input:

```python
["e1", "e2", "e1", "e3", "e2"]
```

Output:

```python
["e1", "e2", "e3"]
```

Không dùng package bên ngoài.

### D – Aggregate

Viết:

```python
def summarize_cells(events: list[dict]) -> list[dict]:
    ...
```

Yêu cầu:

- output grain 1 row/cell;
- reject `dropped is None`;
- không mutate input;
- sort output theo `cell_id` để test deterministic.

---

## 7. Knowledge check – MCQ

**Q1.** Cấu trúc phù hợp nhất cho repeated membership check `event_id đã thấy chưa?`

A. list  
B. set  
C. string  
D. float

**Q2.** Vì sao dict comprehension có thể làm mất dữ liệu?

A. Dict không lưu value.  
B. Duplicate key có thể overwrite value trước.  
C. Dict không hỗ trợ string key.  
D. Dict luôn unordered theo nghĩa không iterate được.

**Q3.** Nested loop join 1M events với 10k cells về mặt intuition gần:

A. O(1)  
B. O(log n)  
C. O(n*m)  
D. luôn O(n)

**Q4.** Khi nào comprehension nên tránh?

A. Mapping một field đơn giản.  
B. Filter một điều kiện đơn giản.  
C. Logic nhiều branch + logging + side effects.  
D. Tạo set từ IDs.

**Q5.** `.get()` luôn tốt hơn `[]` access?

A. Đúng.  
B. Sai; với required field, `.get()` có thể che lỗi schema/missing key.  
C. Đúng vì không bao giờ trả `None`.  
D. Chỉ đúng với list.

---

## 8. Tự luận / Interview

1. Khi nào chọn list, dict, set trong pipeline?
2. Tại sao build lookup dict giống một local hash-index/hash-join?
3. Nếu `customer_id` duplicate, dùng dict comprehension sẽ có risk gì?
4. Tại sao performance reasoning phải đi cùng correctness?
5. Viết một ví dụ mà set-based dedup là sai business semantics.
6. Giải thích input grain/output grain của `summarize_cells()`.

---

## 9. Exit criteria

- [ ] Hoàn thành nested-loop vs dict benchmark.
- [ ] Viết duplicate-key validation.
- [ ] Dedup preserving order đúng.
- [ ] `summarize_cells()` có deterministic output.
- [ ] Giải thích được O(n²) → O(n) intuition.
- [ ] Đạt ít nhất 4/5 MCQ.
