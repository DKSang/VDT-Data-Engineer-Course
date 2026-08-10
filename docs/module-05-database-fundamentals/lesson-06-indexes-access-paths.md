# Lesson 06 – Indexes, Access Paths & Workload Trade-offs

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- explain why indexes can reduce read work;
- explain index maintenance/storage cost;
- understand B-tree, hash, GIN and BRIN at awareness/practical-selection level;
- reason about equality, range, ordering and multi-column access patterns;
- explain selectivity and why an index can be ignored;
- distinguish index design from query correctness;
- design candidate indexes from actual workload rather than “index every filter column”.

## 2. Source alignment

### Primary Databricks sources

This is a supplementary RDBMS lesson. Databricks-specific table layout/optimization belongs to later modules.

### Supplementary primary sources

- PostgreSQL Indexes: https://www.postgresql.org/docs/18/indexes.html
- B-tree: https://www.postgresql.org/docs/18/btree.html
- GIN: https://www.postgresql.org/docs/18/gin.html
- Built-in index access methods: https://www.postgresql.org/docs/18/indextypes.html

## 3. Principles

### Principle 1 – An index is an extra data structure maintained for access

Index is not free metadata. It consumes storage and must be updated as indexed data changes.

### Principle 2 – Optimize for query patterns, not columns in isolation

Question is not:

> Should `customer_id` have an index?

Better question:

> Which high-value queries filter/join/order by which columns, at what selectivity and frequency?

### Principle 3 – Index usefulness depends on work avoided

If query returns 90% of a table, walking an index plus fetching rows may be worse than scanning table directly.

### Principle 4 – Composite order encodes access patterns

Index `(customer_id, transaction_ts)` is especially natural for equality on customer then range/order on time.

Do not turn this into a blind left-prefix slogan; validate against real planner behavior.

## 4. Fundamentals

### 4.1 B-tree

Default PostgreSQL index type for many common ordered types.

Useful mental model:

```text
ordered search structure
→ equality
→ range
→ ordered retrieval
```

Example:

```sql
CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts);
```

### 4.2 Hash index

Hash index is equality-oriented.

Practical awareness:

- only equality operators;
- no ordering/range semantics;
- generally much less common default choice than B-tree.

### 4.3 GIN awareness

GIN is useful for composite/multi-valued data where queries search contained keys/elements, such as full-text or arrays/JSON-related operator classes.

Do not use B-tree intuition for every data type.

### 4.4 BRIN awareness

BRIN summarizes ranges of physical blocks. It can be very compact and useful for huge tables where physical ordering correlates with queried value, e.g. append-heavy time-series tables.

It is not a direct replacement for B-tree.

### 4.5 Selectivity

Highly selective:

```sql
WHERE transaction_id = 918273645
```

Low selective:

```sql
WHERE status = 'success'
```

if most rows are `success`.

The planner weighs access costs; “index exists” does not mean “index must be used”.

### 4.6 Composite index

Query:

```sql
WHERE customer_id = 1001
  AND transaction_ts >= TIMESTAMP '2026-08-01'
  AND transaction_ts <  TIMESTAMP '2026-09-01'
ORDER BY transaction_ts
```

Candidate:

```sql
(customer_id, transaction_ts)
```

Reasoning:

- equality narrows customer;
- range traverses time values within that customer;
- ordering may benefit from index order.

### 4.7 Covering/index-only awareness

Some engines/plans can satisfy requested columns from index without visiting heap for every row if visibility/conditions allow.

Do not memorize “INCLUDE always faster”; measure.

### 4.8 Write amplification

Each extra index may require work on:

```text
INSERT
UPDATE indexed column
DELETE
VACUUM/maintenance
storage/cache
```

High-write OLTP table with many indexes can suffer.

### 4.9 Partial index awareness

If only a subset matters:

```sql
CREATE INDEX ...
WHERE status = 'pending';
```

can target a valuable selective workload.

Again: planner must prove predicate relation.

## 5. Worked example – Customer transaction history

Workload:

```sql
SELECT transaction_id, transaction_ts, amount, status
FROM billing_transactions
WHERE customer_id = $1
  AND transaction_ts >= $2
  AND transaction_ts < $3
ORDER BY transaction_ts DESC
LIMIT 100;
```

Candidate index:

```sql
CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts DESC);
```

Why not index `status` first?

Because the query does not primarily search by status, and status is often low-cardinality.

Why not index every selected column?

Because index size/write cost may exceed benefit. Start from workload and measure.

## 6. Hands-on lab

Scale `billing_transactions` to >=100k rows.

### Experiment A – no candidate index

Run query by customer/time and capture:

```sql
EXPLAIN (ANALYZE, BUFFERS)
...
```

### Experiment B – single-column

```sql
CREATE INDEX idx_billing_customer
ON billing_transactions(customer_id);
```

Re-run.

### Experiment C – composite

```sql
CREATE INDEX idx_billing_customer_ts
ON billing_transactions(customer_id, transaction_ts);
```

Re-run.

Compare:

```text
scan node
rows read
buffers
sort node
execution time
```

### Experiment D – low selectivity

Index `status`, then query a value representing most rows. Observe whether planner chooses index or sequential scan.

### Experiment E – write cost

Measure rough time for bulk inserts with:

1. minimal indexes;
2. several extra indexes.

Do not claim universal benchmark; record environment and relative observation.

### Challenge – choose access method

For each workload, propose B-tree/GIN/BRIN/no index and explain:

1. customer_id equality;
2. transaction timestamp range;
3. tags array contains value;
4. 1B append-only events ordered by event_ts;
5. status column with 99% `success`.

## 7. Knowledge check – MCQ

**Q1.** Index primarily helps by:  
A. reducing search/read work for suitable access patterns  
B. guaranteeing every query faster  
C. removing write cost  
D. replacing constraints

**Q2.** B-tree is naturally suited to:  
A. equality/range/order operations  
B. only image search  
C. transaction rollback  
D. WAL decoding

**Q3.** Low-selectivity predicate may cause planner to:  
A. prefer sequential scan  
B. always force index  
C. fail syntax  
D. drop table

**Q4.** Composite `(customer_id, transaction_ts)` matches:  
A. customer equality + time range workload  
B. random JSON key only  
C. no filter workload always  
D. foreign-key enforcement only

**Q5.** More indexes usually mean:  
A. more write/storage maintenance  
B. zero downside  
C. fewer data structures  
D. no planning

**Q6.** BRIN is especially interesting for:  
A. huge physically correlated data ranges  
B. all point lookups always  
C. enforcing PK  
D. rollback

## 8. Tự luận / Interview

1. Why can index make reads faster but writes slower?
2. What is selectivity?
3. B-tree vs hash awareness.
4. When is composite index useful?
5. Why might planner ignore an existing index?
6. GIN and BRIN solve different access patterns how?
7. Why should you not index every foreign key/filter column blindly?
8. What evidence would you collect before/after adding an index?

## 9. Exit criteria

- [ ] run >=3 index experiments;
- [ ] compare no/single/composite index;
- [ ] explain low-selectivity scan choice;
- [ ] explain write amplification;
- [ ] choose plausible access method for 5 workloads;
- [ ] >=5/6 MCQ.
