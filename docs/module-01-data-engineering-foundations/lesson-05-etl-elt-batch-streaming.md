# Lesson 05 – ETL vs ELT, Batch vs Streaming, Full vs Incremental

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Phân biệt ETL và ELT theo nơi/thời điểm transformation xảy ra.
- Phân biệt batch và streaming theo data flow + latency requirement.
- So sánh full load, incremental load, CDC.
- Hiểu idempotency ở mức principle.
- Chọn processing pattern theo requirement thay vì trend.

---

## 2. Principles

### Principle 1 – Latency là business requirement, không phải vanity metric

Nếu dashboard chỉ cần trước 8:00 sáng, pipeline 5 phút chưa chắc có giá trị hơn pipeline 30 phút nhưng đơn giản và ổn định.

### Principle 2 – Incremental processing giảm work nhưng tăng state complexity

Full reload đơn giản về correctness nhưng tốn tài nguyên. Incremental load hiệu quả hơn nhưng phải theo dõi watermark/offset/change state và xử lý retry.

### Principle 3 – Retry-safe/idempotent design là nền của pipeline production

Một job fail giữa chừng và chạy lại không nên vô tình nhân đôi dữ liệu.

---

## 3. Fundamentals

### 3.1 ETL

```text
Extract → Transform → Load
```

Transformation xảy ra trước khi dữ liệu vào target analytical store. Hợp lý khi target yêu cầu schema strict, cần filter sensitive data trước khi load, hoặc compute transform nằm ngoài target.

### 3.2 ELT

```text
Extract → Load → Transform
```

Raw/near-raw data được load trước, rồi transform bằng compute của warehouse/lakehouse. Lợi ích: giữ raw history, replay dễ, tận dụng scalable compute, tách ingestion và business transformation.

### 3.3 Batch

Process dữ liệu theo batch bounded. Ưu điểm: đơn giản, dễ retry, cost predictable, hợp SLA phút/giờ/ngày.

### 3.4 Streaming

Process unbounded events liên tục hoặc micro-batch với latency thấp hơn. Phải giải quyết thêm offset, ordering, state, windows, late data, checkpoint và delivery semantics.

### 3.5 Full load

Mỗi run đọc toàn bộ source. Ưu điểm là logic/state đơn giản; nhược điểm là scale kém khi dữ liệu lớn và gây tải source.

### 3.6 Incremental load

Chỉ lấy phần mới/thay đổi. Ví dụ watermark:

```sql
SELECT *
FROM transactions
WHERE updated_at > :last_watermark
  AND updated_at <= :current_watermark;
```

Cần lưu `last_watermark` đáng tin cậy.

### 3.7 CDC – Change Data Capture

CDC capture insert/update/delete từ transaction log hoặc change stream. Ưu: ít query source, bắt update/delete tốt, có thể gần real-time. Đổi lại: infrastructure và operational state phức tạp hơn.

### 3.8 Idempotency

Một operation idempotent có thể chạy lại mà kết quả cuối không bị nhân đôi ngoài mong muốn.

Ví dụ không idempotent:

```sql
INSERT INTO daily_revenue
SELECT ...;
```

chạy lại → duplicate.

Pattern tốt hơn tùy hệ thống:

```text
DELETE partition/day rồi INSERT lại
hoặc
MERGE theo business key
hoặc
write deterministic output path + atomic replace
```

### 3.9 At-least-once mindset

Trong distributed systems, retry rất bình thường. Nhiều pipeline nên được thiết kế với giả định dữ liệu/task có thể được xử lý hơn một lần, rồi dùng key/transaction/merge để bảo đảm final state đúng.

---

## 4. Worked example – Billing transactions

10 triệu transaction/ngày, dashboard cập nhật mỗi giờ.

- Full reload mỗi giờ sẽ quét toàn lịch sử, chi phí tăng dần.
- Incremental watermark lấy `last_successful_watermark < updated_at <= current_watermark`, rồi MERGE theo `transaction_id`.
- Nếu hourly SLA, source có `updated_at` đáng tin và hard delete không quan trọng, watermark có thể đủ.
- Nếu cần near real-time và bắt hard delete/update chính xác, CDC đáng cân nhắc hơn.

---

## 5. Hands-on lab – Thiết kế incremental pipeline

Cho bảng:

```text
transactions(
  transaction_id,
  subscriber_id,
  amount,
  status,
  created_at,
  updated_at
)
```

Tạo `lab-05-incremental-design.md` và trả lời:

1. Thiết kế full load đầu tiên.
2. Định nghĩa watermark state.
3. Viết pseudo-SQL incremental query.
4. Mô tả target merge/upsert.
5. Nếu job fail sau khi target đã ghi nhưng trước khi watermark commit, retry thế nào?
6. Làm sao giữ pipeline idempotent?
7. Nếu source update record với `updated_at` bị backdate, có thể miss không?
8. Nếu source có hard delete, watermark solution xử lý được không?
9. Khi nào chuyển sang CDC?

Bonus: implement một phiên bản Python + SQLite/PostgreSQL nhỏ.

---

## 6. Knowledge check – MCQ

**Q1.** ELT khác ETL chủ yếu ở: A. có SQL hay không; B. transformation sau khi load vào target analytical platform; C. chỉ streaming; D. không ingestion.

**Q2.** Full load có lợi thế lớn nhất là: A. logic/state đơn giản; B. luôn rẻ nhất; C. luôn nhanh nhất; D. bắt delete tự động mọi hệ thống.

**Q3.** Incremental load thường yêu cầu: A. state như watermark/offset; B. không cần key; C. không retry; D. không cần hiểu source.

**Q4.** Idempotency quan trọng vì: A. pipeline distributed thường retry/re-run; B. làm UI đẹp; C. thay monitoring; D. loại bỏ mọi lỗi source.

**Q5.** CDC đặc biệt hữu ích khi cần: A. capture insert/update/delete với latency thấp; B. tải CSV tĩnh mỗi năm; C. không có source DB; D. không cần change state.

---

## 7. Knowledge check – Tự luận / Interview

1. ETL và ELT không phải hai phe đối lập tuyệt đối. Giải thích.
2. Khi nào batch là lựa chọn tốt hơn streaming?
3. Watermark incremental load có những edge case nào?
4. Idempotency khác deduplication như thế nào?
5. So sánh full load, incremental watermark và CDC cho một bảng 500 triệu row.

---

## 8. Exit criteria

- [ ] Phân biệt ETL/ELT.
- [ ] Phân biệt batch/streaming theo requirement.
- [ ] Thiết kế được watermark incremental pipeline.
- [ ] Giải thích idempotency bằng failure scenario.
- [ ] Đạt ít nhất 4/5 MCQ.
