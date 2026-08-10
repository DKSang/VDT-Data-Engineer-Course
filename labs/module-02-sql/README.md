# Module 02 SQL Lab – Telecom Dataset

## Mục tiêu

Lab này tạo một PostgreSQL database nhỏ nhưng đủ quan hệ để luyện:

- filtering và NULL semantics;
- aggregation theo grain;
- one-to-many / many-to-many join reasoning;
- window functions;
- dedup và latest-record patterns;
- incremental extraction;
- execution plan và index.

## Chạy nhanh bằng Docker

Nếu máy đã có Docker:

```bash
docker run --name vdt-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=vdt_sql \
  -p 5432:5432 \
  -d postgres:18
```

Sau đó dùng `psql`, DBeaver, DataGrip hoặc VS Code PostgreSQL extension để chạy theo thứ tự:

```text
schema.sql
seed.sql
```

Nếu đã có PostgreSQL local thì không cần Docker.

## Data model

```text
plans 1 ────────< subscriptions >──────── 1 customers
                         │
                         │
customers 1 ─────< billing_transactions

cell_towers 1 ───< network_events

customers 1 ─────< customer_status_history
```

### Grain của từng bảng

| Bảng | Grain |
|---|---|
| `customers` | 1 row / customer |
| `plans` | 1 row / plan |
| `subscriptions` | 1 row / subscription contract |
| `billing_transactions` | 1 row / billing transaction |
| `cell_towers` | 1 row / cell tower |
| `network_events` | 1 row / network event |
| `customer_status_history` | 1 row / customer status change |

## Quy ước quan trọng

1. `network_events.event_id` trong schema không được ép unique để có thể luyện dedup.
2. `customer_status_history` có thể có nhiều row/customer vì đây là history table.
3. Một customer có thể có nhiều billing transaction và nhiều subscription theo thời gian.
4. `subscriptions.ended_at IS NULL` nghĩa là contract chưa có thời điểm kết thúc được ghi nhận; không tự động đồng nghĩa với mọi định nghĩa business về “active”.
5. Mọi câu hỏi aggregate phải ghi rõ grain output trước khi viết SQL.

## Workflow học

Tạo thư mục cá nhân, ví dụ:

```text
my-work/module-02/
├── lesson-01.sql
├── lesson-02.sql
├── ...
├── lesson-08.sql
└── notes.md
```

Với mỗi bài tập, lưu cả:

```sql
-- Expected grain:
-- Assumptions:
-- Query:

-- Validation checks:
-- 1.
-- 2.
```

Đừng chỉ lưu query chạy được; hãy lưu reasoning khiến query đó đáng tin.