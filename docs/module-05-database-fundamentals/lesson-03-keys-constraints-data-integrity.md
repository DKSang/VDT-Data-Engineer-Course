# Lesson 03 – Keys, Constraints & Data Integrity

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- phân biệt candidate key, primary key, unique key và foreign key;
- dùng `NOT NULL`, `CHECK`, `UNIQUE`, `PRIMARY KEY`, `FOREIGN KEY` đúng mục tiêu;
- giải thích referential integrity và orphan records;
- hiểu constraint là executable data contract ở RDBMS;
- biết constraint nào Databricks Delta enforce và constraint nào chỉ informational;
- quyết định integrity rule nên nằm ở database, pipeline, application hay nhiều lớp.

## 2. Source alignment

### Primary Databricks sources

- Constraints on Databricks: https://docs.databricks.com/aws/en/tables/constraints
- Constraint clause: https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-syntax-ddl-create-table-constraint

### Supplementary primary sources

- PostgreSQL Constraints: https://www.postgresql.org/docs/18/ddl-constraints.html

## 3. Principles

### Principle 1 – A constraint protects an assumption continuously

Comment trong README không ngăn bad row được insert. Database constraint có thể biến assumption thành rule được kiểm tra ở write time.

### Principle 2 – Keys express identity, not just join convenience

Nếu business không định nghĩa identity rõ, dedup, CDC, upsert và history đều trở nên mơ hồ.

### Principle 3 – Referential integrity is about valid relationships

`subscription.customer_id = 999999` nhưng customer không tồn tại là orphan relation. FK có thể ngăn state này trong RDBMS.

### Principle 4 – Enforcement differs by platform

Không được suy luận:

> “Có khai báo PRIMARY KEY nghĩa là engine luôn enforce uniqueness.”

Trên Databricks, `NOT NULL` và `CHECK` là enforced constraints; primary key, foreign key và unique constraints có thể là informational only.

## 4. Fundamentals

### 4.1 Candidate key

Minimal attribute set có thể identify một entity uniquely theo business rule.

Example possible candidates:

```text
customer_id
national_id
phone_number (nếu business guarantee unique/current)
```

Không phải mọi candidate đều nên làm primary key.

### 4.2 Primary key

Trong PostgreSQL, primary key implies unique + not null semantics và được engine enforce.

```sql
CREATE TABLE customers (
  customer_id BIGINT PRIMARY KEY,
  email TEXT
);
```

### 4.3 UNIQUE

```sql
email TEXT UNIQUE
```

Nhưng NULL semantics của UNIQUE có thể khác intuition và khác engine/options. Không giả định cross-engine behavior nếu chưa đọc docs.

### 4.4 NOT NULL

```sql
customer_id BIGINT NOT NULL
```

Use when absence is invalid, không phải chỉ vì developer “thường có value”.

### 4.5 CHECK

```sql
CHECK (amount >= 0)
```

Useful for row-local invariant.

Bad use: check constraint cố validate dynamic data từ table khác; cross-row/cross-table rules cần mechanism khác.

### 4.6 FOREIGN KEY

```sql
customer_id BIGINT REFERENCES customers(customer_id)
```

FK maintains referential integrity from child to parent.

Questions to decide:

```text
What happens on parent DELETE?
RESTRICT?
CASCADE?
SET NULL?
```

Choice is business semantics.

### 4.7 Surrogate vs natural key

Surrogate key:

```text
subscription_id = 2001
```

Natural/business key may be:

```text
(source_system, source_subscription_code)
```

A surrogate key does not remove need to understand business uniqueness.

### 4.8 Constraints and pipelines

Operational DB may enforce PK/FK strongly.

Lakehouse ingestion often receives imperfect source data. You may need:

```text
Bronze: preserve raw
Silver: validate/quarantine/dedup
Gold: publish trusted relation
```

Database and pipeline integrity complement rather than replace each other.

### 4.9 Databricks constraint difference

Databricks Delta supports enforced `NOT NULL` and `CHECK`. PK/FK/UNIQUE metadata can document relationships and inform optimization, but should not be treated as proof that bad duplicates/orphans cannot exist.

Therefore pipeline validation remains necessary.

## 5. Worked example – Subscription integrity

Requirements:

1. subscription_id unique;
2. customer_id required and valid;
3. plan_id required and valid;
4. status in accepted values;
5. ended_at cannot be before started_at.

PostgreSQL design:

```sql
CREATE TABLE subscriptions (
  subscription_id BIGINT PRIMARY KEY,
  customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
  plan_id INT NOT NULL REFERENCES plans(plan_id),
  status TEXT NOT NULL CHECK (status IN ('active','suspended','cancelled')),
  started_at TIMESTAMP NOT NULL,
  ended_at TIMESTAMP,
  CHECK (ended_at IS NULL OR ended_at >= started_at)
);
```

This converts five assumptions into executable rules.

## 6. Hands-on lab

### Part A – Break the schema intentionally

Try to insert:

1. duplicate primary key;
2. NULL required key;
3. orphan customer_id;
4. invalid status;
5. ended_at before started_at.

For each:

```text
Expected failure:
Actual DB error:
Constraint responsible:
```

### Part B – Remove enforcement

Create `subscriptions_staging` without constraints and insert the same bad rows.

Write SQL checks to detect them afterward.

Explain difference between:

```text
prevent bad state
vs
allow then detect bad state
```

### Part C – Databricks contrast

On a Delta table:

- add `NOT NULL`/`CHECK` when supported;
- declare/document PK/FK if your environment supports it;
- prove with validation query that declared informational PK/FK should not be treated as enforcement.

### Challenge – business identity

Network events have:

```text
ingest_row_id
source_system
event_id
payload_version
```

Answer:

- technical row identity?
- business event identity?
- version identity?
- target upsert key?

## 7. Knowledge check – MCQ

**Q1.** Primary key primarily represents:  
A. row/entity identity  
B. sort order only  
C. storage compression  
D. transaction isolation

**Q2.** Foreign key protects:  
A. referential integrity  
B. query timeout  
C. WAL size  
D. heap order

**Q3.** `CHECK (amount >= 0)` protects:  
A. row-level domain invariant  
B. join cardinality automatically  
C. all cross-table business rules  
D. index choice

**Q4.** Databricks PK/FK should be assumed:  
A. informational unless docs say enforced  
B. always same enforcement as PostgreSQL  
C. impossible to declare  
D. replacement for validation

**Q5.** Surrogate key:  
A. does not automatically define business uniqueness  
B. always natural  
C. removes need for business key  
D. cannot join

**Q6.** Staging without constraints:  
A. requires explicit validation if trust is needed  
B. guarantees perfect data  
C. removes duplicates automatically  
D. enforces FK implicitly

## 8. Tự luận / Interview

1. PK vs UNIQUE vs candidate key.
2. Why can surrogate key and business key both be necessary?
3. Foreign key prevents what data state?
4. When is `ON DELETE CASCADE` dangerous?
5. Why might Bronze ingest not enforce all business rules?
6. How would you find orphan records if FK is not enforced?
7. PostgreSQL vs Databricks constraint enforcement differs how?
8. What rules belong in DB vs pipeline?

## 9. Exit criteria

- [ ] create schema with PK/FK/NOT NULL/CHECK;
- [ ] intentionally trigger >=5 constraint failures;
- [ ] reproduce equivalent validation SQL on unconstrained staging;
- [ ] explain Databricks informational constraints;
- [ ] identify technical vs business key in event data;
- [ ] >=5/6 MCQ.
