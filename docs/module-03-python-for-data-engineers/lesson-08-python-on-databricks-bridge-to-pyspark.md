# Lesson 08 – Python on Databricks & Bridge to PySpark

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Mô tả cách Python code được tổ chức trong Databricks bằng notebooks, workspace files và Git folders.
- Biết khi nào nên refactor notebook logic thành `.py` module.
- Hiểu current working directory/workspace-file caveats ở mức cần thiết.
- Phân biệt local Python object/pandas DataFrame với PySpark DataFrame.
- Giải thích driver-side Python logic vs distributed Spark transformations ở mức mental model.
- Viết một notebook mỏng import reusable module thay vì chứa toàn bộ business logic.
- Biết test Python modules trực tiếp trong Databricks workspace theo pytest conventions.
- Chuẩn bị mental model cho Module 09 – Apache Spark & PySpark mà không học trước internals.

---

## 2. Source alignment

### Primary Databricks sources

- Databricks for Python developers: https://docs.databricks.com/aws/en/languages/python
- Workspace files: https://docs.databricks.com/aws/en/files/workspace
- Work with Python modules: https://docs.databricks.com/aws/en/files/workspace-modules
- Share code between notebooks: https://docs.databricks.com/aws/en/notebooks/share-code
- Databricks Git folders: https://docs.databricks.com/aws/en/repos/
- Python unit testing in workspace: https://docs.databricks.com/aws/en/files/python-unit-tests
- PySpark on Databricks: https://docs.databricks.com/aws/en/pyspark/
- PySpark basics: https://docs.databricks.com/aws/en/pyspark/basics
- DataFrame tutorial: https://docs.databricks.com/aws/en/getting-started/dataframes

### Databricks Academy alignment

Databricks Academy Introduction to Python đặt Python trong Databricks workspace và dùng notebook/lab environment. Data Engineer Learning Plan sau đó chuyển dần sang Data Engineering workloads trên platform.

### Scope note

Bài này **không** dạy shuffle, stage/task, partitioning, broadcast join hay Catalyst. Chỉ thiết lập execution boundary để người học không mang nguyên mental model pandas/local Python sang PySpark.

---

## 3. Principles

### Principle 1 – Notebook là development surface, không nhất thiết là software boundary

Notebook rất tốt cho:

- exploration;
- teaching/demo;
- interactive debugging;
- orchestration glue nhỏ.

Reusable business logic nên được modularize khi code trưởng thành.

### Principle 2 – Source control trước production habit

Databricks Git folders tích hợp Git workflows trong workspace cho interactive development. Code nên có history/review/branching, không chỉ tồn tại trong một notebook cá nhân.

### Principle 3 – Python API không có nghĩa execution là local Python

Khi viết PySpark:

```python
df.filter(...).groupBy(...).agg(...)
```

bạn đang dùng Python API để mô tả distributed Spark computation, không phải loop Python qua từng row trong driver.

### Principle 4 – Giữ transformation semantics portable

Business rule nên tách khỏi environment-specific plumbing nếu có thể.

Ví dụ:

```text
normalize cell ID
validate duration
calculate metric definition
```

phải có semantics rõ trước khi map sang Python/pandas/PySpark.

---

## 4. Fundamentals

### 4.1 Databricks Python development surfaces

Mental map:

```text
Databricks Workspace
├── Notebooks
├── Workspace files (.py, .yaml, small files...)
├── Git folders
├── Jobs / pipeline source
└── Governed data locations
```

Databricks documentation hiện hỗ trợ import Python modules từ workspace files và Git folders.

### 4.2 Workspace files

Workspace files có thể chứa:

- `.py` modules;
- notebooks;
- YAML;
- small CSV/test files;
- wheel/library artifacts trong các use case phù hợp.

Không coi workspace file system là universal production data storage. File size/access/executor limitations tồn tại tùy compute/runtime.

### 4.3 Current working directory

Databricks Runtime mới có behavior CWD gắn với notebook/script directory. Relative import/file behavior vì vậy phải được hiểu theo runtime/documentation hiện tại.

Best habit:

- dùng module/package imports rõ;
- tránh assumptions hidden về notebook launch directory;
- với production data, dùng governed path/location phù hợp thay vì relative local file path mơ hồ.

### 4.4 Python modules in workspace

Ví dụ:

```text
telecom_project/
├── notebooks/
│   └── run_daily_quality.py
├── src/
│   └── telecom_etl/
│       ├── __init__.py
│       ├── validation.py
│       └── transforms.py
└── tests/
    └── test_validation.py
```

Notebook:

```python
from telecom_etl.validation import validate_event
```

Databricks docs hỗ trợ relative/path-based module workflows trong workspace files/Git folders, với runtime-specific behavior cần đối chiếu docs.

### 4.5 `%run` vs import

`%run` có thể dùng để execute another notebook và đưa definitions vào current context, nhưng reusable Python logic nên ưu tiên module/import khi phù hợp.

Import cho:

- explicit dependency;
- testable source files;
- IDE/tooling;
- standard Python structure.

### 4.6 Git folders

Databricks Git folders cho phép clone/pull/push/branch/diff trong workspace cho interactive development.

Workflow tinh gọn:

```text
GitHub repo
   ↕
Databricks Git folder
   ↓
notebook + .py source + tests
```

Production CI/CD sẽ học sâu ở module production/DevOps; Git folder không phải toàn bộ deployment strategy.

### 4.7 Local Python object

```python
records = [{"event_id": "e1"}, {"event_id": "e2"}]
```

Đây là object trong Python process.

Loop:

```python
for row in records:
    ...
```

chạy Python code local process.

### 4.8 pandas DataFrame

```python
import pandas as pd
pdf = pd.DataFrame(records)
```

vẫn chủ yếu local Python process memory.

### 4.9 PySpark DataFrame

```python
sdf = spark.createDataFrame(records)
```

PySpark DataFrame là distributed collection/logical dataset do Spark quản lý.

Databricks docs định nghĩa DataFrame là primary object của Spark, organized into named columns và hỗ trợ operations như select/filter/join/aggregate.

### 4.10 Transformation description vs execution

```python
result = (
    sdf.filter("duration_ms >= 0")
       .groupBy("cell_id")
       .count()
)
```

Ở mức mental model Module 03:

```text
Python call chain
      ↓
builds Spark transformation plan
      ↓
Spark executes on compute when action/output requires it
```

Chi tiết lazy evaluation/jobs/stages/tasks học ở Module 09.

### 4.11 Driver-side code

Ví dụ:

```python
threshold = 0.05
```

local Python scalar.

```python
if threshold > 0:
    ...
```

driver-side control flow.

Không viết:

```python
for row in sdf.collect():
    ...
```

cho large dataset chỉ để quay lại Python loop. `collect()` kéo data về driver và phá distributed scale nếu result lớn.

### 4.12 Column expressions

PySpark style:

```python
from pyspark.sql import functions as F

clean = sdf.withColumn(
    "cell_id",
    F.upper(F.trim(F.col("cell_id"))),
)
```

Logic được biểu diễn bằng Spark Column expressions thay vì Python per-row function.

Đây là skill quan trọng sẽ học sâu ở Module 09.

### 4.13 Python UDF boundary – preview only

Python UDF cho phép custom Python logic chạy trong Spark context, nhưng có serialization/execution trade-offs và thường không nên là first choice nếu built-in Spark SQL functions giải quyết được.

Module 09 sẽ giải thích kỹ hơn. Hiện tại chỉ nhớ:

> Python code chạy “trên Spark rows” không đồng nghĩa cost giống native Spark expression.

### 4.14 Testing structure on Databricks

Databricks workspace hiện nhận diện pytest files theo naming convention.

Tổ chức:

```text
src/
  transforms.py

tests/
  test_transforms.py
```

Test pure Python functions không cần Spark. Test Spark transformation sẽ cần Spark context/fixture ở Module 09.

### 4.15 Thin notebook pattern

Notebook nên gần:

```python
from telecom_etl.config import load_config
from telecom_etl.pipeline import run

config = load_config()
run(config)
```

thay vì 1,000 lines parsing/validation/business rules viết thẳng trong cells.

---

## 5. Worked example – Local function → module → Databricks notebook → PySpark bridge

### Step 1 – Pure normalization

`src/telecom_etl/normalization.py`

```python
def normalize_cell_id(value: str) -> str:
    normalized = value.strip().upper()
    if not normalized:
        raise ValueError("cell_id is empty")
    return normalized
```

### Step 2 – Unit test

`tests/test_normalization.py`

```python
import pytest
from telecom_etl.normalization import normalize_cell_id


def test_normalize_cell_id():
    assert normalize_cell_id(" hn-01 ") == "HN-01"


def test_empty_cell_id():
    with pytest.raises(ValueError):
        normalize_cell_id("   ")
```

### Step 3 – Notebook import

```python
from telecom_etl.normalization import normalize_cell_id
```

### Step 4 – Spark equivalent mindset

Không loop Python trên Spark DataFrame. Với simple string normalization, dùng built-in Spark functions:

```python
from pyspark.sql import functions as F

sdf = sdf.withColumn(
    "cell_id",
    F.upper(F.trim("cell_id")),
)
```

Business semantics giống; execution implementation khác.

---

## 6. Hands-on lab

### A – Repo structure

Refactor Module 03 lab thành:

```text
labs/module-03-python/
├── src/
│   └── telecom_etl/
│       ├── __init__.py
│       ├── parsing.py
│       ├── validation.py
│       └── transforms.py
├── tests/
│   ├── test_parsing.py
│   └── test_validation.py
├── notebooks/
│   └── README.md
└── data/
```

### B – Thin notebook design

Viết pseudo-notebook tối đa 20 lines orchestration code:

1. import module;
2. resolve input location;
3. run processing;
4. display summary.

Business rules không viết lại trong notebook.

### C – Databricks file decision

Phân loại 6 artifacts:

```text
normalization.py
config.yaml
10KB demo.csv
500GB raw events/day
pytest file
temporary driver scratch file
```

Chọn workspace file / Git folder / governed data storage / ephemeral local storage và giải thích.

### D – Local vs Spark rewrite

Cho logic local:

```python
clean = [
    {
        **r,
        "cell_id": r["cell_id"].strip().upper(),
    }
    for r in records
    if r["duration_ms"] >= 0
]
```

Viết PySpark-style equivalent bằng `filter` + built-in column functions. Chưa cần chạy nếu chưa có Databricks environment.

### E – Anti-pattern review

Phân tích:

```python
rows = spark.table("prod.events").collect()
for row in rows:
    ...
```

Trả lời:

- dữ liệu đi đâu?
- failure nếu table lớn?
- rewrite theo distributed operation thế nào ở mức high-level?

---

## 7. Knowledge check – MCQ

**Q1.** Reusable business logic trên Databricks nên ưu tiên khi phù hợp:

A. copy vào mọi notebook.  
B. `.py` modules + imports + tests.  
C. screenshot code.  
D. hard-code vào widget.

**Q2.** PySpark DataFrame là:

A. list Python bắt buộc nằm hết trong driver.  
B. distributed dataset abstraction do Spark quản lý.  
C. pandas alias.  
D. CSV file.

**Q3.** `collect()` large Spark DataFrame có risk chính:

A. push toàn bộ driver code xuống executors.  
B. kéo data về driver và có thể gây memory failure.  
C. tạo index tự động.  
D. convert thành Delta table.

**Q4.** Với uppercase/trim simple column, first choice trong PySpark thường là:

A. built-in Spark column functions.  
B. collect + Python loop.  
C. write CSV rồi đọc lại.  
D. custom Python UDF bắt buộc.

**Q5.** Git folders dùng chủ yếu để:

A. thay distributed storage.  
B. integrate Git-based source control với Databricks development workflow.  
C. host Kafka broker.  
D. thay Unity Catalog.

---

## 8. Tự luận / Interview

1. Notebook vs Python module nên chia responsibility thế nào?
2. Workspace files và governed data storage khác vai trò ra sao?
3. Python loop trên list khác PySpark DataFrame transformation thế nào?
4. Vì sao `collect()` là code smell khi chưa biết output size?
5. Tại sao built-in Spark expressions thường nên ưu tiên trước Python UDF?
6. Databricks Git folders giúp workflow software engineering ở điểm nào?
7. Hãy mô tả đường chuyển từ Module 03 sang Module 09 bằng mental model của bạn.

---

## 9. Exit criteria

- [ ] Refactor code thành `src/` + `tests/`.
- [ ] Thin notebook <= 20 lines orchestration logic.
- [ ] Phân loại đúng artifact storage/location.
- [ ] Viết được PySpark-style rewrite cho local transformation đơn giản.
- [ ] Giải thích driver vs distributed execution boundary.
- [ ] Đạt ít nhất 4/5 MCQ.
