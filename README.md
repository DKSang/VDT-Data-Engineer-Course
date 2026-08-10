# VDT Data Engineer Foundations to Interview

> Lộ trình tự học Data Engineering theo hướng VDT-first, sử dụng **Databricks official documentation + Databricks Academy** làm learning backbone cho các chủ đề Data Engineering hiện đại.

## Mục tiêu

Khóa học không bắt đầu bằng việc học thuộc tool. Trọng tâm là hiểu **principle**, **fundamental**, cơ chế bên dưới, trade-off kiến trúc và khả năng giải thích quyết định kỹ thuật.

Khóa học áp dụng **Databricks-first source policy**:

- Databricks Documentation, Databricks Academy và official Databricks learning/certification content là nguồn canonical cho các chủ đề mà Databricks có tài liệu chính thức.
- Nội dung repo không sao chép course Databricks; repo diễn giải lại bằng tiếng Việt và thêm fundamental, telecom labs, failure reasoning, MCQ, tự luận và VDT interview questions.
- Với prerequisite Databricks giả định nhưng không dạy sâu (ví dụ DSA, Python language fundamentals, database internals, Linux), nguồn primary khác chỉ được dùng như **Supplementary prerequisite** và phải ghi nhãn rõ.

➡️ Xem quy ước đầy đủ tại [`SOURCE_POLICY.md`](SOURCE_POLICY.md).

Mỗi lesson có cấu trúc cố định:

1. Learning objectives
2. Source alignment
3. Principles
4. Fundamentals
5. Worked example
6. Hands-on lab
7. Knowledge check – trắc nghiệm
8. Tự luận / interview questions
9. Exit criteria

## Databricks learning backbone

Course được đối chiếu thường xuyên với các nguồn chính thức như:

- Data Engineering with Databricks / Get Started with Databricks for Data Engineering
- Data Engineering Concepts
- Databricks Data Engineer Learning Plan
- Introduction to Python for Data Science and Data Engineering
- Databricks SQL Language Reference
- Apache Spark on Databricks / PySpark DataFrames
- Delta Lake
- Lakeflow Connect
- Structured Streaming
- Lakeflow Spark Declarative Pipelines
- Lakeflow Jobs
- Unity Catalog
- Databricks Well-Architected Framework

Tên sản phẩm/feature trong lesson phải ưu tiên terminology hiện hành trong official Databricks documentation.

## Curriculum

| Module | Chủ đề | Trạng thái |
|---|---|---|
| 01 | Data Engineering Foundations & System Thinking | ✅ Complete – source audit started |
| 02 | SQL for Data Engineers | ✅ Complete – Databricks SQL primary reference |
| 03 | Python for Data Engineers | ✅ Complete – Databricks Academy Python backbone |
| 04 | DSA for Data Engineer Interviews | ⏳ Planned |
| 05 | Database Fundamentals | ⏳ Planned |
| 06 | Data Warehouse & Dimensional Modeling | ⏳ Planned |
| 07 | Linux, Git & Docker | ⏳ Planned |
| 08 | Distributed Systems & Hadoop | ⏳ Planned |
| 09 | Apache Spark & PySpark | ⏳ Planned |
| 10 | Databricks & Delta Lake | ⏳ Planned |
| 11 | Data Ingestion & CDC | ⏳ Planned |
| 12 | Kafka & Streaming | ⏳ Planned |
| 13 | Airflow & Orchestration | ⏳ Planned |
| 14 | Production Data Engineering | ⏳ Planned |
| 15 | Cloud & Microsoft Fabric Mapping | ⏳ Planned |
| 16 | Capstone – Telecom Data Platform | ⏳ Planned |
| 17 | VDT Technical Test & Interview | ⏳ Planned |

> Curriculum module names có thể được tinh chỉnh sau khi audit Databricks Learning Plan, nhưng các prerequisite phục vụ VDT như SQL, Python, DSA, database fundamentals vẫn được giữ.

## Module đã hoàn thành

### Module 01 – Data Engineering Foundations & System Thinking

- Data Engineer role, value & lifecycle
- Architecture evolution
- Source systems
- Storage & file formats
- ETL/ELT, batch/streaming, full/incremental
- End-to-end pipeline design & trade-offs
- Final Assessment + Suggested Solutions

Official Databricks alignment: Data Engineering concepts, Lakehouse Architecture, Medallion Architecture, Well-Architected Framework.

➡️ [`docs/module-01-data-engineering-foundations`](docs/module-01-data-engineering-foundations/README.md)

### Module 02 – SQL for Data Engineers

- Relational thinking, grain & logical query processing
- NULL, filtering, CASE & data types
- Aggregation, GROUP BY & HAVING
- JOINs, cardinality & set operations
- Subqueries, CTEs & EXISTS
- Window functions
- DE SQL patterns: dedup, latest row, incremental, SCD, quality checks
- Indexes, EXPLAIN & query performance
- PostgreSQL telecom lab + 30-question practice set
- Final Assessment + Suggested Solutions

**Primary SQL reference:** Databricks SQL Language Reference. PostgreSQL remains the local lab engine; PostgreSQL documentation is supplementary for engine-specific planner/index behavior.

➡️ [`docs/module-02-sql-for-data-engineers`](docs/module-02-sql-for-data-engineers/README.md)

### Module 03 – Python for Data Engineers

Databricks backbone: **Introduction to Python for Data Science and Data Engineering**, Databricks for Python developers, workspace files/modules, pandas on Databricks, unit testing and PySpark introductory documentation.

- Objects, names, types & mutability
- Collections, control flow & complexity
- Functions, scope, modules & classes
- Iterables, iterators & generators
- Files, CSV, JSON, timezone & data contracts
- pandas for bounded data & Spark boundary
- Exceptions, logging, testing & reliable scripts
- Python development on Databricks + bridge to PySpark
- Telecom Python ETL lab + sample dirty data + 30-question practice set
- Final Assessment 100 points + Suggested Solutions

Python language semantics that are not Databricks-specific use Python official documentation as **Supplementary prerequisite**. The module intentionally stops before Spark execution internals; those belong to Module 09.

➡️ [`docs/module-03-python-for-data-engineers`](docs/module-03-python-for-data-engineers/README.md)

## Case study xuyên suốt

Khóa học sử dụng một **Telecom Data Platform giả lập** để nối các module thành một hệ thống duy nhất:

```text
Operational DB / APIs / Network Events
               │
               ▼
         Ingestion Layer
               │
       ┌───────┴────────┐
       ▼                ▼
     Batch            Streaming
       │                │
       └───────┬────────┘
               ▼
          Spark/PySpark
               │
               ▼
        Bronze → Silver → Gold
               │
       ┌───────┴────────┐
       ▼                ▼
   Warehouse        Analytics
```

Ở các module Databricks, architecture trên sẽ được hiện thực bằng các primitive hiện hành như Delta Lake, Lakeflow Connect, Structured Streaming, Lakeflow Spark Declarative Pipelines, Lakeflow Jobs và Unity Catalog khi phù hợp.

Module 02 đưa case study vào PostgreSQL với các bảng customer, subscription, billing, network event và status history.

Module 03 đưa cùng domain sang Python local/bounded processing với dirty CSV/JSONL, explicit data contracts, quarantine, deterministic dedup, unit testing và Databricks development mapping. Mục tiêu là chứng minh business semantics trước khi scale bằng Spark.

## Cách học

```text
Official source alignment
          ↓
Principles / fundamentals
          ↓
Tự diễn giải lại không nhìn tài liệu
          ↓
Worked example
          ↓
Hands-on lab
          ↓
MCQ
          ↓
Tự luận / interview
          ↓
Sai phần nào → quay lại fundamentals/source
```

Không chuyển sang module tiếp theo chỉ vì đã đọc hết tài liệu. Chỉ chuyển khi đạt **Exit Criteria** và có thể giải thích được các quyết định kỹ thuật bằng ngôn ngữ của chính mình.

> **Databricks provides the canonical backbone. The course adds fundamentals and deliberate practice.**
