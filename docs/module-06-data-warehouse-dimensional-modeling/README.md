# Module 06 – Data Warehouse & Dimensional Modeling

> **Classification:** Databricks-first data warehousing module with supplementary dimensional-modeling fundamentals.

Module này nối trực tiếp Module 05 (normalized operational databases) với các module Spark/Delta/Lakeflow phía sau. Trọng tâm không phải học thuộc “star schema đẹp”, mà là biến business process thành một analytical model có **grain rõ, measures đúng semantics, dimensions dùng lại được, history có chủ đích và incremental load đáng tin**.

---

## 1. Source alignment

### Primary Databricks sources

- Data warehousing architecture  
  https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- Data modeling on Databricks  
  https://docs.databricks.com/aws/en/transform/data-modeling
- Medallion architecture  
  https://docs.databricks.com/aws/en/lakehouse/medallion
- ETL in Databricks SQL / AUTO CDC  
  https://docs.databricks.com/aws/en/sql/get-started/sql-etl-tutorial
- Lakeflow Connect SCD history tracking  
  https://docs.databricks.com/aws/en/ingestion/lakeflow-connect/scd
- Lakeflow Declarative Pipelines CDC tutorial  
  https://docs.databricks.com/aws/en/ldp/tutorial-pipelines
- Databricks SQL / Delta tables / Unity Catalog documentation as referenced per lesson.

### Databricks Academy alignment

- Get Started with Databricks for Data Engineering
- Databricks Get Started Days: Data Engineering + SQL Analytics and BI
- Data Engineer learning content covering Delta tables, medallion architecture, Databricks SQL and data warehousing.

### Supplementary prerequisite sources

Databricks documents **where and why** dimensional models fit in the lakehouse, but does not attempt to be a complete textbook for every classic dimensional-modeling concept. Therefore the course supplements concepts such as fact-table types, additive measures, conformed dimensions and bus matrices using dimensional-modeling literature. These concepts are clearly marked as vendor-neutral fundamentals and never override Databricks-specific platform behavior.

---

## 2. Databricks architecture position

Databricks supports more than one modeling style. A practical architecture taught in this module is:

```text
Bronze
raw / replayable source-aligned data
        │
        ▼
Silver
validated + integrated + detailed data
can include normalized warehouse / 3NF-style core
        │
        ▼
Gold
business-facing data marts
star / snowflake / aggregates / semantic serving
```

Important:

- **Silver is not automatically a star schema.**
- **Gold is not automatically one giant aggregate table.**
- A dimensional mart exists to answer a defined business process efficiently and consistently.
- Medallion layers describe increasing data quality and business usefulness; dimensional modeling describes analytical relationships and grain. They solve related but different problems.

---

## 3. Learning outcomes

Sau Module 06, bạn phải có thể:

- phân biệt OLTP normalized model, enterprise warehouse core và analytical data mart;
- xác định **business process** và **grain** trước khi chọn facts/dimensions;
- phân biệt transaction fact, periodic snapshot fact và accumulating snapshot fact;
- phân loại measures thành additive, semi-additive và non-additive;
- thiết kế dimension với natural key, surrogate key và history semantics rõ;
- giải thích role-playing, degenerate, junk và conformed dimensions;
- thiết kế date dimension và point-in-time joins;
- triển khai SCD Type 1/2 reasoning trên Delta;
- xử lý unknown/late-arriving dimension members;
- thiết kế bus matrix cho nhiều business processes;
- xây Gold star schema từ Silver tables trên Databricks;
- dùng `MERGE`, AUTO CDC awareness và validation để incremental-load dimensions/facts;
- giải thích vì sao Databricks có thể dùng star/snowflake hiệu quả hơn heavily-normalized serving model;
- bảo vệ một dimensional design trong system-design/interview discussion.

---

## 4. Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm |
|---|---|---|
| 01 | Warehouse Layers, Business Process & Grain | Ta đang model business process nào và một row đại diện điều gì? |
| 02 | Fact Tables & Measures | Sự kiện nào trở thành fact, measure có thể aggregate thế nào? |
| 03 | Dimensions & Keys | Context analytical nên được lưu, định danh và dùng lại ra sao? |
| 04 | Star Schema Design Workflow | Từ requirement đến một star schema hoàn chỉnh như thế nào? |
| 05 | Slowly Changing Dimensions & Late Data | Khi dimension thay đổi theo thời gian, fact phải thấy version nào? |
| 06 | Conformed Dimensions, Bus Matrix & Data Marts | Nhiều marts giữ cùng một business vocabulary thế nào? |
| 07 | Incremental Dimension/Fact Loading on Databricks | Làm sao cập nhật Gold đúng khi source thay đổi và data đến muộn? |
| 08 | Gold Serving Models on Databricks | Đưa dimensional model vào medallion/Delta/Databricks SQL ra sao? |

---

## 5. Telecom analytical case study

Business processes chính:

```text
Billing
  → doanh thu / giao dịch / phương thức thanh toán

Subscriptions
  → lifecycle gói cước / activation / cancellation

Network Operations
  → call-end/drop quality metrics theo tower/time/location
```

Gold target tables:

```text
dim_date
dim_customer
dim_plan
dim_tower

fact_billing_transaction
fact_subscription_snapshot
fact_network_daily
```

Mục tiêu của module không phải tạo schema “nhiều bảng nhất”, mà tạo **một schema có thể giải thích được grain và metric semantics cho từng fact**.

---

## 6. Lab

Primary lab chạy trên **Databricks SQL / Databricks Runtime + Delta tables**.

```text
labs/module-06-warehouse/
├── README.md
├── databricks-setup.sql
├── practice-set.md
└── modeling-template.md
```

Lab đi từ Silver source-aligned tables đến Gold dimensions/facts. Người học phải tự viết validation cho:

- fact grain uniqueness;
- surrogate/business key mapping;
- orphan foreign keys;
- SCD2 overlap;
- one-current-version rule;
- reconciliation revenue;
- late-arriving dimension handling.

---

## 7. Cách học

Với mọi bài modeling, trước SQL phải ghi:

```text
Business process:
Business question:
Fact grain:
Dimensions:
Measures:
Additivity:
History requirement:
Late-data rule:
Validation:
```

Nếu chưa trả lời được `Fact grain`, chưa được viết fact table.

---

## 8. Suggested pace

| Tuần | Nội dung |
|---|---|
| 1 | Lesson 01–02 + grain/fact drills |
| 2 | Lesson 03–04 + design first star schema |
| 3 | Lesson 05–06 + SCD/bus matrix |
| 4 | Lesson 07–08 + Databricks lab + Final Assessment |

---

## 9. Exit criteria của module

- Final Assessment >= **75/100**.
- Modeling/System Design >= **30/40**.
- Không được sai các fundamental:
  - grain trước facts;
  - natural key != surrogate key;
  - SCD1 != SCD2;
  - fact foreign key phải map đúng dimension version;
  - additive/semi-additive/non-additive;
  - conformed dimension meaning;
  - late-arriving data và retry phải có explicit rule.
