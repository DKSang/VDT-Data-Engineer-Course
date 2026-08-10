# Lesson 05 – Concurrency, MVCC, Isolation & Deadlocks

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- explain why concurrency control exists;
- explain MVCC and snapshot visibility at practical level;
- distinguish Read Committed, Repeatable Read and Serializable in PostgreSQL;
- identify dirty read, non-repeatable read, phantom read and serialization anomaly;
- explain row locks and deadlocks;
- design a consistent lock ordering and transaction retry strategy;
- relate isolation to Data Engineering extraction consistency.

## 2. Source alignment

### Primary Databricks sources

- ACID guarantees: https://docs.databricks.com/aws/en/lakehouse/acid
- Isolation levels and write conflicts: https://docs.databricks.com/aws/en/optimizations/isolation/

### Supplementary primary sources

- PostgreSQL MVCC: https://www.postgresql.org/docs/18/mvcc.html
- PostgreSQL transaction isolation: https://www.postgresql.org/docs/18/transaction-iso.html

## 3. Principles

### Principle 1 – Concurrency creates interleavings

Two individually correct transactions can produce an incorrect outcome if their reads/writes interleave in a harmful way.

### Principle 2 – Isolation defines observable worlds

Isolation level answers:

> Which committed/uncommitted changes can this transaction observe, and what anomalies are prevented?

### Principle 3 – MVCC favors snapshots over read/write blocking

PostgreSQL uses multiple row versions so readers can often observe a consistent snapshot without blocking writers.

### Principle 4 – Stronger isolation can require retries

Serializable correctness does not mean every transaction always succeeds first try. Detecting dangerous concurrency may abort one transaction; application must retry the whole logical unit.

## 4. Fundamentals

### 4.1 Dirty read

Transaction A reads uncommitted data from B. If B rolls back, A observed a state that never committed.

PostgreSQL does not allow dirty reads even when Read Uncommitted is requested; it behaves as Read Committed.

### 4.2 Non-repeatable read

Inside one transaction:

```text
SELECT balance → 100
other transaction commits balance=80
SELECT balance again → 80
```

Possible in PostgreSQL Read Committed because each statement gets a fresh snapshot.

### 4.3 Phantom read

A repeated predicate query returns a different set of rows because another transaction inserts/deletes matching rows.

### 4.4 Serialization anomaly

Concurrent result cannot be explained by any serial ordering of the same committed transactions.

Classic pattern: write skew.

### 4.5 Read Committed

Default PostgreSQL isolation.

Each statement sees a snapshot as of statement start, plus its own prior writes.

Consequence: two SELECT statements in one transaction can see different committed states.

### 4.6 Repeatable Read

Transaction sees a stable snapshot from its first non-transaction-control statement.

PostgreSQL Repeatable Read prevents non-repeatable reads and phantom reads, but serialization anomalies can still exist.

### 4.7 Serializable

Goal:

> Successfully committed concurrent transactions have an outcome equivalent to some serial execution.

Applications must handle serialization failures with retry.

### 4.8 MVCC mental model

Simplified:

```text
row v1 exists
transaction T1 starts → snapshot sees v1
T2 updates row → creates v2 and commits
T1 may continue seeing v1 depending on isolation/snapshot
new transaction sees v2
```

Physical implementation has more details; the key idea is visibility by transaction/version rather than destructive in-place state from every reader's perspective.

### 4.9 Locks

MVCC does not eliminate all locks.

Updates of the same row can conflict. Explicit locking may be needed:

```sql
SELECT ... FOR UPDATE;
```

Use when business logic must read a row and reserve it against conflicting updates.

### 4.10 Deadlock

T1:

```text
lock account A
wait for B
```

T2:

```text
lock account B
wait for A
```

Cycle → deadlock. DB detects and aborts a participant.

Common prevention strategy: acquire locks in consistent order.

## 5. Worked example – Lost reservation / oversell reasoning

Inventory row:

```text
available_slots = 1
```

Two transactions both:

1. read available_slots = 1;
2. decide reservation allowed;
3. write new state.

A naive read-then-write may allow both business decisions against the same old state.

Safer patterns include:

```sql
UPDATE capacity
SET available_slots = available_slots - 1
WHERE resource_id = 10
  AND available_slots > 0
RETURNING available_slots;
```

or explicit row locking, depending on business logic.

Principle: make conflict visible to database rather than relying on application timing.

## 6. Hands-on lab

Use two `psql` sessions: Session A and Session B.

### Experiment 1 – Read Committed snapshot

A:

```sql
BEGIN;
SELECT status FROM subscriptions WHERE subscription_id = 2001;
```

B:

```sql
UPDATE subscriptions SET status='suspended' WHERE subscription_id=2001;
COMMIT;
```

A runs SELECT again. Record what it sees.

### Experiment 2 – Repeatable Read

Repeat after:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
```

Explain changed behavior.

### Experiment 3 – Row lock

A:

```sql
BEGIN;
SELECT * FROM accounts WHERE account_id=1 FOR UPDATE;
```

B tries to update same row. Observe wait/block behavior.

### Experiment 4 – Deadlock

A locks row 1 then requests row 2.
B locks row 2 then requests row 1.

Record database deadlock error and identify cycle.

### Experiment 5 – Serializable retry

Create a business invariant that can suffer write skew, run concurrent Serializable transactions and capture a serialization failure if reproduced.

Write retry pseudocode:

```text
for attempt in range(max_retries):
  begin
  try logical transaction
  commit
  if serialization failure: rollback + backoff + retry
```

### Data Engineering challenge – consistent extract

Pipeline reads:

```text
customers
subscriptions
billing_transactions
```

sequentially while source keeps changing.

Answer:

- could tables reflect different business moments?
- when is that acceptable?
- would Repeatable Read snapshot help?
- what source-load/long-transaction cost can arise?
- when is CDC a better design?

## 7. Knowledge check – MCQ

**Q1.** PostgreSQL Read Committed normally uses snapshot per:  
A. statement  
B. database lifetime  
C. table creation  
D. index

**Q2.** Repeatable Read gives a more stable:  
A. transaction snapshot  
B. schema name  
C. index root  
D. WAL file name

**Q3.** Serializable may require:  
A. application retry  
B. disabling transactions  
C. no concurrent users  
D. dropping constraints

**Q4.** MVCC mainly helps by:  
A. maintaining versions/snapshots for concurrency  
B. sorting every table  
C. removing all locks  
D. enforcing all business rules

**Q5.** Deadlock requires:  
A. circular wait dependency  
B. only one transaction  
C. SELECT DISTINCT  
D. no locks

**Q6.** `SELECT ... FOR UPDATE`:  
A. can lock selected rows for update coordination  
B. creates index  
C. disables WAL  
D. changes isolation to Serializable automatically

## 8. Tự luận / Interview

1. Dirty vs non-repeatable vs phantom read.
2. Read Committed vs Repeatable Read in PostgreSQL.
3. What is MVCC?
4. Why does MVCC not mean “no locks”?
5. What is deadlock and how can lock ordering reduce it?
6. Why should Serializable applications implement retries?
7. How can a multi-table ETL extract be inconsistent under source concurrency?
8. Long-lived source transactions can hurt operational systems how?

## 9. Exit criteria

- [ ] run two-session Read Committed experiment;
- [ ] run Repeatable Read experiment;
- [ ] demonstrate blocking row lock;
- [ ] reproduce or clearly simulate deadlock;
- [ ] explain four anomaly types;
- [ ] write serialization retry pseudocode;
- [ ] >=5/6 MCQ.
