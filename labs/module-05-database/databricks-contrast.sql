-- Module 05 - PostgreSQL vs Databricks/Delta contrast
-- Run in a disposable Databricks schema.

CREATE OR REPLACE TABLE db05_customers (
  customer_id BIGINT NOT NULL,
  full_name STRING NOT NULL,
  province STRING,
  segment STRING
) USING DELTA;

ALTER TABLE db05_customers
ADD CONSTRAINT valid_customer_id CHECK (customer_id > 0);

-- Depending on workspace/runtime/catalog support, declare informational PK.
-- The key lesson: declaration does not mean PostgreSQL-style uniqueness enforcement.
ALTER TABLE db05_customers
ADD CONSTRAINT db05_customers_pk PRIMARY KEY (customer_id) NOT ENFORCED;

INSERT INTO db05_customers VALUES
(1,'Alice','Ha Noi','mass'),
(2,'Bob','HCM','premium');

-- Test enforced NOT NULL/CHECK behavior with invalid rows in your environment.
-- Example expected to fail because CHECK:
-- INSERT INTO db05_customers VALUES (-1,'Invalid','HCM','mass');

-- Test informational PK behavior in a disposable table.
-- If your environment permits duplicate customer_id despite declared PK,
-- record that evidence and explain why pipeline validation is still necessary.
-- INSERT INTO db05_customers VALUES (1,'Duplicate Alice','Da Nang','mass');

CREATE OR REPLACE TABLE db05_subscription_state (
  subscription_id BIGINT NOT NULL,
  customer_id BIGINT NOT NULL,
  status STRING NOT NULL,
  source_sequence BIGINT NOT NULL,
  updated_at TIMESTAMP NOT NULL
) USING DELTA;

INSERT INTO db05_subscription_state VALUES
(2001,1,'active',100,TIMESTAMP '2026-08-01 10:00:00');

-- Create versions to inspect transaction history.
UPDATE db05_subscription_state
SET status='suspended', source_sequence=101, updated_at=TIMESTAMP '2026-08-02 10:00:00'
WHERE subscription_id=2001;

UPDATE db05_subscription_state
SET status='active', source_sequence=102, updated_at=TIMESTAMP '2026-08-03 10:00:00'
WHERE subscription_id=2001;

DESCRIBE HISTORY db05_subscription_state;

-- Inspect current snapshot.
SELECT * FROM db05_subscription_state;

-- Optional time-travel/version exercise after reading current Databricks docs:
-- SELECT * FROM db05_subscription_state VERSION AS OF <version>;

-- Concurrency reasoning exercise:
-- Writer A and Writer B both start from a prior snapshot.
-- Draw read -> write candidate files -> validate -> commit/conflict.
-- Do not simulate by inventing behavior; if you have two Databricks sessions,
-- perform a controlled experiment and record actual outcome.

-- Cleanup when done:
-- DROP TABLE db05_subscription_state;
-- DROP TABLE db05_customers;
