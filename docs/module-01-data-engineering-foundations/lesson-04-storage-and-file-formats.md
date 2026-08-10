# Lesson 04 – Storage Systems & File Formats

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Giải thích trade-off row-oriented và column-oriented storage.
- Phân biệt CSV, JSON, Parquet ở góc nhìn Data Engineering.
- Hiểu compression, partitioning, metadata và small-files problem ở mức nền tảng.
- Giải thích vì sao object storage phổ biến trong data lake/lakehouse.
- Thiết kế layout dữ liệu raw/curated đơn giản.

---

## 2. Principles

### Principle 1 – Storage layout là một phần của query design

Cùng một dataset, format/layout khác nhau có thể tạo chênh lệch rất lớn về bytes phải đọc, CPU decode, metadata overhead, số request/file open và chi phí.

### Principle 2 – Chọn format theo access pattern

Không có format “tốt nhất”. CSV dễ trao đổi; JSON linh hoạt; Parquet phù hợp analytical scan.

### Principle 3 – Partition là pruning mechanism, không phải càng nhiều càng tốt

Partition giúp bỏ qua dữ liệu không liên quan, nhưng partition quá nhỏ tạo nhiều file/directory và metadata overhead.

---

## 3. Fundamentals

### 3.1 Row-oriented vs column-oriented

Row store đặt dữ liệu của một record gần nhau, phù hợp point lookup, insert/update và OLTP. Column store đặt giá trị cùng cột gần nhau, phù hợp analytics vì engine có thể chỉ đọc cột cần thiết và compression hiệu quả hơn.

### 3.2 CSV

Ưu: đơn giản, human-readable, tương thích rộng. Nhược: type metadata yếu, parse tốn CPU, không column pruning và dễ gặp lỗi delimiter/quoting.

### 3.3 JSON

Ưu: nested/semi-structured, tự nhiên với API/event. Nhược: verbose, lặp key, parse cost cao hơn và schema có thể không nhất quán.

### 3.4 Parquet

Parquet là columnar format phổ biến cho analytics. Nó hỗ trợ column pruning, typed schema, compression tốt, nested data và metadata/statistics để engine giảm lượng dữ liệu phải đọc trong nhiều trường hợp.

### 3.5 Compression

Compression giảm storage, network IO và bytes phải đọc, đổi lại cần CPU encode/decode. Cần hiểu trade-off tốc độ vs compression ratio thay vì học thuộc codec.

### 3.6 Partitioning

Ví dụ:

```text
gold/revenue/date=2026-08-10/part-000.parquet
```

Query có `WHERE date = '2026-08-10'` có thể chỉ đọc partition liên quan. Ngược lại, partition theo `transaction_id` thường tệ vì cardinality cực cao.

### 3.7 Small files problem

Một dataset 100 GB lưu thành 1,000,000 file nhỏ có thể chậm hơn rất nhiều so với số lượng file hợp lý vì metadata listing, file-open/request overhead, scheduler overhead và task quá nhỏ.

### 3.8 Object storage

Object storage phù hợp data lake vì scale lớn, durability cao, chi phí thấp và tách compute/storage. Tuy nhiên object storage không phải database; cần engine/table layer phía trên để query/update theo semantics phong phú.

---

## 4. Worked example – CSV vs Parquet cho revenue analytics

Dataset 500 GB có 25 cột nhưng dashboard chỉ dùng `date, province, service_type, amount`.

- Với CSV, engine thường phải đọc/parse toàn bộ dòng.
- Với Parquet, engine có thể chỉ đọc column chunks cần thiết.
- Nếu partition theo `date`, query một ngày còn có thể giảm scan thêm.

**Principle rút ra:** hiệu năng không chỉ đến từ “cluster mạnh”, mà bắt đầu từ format và layout.

---

## 5. Hands-on lab – Benchmark nhỏ CSV vs Parquet

Dùng Python + pandas hoặc PyArrow:

1. Tạo dataset ít nhất 1 triệu row với `transaction_id`, `subscriber_id`, `province`, `service_type`, `amount`, `event_date` và 10 cột phụ.
2. Ghi thành CSV.
3. Ghi thành Parquet.
4. So sánh file size.
5. Đọc chỉ 4 cột cần thiết từ Parquet.
6. Đo thời gian tương đối.
7. Viết 200–300 từ giải thích kết quả.

Bonus: thử Gzip CSV; partition Parquet theo `event_date`; quan sát số file tạo ra.

---

## 6. Knowledge check – MCQ

**Q1.** Columnar format đặc biệt phù hợp: A. update từng row; B. analytical query đọc một số cột trên nhiều row; C. chỉ lưu ảnh; D. transaction lookup theo PK.

**Q2.** Parquet có lợi thế nào so với CSV cho analytics? A. Column pruning và typed schema; B. Không cần storage; C. Không cần compression; D. Luôn human-readable.

**Q3.** Partition theo trường nào thường nguy hiểm? A. `event_date`; B. `year`; C. `transaction_id` cardinality cực cao; D. `country` vài chục giá trị.

**Q4.** Small files problem chủ yếu gây: A. metadata/file-open/scheduling overhead; B. SQL syntax error; C. network không hoạt động; D. schema biến mất.

**Q5.** Object storage nên được hiểu là: A. thay thế mọi DB; B. storage substrate cần compute/table/query layer phía trên; C. chỉ backup ảnh; D. message broker.

---

## 7. Knowledge check – Tự luận / Interview

1. Vì sao Parquet thường nhanh hơn CSV cho analytical query?
2. Vì sao partition cardinality quá cao là xấu?
3. Nếu query thường filter theo `event_date` và `province`, bạn cân nhắc partition thế nào?
4. Row store và column store phù hợp workload nào?
5. Object storage khác filesystem/database ở mental model nào?

---

## 8. Exit criteria

- [ ] Giải thích được row vs column orientation.
- [ ] So sánh CSV/JSON/Parquet.
- [ ] Hiểu partition pruning và small files.
- [ ] Hoàn thành benchmark lab.
- [ ] Đạt ít nhất 4/5 MCQ.
