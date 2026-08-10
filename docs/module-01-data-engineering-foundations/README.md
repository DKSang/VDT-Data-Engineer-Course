# Module 01 – Data Engineering Foundations & System Thinking

## Official Databricks sources

### Primary

Module này được audit theo các nguồn Databricks chính thức:

- Data Engineering with Databricks  
  https://docs.databricks.com/aws/en/data-engineering/
- Data Engineering Concepts  
  https://docs.databricks.com/aws/en/data-engineering/concepts
- Databricks Architecture  
  https://docs.databricks.com/aws/en/getting-started/architecture
- What is a Data Lakehouse?  
  https://docs.databricks.com/aws/en/lakehouse/
- Medallion Architecture  
  https://docs.databricks.com/aws/en/lakehouse/medallion
- Databricks Well-Architected Framework  
  https://docs.databricks.com/aws/en/lakehouse-architecture/well-architected

### Databricks Academy alignment

- Databricks Data Engineer Learning Plan  
  https://customer-academy.databricks.com/learn/learning-plans/10/data-engineer-learning-plan

### Source note

Module 01 giải thích rộng hơn phạm vi một sản phẩm Databricks cụ thể vì mục tiêu là xây system thinking. Tuy nhiên terminology về lakehouse, medallion, batch/streaming và Data Engineering workflow phải được đối chiếu với official Databricks sources trước khi mở rộng bằng reasoning riêng của khóa.

---

## Vì sao module này đứng đầu?

Một fresher dễ rơi vào bẫy học Data Engineering bằng danh sách công cụ: Spark, Kafka, Airflow, Databricks, Docker… nhưng không hiểu công cụ đang giải quyết vấn đề nào. Module này xây “mental model” trước: dữ liệu sinh ra ở đâu, đi qua những giai đoạn nào, tại sao hệ thống phải lưu trữ/biến đổi/phục vụ theo những cách khác nhau, và cách đánh giá trade-off.

Đây cũng là nền để trả lời interview theo kiểu reasoning thay vì học thuộc định nghĩa.

Databricks hiện mô tả Data Engineering trên nền tảng của họ qua một chuỗi thống nhất gồm ingestion, transformation và orchestration, với Lakeflow là nhóm giải pháp Data Engineering end-to-end; Spark/Structured Streaming và Delta Lake nằm ở phần compute/storage foundation. Module 01 chưa dạy các feature này, nhưng dùng mental model tương thích để các module sau nối vào tự nhiên.

## Learning outcomes

Hoàn thành module, bạn phải có thể:

- Mô tả vai trò Data Engineer và giá trị mà pipeline tạo ra.
- Vẽ Data Engineering Lifecycle từ source đến serving.
- Phân biệt OLTP/OLAP, database/data warehouse/data lake/lakehouse ở mức nguyên lý.
- Phân tích đặc tính source system trước khi ingest.
- Giải thích row-oriented vs columnar và tại sao columnar formats hữu ích cho analytics.
- So sánh ETL/ELT, batch/streaming, full/incremental theo trade-off.
- Giải thích Medallion Architecture như một data design pattern, không phải quy tắc bắt buộc cho mọi hệ thống.
- Thiết kế một pipeline end-to-end đơn giản và bảo vệ lựa chọn kiến trúc.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm | Databricks alignment |
|---|---|---|---|
| 01 | Role, Value & Lifecycle | Data Engineer thực sự tạo ra giá trị gì? | Data Engineering overview/concepts |
| 02 | Architecture Evolution | Tại sao kiến trúc dữ liệu tiến hóa từ DB → DW → Lake → Lakehouse? | Lakehouse architecture |
| 03 | Source Systems | Trước khi ingest một source, cần biết điều gì? | Data Engineering / ingestion concepts |
| 04 | Storage & File Formats | Tại sao cách lưu trữ ảnh hưởng trực tiếp tới hiệu năng và chi phí? | Delta Lake / supported formats |
| 05 | ETL/ELT & Batch/Streaming | Khi nào chọn mỗi pattern? | Data Engineering concepts / Structured Streaming |
| 06 | End-to-End Design | Làm sao ghép các principle thành một kiến trúc hợp lý? | Architecture / Well-Architected Framework |

## Case study xuyên suốt module

Ta dùng một hệ thống giả lập viễn thông:

- `customer_db`: PostgreSQL chứa thông tin thuê bao.
- `billing_db`: giao dịch cước.
- `network_events`: sự kiện mạng phát sinh liên tục.
- `csv_reference`: danh mục cell tower và khu vực.

Mục tiêu downstream:

1. Dashboard doanh thu theo ngày/tỉnh.
2. Phát hiện cell tower có tỷ lệ lỗi cao gần real-time.
3. Dataset phục vụ mô hình churn trong tương lai.

Module 01 chưa triển khai Spark/Kafka/Lakeflow. Ta chỉ thiết kế và lập luận. Các tool/feature cụ thể sẽ xuất hiện sau khi principle đã rõ.

## Boundary của module

Module này **không khẳng định** mọi pipeline nên dùng lakehouse hoặc Bronze/Silver/Gold. Databricks mô tả Medallion Architecture như một pattern tổ chức dữ liệu nhằm cải thiện dần structure/quality qua các layer. Trong khóa học, ta dùng pattern này khi nó giúp separation of concerns, audit/replay và serving, nhưng vẫn phải bảo vệ quyết định bằng requirements và trade-offs.

## Exit criteria cấp module

Trước khi sang Module 02, bạn nên có thể:

- vẽ lifecycle/source→ingestion→processing→storage→serving;
- giải thích lakehouse giải bài toán gì so với lake/warehouse;
- phân biệt batch và streaming bằng latency/state/failure reasoning;
- giải thích Bronze/Silver/Gold bằng mục tiêu dữ liệu chứ không chỉ thuộc tên layer;
- thiết kế architecture nhỏ và nêu ít nhất 5 trade-offs/failure modes.
