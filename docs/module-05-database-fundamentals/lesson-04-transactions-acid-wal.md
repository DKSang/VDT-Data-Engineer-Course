# Lesson 04 – Transactions, ACID & Write-Ahead Logging

## 1. Learning objectives

Sau bài này, bạn phải có thể:

- explain transaction boundary, `BEGIN`, `COMMIT`, `ROLLBACK`;
- explain ACID with concrete failure scenarios rather than memorized definitions;
- distinguish logical consistency from durability;
- explain why atomic transfer needs multiple statements inside one transaction;
- explain WAL/redo mental model at a practical level;
- reason about crash before commit, after WAL flush, and after commit acknowledgement;
- compare statement-level atomicity with multi-statement transaction scope.

## 2. Source alignment

### Primary Databricks sources

- ACID guarantees: https://docs.databricks.com/aws/en/lakehouse/acid
- Transactions: https://docs.databricks.com/aws/en/transactions
- Delta Lake: https://docs.databricks.com/aws/en/delta

### Supplementary primary sources

- PostgreSQL COMMIT: https://www.postgresql.org/docs/18/sql-commit.html
- PostgreSQL WAL: https://www.postgresql.org/docs/18/wal-intro.html
- Reliability/WAL chapter: https://www.postgresql.org/docs/18/wal.html

## 3. Principles

### Principle 1 – A transaction is a unit of business state change

Do not choose transaction boundaries only by code convenience.

Example transfer:

```text
A.balance -= 100
B.balance += 100
```

If these statements represent one business action, they should not be allowed to commit independently.

### Principle 2 – Atomicity prevents partial success

A transaction should either publish all its intended changes or none.

### Principle 3 – Durability requires a recovery story

“COMMIT returned success” must mean the system has enough durable information to recover committed state after crash, according to the system's configured guarantees.

### Principle 4 – Logs can make recovery cheaper than flushing every page

WAL principle:

> log the intended data-page changes durably before the modified data pages themselves must be written permanently.

This enables redo after crash.

## 4. Fundamentals

### 4.1 Transaction boundary

```sql
BEGIN;
UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
COMMIT;
```

If validation fails:

```sql
ROLLBACK;
```

### 4.2 Atomicity

Failure scenario:

```text
statement 1 succeeds
process crashes
statement 2 never runs
```

Without a proper shared transaction, business state is partial.

### 4.3 Consistency

Consistency is not “database always knows business truth.”

It means transaction takes database from one valid state to another valid state **given the constraints/invariants that are actually encoded and respected**.

Example invariant:

```text
balance >= 0
```

If that rule is not encoded anywhere, ACID does not magically invent it.

### 4.4 Isolation

Isolation concerns concurrent transactions. Lesson 05 goes deep.

Question:

> What intermediate/concurrent effects can another transaction observe?

### 4.5 Durability

After successful commit, changes survive failures according to storage/logging guarantees.

In PostgreSQL, WAL is central to crash recovery. Data pages do not all need to be flushed at each commit if WAL describing their changes has been made durable first.

### 4.6 WAL mental model

Simplified sequence:

```text
transaction changes buffer pages
        ↓
WAL records describe changes
        ↓
WAL flushed sufficiently for commit
        ↓
COMMIT acknowledged
        ↓
data pages may be flushed later
        ↓
crash recovery can REDO committed changes
```

Do not interpret WAL as “a copy of every SQL statement.” It is a recovery/change log at storage-engine level.

### 4.7 Checkpoint awareness

Checkpoint establishes a recovery reference so crash recovery does not need to replay all historical WAL from the beginning of time.

At fresher level, know:

```text
WAL = change/recovery record stream
checkpoint = point that bounds recovery work
```

### 4.8 Logical vs physical change logs

PostgreSQL WAL is physical/recovery-oriented. CDC systems may expose logical row changes through logical decoding or other mechanisms.

Do not assume every transaction log is directly consumable as business CDC event.

### 4.9 Databricks/Delta contrast

Delta Lake uses a transaction log to commit table versions atomically. Databricks writes data files and then commits metadata/state so a new table version becomes visible atomically.

The implementation differs from PostgreSQL WAL, but the shared principle is:

```text
committed state must have an authoritative transaction record
```

## 5. Worked example – Billing refund

Business action:

1. mark original billing transaction as refunded;
2. create refund ledger entry;
3. update customer balance/credit if applicable.

Bad:

```sql
UPDATE billing_transactions ...;
-- application crashes
INSERT INTO refund_ledger ...;
```

Better when same DB and same consistency boundary:

```sql
BEGIN;

UPDATE billing_transactions
SET status = 'refunded'
WHERE transaction_id = 3010;

INSERT INTO refund_ledger(...)
VALUES (...);

COMMIT;
```

If statement 2 fails, rollback protects all-or-nothing behavior.

## 6. Hands-on lab

### Part A – Commit and rollback

1. Record current row.
2. `BEGIN`.
3. Update row.
4. Query inside same transaction.
5. `ROLLBACK`.
6. Verify original state returns.
7. Repeat with `COMMIT`.

### Part B – Atomic transfer simulation

Create:

```sql
accounts(account_id, balance CHECK (balance >= 0))
```

Write a transfer transaction.

Test:

- valid transfer;
- insufficient balance causing constraint failure;
- explicit rollback.

### Part C – Partial write anti-pattern

Execute two dependent statements without transaction. Intentionally fail second statement. Observe partial business state, then reset data.

### Part D – WAL observation awareness

Run:

```sql
SELECT pg_current_wal_lsn();
```

perform a write/commit, then inspect LSN again if permissions/environment allow.

Goal is not decoding WAL manually; goal is seeing that writes advance log position.

### Challenge – exactly-once illusion

Pipeline:

```text
read source batch
write target DB
commit target
process crashes before external checkpoint update
```

Explain why retry can duplicate effect even though target transaction itself was ACID.

Design idempotency key or transactional coordination strategy.

## 7. Knowledge check – MCQ

**Q1.** Atomicity means:  
A. all-or-nothing transaction outcome  
B. every query is fast  
C. no indexes  
D. no concurrency

**Q2.** Durability means committed changes:  
A. survive failure according to storage guarantees  
B. cannot be read  
C. are always replicated globally  
D. never need logs

**Q3.** WAL central rule is roughly:  
A. log changes durably before dependent data-page persistence requirement  
B. flush every table page before writing log  
C. store only SELECT statements  
D. disable recovery

**Q4.** ACID consistency:  
A. depends on encoded/respected invariants, not magical business knowledge  
B. means every field correct automatically  
C. means normalized schema only  
D. means no NULL

**Q5.** A transaction boundary should reflect:  
A. business state-change unit  
B. number of code lines  
C. developer preference only  
D. table name length

**Q6.** Target ACID transaction alone guarantees end-to-end exactly-once across external checkpoint?  
A. No  
B. Yes always  
C. only with SELECT  
D. only with indexes

## 8. Tự luận / Interview

1. Explain ACID using a transfer example.
2. What failure does atomicity prevent?
3. Why is consistency not “data always correct”?
4. Why can WAL improve commit/recovery efficiency?
5. What is REDO in crash recovery?
6. Transaction log vs CDC event log: why not identical concepts?
7. Why can an ACID database still participate in an end-to-end duplicate pipeline?
8. Delta transaction log and PostgreSQL WAL share what principle, and differ how?

## 9. Exit criteria

- [ ] demonstrate COMMIT and ROLLBACK;
- [ ] implement atomic transfer with constraint;
- [ ] explain WAL in <=2 minutes without saying “it stores SQL”;
- [ ] explain end-to-end retry problem despite ACID target;
- [ ] >=5/6 MCQ.
