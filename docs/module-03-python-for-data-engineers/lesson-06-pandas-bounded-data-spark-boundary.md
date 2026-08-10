# Lesson 06 – pandas for Bounded Data & the Spark Boundary

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Dùng pandas DataFrame cho exploratory/local bounded transformations.
- Hiểu pandas DataFrame khác PySpark DataFrame ở execution model và scale.
- Biết khi nào `.collect()`/`.toPandas()`-style thinking có thể làm driver quá tải.
- Giải thích vectorized column operation tốt hơn Python row loop trong nhiều pandas workloads.
- Phân biệt pandas, pandas API on Spark và PySpark DataFrame ở mức định hướng.
- Chuyển một transformation nhỏ từ Python records → pandas mà không thay đổi business semantics.
- Xác định ranh giới khi workload cần distributed compute.

---

## 2. Source alignment

### Primary Databricks sources

- pandas on Databricks: https://docs.databricks.com/aws/en/pandas/
- Databricks for Python developers: https://docs.databricks.com/aws/en/languages/python
- PySpark on Databricks: https://docs.databricks.com/aws/en/pyspark/
- PySpark basics: https://docs.databricks.com/aws/en/pyspark/basics
- DataFrame tutorial: https://docs.databricks.com/aws/en/getting-started/dataframes

Databricks Runtime có pandas; Databricks đồng thời cung cấp PySpark DataFrames cho distributed processing và pandas API on Spark cho pandas-like API trên Spark.

### Databricks Academy alignment

**Introduction to Python for Data Science and Data Engineering** đưa pandas vào cuối Python foundation track. Module này giữ pandas nhưng đặt nó trong Data Engineering boundary thay vì học visualization sâu.

### Scope note

Module 03 chỉ dạy **boundary**. Spark partitioning, lazy execution, shuffle, join strategy, Catalyst/AQE sẽ học ở Module 09.

---

## 3. Principles

### Principle 1 – Chọn engine theo data size + computation + SLA, không theo sở thích API

pandas rất tốt khi:

- data vừa memory một machine;
- interactive analysis;
- unit-test fixtures;
- small reference/config data;
- local preprocessing.

Spark phù hợp hơn khi:

- data vượt single-machine practical limits;
- cần distributed scan/join/aggregation;
- pipeline cần fault-tolerant parallel execution;
- data đã ở lakehouse và compute cần scale ngang.

### Principle 2 – Cùng business rule, execution model có thể khác

Logic:

```text
normalize cell_id
filter invalid duration
aggregate drop rate per cell
```

có thể viết bằng:

- Python records;
- pandas;
- PySpark;
- SQL.

Correctness semantics phải giữ ổn định dù execution engine đổi.

### Principle 3 – Driver memory là boundary

Trong Spark workflow, việc kéo distributed data về Python process/driver có thể phá scale advantage. Không dùng pandas conversion như reflex cho large dataset.

---

## 4. Fundamentals

### 4.1 pandas DataFrame

```python
import pandas as pd

df = pd.DataFrame([
    {"cell_id": "HN-01", "dropped": False},
    {"cell_id": "HN-01", "dropped": True},
])
```

pandas DataFrame sống trong Python process memory.

### 4.2 Column-oriented expressions

Thay vì:

```python
for row in rows:
    row["cell_id"] = row["cell_id"].upper()
```

pandas:

```python
df["cell_id"] = df["cell_id"].str.strip().str.upper()
```

Vectorized expressions thường rõ hơn và tận dụng implementation tối ưu hơn Python-level row loop.

### 4.3 Filtering

```python
valid = df[df["duration_ms"] >= 0]
```

Lưu ý missing values. Boolean filtering với nullable data có semantics riêng; không giả định Python `None` behavior hoàn toàn giống pandas `NaN`/nullable dtypes.

### 4.4 Aggregation

```python
summary = (
    df.groupby("cell_id", as_index=False)
      .agg(
          total_calls=("event_id", "count"),
          dropped_calls=("dropped", "sum"),
      )
)

summary["drop_rate"] = (
    summary["dropped_calls"] / summary["total_calls"]
)
```

Vẫn phải xác định grain:

```text
input: 1 row/event
output: 1 row/cell
```

### 4.5 pandas `apply()` không phải default solution

```python
df["x"] = df.apply(custom_python_func, axis=1)
```

có thể tiện nhưng row-wise Python function thường chậm hơn built-in vectorized expressions.

Rule:

1. ưu tiên built-in column ops;
2. `map`/vectorized library nếu phù hợp;
3. row-wise apply khi logic thật sự cần và data bounded.

### 4.6 Missing values

pandas có lịch sử nhiều representations cho missing data (`NaN`, `NaT`, `pd.NA`).

Data Engineer phải explicit:

- field nullable không?
- missing có khác zero/empty string không?
- aggregation bỏ NULL hay coi là 0?

Không dựa vào implicit conversion mà không kiểm tra dtype.

### 4.7 Dtype matters

```python
print(df.dtypes)
```

CSV có thể khiến numeric/date columns bị đọc thành object/string tùy dữ liệu. Luôn inspect và parse intentionally.

### 4.8 PySpark DataFrame

Databricks docs mô tả DataFrame là distributed collection of data organized into named columns. PySpark API cho select/filter/join/aggregate nhưng execution được Spark quản lý trên compute distributed.

Mental model:

```text
pandas DataFrame
  data primarily in one Python process memory

PySpark DataFrame
  logical distributed dataset + Spark execution plan
```

### 4.9 pandas API on Spark

Databricks hỗ trợ pandas API on Spark để dùng nhiều pandas-like operations trên Spark. Nhưng API quen không làm distributed semantics biến mất:

- execution vẫn Spark;
- shuffle/partition cost vẫn tồn tại;
- không phải mọi pandas pattern đều efficient khi chuyển distributed.

### 4.10 Conversion boundary

Small result → pandas có thể hợp lý cho visualization/local library.

Large fact table → không kéo toàn bộ về driver chỉ để dùng pandas.

Luôn hỏi:

```text
How many rows/bytes after filter?
Can it fit safely in driver memory?
Why is conversion needed?
```

### 4.11 Unit test strategy

Transformation semantics có thể test với small fixture bằng Python/pandas trước, nhưng integration với Spark vẫn cần Spark tests sau này.

Small tests không chứng minh distributed performance correctness.

---

## 5. Worked example – Same metric, two local representations

### Python records

```python
def summarize(events):
    stats = {}
    for event in events:
        cell = event["cell_id"]
        bucket = stats.setdefault(
            cell,
            {"total_calls": 0, "dropped_calls": 0},
        )
        bucket["total_calls"] += 1
        bucket["dropped_calls"] += int(event["dropped"])

    return [
        {
            "cell_id": cell,
            **v,
            "drop_rate": v["dropped_calls"] / v["total_calls"],
        }
        for cell, v in stats.items()
    ]
```

### pandas

```python
summary = (
    df.groupby("cell_id", as_index=False)
      .agg(
          total_calls=("event_id", "count"),
          dropped_calls=("dropped", "sum"),
      )
)
summary["drop_rate"] = summary["dropped_calls"] / summary["total_calls"]
```

### Semantics validation

Hai version phải thống nhất:

- duplicate treatment;
- missing `dropped`;
- event grain;
- denominator.

API khác không được làm business definition thay đổi âm thầm.

---

## 6. Hands-on lab

### A – Load telecom data with pandas

Đọc:

- `customers.csv`;
- `network_events.jsonl`.

Yêu cầu:

- inspect `shape`, `dtypes`;
- parse timestamp;
- report NULL count;
- detect duplicate event key;
- normalize `cell_id`.

### B – Compute metrics

Tạo table:

```text
cell_id
total_events
dropped_events
drop_rate
avg_duration_ms
```

Output grain: 1 row/cell.

### C – Memory boundary experiment

Sinh DataFrame với tăng dần rows:

```text
100k
1M
5M nếu máy cho phép
```

Quan sát memory/runtime. Không cần ép máy tới OOM.

Viết kết luận:

> “fit in memory” không chỉ nghĩa dataset file size nhỏ hơn RAM vì object/DataFrame representation có overhead.

### D – Spark decision memo

Cho ba case:

1. 50MB reference table;
2. 30GB daily event file;
3. 5TB historical event table.

Với mỗi case, chọn Python/pandas/PySpark và giải thích 5–8 câu. Không chỉ dựa vào size; xét reuse, joins, cluster availability, SLA.

---

## 7. Knowledge check – MCQ

**Q1.** pandas DataFrame chủ yếu xử lý dữ liệu ở đâu?

A. Distributed executors tự động trong mọi trường hợp.  
B. Memory/process của Python machine đang chạy pandas.  
C. Kafka broker.  
D. HDFS NameNode bắt buộc.

**Q2.** PySpark DataFrame khác pandas DataFrame quan trọng nhất ở Module này vì:

A. PySpark không có columns.  
B. PySpark đại diện distributed data computation do Spark thực thi.  
C. pandas luôn dùng SQL Warehouse.  
D. PySpark chỉ xử lý string.

**Q3.** Khi nào kéo Spark dataset về pandas hợp lý hơn?

A. Mọi table hàng TB.  
B. Result đã được reduce nhỏ, có lý do dùng local library/visualization.  
C. Trước mọi join.  
D. Để Spark nhanh hơn.

**Q4.** pandas `apply(axis=1)` nên là:

A. default cho mọi transformation.  
B. dùng có chủ đích khi built-in/vectorized ops không phù hợp và data bounded.  
C. distributed shuffle.  
D. index.

**Q5.** pandas API on Spark nghĩa là:

A. Distributed cost biến mất.  
B. API quen hơn nhưng execution vẫn chịu Spark distributed semantics.  
C. data luôn nằm trong driver.  
D. không có partitions.

---

## 8. Tự luận / Interview

1. pandas vs PySpark khác nhau thế nào về execution/scale?
2. Tại sao conversion distributed DataFrame → pandas có thể nguy hiểm?
3. Khi nào pandas là tool tốt cho DE?
4. Tại sao cùng business rule phải giữ semantics qua Python/pandas/Spark/SQL?
5. Vectorized operation là gì ở mức intuition?
6. pandas API on Spark có loại bỏ nhu cầu hiểu Spark không? Vì sao?

---

## 9. Exit criteria

- [ ] Đọc và inspect telecom data bằng pandas.
- [ ] Tính cell metrics đúng grain.
- [ ] Detect NULL/duplicate/type issues.
- [ ] Viết Spark decision memo cho 3 scales.
- [ ] Giải thích được driver-memory boundary.
- [ ] Đạt ít nhất 4/5 MCQ.
