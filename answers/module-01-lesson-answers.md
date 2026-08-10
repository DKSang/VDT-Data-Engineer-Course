# Module 01 – Lesson Answer Key

## Lesson 01
MCQ: 1C, 2B, 3B, 4D, 5B.

Điểm cần xuất hiện trong tự luận:
- DE chịu trách nhiệm reliability/quality/lineage/operability, không chỉ ETL code.
- Freshness là quality vì dữ liệu đúng nhưng quá trễ vẫn không đáp ứng use case.
- “Real-time” phải được lượng hóa bằng latency và business consequence.

## Lesson 02
MCQ: 1B, 2B, 3A, 4A, 5A.

Điểm cần xuất hiện:
- DW tách analytical workload khỏi OLTP và tích hợp nhiều source.
- Lakehouse không “luôn thắng”; workload, cost, team skill và governance quyết định.
- Compute/storage separation tăng elasticity nhưng đòi metadata/network/file-layout management.

## Lesson 03
MCQ: 1B, 2B, 3A, 4D, 5B.

Điểm cần xuất hiện:
- Watermark miss delete/historical backdate nếu source semantics không đảm bảo.
- CDC capture mutation chính xác hơn từ change log/stream.
- Event time cần cho time-window correctness khi dữ liệu tới trễ.

## Lesson 04
MCQ: 1B, 2A, 3C, 4A, 5B.

Điểm cần xuất hiện:
- Parquet giảm scan nhờ column pruning + compression + metadata.
- High-cardinality partition gây many small partitions/files.
- Object storage là storage substrate, không tự có query/transaction semantics như DB.

## Lesson 05
MCQ: 1B, 2A, 3A, 4A, 5A.

Điểm cần xuất hiện:
- Incremental = ít work hơn nhưng state/retry correctness phức tạp hơn.
- Idempotency nói về repeated execution; dedup là kỹ thuật cụ thể chống duplicate records.
- CDC đáng giá khi mutation/latency làm watermark không đủ.

## Lesson 06
MCQ: 1C, 2B, 3A, 4B, 5B.

Điểm cần xuất hiện:
- Architecture bắt đầu từ requirements.
- Mỗi component thêm operational burden.
- Design phải mô tả failure/recovery, không chỉ happy path.
