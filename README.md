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

| Module | Chủ đề |
|---|---|
| 01 | Data Engineering Foundations & System Thinking |
| 02 | SQL for Data Engineers |
| 03 | Python for Data Engineers |
| 04 | DSA for Data Engineer Interviews |
| 05 | Database Fundamentals |
| 06 | Data Warehouse & Dimensional Modeling |
| 07 | Linux, Git & Docker |
| 08 | Distributed Systems & Hadoop |
| 09 | Apache Spark & PySpark |
| 10 | Databricks & Delta Lake |
| 11 | Data Ingestion & CDC |
| 12 | Kafka & Streaming |
| 13 | Airflow & Orchestration |
| 14 | Production Data Engineering |
| 15 | Cloud & Microsoft Fabric Mapping |
| 16 | Capstone – Telecom Data Platform |
| 17 | VDT Technical Test & Interview |

## Module đang triển khai

### Module 01 – Data Engineering Foundations & System Thinking

- Lesson 01 – Data Engineer: Role, Value & Data Lifecycle
- Lesson 02 – Data Architecture Evolution
- Lesson 03 – Source Systems & Data Characteristics
- Lesson 04 – Storage Systems & File Formats
- Lesson 05 – ETL vs ELT, Batch vs Streaming, Full vs Incremental
- Lesson 06 – End-to-End Pipeline Design & Trade-offs
- Final Assessment + Suggested Solutions

Xem chi tiết tại [`docs/module-01-data-engineering-foundations`](docs/module-01-data-engineering-foundations/README.md).

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

Không chuyển sang module tiếp theo chỉ vì đã đọc hết tài liệu. Chỉ chuyển khi đạt **Exit Criteria** và có thể giải thích được các quyết định kiến trúc bằng ngôn ngữ của chính mình.

> **Tools change. Principles survive.**
