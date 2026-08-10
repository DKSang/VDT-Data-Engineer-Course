# VDT Data Engineer Foundations to Interview

> Lộ trình tự học Data Engineering theo hướng VDT-first: từ nền tảng hệ thống đến Big Data, streaming, orchestration, capstone và technical interview.

## Mục tiêu

Khóa học này không bắt đầu bằng việc học thuộc tool. Trọng tâm là hiểu **principle**, **fundamental**, cơ chế bên dưới, trade-off kiến trúc và khả năng giải thích quyết định kỹ thuật.

Mỗi lesson có cấu trúc cố định:

1. Learning objectives
2. Principles
3. Fundamentals
4. Worked example
5. Hands-on lab
6. Knowledge check – trắc nghiệm
7. Tự luận / interview questions
8. Exit criteria

## Curriculum

| Module | Chủ đề | Trạng thái |
|---|---|---|
| 01 | Data Engineering Foundations & System Thinking | ✅ Complete |
| 02 | SQL for Data Engineers | ✅ Complete |
| 03 | Python for Data Engineers | ⏳ Planned |
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

## Module đã hoàn thành

### Module 01 – Data Engineering Foundations & System Thinking

- Data Engineer role, value & lifecycle
- Architecture evolution
- Source systems
- Storage & file formats
- ETL/ELT, batch/streaming, full/incremental
- End-to-end pipeline design & trade-offs
- Final Assessment + Suggested Solutions

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

➡️ [`docs/module-02-sql-for-data-engineers`](docs/module-02-sql-for-data-engineers/README.md)

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
     Batch            Kafka
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

Airflow     → orchestration
Docker      → local runtime
Git/GitHub  → version control
Tests       → data/code quality
```

Module 02 đưa case study này vào PostgreSQL với các bảng customer, subscription, billing, network event và status history. Dataset được cố tình cài duplicate, late-arriving event và history fan-out để luyện các lỗi Data Engineering thực tế.

## Cách học

```text
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
Sai phần nào → quay lại fundamentals
```

Không chuyển sang module tiếp theo chỉ vì đã đọc hết tài liệu. Chỉ chuyển khi đạt **Exit Criteria** và có thể giải thích được các quyết định kỹ thuật bằng ngôn ngữ của chính mình.

> **Tools change. Principles survive.**