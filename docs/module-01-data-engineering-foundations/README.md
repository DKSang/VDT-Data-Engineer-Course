# Module 01 – Data Engineering Foundations & System Thinking

## Vì sao module này đứng đầu?

Một fresher dễ rơi vào bẫy học Data Engineering bằng danh sách công cụ: Spark, Kafka, Airflow, Databricks, Docker… nhưng không hiểu công cụ đang giải quyết vấn đề nào. Module này xây “mental model” trước: dữ liệu sinh ra ở đâu, đi qua những giai đoạn nào, tại sao hệ thống phải lưu trữ/biến đổi/phục vụ theo những cách khác nhau, và cách đánh giá trade-off.

Đây cũng là nền để trả lời interview theo kiểu reasoning thay vì học thuộc định nghĩa.

## Learning outcomes

Hoàn thành module, bạn phải có thể:

- Mô tả vai trò Data Engineer và giá trị mà pipeline tạo ra.
- Vẽ Data Engineering Lifecycle từ source đến serving.
- Phân biệt OLTP/OLAP, database/data warehouse/data lake/lakehouse ở mức nguyên lý.
- Phân tích đặc tính source system trước khi ingest.
- Giải thích row-oriented vs columnar và tại sao Parquet phù hợp analytics.
- So sánh ETL/ELT, batch/streaming, full/incremental theo trade-off.
- Thiết kế một pipeline end-to-end đơn giản và bảo vệ lựa chọn kiến trúc.

## Lesson map

| Lesson | Chủ đề | Câu hỏi trọng tâm |
|---|---|---|
| 01 | Role, Value & Lifecycle | Data Engineer thực sự tạo ra giá trị gì? |
| 02 | Architecture Evolution | Tại sao kiến trúc dữ liệu tiến hóa từ DB → DW → Lake → Lakehouse? |
| 03 | Source Systems | Trước khi ingest một source, cần biết điều gì? |
| 04 | Storage & File Formats | Tại sao cách lưu trữ ảnh hưởng trực tiếp tới hiệu năng và chi phí? |
| 05 | ETL/ELT & Batch/Streaming | Khi nào chọn mỗi pattern? |
| 06 | End-to-End Design | Làm sao ghép các principle thành một kiến trúc hợp lý? |

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

Module 01 chưa triển khai Spark/Kafka/Airflow. Ta chỉ thiết kế và lập luận. Các tool cụ thể sẽ xuất hiện sau khi principle đã rõ.
