# Lesson 04 – Iterables, Iterators & Generators

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Phân biệt iterable, iterator và generator.
- Giải thích eager materialization vs lazy iteration.
- Viết generator xử lý file/record theo từng phần tử thay vì load toàn bộ vào RAM.
- Nhận biết khi nào `list(...)` vô tình phá bounded-memory design.
- Thiết kế pipeline function theo kiểu iterator-in → iterator-out.
- Liên hệ lazy Python iteration với tư duy deferred/distributed execution mà sau này sẽ gặp trong Spark, nhưng không đánh đồng hai cơ chế.

---

## 2. Source alignment

### Primary Databricks sources

- Databricks for Python developers: https://docs.databricks.com/aws/en/languages/python
- Work with files on Databricks: https://docs.databricks.com/aws/en/files/

Databricks cho phép dùng Python/OSS file APIs trong notebook/jobs và dùng Spark cho dataset lớn. Bài này xây nền memory-aware processing trước khi bước sang PySpark.

### Supplementary prerequisite

Python Tutorial – Iterators / Generators:

- https://docs.python.org/3/tutorial/classes.html#iterators
- https://docs.python.org/3/tutorial/classes.html#generators

### Scope note

Generator là Python language feature. Nó **không phải** Spark lazy evaluation. Điểm chung chỉ là tư duy “không nhất thiết materialize mọi thứ ngay”. Spark execution model sẽ học ở Module 09.

---

## 3. Principles

### Principle 1 – Data volume quyết định materialization strategy

Code:

```python
rows = list(source)
```

có nghĩa là yêu cầu materialize toàn bộ source vào memory. Với 100 rows, không đáng lo. Với 100GB JSONL, design sai.

### Principle 2 – Streaming interface giảm coupling

Một function nhận iterator và yield record sạch có thể xử lý:

- file;
- API pages;
- database cursor;
- generated test data.

Không cần biết toàn bộ dataset nằm ở đâu.

### Principle 3 – Laziness không miễn phí

Generator giảm memory nhưng tạo trade-off:

- iterator thường one-pass;
- exception xảy ra khi consume, không phải khi tạo generator;
- debug có thể khó hơn;
- một số operation cần toàn dataset như global sort/exact median.

---

## 4. Fundamentals

### 4.1 Iterable

Một object **iterable** có thể cung cấp iterator.

Ví dụ:

```python
records = [1, 2, 3]
for x in records:
    print(x)
```

List là iterable.

### 4.2 Iterator

Iterator giữ state iteration và trả phần tử tiếp theo qua `next()`.

```python
it = iter([10, 20, 30])
print(next(it))  # 10
print(next(it))  # 20
```

Khi hết dữ liệu, iterator raise `StopIteration`.

### 4.3 Generator function

Function có `yield` tạo generator.

```python
def numbers():
    yield 1
    yield 2
    yield 3
```

Gọi:

```python
g = numbers()
```

chưa chạy toàn bộ body để tạo list `[1, 2, 3]`. Values được tạo dần khi consumer yêu cầu.

### 4.4 Generator expression

```python
squares = (x * x for x in range(1_000_000))
```

khác list comprehension:

```python
squares = [x * x for x in range(1_000_000)]
```

List materialize toàn bộ; generator expression tạo lazy iterator.

### 4.5 File object là iterable

```python
with open("events.jsonl", encoding="utf-8") as f:
    for line in f:
        ...
```

Pattern này đọc theo stream buffer thay vì `f.readlines()` để tạo list toàn bộ lines.

### 4.6 Iterator pipeline

```python
def parse_lines(lines):
    for line in lines:
        yield json.loads(line)


def valid_events(events):
    for event in events:
        if event.get("event_id"):
            yield event
```

Compose:

```python
with open("events.jsonl") as f:
    events = parse_lines(f)
    clean = valid_events(events)
    for event in clean:
        ...
```

Memory footprint gần với số record đang xử lý, không phải total rows.

### 4.7 One-pass semantics

```python
g = (x for x in range(3))
print(list(g))  # [0, 1, 2]
print(list(g))  # []
```

Generator đã consumed.

Đây là source của nhiều bug test/debug nếu tưởng iterator giống reusable list.

### 4.8 `yield from`

Khi flatten nested iterator:

```python
def read_many(files):
    for path in files:
        with open(path) as f:
            yield from f
```

### 4.9 Chunking

Một số downstream API/DB writer cần batch.

```python
def batched(iterable, size):
    batch = []
    for item in iterable:
        batch.append(item)
        if len(batch) == size:
            yield batch
            batch = []
    if batch:
        yield batch
```

Trade-off batch size:

- lớn: throughput tốt hơn, memory/risk retry cao hơn;
- nhỏ: overhead cao hơn nhưng checkpoint/retry granular hơn.

### 4.10 Backpressure intuition

Trong local synchronous generator pipeline, producer tạo next item khi consumer pull. Điều này tạo natural bounded flow ở mức đơn giản.

Không nhầm với distributed streaming backpressure; nhưng đây là mental model tốt cho producer/consumer flow.

### 4.11 Khi generator không đủ

Generator không giải quyết:

- distributed compute;
- dataset lớn hơn một máy về CPU/storage;
- fault-tolerant distributed state;
- global joins/sorts ở massive scale.

Lúc đó Spark/DataFrame là lớp abstraction khác.

---

## 5. Worked example – Process 10M events mà không tạo list 10M rows

### Eager version

```python
def load_events(path):
    with open(path) as f:
        return [json.loads(line) for line in f]
```

Nếu mỗi decoded record trung bình vài KB, memory có thể phình rất lớn.

### Lazy version

```python
def iter_events(path):
    with open(path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            if not line.strip():
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid JSON at line {line_no}") from exc
```

Consumer:

```python
count = 0
for event in iter_events("network_events.jsonl"):
    count += 1
```

### Transform pipeline

```python
def normalize_events(events):
    for event in events:
        yield {
            **event,
            "cell_id": event["cell_id"].strip().upper(),
        }
```

Compose:

```python
for event in normalize_events(iter_events(path)):
    ...
```

---

## 6. Hands-on lab

### A – Memory experiment

Sinh file JSONL ít nhất 200k rows.

So sánh:

```python
rows = [json.loads(line) for line in f]
```

với generator loop.

Không cần benchmark hoàn hảo; ghi nhận:

- runtime;
- process memory quan sát bằng Task Manager/top nếu có;
- code complexity.

### B – Generator pipeline

Viết:

```python
def iter_jsonl(path): ...
def normalize_events(events): ...
def filter_valid_events(events): ...
def batched(events, size): ...
```

Yêu cầu:

- mỗi function nhận iterable/iterator;
- không gọi `list()` bên trong;
- batch size configurable;
- invalid row phải có line/context.

### C – One-pass test

Viết test chứng minh generator consumed một lần. Sau đó giải thích khi nào phải materialize intentionally.

### D – Global operation discussion

Tự luận 8–10 câu:

> Tại sao exact global sort không thể được thực hiện chỉ bằng một streaming generator đơn giản mà không giữ/ngoại hóa state đáng kể?

---

## 7. Knowledge check – MCQ

**Q1.** Generator khác list chính ở điểm nào?

A. Generator luôn nhanh hơn mọi trường hợp.  
B. Generator tạo values theo nhu cầu thay vì materialize toàn bộ ngay.  
C. Generator distributed tự động.  
D. Generator giữ toàn bộ dataset hai lần.

**Q2.** `list(generator)` có tác dụng gì?

A. Giữ lazy hoàn toàn.  
B. Materialize toàn bộ remaining values vào list.  
C. Reset generator.  
D. Chuyển thành Spark DataFrame.

**Q3.** Vì sao file loop `for line in f` thường tốt hơn `f.readlines()` cho file lớn?

A. Vì loop luôn multi-threaded.  
B. Có thể xử lý tuần tự mà không cần list chứa toàn bộ lines.  
C. `readlines()` không đọc file.  
D. File object không iterable.

**Q4.** Generator one-pass nghĩa là:

A. Có thể consume vô hạn lần từ đầu tự động.  
B. Khi đã exhausted, tiếp tục iteration không tự reset.  
C. Không raise exception.  
D. Không giữ state.

**Q5.** Generator có thay Spark cho 10TB join không?

A. Có, luôn luôn.  
B. Không; generator chỉ là local iteration abstraction, không cung cấp distributed compute.  
C. Có nếu dùng tuple.  
D. Có nếu batch size = 1.

---

## 8. Tự luận / Interview

1. Iterable vs iterator vs generator khác nhau thế nào?
2. Khi nào bạn chủ động materialize iterator thành list?
3. Tại sao lazy iteration giúp bounded memory?
4. Generator exception xảy ra ở thời điểm nào?
5. Chunk/batch size có trade-off gì?
6. Generator laziness và Spark lazy evaluation giống/khác nhau ở mức concept nào?

---

## 9. Exit criteria

- [ ] Tạo generator đọc JSONL.
- [ ] Pipeline không `list()` toàn bộ input.
- [ ] Có batching configurable.
- [ ] Chứng minh one-pass behavior.
- [ ] Giải thích được khi generator không đủ và cần Spark.
- [ ] Đạt ít nhất 4/5 MCQ.
