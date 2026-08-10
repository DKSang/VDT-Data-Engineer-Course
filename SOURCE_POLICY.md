# Source Policy – Databricks-First Curriculum

> Quyết định kiến trúc nội dung của khóa học: **Databricks official documentation và Databricks Academy là canonical sources cho toàn bộ phần Data Engineering mà Databricks có tài liệu/đào tạo chính thức.**

## 1. Mục tiêu của policy

Khóa học này không tự xây một định nghĩa Data Engineering riêng rồi mới tìm tài liệu để khớp vào. Từ phiên bản này, terminology, concept map, recommended patterns và thứ tự học của các chủ đề Data Engineering phải được đối chiếu trước với tài liệu do Databricks phát hành.

Điều này giúp khóa học:

- bám một hệ sinh thái Data Engineering hiện đại và có curriculum chính thức;
- dùng terminology đang được Databricks sử dụng hiện tại;
- nối liền SQL → Spark/PySpark → Delta Lake → ingestion → streaming → orchestration → governance → production;
- tận dụng Databricks Academy Data Engineer Learning Plan như một learning backbone;
- vẫn giữ mục tiêu riêng của repo: giải thích sâu fundamentals, system reasoning và chuẩn bị VDT.

## 2. Source hierarchy

Khi viết hoặc sửa một lesson, ưu tiên nguồn theo thứ tự sau.

### Tier 1 – Canonical

1. **Databricks Documentation** – `docs.databricks.com`
2. **Databricks Academy / Databricks Learning** – `customer-academy.databricks.com`
3. **Databricks official certification guides / learning pages** – `databricks.com/learn`

Tier 1 quyết định:

- terminology;
- platform concepts;
- behavior của Databricks SQL / Runtime / Lakeflow / Delta Lake;
- recommended patterns và best practices;
- nội dung/lộ trình mà Databricks coi là Data Engineer skill.

### Tier 2 – Primary supplementary sources

Chỉ dùng khi Databricks **giả định prerequisite nhưng không dạy đủ fundamental đó**.

Ví dụ:

- Python language fundamentals;
- DSA;
- database internals;
- Linux/Git/Docker fundamentals;
- Hadoop internals;
- Kafka protocol concepts khi cần đào sâu ngoài integration trên Databricks.

Nguồn Tier 2 phải là tài liệu primary/official của công nghệ tương ứng nếu có. Nội dung sử dụng Tier 2 phải được ghi rõ là **Supplementary prerequisite**, không được trình bày như nội dung phát hành bởi Databricks.

### Tier 3 – Explanatory references

Sách, bài blog, course bên thứ ba chỉ được dùng để bổ sung cách diễn giải hoặc bài tập sau khi Tier 1/Tier 2 đã xác lập concept. Không dùng Tier 3 để override Databricks official behavior hoặc terminology.

## 3. Cách sử dụng Databricks source

Khóa học **không sao chép nguyên văn** lesson/course của Databricks Academy.

Mỗi lesson trong repo phải chuyển source thành trải nghiệm học riêng:

```text
Databricks official source
        ↓
Canonical terminology & behavior
        ↓
Principle / fundamental explanation bằng tiếng Việt
        ↓
Worked example riêng
        ↓
Telecom hands-on lab riêng
        ↓
MCQ + tự luận + VDT interview reasoning
```

Source trả lời câu hỏi **“concept/tool hoạt động và được Databricks định nghĩa thế nào?”**.

Repo phải trả lời thêm:

- Vì sao concept tồn tại?
- Problem nào dẫn tới nó?
- Assumption nào phải đúng?
- Failure mode là gì?
- Trade-off là gì?
- Nếu bỏ Databricks UI/managed service đi thì fundamental bên dưới là gì?
- Interviewer có thể hỏi ngược lại thế nào?

## 4. Canonical Databricks source map

### Data Engineering backbone

- Data engineering with Databricks  
  https://docs.databricks.com/aws/en/data-engineering/
- Data engineering concepts  
  https://docs.databricks.com/aws/en/data-engineering/concepts
- Databricks Data Engineer Learning Plan  
  https://customer-academy.databricks.com/learn/learning-plans/10/data-engineer-learning-plan

### Architecture & Lakehouse

- Databricks architecture  
  https://docs.databricks.com/aws/en/getting-started/architecture
- What is a data lakehouse?  
  https://docs.databricks.com/aws/en/lakehouse/
- Medallion architecture  
  https://docs.databricks.com/aws/en/lakehouse/medallion
- Databricks well-architected framework  
  https://docs.databricks.com/aws/en/lakehouse-architecture/well-architected

### SQL

- Databricks SQL language reference  
  https://docs.databricks.com/aws/en/sql/language-manual
- Window functions  
  https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-window-functions

### Spark / PySpark

- Apache Spark overview on Databricks  
  https://docs.databricks.com/aws/en/spark/
- DataFrame tutorial  
  https://docs.databricks.com/aws/en/getting-started/dataframes

### Delta Lake

- Delta Lake on Databricks  
  https://docs.databricks.com/aws/en/delta

### Ingestion

- Data Ingestion with Lakeflow Connect – Databricks Academy
- Lakeflow Connect documentation
- ETL tutorial with Spark / Auto Loader  
  https://docs.databricks.com/aws/en/getting-started/etl-quick-start

### Batch, streaming & pipelines

- Structured Streaming concepts  
  https://docs.databricks.com/aws/en/structured-streaming/concepts
- Lakeflow Spark Declarative Pipelines concepts  
  https://docs.databricks.com/aws/en/ldp/concepts
- Lakeflow pipelines ETL tutorial  
  https://docs.databricks.com/aws/en/getting-started/data-pipeline-get-started

### Orchestration

- Deploy Workloads with Lakeflow Jobs – Databricks Academy
- Lakeflow Jobs documentation through the Data Engineering documentation tree

### Governance / production

- Unity Catalog documentation and Databricks Academy Data Engineer learning content
- Databricks well-architected framework

> Các URL/course name có thể được Databricks đổi theo thời gian. Trước khi tạo một module mới phải kiểm tra lại official docs/Academy để dùng terminology hiện hành.

## 5. Terminology policy

Luôn dùng **tên hiện tại trong official Databricks documentation** làm tên chính.

Ví dụ hiện tại:

- **Lakeflow Connect** – ingestion;
- **Lakeflow Spark Declarative Pipelines** – declarative batch/streaming pipelines;
- **Lakeflow Jobs** – orchestration;
- **Delta Lake** – storage/table layer;
- **Unity Catalog** – governance;
- **Databricks Runtime for Apache Spark** – Spark execution environment.

Nếu một thuật ngữ cũ vẫn thường xuất hiện trong interview hoặc tài liệu lịch sử, ghi theo format:

```text
Tên hiện tại (formerly: tên cũ)
```

Không xây lesson mới quanh terminology đã deprecated chỉ vì course bên thứ ba còn dùng tên đó.

## 6. Required source section cho mỗi module

Từ Module 03 trở đi, mỗi `README.md` module phải có:

```markdown
## Official Databricks sources

### Primary
- ...

### Databricks Academy alignment
- ...

### Supplementary prerequisites
- ... (chỉ khi Databricks không bao phủ đủ)
```

Mỗi lesson nên có mục `Source alignment` ngắn ghi source nào quyết định concept của bài.

## 7. Quy tắc khi source và kiến thức phổ biến khác nhau

1. Với behavior của Databricks platform: **official Databricks docs thắng**.
2. Với Apache Spark behavior chung nhưng Databricks có extension: tách rõ `Apache Spark fundamental` và `Databricks-specific behavior`.
3. Với kiến thức không thuộc Databricks: không gán nguồn Databricks; dùng supplementary primary source.
4. Nếu official source thay đổi: cập nhật course và ghi chú migration/renaming khi cần.

## 8. Ảnh hưởng tới curriculum hiện tại

### Module 01

Giữ nội dung fundamentals hiện có nhưng audit terminology/architecture theo:

- Data engineering concepts;
- lakehouse architecture;
- medallion architecture;
- well-architected framework.

### Module 02

Databricks SQL Language Reference trở thành **primary SQL reference** cho nội dung khóa. PostgreSQL tiếp tục là local lab engine và PostgreSQL docs chỉ dùng để giải thích behavior riêng của lab engine (`EXPLAIN`, indexes, planner...).

### Module 03+

Mọi module phải bắt đầu bằng bước **Databricks source discovery** trước khi thiết kế lesson map.

Đặc biệt Module 09–14 sẽ bám rất sát Data Engineer learning backbone của Databricks:

```text
Spark/PySpark
   ↓
Delta Lake
   ↓
Lakeflow Connect / ingestion
   ↓
Structured Streaming
   ↓
Lakeflow Spark Declarative Pipelines
   ↓
Lakeflow Jobs
   ↓
Unity Catalog / production practices
```

## 9. Nguyên tắc cuối cùng

> **Databricks provides the canonical learning backbone; this repo adds fundamentals, deliberate practice, telecom labs, failure reasoning, and VDT interview depth.**
