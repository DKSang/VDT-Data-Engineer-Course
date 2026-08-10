# Lesson 06 – End-to-End Data Pipeline Design & Trade-offs

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- Chuyển business requirement thành data architecture sơ bộ.
- Xác định source, ingestion, storage, transformation, serving.
- Đặt non-functional requirements: latency, scale, reliability, security, cost.
- Dùng trade-off reasoning thay vì chọn công nghệ theo popularity.
- Trình bày architecture trong 5–10 phút như một mini system-design interview.

---

## 2. Principles

### Principle 1 – Requirement trước architecture

Không chọn Kafka chỉ vì dữ liệu “nhiều”. Không chọn streaming chỉ vì business nói “real-time” mà chưa định nghĩa latency.

### Principle 2 – Simplest architecture that satisfies requirements

Mỗi component thêm vào hệ thống tạo thêm failure mode, monitoring, security surface, deployment và knowledge requirement. Kiến trúc đơn giản nhưng đủ SLA thường tốt hơn kiến trúc “đẹp CV” nhưng khó vận hành.

### Principle 3 – Design for failure

Luôn hỏi: source down thì sao? duplicate thì sao? late data thì sao? schema đổi thì sao? job chạy lại thì sao? downstream đọc dữ liệu dở dang thì sao?

### Principle 4 – Make trade-offs explicit

Một decision tốt có format:

> Chọn X vì requirement A/B; chấp nhận trade-off C; nếu scale/latency thay đổi tới D thì cân nhắc Y.

---

## 3. Fundamentals

### 3.1 Functional requirements

Hệ thống phải làm gì? Ví dụ ingest network events, tính error rate theo cell, aggregate revenue, cung cấp dashboard.

### 3.2 Non-functional requirements

- **Latency/Freshness:** seconds, minutes, hourly hay daily?
- **Volume/Throughput:** rows/day, MB/s, peak traffic.
- **Reliability:** acceptable data loss, retry, recovery time.
- **Correctness:** financial exactness hay approximate monitoring metric?
- **Cost:** always-on compute có chấp nhận?
- **Security:** PII, encryption, least privilege.
- **Operability:** team có đủ năng lực vận hành stack không?

### 3.3 Architecture decision template

```text
Problem:
Requirement:
Options:
Decision:
Why:
Trade-off:
Failure modes:
When to revisit:
```

### 3.4 Bronze / Silver / Gold as separation of concerns

**Bronze/raw:** gần source, trace/replay, ít business logic.

**Silver/cleaned:** normalized, deduplicated, validated, joined/standardized.

**Gold/serving:** business-ready, metric/aggregate, grain phù hợp downstream.

Đây là separation-of-concerns pattern, không phải luật bắt buộc.

### 3.5 Batch + streaming coexistence

Một hệ thống có thể dùng cả hai:

```text
Billing DB ──hourly batch────┐
                             ├─> Lakehouse/Warehouse ─> Dashboard
Network events ─stream───────┘
```

Không cần ép mọi source vào một pattern duy nhất.

---

## 4. Worked example – Telecom Operations Platform

### Requirements

1. Revenue dashboard: cập nhật mỗi giờ.
2. Network anomaly dashboard: latency < 2 phút.
3. Raw events giữ 90 ngày để replay.
4. Customer data chứa PII.
5. Team 5 Data Engineers.

### Architecture reasoning

**Billing:** hourly SLA → batch incremental từ database hợp lý.

```text
Billing DB → Incremental ingestion → Bronze → Silver → Gold revenue
```

**Network events:** < 2 phút → streaming path.

```text
Network producer → Broker → Streaming processor → Bronze/Silver → live aggregate
```

**Storage:** raw history lớn → object storage/lakehouse.

**Serving:** Gold revenue + anomaly tables có thể serve qua warehouse/SQL engine.

**Security:** minimize propagation của PII, restrict access, mask/hash khi không cần raw identifier, audit access.

### Failure scenarios

- Broker unavailable → producer retry/buffer hoặc chấp nhận loss theo SLA.
- Streaming processor restart → resume từ checkpoint/offset.
- Duplicate event → dedup theo `event_id` hoặc idempotent aggregation.
- Schema change → contract + validation + quarantine/compatible evolution.

---

## 5. Hands-on lab – Mini system design

### Prompt

> Thiết kế data platform cho một nhà mạng giả lập có 20 triệu thuê bao. Hệ thống cần: (1) dashboard doanh thu cập nhật mỗi giờ; (2) phát hiện cell tower có call-drop rate bất thường trong tối đa 2 phút; (3) dữ liệu raw lưu 180 ngày; (4) dataset churn cập nhật mỗi ngày.

### Deliverables

Tạo `lab-06-mini-system-design.md` gồm:

1. Requirement clarification – ít nhất 10 câu hỏi.
2. Functional requirements.
3. Non-functional requirements.
4. Architecture diagram.
5. Source table/event assumptions.
6. Batch path.
7. Streaming path.
8. Storage layers.
9. Serving datasets + grain.
10. Data quality rules.
11. Idempotency/retry strategy.
12. Late data strategy.
13. Security/PII considerations.
14. Monitoring metrics.
15. 5 trade-offs.
16. “When to revisit” – điều kiện khiến bạn đổi kiến trúc.

### Interview simulation

Tự record 8 phút trình bày architecture mà không đọc script. Chấm lại: có nói requirement trước tool không, có nêu trade-off/failure/data quality/scale/latency không?

---

## 6. Knowledge check – MCQ

**Q1.** Bước đầu tiên khi system design data platform nên là: A. chọn Kafka; B. chọn Spark; C. làm rõ functional và non-functional requirements; D. vẽ logo kiến trúc.

**Q2.** Requirement “real-time” nên được xử lý bằng cách: A. mặc định streaming; B. hỏi latency/freshness cụ thể và consequence nếu trễ; C. bỏ qua; D. batch 24 giờ.

**Q3.** Bronze/Silver/Gold chủ yếu giúp: A. separation of concerns; B. tăng RAM; C. loại duplicate tự động; D. không cần testing.

**Q4.** Một component mới trong architecture thường: A. chỉ thêm lợi ích; B. thêm cả capability và operational complexity; C. không monitoring; D. không failure mode.

**Q5.** Design for failure nghĩa là: A. ngăn mọi failure; B. giả định failure có thể xảy ra và thiết kế recovery/correctness; C. không retry; D. chỉ backup DB.

---

## 7. Knowledge check – Tự luận / Interview

1. Nếu business yêu cầu latency từ 2 phút xuống 5 giây, architecture nào có thể cần thay đổi?
2. Nếu traffic tăng 10 lần, bottleneck có thể nằm ở những đâu?
3. Vì sao raw layer hữu ích cho replay/debug?
4. Khi nào không cần Bronze/Silver/Gold?
5. Hãy bảo vệ một quyết định “không dùng Kafka” trong một use case cụ thể.
6. Hãy bảo vệ một quyết định “cần Kafka/streaming” trong use case khác.

---

## 8. Exit criteria

- [ ] Hoàn thành mini system design.
- [ ] Trình bày architecture trong 8 phút.
- [ ] Nêu ít nhất 5 trade-offs.
- [ ] Nêu failure strategy cho retry/duplicate/late data/schema change.
- [ ] Đạt ít nhất 4/5 MCQ.
