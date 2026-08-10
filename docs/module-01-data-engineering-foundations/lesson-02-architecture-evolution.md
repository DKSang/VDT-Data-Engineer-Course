# Lesson 02 – Data Architecture Evolution: Database → Warehouse → Lake → Lakehouse

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích **vì sao** các kiến trúc dữ liệu mới xuất hiện thay vì chỉ học định nghĩa.
- Phân biệt OLTP và OLAP.
- So sánh database, data warehouse, data lake và lakehouse.
- Hiểu separation of compute and storage ở mức principle.
- Nhận ra “không có kiến trúc tốt nhất cho mọi bài toán”.

---

## 2. Principles

### Principle 1 – Architecture tiến hóa vì workload thay đổi

Một relational database có thể rất tốt cho giao dịch nhưng không tối ưu cho quét hàng tỷ record phân tích. Một object store rất rẻ để lưu dữ liệu nhưng bản thân nó không cung cấp đầy đủ table semantics như transaction/update/catalog.

Kiến trúc mới xuất hiện để giải quyết giới hạn của kiến trúc cũ trong workload mới.

### Principle 2 – Tối ưu cho workload, không tối ưu cho buzzword

Chọn hệ thống phải dựa vào:

- read/write pattern;
- latency;
- scale;
- schema flexibility;
- consistency requirement;
- cost;
- operational complexity.

### Principle 3 – Tách compute và storage tăng tính linh hoạt, nhưng không miễn phí

Compute-storage separation giúp scale độc lập, nhưng kéo theo network IO, metadata management, file layout và governance phức tạp hơn.

---

## 3. Fundamentals

### 3.1 OLTP vs OLAP

#### OLTP – Online Transaction Processing

Đặc điểm:

- nhiều transaction nhỏ;
- insert/update thường xuyên;
- latency thấp;
- truy cập một vài row theo key;
- consistency quan trọng.

Ví dụ: nạp tiền điện thoại, cập nhật trạng thái thuê bao.

#### OLAP – Online Analytical Processing

Đặc điểm:

- scan lượng dữ liệu lớn;
- aggregate/join;
- đọc nhiều hơn ghi;
- query phức tạp;
- tối ưu throughput hơn point lookup.

Ví dụ: tổng doanh thu 12 tháng theo tỉnh và gói cước.

### 3.2 Operational database

RDBMS như PostgreSQL/MySQL phù hợp transaction vì:

- constraint;
- index;
- ACID transaction;
- row-level updates;
- strong schema.

Nhưng chạy analytical workload nặng trực tiếp trên production DB có thể cạnh tranh CPU/IO với ứng dụng.

### 3.3 Data warehouse

Warehouse tập trung dữ liệu từ nhiều source vào một hệ thống tối ưu analytics.

Lợi ích:

- analytical SQL;
- dimensional model;
- governance tốt;
- BI-friendly.

Giới hạn lịch sử:

- storage/compute có thể đắt;
- semi-structured/unstructured data kém linh hoạt hơn;
- schema-on-write yêu cầu thiết kế trước.

### 3.4 Data lake

Data lake thường dựa trên object storage/HDFS, lưu:

- structured;
- semi-structured;
- unstructured;
- raw history.

Lợi ích:

- rẻ;
- scale lớn;
- flexible formats.

Rủi ro:

- thiếu governance → “data swamp”;
- file nhỏ;
- schema lộn xộn;
- update/delete khó;
- transaction semantics hạn chế nếu chỉ dùng file thuần.

### 3.5 Lakehouse

Lakehouse cố gắng giữ tính linh hoạt/chi phí của data lake nhưng bổ sung table-layer semantics:

- ACID-like transactions ở table layer;
- schema enforcement/evolution;
- metadata;
- time travel/versioning tùy format;
- SQL/BI access tốt hơn.

Các table format/layer phổ biến: Delta Lake, Apache Iceberg, Apache Hudi.

### 3.6 Compute-storage separation

Kiến trúc truyền thống:

```text
[Compute + Local Storage]
```

Kiến trúc tách rời:

```text
        ┌─ Compute cluster A
Object ─┼─ Compute cluster B
Storage └─ SQL engine C
```

Ưu điểm:

- scale compute độc lập;
- nhiều engine dùng chung dữ liệu;
- storage lifecycle độc lập.

Đổi lại:

- cần network;
- cần catalog/metadata;
- file layout ảnh hưởng query;
- concurrent writes phải được quản lý.

---

## 4. Worked example – Chọn nơi chạy báo cáo doanh thu

### Bối cảnh

Production PostgreSQL có 200 triệu transaction. Product app dùng DB này để ghi giao dịch cước.

Business muốn query:

```sql
SELECT province, DATE_TRUNC('month', paid_at), SUM(amount)
FROM transactions
WHERE paid_at >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY 1, 2;
```

### Phương án A – Query trực tiếp production DB

Ưu:

- đơn giản;
- không cần copy data.

Nhược:

- scan lớn;
- cạnh tranh IO/CPU;
- ảnh hưởng workload giao dịch;
- khó join nhiều source khác.

### Phương án B – Replicate/incremental load sang warehouse/lakehouse

Ưu:

- tách analytical workload;
- có lịch sử;
- dễ join data source khác;
- có thể tổ chức partition/columnar.

Nhược:

- thêm pipeline;
- data latency;
- thêm cost/operations.

### Kết luận

Nếu báo cáo là workload lặp lại và lớn, việc tách analytical storage thường hợp lý hơn. Đây là quyết định workload isolation, không phải vì warehouse “hiện đại” hơn database.

---

## 5. Hands-on lab – Architecture comparison matrix

Tạo `lab-02-architecture-matrix.md`.

Với 4 use case sau, chọn storage/serving architecture phù hợp và giải thích:

1. Thanh toán cước cần response < 200ms, update theo transaction.
2. Dashboard doanh thu 3 năm, refresh mỗi giờ.
3. Lưu raw network logs 2 năm với chi phí thấp.
4. Data science team muốn đọc cùng dữ liệu raw + curated bằng Spark và SQL.

Cho mỗi use case, chấm 1–5 cho:

- latency;
- update frequency;
- scan volume;
- schema flexibility;
- cost sensitivity;
- consistency requirement.

Sau đó chọn giữa:

- RDBMS;
- warehouse;
- data lake;
- lakehouse.

Không được trả lời chỉ bằng tên công nghệ. Phải nêu trade-off.

---

## 6. Knowledge check – MCQ

**Q1.** OLTP thường tối ưu cho:

A. Scan toàn bộ lịch sử 5 năm.  
B. Transaction nhỏ, latency thấp, point lookup/update.  
C. Chỉ machine learning.  
D. Lưu video.

**Q2.** Lý do chính không nên chạy analytical query rất nặng trực tiếp production OLTP DB là:

A. SQL không chạy được trên RDBMS.  
B. Có thể cạnh tranh tài nguyên với transactional workload.  
C. Database không lưu được số.  
D. OLTP không có index.

**Q3.** Data lake thuần dễ trở thành “data swamp” nếu thiếu:

A. Governance và metadata.  
B. RAM.  
C. REST API.  
D. Java.

**Q4.** Lakehouse cố gắng kết hợp:

A. Data lake flexibility + table/warehouse-like management.  
B. Mobile app + database.  
C. Kafka + Docker.  
D. Only ML.

**Q5.** Compute-storage separation cho phép:

A. Scale compute và storage độc lập hơn.  
B. Không cần network.  
C. Không cần metadata.  
D. Query luôn nhanh hơn.

---

## 7. Knowledge check – Tự luận / Interview

1. Vì sao data warehouse xuất hiện khi doanh nghiệp đã có relational database?
2. Data lake khác database ở điểm nào quan trọng nhất về cách tổ chức và workload?
3. Lakehouse đang giải quyết những pain point nào của data lake?
4. Separation of compute and storage đem lại lợi ích gì và tạo ra vấn đề gì?
5. “Lakehouse luôn tốt hơn warehouse” – phản biện nhận định này.

---

## 8. Exit criteria

- [ ] Giải thích được OLTP vs OLAP bằng workload, không chỉ định nghĩa.
- [ ] Vẽ được evolution DB → DW → Lake → Lakehouse.
- [ ] Nêu ít nhất 2 ưu/nhược điểm của mỗi kiến trúc.
- [ ] Hoàn thành architecture matrix.
- [ ] Đạt ít nhất 4/5 MCQ.
