# Module 05 – Two-Session Concurrency Lab

Open **Session A** and **Session B** against the same PostgreSQL database.

For every experiment write:

```text
Initial state:
Isolation level:
Session A actions:
Session B actions:
Observed result:
Anomaly/block/conflict:
Explanation:
```

## Experiment 1 – Read Committed non-repeatable observation

Session A:

```sql
BEGIN;
SHOW transaction_isolation;
SELECT status FROM subscriptions WHERE subscription_id = 2001;
```

Session B:

```sql
BEGIN;
UPDATE subscriptions
SET status = 'suspended'
WHERE subscription_id = 2001;
COMMIT;
```

Session A:

```sql
SELECT status FROM subscriptions WHERE subscription_id = 2001;
ROLLBACK;
```

Reset status afterward.

Question: why can two SELECT statements inside one Read Committed transaction observe different committed values?

## Experiment 2 – Repeatable Read snapshot

Session A:

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT status FROM subscriptions WHERE subscription_id = 2001;
```

Session B updates and commits.

Session A re-runs SELECT.

Question: which snapshot is Session A reading?

## Experiment 3 – Row locking

Session A:

```sql
BEGIN;
SELECT * FROM accounts WHERE account_id = 1 FOR UPDATE;
```

Session B:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 10 WHERE account_id = 1;
```

Observe B waiting until A commits/rolls back.

## Experiment 4 – Deadlock

Session A:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 1 WHERE account_id = 1;
```

Session B:

```sql
BEGIN;
UPDATE accounts SET balance = balance - 1 WHERE account_id = 2;
```

Session A:

```sql
UPDATE accounts SET balance = balance - 1 WHERE account_id = 2;
```

Session B:

```sql
UPDATE accounts SET balance = balance - 1 WHERE account_id = 1;
```

Observe deadlock detection. Roll back/reset balances after experiment.

Question: how does consistent lock ordering prevent this pattern?

## Experiment 5 – Atomic transfer

Implement transfer 100 from account 1 to 2 in one transaction.

Then deliberately violate `balance >= 0` with an oversized transfer and verify whole transaction rolls back.

## Experiment 6 – Serializable retry reasoning

Use:

```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
```

Design two transactions that read shared business state and then update disjoint rows based on that state.

If PostgreSQL aborts one with serialization failure, write retry pseudocode. If your exact experiment does not reproduce an abort, explain the intended write-skew pattern and do not fabricate an observed failure.

## Experiment 7 – ETL snapshot consistency

Session A begins a long transaction and reads counts from `customers`, `subscriptions`, and `billing_transactions`.

Session B changes data between A's reads.

Repeat under Read Committed and Repeatable Read.

Discuss:

- cross-table consistency;
- freshness;
- long-running transaction cost;
- why CDC may be preferable for continuous replication.
