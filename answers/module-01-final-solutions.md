# Module 01 Final – Suggested Solutions

## Phần A

1B, 2A, 3B, 4B, 5B, 6A, 7A, 8A, 9A, 10A, 11A, 12A, 13A, 14A, 15A, 16B, 17A, 18A, 19A, 20B.

## Phần B – Rubric gợi ý

Mỗi câu 5 điểm:

- 2 điểm: đúng fundamental.
- 2 điểm: có example/failure/trade-off.
- 1 điểm: diễn đạt rõ và dùng đúng terminology.

## Phần C – Hướng trả lời

Không có duy nhất một architecture đúng. Bài tốt cần nêu:

- Billing/customer: batch incremental hoặc CDC tùy latency/mutation.
- Network events: streaming path vì 50k events/s và <2 phút.
- Raw retention trên scalable object storage/lakehouse là hợp lý.
- `event_time` và ingestion/processing metadata cần tách.
- Revenue không nên full scan 300M rows mỗi giờ nếu có incremental key/change semantics đáng tin.
- Failure modes: source unavailable, duplicate, schema drift, late events, checkpoint/state loss, target write partial, poison record, auth expiry.
- Quality: uniqueness, completeness, valid ranges, referential mapping, freshness, volume anomaly.
- Security: PII, least privilege, encryption, secret management, audit.

## Phần D – Architecture defense

Một câu trả lời mạnh nên dùng format:

1. Requirement + assumption.
2. Source characteristics.
3. Batch path.
4. Streaming path.
5. Storage/layers.
6. Serving.
7. Reliability + quality.
8. Security.
9. Trade-offs.
10. When to revisit.
