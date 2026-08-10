# Module 03 – Python for Data Engineers

> **Source policy:** Databricks-first. Module này lấy **Databricks Academy – Introduction to Python for Data Science and Data Engineering** và **Databricks for Python developers** làm backbone. Python Standard Library / Python Tutorial là **Supplementary prerequisite** cho các language fundamentals Databricks sử dụng nhưng không cần định nghĩa lại theo platform.

## Vì sao Python đứng ở đây?

SQL giúp ta tư duy theo relation và set. Python bổ sung khả năng viết ingestion code, validation, orchestration helpers, file/API processing, testing và reusable modules. Nhưng một Data Engineer không cần học mọi feature của Python trước khi làm dữ liệu.

Module này vì vậy chọn đúng subset cần cho Data Engineering:

1. object/type/mutability để tránh bug trạng thái;
2. collection/control flow để xử lý record;
3. function/module/class để tổ chức code;
4. iterator/generator để hiểu lazy, bounded-memory processing;
5. file/JSON/CSV/time để xử lý dữ liệu thực;
6. pandas cho workload bounded/local và ranh giới với distributed processing;
7. exceptions/logging/testing để code vận hành được;
8. Python development trên Databricks và bridge sang PySpark.

## Canonical source alignment

### Databricks Academy

- **Introduction to Python for Data Science and Data Engineering**  
  https://customer-academy.databricks.com/learn/courses/969/introduction-to-python-for-data-science-and-data-engineering
- **Data Engineer Learning Plan**  
  https://customer-academy.databricks.com/learn/learning-plans/10/data-engineer-learning-plan

Khóa Introduction to Python của Databricks bao phủ Python overview, variables/data types, complex data types, control flow, loops, functions, classes, libraries và pandas. Module 03 giữ backbone đó nhưng bổ sung engineering concerns phục vụ DE/VDT.

### Databricks Documentation

- Databricks for Python developers: https://docs.databricks.com/aws/en/languages/python
- PySpark on Databricks: https://docs.databricks.com/aws/en/pyspark/
- PySpark basics: https://docs.databricks.com/aws/en/pyspark/basics
- Workspace files: https://docs.databricks.com/aws/en/files/workspace
- Work with Python modules: https://docs.databricks.com/aws/en/files/workspace-modules
- Work with files: https://docs.databricks.com/aws/en/files/
- Python unit testing in workspace: https://docs.databricks.com/aws/en/files/python-unit-tests
- Databricks Git folders: https://docs.databricks.com/aws/en/repos/
- pandas on Databricks: https://docs.databricks.com/aws/en/pandas/

### Supplementary prerequisite – Python official

- Python Tutorial: https://docs.python.org/3/tutorial/
- Errors and Exceptions: https://docs.python.org/3/tutorial/errors.html
- Standard Library: https://docs.python.org/3/library/

## Learning outcomes

Hoàn thành Module 03, bạn phải có thể:

- Giải thích Python name/object/reference, mutable vs immutable và aliasing.
- Chọn `list`, `tuple`, `dict`, `set` theo semantics và complexity cơ bản.
- Viết control flow rõ, tránh nested-loop không cần thiết khi có hash lookup.
- Viết function nhỏ, pure khi có thể, dùng parameter/default/return hợp lý.
- Tách code thành module/package thay vì notebook monolith.
- Giải thích iterable, iterator, generator và lợi ích bounded memory.
- Đọc/ghi CSV, JSON/JSONL bằng context manager và xử lý encoding/schema/time.
- Chuẩn hóa timestamp/timezone và phân biệt event time với processing time.
- Dùng pandas đúng cho dataset bounded; biết khi nào phải chuyển sang Spark.
- Thiết kế exception taxonomy, retry boundary, logging và validation.
- Viết unit test cho transformation thuần và biết cách Databricks workspace phát hiện pytest tests.
- Tổ chức Python code trong workspace files/Git folders và import reusable modules.
- Giải thích Python driver code khác PySpark distributed transformation như thế nào.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm |
|---|---|---|
| 01 | Objects, Names, Types & Mutability | `a = b` thực sự làm gì và vì sao mutable state gây bug pipeline? |
| 02 | Collections, Control Flow & Complexity | Chọn data structure nào để code vừa đúng vừa không O(n²) vô ích? |
| 03 | Functions, Scope, Modules & Classes | Làm sao biến notebook/script thành code có thể reuse/test? |
| 04 | Iterables, Iterators & Generators | Làm sao xử lý stream/file lớn mà không load toàn bộ vào memory? |
| 05 | Files, CSV, JSON, Time & Data Contracts | Làm sao đọc dữ liệu ngoài đời mà giữ semantics/schema/time rõ ràng? |
| 06 | pandas for Bounded Data & Spark Boundary | Khi nào pandas đúng tool, khi nào phải chuyển distributed DataFrame? |
| 07 | Exceptions, Logging, Testing & Reliable Scripts | Code chạy được khác code vận hành được ở điểm nào? |
| 08 | Python on Databricks & Bridge to PySpark | Tổ chức code Python trên Databricks thế nào để sẵn sàng cho Spark? |

## Telecom Python lab

Lab nằm tại [`labs/module-03-python`](../../labs/module-03-python/README.md).

Case study tiếp tục hệ thống viễn thông:

```text
customers.csv
network_events.jsonl
        │
        ▼
Python ingestion / validation
        │
        ├── parse + normalize
        ├── reject/quarantine invalid rows
        ├── deduplicate by business rule
        └── aggregate bounded diagnostics
        │
        ▼
clean records + quality report
```

Mục tiêu Module 03 **không phải** xây distributed pipeline. Ta cố tình làm phiên bản bounded/local trước để hiểu correctness. Sang Module 09, cùng semantics này sẽ được chuyển sang PySpark DataFrame transformations.

## Quy tắc coding của module

- Không dùng `except Exception: pass`.
- Không dùng mutable default argument.
- Không mutate input object nếu contract không nói rõ.
- Không load file vô hạn vào `list` chỉ vì code ngắn hơn.
- Timestamp phải timezone-aware khi đại diện thời điểm thực.
- Mọi dedup phải ghi business key + winner rule.
- Transformation logic nên tách khỏi I/O để unit test được.
- Logging ghi context; không log secret/PII vô tội vạ.
- Notebook là nơi orchestration/interactive exploration; reusable logic ưu tiên `.py` modules.

## Suggested pace

| Tuần | Nội dung |
|---|---|
| 1 | Lesson 01–02 + coding drills |
| 2 | Lesson 03–04 + refactor/generator labs |
| 3 | Lesson 05–06 + file/pandas labs |
| 4 | Lesson 07–08 + mini ETL + Final Assessment |

## Pass criteria

- Hoàn thành 8 lesson labs.
- Hoàn thành telecom mini ETL.
- Final Assessment >= 75/100.
- Coding section >= 30/40.
- Không sai các fundamental: mutability/aliasing, iterator vs list, exception boundary, timezone, pandas vs Spark boundary.
