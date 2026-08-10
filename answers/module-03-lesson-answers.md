# Module 03 – Lesson Answer Key

> Đây là answer key cho MCQ và các điểm bắt buộc nên xuất hiện trong tự luận. Không dùng để học thuộc câu chữ.

## Lesson 01 – Objects, Names, Types & Mutability

MCQ: **1B, 2C, 3B, 4B, 5B**.

Điểm cần xuất hiện trong tự luận:

- Python assignment bind name tới object; `b = a` không imply copy.
- `==` so value/equality semantics; `is` so identity, điển hình `is None`.
- Mutable object shared qua aliases có thể tạo hidden side effect.
- Shallow copy chỉ copy outer container; nested mutables có thể vẫn shared.
- Mutable default được evaluate khi function definition thực thi nên state có thể sống qua nhiều calls.
- Câu “pass by reference/value” nên tránh oversimplify; argument passing có thể giải thích là object references được bound vào local parameter names.

## Lesson 02 – Collections, Control Flow & Complexity

MCQ: **1B, 2B, 3C, 4C, 5B**.

Điểm cần xuất hiện:

- list: ordered sequence/duplicates; dict: mapping; set: membership/uniqueness.
- dict/set lookup trung bình gần O(1); list membership O(n) intuition.
- nested join scans có thể O(n*m); build lookup map một lần thường giảm về O(n+m) intuition.
- Dict comprehension duplicate key có thể overwrite, do đó phải define/validate uniqueness.
- Grain vẫn cần trong Python aggregation.
- Comprehension không nên chứa complex branching/side effects khiến readability giảm.

## Lesson 03 – Functions, Scope, Modules & Classes

MCQ: **1B, 2B, 3A, 4B, 5B**.

Điểm cần xuất hiện:

- Function contract gồm input/output/side effect/failure.
- Pure/pure-ish transformations dễ test/reuse/reason hơn.
- Global mutable notebook state gây order-dependent behavior khi re-run.
- `.py` modules + imports phù hợp reusable logic; notebook phù hợp orchestration/exploration.
- Type hints hỗ trợ communication/tooling, không thay runtime validation.
- Class hữu ích khi state + behavior có cohesion; không cần convert mọi record thành class.
- Dependency injection giúp fake clock/network/sleeper và giữ tests deterministic.

## Lesson 04 – Iterables, Iterators & Generators

MCQ: **1B, 2B, 3B, 4B, 5B**.

Điểm cần xuất hiện:

- iterable có thể tạo iterator; iterator có state và `next`; generator là iterator được tạo bởi `yield`/generator expression.
- Generator lazy/bounded-memory hơn list materialization trong line-by-line workloads.
- `list(generator)` materialize remaining stream và generator không tự reset.
- Generator không cung cấp distributed execution/fault tolerance như Spark.
- Batch size trade-off throughput vs memory/retry granularity.
- Generator laziness chỉ là analogy hạn chế với Spark lazy execution, không phải cùng implementation.

## Lesson 05 – Files, CSV, JSON, Time & Data Contracts

MCQ: **1B, 2B, 3B, 4B, 5B**.

Điểm cần xuất hiện:

- CSV thường không mang native numeric/date type; parse explicit.
- JSONL line-oriented thuận tiện cho streaming/append/record-by-record processing.
- Parse/type conversion khác semantic/business validation.
- Event timestamp nên timezone-aware; normalize UTC internally khi phù hợp.
- Event time dùng business-window semantics; processing time phản ánh pipeline execution.
- Quarantine phải giữ line/source/error/context an toàn.
- Workspace files phù hợp code/small development files; production large data cần governed storage phù hợp.

## Lesson 06 – pandas for Bounded Data & Spark Boundary

MCQ: **1B, 2B, 3B, 4B, 5B**.

Điểm cần xuất hiện:

- pandas chủ yếu single-process memory; PySpark DataFrame distributed Spark abstraction.
- pandas hợp bounded/local data; Spark hợp distributed scale/workloads.
- Conversion large Spark result về pandas/driver có OOM risk.
- Built-in/vectorized pandas operations thường ưu tiên trước row-wise `apply` khi phù hợp.
- pandas API on Spark giữ Spark execution semantics dù API pandas-like.
- Business semantics/grain phải giữ nhất quán giữa Python/pandas/SQL/Spark.

## Lesson 07 – Exceptions, Logging, Testing & Reliable Scripts

MCQ: **1B, 2B, 3B, 4A, 5A**.

Điểm cần xuất hiện:

- Permanent validation error không nên retry như transient timeout.
- Catch exception cụ thể; catch rộng có thể nuốt bug ngoài intended policy.
- Exception chaining giữ root cause.
- Retry cần backoff/jitter theo service policy và phải reasoning idempotency.
- Logs cần run/source/stage/error/context nhưng không secret/PII vô nguyên tắc.
- Unit tests nên deterministic, fake/inject clock/network/sleeper.
- Databricks workspace phát hiện pytest-style naming và khuyến khích reusable source/test files.

## Lesson 08 – Python on Databricks & Bridge to PySpark

MCQ: **1B, 2B, 3B, 4A, 5B**.

Điểm cần xuất hiện:

- Notebook nên mỏng khi logic cần reuse/test; `.py` modules chứa reusable logic.
- Workspace files/Git folders phục vụ development/source assets; governed storage phục vụ data phù hợp.
- PySpark DataFrame không phải Python list/pandas object; Spark quản lý distributed computation.
- `collect()` đưa result về driver và là risk nếu size chưa bounded.
- Built-in Spark expressions thường ưu tiên trước Python UDF cho simple transformations.
- Git folders đưa Git source control workflow vào Databricks interactive development; production CI/CD còn có lớp deployment riêng.
