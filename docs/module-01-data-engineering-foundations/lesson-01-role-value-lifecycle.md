# Lesson 01 – Data Engineer: Role, Value & Data Lifecycle

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích Data Engineering bằng **đầu vào → trách nhiệm → đầu ra**, không chỉ bằng tên tool.
- Phân biệt Data Engineer với Software Engineer, Data Analyst, Data Scientist.
- Mô tả Data Engineering Lifecycle.
- Nhận ra các thuộc tính chất lượng quan trọng: correctness, completeness, freshness, reliability, lineage.
- Phân tích một yêu cầu business và chuyển thành các yêu cầu dữ liệu sơ bộ.

---

## 2. Principles

### Principle 1 – Data Engineering tạo ra **dữ liệu đáng tin cậy**, không chỉ di chuyển dữ liệu

Một pipeline copy dữ liệu thành công về mặt kỹ thuật vẫn có thể thất bại về mặt sản phẩm nếu:

- mất bản ghi;
- duplicate bản ghi;
- schema thay đổi nhưng pipeline không phát hiện;
- dữ liệu đến trễ;
- đơn vị đo sai;
- downstream không biết nguồn gốc dữ liệu.

Vì vậy output thật sự của Data Engineer không phải “file đã copy xong”, mà là **data product có thể sử dụng an toàn**.

### Principle 2 – Hãy nghĩ theo lifecycle trước khi nghĩ theo tool

Tool thay đổi nhanh. Lifecycle thay đổi chậm hơn:

```text
Source/Generation
      ↓
Ingestion
      ↓
Storage
      ↓
Transformation
      ↓
Serving
      ↓
Analytics / ML / Product
```

Observability, security, governance và orchestration cắt ngang toàn bộ lifecycle.

### Principle 3 – Downstream trust là thước đo quan trọng

Nếu analyst luôn phải hỏi “bảng này hôm nay đã refresh chưa?”, hoặc “field này có duplicate không?”, hệ thống chưa tạo được niềm tin dù công nghệ hiện đại đến đâu.

---

## 3. Fundamentals

### 3.1 Data Engineer là ai?

Một Data Engineer xây dựng và vận hành các hệ thống đưa dữ liệu từ trạng thái **thô, phân tán, khó tin cậy** sang trạng thái **có cấu trúc, truy vết được, đủ chất lượng và sẵn sàng cho downstream**.

Có thể mô hình hóa công việc như sau:

```text
Raw Sources
   ↓
[Acquire]  lấy dữ liệu
   ↓
[Store]    lưu dữ liệu
   ↓
[Process]  làm sạch/chuẩn hóa/kết hợp
   ↓
[Serve]    cung cấp dataset/interface phù hợp
   ↓
[Operate]  theo dõi, retry, kiểm tra chất lượng
```

### 3.2 So sánh các vai trò

| Vai trò | Câu hỏi chính | Output thường gặp |
|---|---|---|
| Software Engineer | Làm sao xây sản phẩm/hệ thống giao dịch đúng và ổn định? | API, service, application |
| Data Engineer | Làm sao biến dữ liệu phân tán thành dữ liệu đáng tin để dùng tiếp? | Pipeline, tables, datasets, platform |
| Data Analyst | Dữ liệu nói gì về business? | Dashboard, report, insight |
| Data Scientist | Có thể dự đoán/tối ưu điều gì từ dữ liệu? | Model, experiment, feature set |

Ranh giới không tuyệt đối. Ở team nhỏ một người có thể làm nhiều vai trò.

### 3.3 Data Engineering Lifecycle

#### Source/Generation

Dữ liệu có thể sinh từ:

- transaction database;
- application log;
- sensor/network event;
- REST API;
- CSV/Excel;
- third-party platform.

#### Ingestion

Đưa dữ liệu từ source tới hệ thống dữ liệu. Hai câu hỏi đầu tiên:

1. Batch hay stream?
2. Full load hay incremental?

#### Storage

Lưu dữ liệu theo mục đích:

- database cho transaction;
- warehouse cho analytical query;
- object storage/data lake cho dữ liệu quy mô lớn và đa định dạng;
- lakehouse kết hợp object storage + table semantics.

#### Transformation

Các công việc phổ biến:

- cast data types;
- standardize units;
- deduplicate;
- join dimensions;
- calculate metrics;
- apply business rules.

#### Serving

Dữ liệu cuối cùng có thể phục vụ:

- BI/dashboard;
- ad-hoc SQL;
- API;
- machine learning;
- reverse ETL;
- downstream pipeline khác.

### 3.4 Undercurrents – các mối quan tâm xuyên suốt

Một hệ thống dữ liệu tốt luôn phải nghĩ tới:

- **Security** – ai được truy cập gì?
- **Data quality** – dữ liệu có đúng/đủ/tươi không?
- **Observability** – pipeline có đang khỏe không?
- **Orchestration** – task chạy theo thứ tự nào, retry ra sao?
- **Governance/Lineage** – dữ liệu từ đâu tới, ai sở hữu?
- **Software engineering** – code có test, version control, deploy được không?

### 3.5 Data quality dimensions cơ bản

| Dimension | Câu hỏi |
|---|---|
| Correctness/Accuracy | Giá trị có đúng với thực tế/business rule không? |
| Completeness | Có thiếu record/field quan trọng không? |
| Uniqueness | Có duplicate không? |
| Freshness | Dữ liệu có đến đúng thời gian mong đợi không? |
| Consistency | Cùng một concept có được biểu diễn nhất quán không? |
| Validity | Dữ liệu có thỏa format/range/schema không? |

---

## 4. Worked example – Telecom Revenue Dashboard

### Yêu cầu business

> “Ban vận hành muốn xem doanh thu data/mobile theo tỉnh, cập nhật trước 8:00 mỗi sáng.”

### Phân rã yêu cầu

**Source**

- `billing_db.transactions`
- `customer_db.subscribers`
- `province_reference.csv`

**Ingestion**

- Transaction mới mỗi ngày.
- Subscriber có thể thay đổi trạng thái.
- Province reference thay đổi rất ít.

**Storage/Transformation**

- Giữ raw snapshot để audit.
- Chuẩn hóa transaction timestamp.
- Join subscriber → province.
- Aggregate revenue theo `date, province, service_type`.

**Serving**

- Gold table cho dashboard.

**Quality expectations**

- `transaction_id` unique.
- `amount >= 0` trừ record điều chỉnh có flag rõ ràng.
- `province_code` phải map được.
- Pipeline hoàn thành trước 07:30.

### Điều quan trọng

Yêu cầu “dashboard trước 8 giờ” không tự động có nghĩa phải streaming. Một batch pipeline hoàn thành 07:30 có thể là giải pháp đơn giản và đúng hơn.

---

## 5. Hands-on lab – Map một business requirement thành data lifecycle

### Scenario

Viettel-like telecom platform cần một dashboard “Top 20 cell towers có tỷ lệ lỗi cao trong 15 phút gần nhất”.

### Nhiệm vụ

Tạo file `lab-01-lifecycle.md` và trả lời:

1. Những source nào có thể cần?
2. Dữ liệu bounded hay unbounded?
3. Batch hay streaming phù hợp hơn? Vì sao?
4. Storage nào cần cho raw events?
5. Transformation tối thiểu gồm những bước gì?
6. Serving dataset cần grain gì?
7. Ba data quality rule quan trọng nhất?
8. Freshness SLA hợp lý là gì?
9. Nếu event tới trễ 10 phút thì ảnh hưởng ra sao?
10. Vẽ architecture bằng Mermaid hoặc ASCII.

### Yêu cầu output

Ít nhất 400 từ + một sơ đồ.

---

## 6. Knowledge check – MCQ

**Q1.** Định nghĩa nào tốt nhất về Data Engineering?

A. Chuyển CSV sang Parquet.  
B. Xây dashboard cho business.  
C. Xây và vận hành hệ thống biến dữ liệu nguồn thành dữ liệu đáng tin cậy cho downstream.  
D. Huấn luyện machine learning model.

**Q2.** Dashboard cần dữ liệu mỗi sáng lúc 8:00. Lựa chọn đầu tiên hợp lý nhất là:

A. Streaming vì streaming luôn tốt hơn batch.  
B. Batch nếu đáp ứng SLA và đơn giản hơn.  
C. Kafka bắt buộc.  
D. Không cần pipeline.

**Q3.** “Dữ liệu hôm nay chưa cập nhật” chủ yếu liên quan dimension nào?

A. Uniqueness.  
B. Freshness.  
C. Validity.  
D. Cardinality.

**Q4.** Thành phần nào là concern xuyên suốt lifecycle?

A. Security.  
B. Data quality.  
C. Observability.  
D. Tất cả đáp án trên.

**Q5.** Việc analyst không biết bảng đến từ source nào phản ánh thiếu:

A. Compression.  
B. Lineage.  
C. Index.  
D. Partition count.

---

## 7. Knowledge check – Tự luận / Interview

1. “Data Engineer không chỉ là người viết ETL.” Hãy giải thích trong 3–5 phút.
2. Vì sao freshness là một phần của data quality?
3. Một pipeline chạy thành công nhưng dữ liệu duplicate 5% có được coi là reliable không? Vì sao?
4. Hãy mô tả lifecycle của dữ liệu khi bạn thanh toán cước điện thoại tới khi số liệu xuất hiện trên dashboard doanh thu.
5. Nếu business yêu cầu “real-time”, bạn sẽ hỏi lại những câu gì trước khi chọn streaming?

---

## 8. Exit criteria

Bạn hoàn thành lesson khi:

- [ ] Có thể vẽ lifecycle không nhìn tài liệu.
- [ ] Phân biệt được vai trò DE/DA/DS/SWE.
- [ ] Nêu được ít nhất 5 quality dimensions.
- [ ] Hoàn thành lab và tự bảo vệ lựa chọn batch/streaming.
- [ ] Đạt ít nhất 4/5 MCQ trước khi xem đáp án.
