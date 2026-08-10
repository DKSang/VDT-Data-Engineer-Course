# Module 01 Final Assessment

> Không xem `answers/module-01-final-solutions.md` trước khi hoàn thành.

## Phần A – MCQ (20 điểm)

Mỗi câu 1 điểm.

1. Data Engineering lifecycle tốt nhất được hiểu là gì?
   - A. Danh sách tool
   - B. Dòng chảy từ source tới serving cùng các concern vận hành
   - C. Chỉ transformation
   - D. Chỉ database administration
2. OLTP tối ưu chủ yếu cho: A. Transaction nhỏ, latency thấp; B. Scan lịch sử hàng TB; C. Chỉ ML; D. Data lake.
3. OLAP thường liên quan: A. Point update liên tục; B. Aggregate/join trên lượng dữ liệu lớn; C. Authentication; D. DNS.
4. Network event stream liên tục là: A. Bounded; B. Unbounded; C. Snapshot; D. Dimension.
5. Event time là: A. Thời điểm hệ thống xử lý; B. Thời điểm event thực tế xảy ra; C. Thời điểm dashboard render; D. Thời điểm file bị xóa.
6. Parquet thường phù hợp analytics vì: A. Columnar + typed metadata; B. Chỉ text; C. Không cần compute; D. Không compression.
7. Partition cardinality rất cao có thể gây: A. Small files/metadata overhead; B. ACID mạnh hơn; C. Query luôn nhanh; D. Không ảnh hưởng.
8. Full load có ưu điểm: A. State đơn giản; B. Luôn scale tốt nhất; C. Bắt CDC tự động; D. Không đọc source.
9. Incremental load thường cần: A. Watermark/offset/change state; B. Không key; C. Không retry; D. Không schema.
10. Idempotency giúp: A. Re-run an toàn hơn; B. Tăng kích thước file; C. Loại security; D. Không quality check.
11. CDC đặc biệt phù hợp khi: A. Capture insert/update/delete gần real-time; B. CSV tĩnh; C. Không source DB; D. Không change tracking.
12. Data lake risk phổ biến khi thiếu governance: A. Data swamp; B. OLTP; C. DNS failure; D. UI lag.
13. Lakehouse cố gắng bổ sung vào lake: A. Table semantics/transactions/metadata; B. Mobile UI; C. CPU instruction; D. SMTP.
14. Freshness nghĩa là: A. Data cập nhật đúng thời gian kỳ vọng; B. Data unique; C. Data compressed; D. Data encrypted.
15. Batch thích hợp khi: A. SLA cho phép và complexity thấp hơn; B. Streaming luôn bắt buộc; C. Không dữ liệu; D. Chỉ ML.
16. “Real-time” requirement nên: A. Chuyển ngay Kafka; B. Làm rõ latency business thật sự; C. Bỏ qua; D. Luôn 1-second SLA.
17. Bronze layer thường: A. Giữ dữ liệu gần source, trace/replay; B. Chỉ KPI cuối; C. Chỉ ML; D. Không metadata.
18. Column store phù hợp: A. Analytical scan một số cột; B. Chỉ point update; C. DNS; D. Authentication.
19. Source assessment nên kiểm tra: A. Rate limit/auth/schema/key/time semantics; B. Chỉ tên DB; C. Chỉ file size; D. Không owner.
20. Kiến trúc tốt nên: A. Dùng nhiều tool nhất; B. Đáp ứng requirement với trade-off rõ và complexity hợp lý; C. Luôn streaming; D. Luôn lakehouse.

## Phần B – Short answer (30 điểm)

Mỗi câu 5 điểm.

1. Giải thích OLTP vs OLAP bằng workload cụ thể.
2. Phân biệt event time, ingestion time, processing time và nêu một bug nếu dùng sai time.
3. So sánh CSV và Parquet cho analytical workload.
4. So sánh full load, incremental watermark và CDC.
5. Giải thích idempotency bằng một failure scenario.
6. Vì sao requirement phải đi trước lựa chọn tool?

## Phần C – System reasoning (20 điểm)

Một telco có PostgreSQL billing 300 triệu transaction; customer profile 20 triệu thuê bao; network event 50,000 events/second peak; dashboard doanh thu hourly; network anomaly latency <2 phút; raw retention 180 ngày.

Trả lời:

1. Source nào batch, source nào streaming?
2. Storage/layering đề xuất?
3. Revenue pipeline nên full hay incremental? Vì sao?
4. Network event cần giữ timestamp nào?
5. 5 failure modes quan trọng.
6. 5 quality checks.
7. 3 security concerns.
8. 5 trade-offs.

## Phần D – Architecture defense (30 điểm)

Vẽ sơ đồ end-to-end và record video/audio 8–10 phút giải thích.

| Tiêu chí | Điểm |
|---|---:|
| Requirement clarification | 5 |
| Lifecycle rõ | 5 |
| Batch/stream reasoning | 5 |
| Storage/layout reasoning | 5 |
| Failure + quality | 5 |
| Trade-off communication | 5 |

## Pass criteria

- >= 70/100 tổng.
- Phần D phải >= 15/30.
- Không được sai fundamental: OLTP/OLAP, event time, incremental/idempotency.
