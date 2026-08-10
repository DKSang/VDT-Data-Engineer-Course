# Lesson 07 – Query Planner, Statistics & EXPLAIN

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- explain the difference between SQL semantics and physical execution plan;
- read basic PostgreSQL plan nodes;
- explain estimated rows, actual rows, loops and cost at practical level;
- explain why cardinality estimation matters;
- understand planner statistics and data skew awareness;
- identify nested loop, hash join and merge join mental models;
- use `EXPLAIN` vs `EXPLAIN ANALYZE` safely;
- form an optimization hypothesis based on evidence rather than folklore.

## 2. Source alignment

### Primary Databricks sources

- Module 02 already covers Databricks `EXPLAIN` and Query Profile. This lesson adds RDBMS planner fundamentals for transfer learning.

### Supplementary primary sources

- PostgreSQL Using EXPLAIN: https://www.postgresql.org/docs/18/using-explain.html
- PostgreSQL Planner Statistics: https://www.postgresql.org/docs/18/planner-stats.html
- How the Planner Uses Statistics: https://www.postgresql.org/docs/18/planner-stats-details.html

## 3. Principles

### Principle 1 – SQL describes result; planner chooses physical work

Two equivalent SQL queries may produce different plans depending on engine, statistics, indexes and data distribution.

### Principle 2 – Cardinality estimates drive many cost decisions

If planner expects 100 rows but gets 10,000,000, join order/algorithm and memory decisions may be poor.

### Principle 3 – EXPLAIN is evidence, not a score leaderboard

A lower estimated cost is not a universal time unit. Compare plans within context and use actual measurements when appropriate.

### Principle 4 – Optimization loop is scientific

```text
prove correctness
measure baseline
inspect plan
form hypothesis
change one thing
remeasure
```

## 4. Fundamentals

### 4.1 EXPLAIN

```sql
EXPLAIN
SELECT ...;
```

shows estimated plan and costs without executing SELECT result logic for runtime metrics.

### 4.2 EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT ...;
```

executes query and reports actual rows/timing plus buffer information.

For write statements, `ANALYZE` actually performs side effects unless wrapped/rolled back appropriately.

### 4.3 Scan nodes

Common nodes:

```text
Seq Scan
Index Scan
Index Only Scan
Bitmap Heap Scan
```

Do not classify Seq Scan as automatically bad. Full scan can be the cheapest correct choice.

### 4.4 Sort and aggregate

```text
Sort
Aggregate
HashAggregate
GroupAggregate
```

Sort may be required for ordering, merge join, or grouped processing depending on plan.

### 4.5 Nested Loop

Mental model:

```text
for each outer row:
  find matching inner rows
```

Can be excellent when outer side is small and inner lookup efficient.

### 4.6 Hash Join

Mental model:

```text
build hash table from one input
scan/probe from other input
```

Natural for equality joins when build-side cost/memory is reasonable.

### 4.7 Merge Join

Mental model:

```text
walk two ordered streams by join key
```

Can benefit when ordering already exists or sort cost is justified.

### 4.8 Estimated vs actual rows

Example:

```text
estimated: 100
actual:    100000
```

Error factor 1000x.

Investigate:

```text
stale statistics
skew
correlated predicates
non-uniform distribution
join dependency
expression/cast
```

### 4.9 Statistics

Planner stores estimates such as:

- row counts;
- distinct values;
- null fraction;
- common values/frequencies;
- histograms depending on type/configuration.

Statistics are summaries, not full data copies.

### 4.10 ANALYZE

After major data changes, fresh statistics may be needed so planner sees new distribution.

Autovacuum/autoanalyze normally handles much of this, but large bulk changes can make an explicit `ANALYZE` useful in labs/operations.

## 5. Worked example – Join estimate changes

Query:

```sql
SELECT c.province, SUM(b.amount)
FROM billing_transactions b
JOIN customers c ON c.customer_id = b.customer_id
WHERE b.status = 'success'
GROUP BY c.province;
```

Ask before plan:

```text
billing rows?
success selectivity?
customers unique by customer_id?
expected matches per billing row?
```

Then run:

```sql
EXPLAIN (ANALYZE, BUFFERS)
...
```

Look for:

- scan choice on billing;
- join algorithm;
- estimated/actual rows before aggregate;
- aggregate node;
- whether estimates roughly match reality.

If join output rows greatly exceed fact rows, investigate correctness/cardinality before performance.

## 6. Hands-on lab

### Part A – Plan reading

Capture plans for:

1. PK point lookup;
2. low-selectivity status filter;
3. customer/time range;
4. billing → customer join;
5. aggregation by province;
6. intentionally fan-out join to status history.

For each, record:

```text
root node
scan node(s)
join node
estimated rows
actual rows
largest error factor
```

### Part B – Statistics experiment

1. create `billing_big` with skewed status/customer distribution;
2. run `ANALYZE`;
3. capture plan;
4. insert a large new skewed batch;
5. inspect plan before/after fresh `ANALYZE`.

Do not guarantee dramatic difference; document what your environment actually shows.

### Part C – Join algorithm experiment

Find queries that produce nested loop/hash join if possible. Explain why input sizes/access paths make the choice reasonable.

Do not force planner settings just to prove one algorithm unless clearly labelled as educational experiment.

### Part D – Correctness before optimization

Take fan-out query:

```sql
billing_transactions
JOIN customer_status_history USING (customer_id)
```

Show that reducing runtime without fixing multiple matches would still produce wrong revenue.

### Challenge – performance incident note

Write:

```text
Symptom
Business query
Correctness assumptions
Input sizes
Plan evidence
Estimate error
Likely work driver
Change proposed
Expected trade-off
Post-change evidence
```

## 7. Knowledge check – MCQ

**Q1.** Planner primarily chooses:  
A. physical execution strategy  
B. business metric definition  
C. primary-key semantics  
D. data contract ownership

**Q2.** `EXPLAIN ANALYZE`:  
A. executes statement to collect actual metrics  
B. never executes  
C. creates index automatically  
D. updates statistics only

**Q3.** Estimated rows 100 vs actual 100000 suggests:  
A. large cardinality-estimation error  
B. perfect estimate  
C. FK violation automatically  
D. deadlock

**Q4.** Hash join mental model:  
A. build hash then probe  
B. nested iteration only  
C. WAL replay  
D. B-tree root scan only

**Q5.** Seq Scan:  
A. can be optimal for large-result/full-scan workloads  
B. is always a bug  
C. means no statistics  
D. means corrupt table

**Q6.** Planner statistics mainly help estimate:  
A. cardinality/selectivity/cost  
B. source business owner  
C. encryption keys  
D. Git history

## 8. Tự luận / Interview

1. What is the difference between logical SQL and physical plan?
2. Why does cardinality estimation matter?
3. EXPLAIN vs EXPLAIN ANALYZE.
4. Nested Loop vs Hash Join vs Merge Join.
5. Why can stale statistics hurt planning?
6. Why can Seq Scan be correct even with an index?
7. How do you investigate a 1000x estimate error?
8. Why must correctness precede tuning?

## 9. Exit criteria

- [ ] capture >=6 plans;
- [ ] identify scans/joins/aggregates;
- [ ] calculate estimate error factor;
- [ ] explain three join algorithms;
- [ ] run statistics experiment;
- [ ] write one evidence-based performance incident note;
- [ ] >=5/6 MCQ.
