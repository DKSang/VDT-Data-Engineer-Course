# Lesson 01 – Database Workloads & Architecture

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- phân biệt OLTP và OLAP theo access pattern, latency, concurrency, data shape và consistency requirement;
- giải thích vì sao operational database, warehouse và lakehouse tối ưu cho các mục tiêu khác nhau;
- phân biệt row-oriented mental model với columnar analytical storage ở mức principle;
- nhận diện khi nào Data Engineer nên query trực tiếp source DB và khi nào nên ingest/copy sang analytical system;
- mô tả trade-off giữa freshness, source load, consistency và cost.

## 2. Source alignment

### Primary Databricks sources

- Data warehousing architecture: https://docs.databricks.com/aws/en/sql/get-started/data-warehousing-concepts
- What is a lakehouse?: https://docs.databricks.com/aws/en/lakehouse/
- Databricks reference architectures: https://docs.databricks.com/aws/en/lakehouse-architecture/reference

### Supplementary primary sources

- PostgreSQL tutorial / relational concepts: https://www.postgresql.org/docs/18/tutorial.html

### Scope note

Databricks source xác lập lakehouse/warehouse role. OLTP fundamentals được thêm như prerequisite để hiểu source systems và database workload.

## 3. Principles

### Principle 1 – Architecture follows workload

Không có database “tốt nhất” chung chung. Hãy hỏi:

```text
How many concurrent users?
Read/write ratio?
Point lookup hay scan billions of rows?
Latency target?
Transaction scope?
Historical analysis?
Data freshness?
```

Một hệ tối ưu cho 5 ms point lookup không nhất thiết tối ưu cho scan 10 TB.

### Principle 2 – Operational truth and analytical truth serve different jobs

OLTP thường phục vụ trạng thái hiện tại của business process:

```text
customer account
order
payment
subscription
inventory
```

Analytical systems thường phục vụ:

```text
trend
history
aggregation
cross-source analysis
BI / ML
```

### Principle 3 – Querying source directly has a cost

Một analytical query nặng chạy trên production OLTP có thể cạnh tranh CPU, memory, I/O và locks với user-facing traffic.

Do đó Data Engineer phải nghĩ về extraction architecture, không chỉ câu SQL.

### Principle 4 – Freshness is not free

Near-real-time freshness thường yêu cầu nhiều coordination/state hơn batch daily.

Trade-off luôn tồn tại giữa:

```text
freshness
source load
complexity
cost
consistency
```

## 4. Fundamentals

### 4.1 OLTP characteristics

Typical characteristics:

- nhiều transactions nhỏ;
- point lookup/update theo key;
- high concurrency;
- current state quan trọng;
- normalized schema thường hữu ích;
- strong integrity/transaction semantics quan trọng.

Example:

```sql
UPDATE subscriptions
SET status = 'cancelled'
WHERE subscription_id = 2001;
```

### 4.2 OLAP characteristics

Typical characteristics:

- scan nhiều rows;
- aggregation/grouping;
- historical data;
- joins across subject areas;
- fewer writes but large batch/stream ingestion;
- columnar storage/layout thường hữu ích.

Example:

```sql
SELECT province, DATE_TRUNC('month', transaction_ts), SUM(amount)
FROM billing_transactions
GROUP BY province, DATE_TRUNC('month', transaction_ts);
```

### 4.3 Row-oriented vs columnar mental model

Row-oriented layout thuận lợi khi application cần lấy/update phần lớn columns của một row theo key.

Columnar layout thuận lợi khi analytics chỉ scan một vài columns trên rất nhiều rows.

Đừng biến đây thành luật tuyệt đối; storage engine có nhiều optimization. Mục tiêu là hiểu **work avoided**.

### 4.4 Database vs warehouse vs lakehouse

Operational relational DB:

```text
transaction processing
constraints
low-latency row operations
```

Warehouse:

```text
analytical SQL
modeled historical data
BI workloads
```

Lakehouse:

```text
open data/storage architecture
warehouse-style analytics
batch + streaming + ML/AI workloads
```

Databricks describes lakehouse as combining benefits of lakes and warehouses, with Delta Lake providing ACID/schema capabilities and Unity Catalog governance.

### 4.5 Source extraction patterns

Possible patterns:

1. direct query;
2. periodic full snapshot;
3. incremental timestamp query;
4. CDC/log-based capture;
5. replication/read replica;
6. federation for selected workloads.

Selection depends on source guarantees and workload impact.

## 5. Worked example – Telecom subscription dashboard

Requirement:

> Dashboard needs active subscriber count by province every 5 minutes.

Naive design:

```text
BI dashboard → production subscription DB
```

Every dashboard refresh scans/join operational tables.

Questions:

- source has enough capacity?
- one query or hundreds of concurrent viewers?
- transaction consistency needed across tables?
- 5-minute freshness requires CDC, timestamp incremental, or direct query?
- can stale-by-5-min copy satisfy business need?

A more scalable design may be:

```text
Operational PostgreSQL
      ↓ CDC / incremental
Lakehouse Silver table
      ↓
Gold aggregate
      ↓
Dashboard
```

The point is not “always copy”. The point is **separate workload when the trade-off justifies it**.

## 6. Hands-on lab

### Part A – Classify workloads

For each requirement, classify OLTP/OLAP/mixed and explain why:

1. update a customer's email;
2. authorize a payment;
3. monthly revenue by province for 3 years;
4. latest 100 network incidents;
5. churn feature generation over 12 months;
6. current subscription lookup by customer_id.

### Part B – Source-load reasoning

Given:

```text
production DB: 4 vCPU
2,000 writes/sec peak
BI query scans 20M billing rows
50 dashboard viewers refresh every 30 sec
```

Write a one-page design explaining why/when you would isolate analytics.

### Part C – Query shape

For 10 sample requirements, identify:

```text
point lookup
range scan
full scan
aggregate
join-heavy
write-heavy
```

### Telecom challenge

Design two architectures for daily revenue:

A. direct source query;
B. incremental copy → lakehouse.

Compare:

```text
freshness
source impact
failure recovery
historical retention
cost
operational complexity
```

## 7. Knowledge check – MCQ

**Q1.** OLTP workload thường ưu tiên gì hơn?  
A. nhiều small transactions/point operations  
B. full-table scans only  
C. offline training only  
D. no concurrency

**Q2.** OLAP query thường:  
A. aggregate/scan nhiều rows  
B. update một row duy nhất luôn  
C. không join  
D. không có history

**Q3.** Direct BI query lên OLTP có risk chính nào?  
A. cạnh tranh resource với application workload  
B. SQL không chạy được  
C. data tự duplicate  
D. primary key biến mất

**Q4.** Freshness cao hơn thường:  
A. có thể tăng complexity/cost  
B. luôn miễn phí  
C. giảm mọi consistency concern  
D. bỏ cần state

**Q5.** Row vs column orientation nên chọn dựa trên:  
A. workload/access pattern  
B. tên vendor  
C. số developer  
D. màu dashboard

**Q6.** Lakehouse trong Databricks nhằm:  
A. kết hợp analytical/lake capabilities trên cùng platform  
B. thay mọi OLTP database  
C. cấm streaming  
D. chỉ lưu CSV

## 8. Tự luận / Interview

1. OLTP vs OLAP khác nhau ở workload nào?
2. Tại sao normalized schema thường hợp operational system hơn một giant flat table?
3. Khi nào direct query source DB chấp nhận được?
4. Khi nào bạn cần CDC thay vì daily snapshot?
5. Source load và data freshness trade-off ra sao?
6. Lakehouse có làm OLTP database trở nên vô nghĩa không? Vì sao?
7. Nếu dashboard chỉ cần stale 10 phút, architecture có thể đơn giản hơn thế nào?

## 9. Exit criteria

- [ ] phân loại đúng ít nhất 8/10 workloads;
- [ ] giải thích được source-load risk;
- [ ] vẽ được OLTP → ingestion → lakehouse flow;
- [ ] so sánh direct query vs copy bằng trade-off;
- [ ] đạt >=5/6 MCQ.
