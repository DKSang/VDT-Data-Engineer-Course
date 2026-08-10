# Lesson 03 – Source Systems & Data Characteristics

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Phân loại source: database, file, API, log, message/event stream.
- Hiểu bounded vs unbounded data.
- Phân biệt event time, ingestion time, processing time.
- Xác định source constraints: rate limit, transaction load, schema drift, authentication.
- Tạo một source assessment trước khi viết ingestion pipeline.

---

## 2. Principles

### Principle 1 – Source system tồn tại để phục vụ mục đích của nó, không phải pipeline của bạn

Production database ưu tiên application transaction. API có rate limit. Event source có thể gửi duplicate. CSV có thể đổi cột thủ công.

Data Engineer phải thích nghi với source thay vì giả định source “sạch”.

### Principle 2 – Hiểu semantics trước khi copy bytes

Biết field `timestamp` là chưa đủ. Cần biết:

- timezone?
- event time hay update time?
- có mutable không?
- có late-arriving không?
- key ổn định không?

### Principle 3 – Ingestion tốt bắt đầu bằng source contract/assessment

Trước khi code, phải biết dữ liệu được tạo ra như thế nào, thay đổi ra sao và có ràng buộc gì.

---

## 3. Fundamentals

### 3.1 Các loại source phổ biến

#### Relational database

Ví dụ PostgreSQL, SQL Server, MySQL.

Đặc tính:

- schema rõ;
- primary key;
- mutable data;
- transaction;
- có thể lấy incremental qua timestamp/ID/CDC.

Rủi ro:

- query ingestion ảnh hưởng production;
- update/delete khó capture nếu chỉ dùng `WHERE updated_at > watermark`;
- timezone và transaction consistency.

#### File

CSV/JSON/Parquet từ SFTP/object storage.

Câu hỏi:

- append file hay overwrite?
- naming convention?
- file đến đúng giờ không?
- có duplicate file không?
- schema có drift?

#### REST API

Cần hiểu:

- pagination;
- authentication;
- rate limit;
- retry/backoff;
- cursor/token;
- API version;
- response schema.

#### Logs

Thường append-only, volume cao. Schema có thể semi-structured.

#### Message/Event stream

Ví dụ Kafka topic.

Đặc tính:

- unbounded;
- partitioned;
- ordered trong phạm vi nhất định;
- replay qua offset tùy retention;
- duplicate/lateness là vấn đề thực tế.

### 3.2 Bounded vs unbounded

**Bounded data** có điểm kết thúc rõ ràng.

Ví dụ:

- file `transactions_2026-08-10.csv`;
- snapshot khách hàng lúc 00:00.

**Unbounded data** tiếp tục phát sinh.

Ví dụ:

- network events;
- clickstream;
- sensor telemetry.

Khái niệm này ảnh hưởng trực tiếp tới cách xử lý: batch engine thường xử lý bounded dataset; streaming engine xử lý unbounded flow theo window/state.

### 3.3 Event time, ingestion time, processing time

Giả sử một network event xảy ra 10:00:00, tới Kafka 10:00:07, được Spark xử lý 10:00:12.

- `event_time = 10:00:00`
- `ingestion_time = 10:00:07`
- `processing_time = 10:00:12`

Nếu tính “lỗi trong 5 phút gần nhất” theo processing time, late event có thể bị đặt sai window. Vì vậy streaming analytics thường quan tâm event time.

### 3.4 Mutable vs append-only

**Append-only:** record cũ không bị thay đổi; event mới chỉ thêm.

**Mutable:** record có update/delete.

Ví dụ customer profile là mutable. Network event thường append-only.

Điều này quyết định ingestion strategy:

- append-only → high-watermark/offset dễ hơn;
- mutable → cần CDC/snapshot/merge logic.

### 3.5 Source assessment checklist

Trước khi ingest, tối thiểu phải biết:

1. Source type?
2. Owner?
3. Connection/authentication?
4. Volume hiện tại?
5. Growth rate?
6. Batch hay continuous?
7. Primary/business key?
8. Mutable hay append-only?
9. Delete có xảy ra?
10. Timestamp semantics?
11. Timezone?
12. Schema change process?
13. Rate limit?
14. SLA/freshness?
15. Historical backfill có cần?
16. PII/sensitive fields?
17. Source có chịu được full scan không?
18. Duplicate có thể xảy ra không?

---

## 4. Worked example – `network_events`

Payload:

```json
{
  "event_id": "evt-99128",
  "subscriber_id": "sub-1024",
  "cell_id": "HN-CELL-221",
  "event_type": "CALL_DROP",
  "event_time": "2026-08-10T10:00:00+07:00",
  "severity": 3
}
```

### Source assessment

- Type: event stream.
- Shape: semi-structured JSON.
- Nature: unbounded.
- Mutation: logically append-only.
- Key: `event_id`.
- Time semantic: `event_time` là thời điểm event xảy ra.
- Possible issue: duplicate retry từ producer.
- Possible issue: mobile/network latency → late events.
- Serving requirement: aggregate error rate theo cell trong 15 phút.

### Derived requirements

- Preserve `event_id` để deduplicate.
- Preserve original `event_time`.
- Add ingestion timestamp riêng.
- Streaming processor phải có late-data strategy.
- Raw events nên replay được trong một khoảng retention.

---

## 5. Hands-on lab – Source assessment document

Chọn một trong hai source:

### Option A – PostgreSQL billing table

Columns:

```text
transaction_id bigint PK
subscriber_id varchar
amount decimal(18,2)
status varchar
created_at timestamp
updated_at timestamp
```

### Option B – REST API customer package

Endpoint:

```text
GET /v1/subscribers?page=1&page_size=500
```

Giả định API giới hạn 100 requests/minute và token hết hạn mỗi 60 phút.

### Nhiệm vụ

Tạo `lab-03-source-assessment.md` gồm:

- source type;
- bounded/unbounded;
- mutable/append-only;
- key;
- timestamp semantics;
- ingestion options;
- failure modes;
- security concerns;
- schema drift concerns;
- backfill strategy;
- 5 câu hỏi bạn cần hỏi source owner.

---

## 6. Knowledge check – MCQ

**Q1.** Dữ liệu Kafka topic đang liên tục nhận network event là:

A. Bounded.  
B. Unbounded.  
C. Static dimension.  
D. Snapshot.

**Q2.** Event xảy ra lúc 10:00 nhưng đến hệ thống lúc 10:03. Thời điểm 10:00 là:

A. Processing time.  
B. Event time.  
C. Ingestion time.  
D. Commit time.

**Q3.** Với mutable table có delete, watermark theo `updated_at` có thể chưa đủ vì:

A. Không bắt được delete nếu source không biểu diễn delete.  
B. SQL không có timestamp.  
C. Watermark luôn duplicate.  
D. Không thể dùng database.

**Q4.** Khi ingest REST API, điều nào cần đánh giá?

A. Rate limit.  
B. Pagination.  
C. Authentication expiry.  
D. Tất cả đáp án trên.

**Q5.** Vì sao phải lưu `event_time` riêng với ingestion time?

A. Để file to hơn.  
B. Để phân tích theo thời điểm thực sự xảy ra và xử lý late events.  
C. Vì SQL bắt buộc.  
D. Không có lý do.

---

## 7. Knowledge check – Tự luận / Interview

1. Watermark incremental load có thể miss dữ liệu trong những trường hợp nào?
2. CDC giải quyết vấn đề gì mà snapshot/watermark khó giải quyết?
3. Vì sao API pagination là concern của Data Engineer?
4. Event time khác processing time ảnh hưởng streaming aggregation như thế nào?
5. Hãy đưa ra 10 câu hỏi bạn sẽ hỏi trước khi ingest một bảng production mới.

---

## 8. Exit criteria

- [ ] Phân biệt bounded/unbounded.
- [ ] Phân biệt 3 loại time.
- [ ] Giải thích mutable vs append-only.
- [ ] Hoàn thành source assessment lab.
- [ ] Đạt ít nhất 4/5 MCQ.
