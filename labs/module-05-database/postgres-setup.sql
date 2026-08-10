-- Module 05 - Database Fundamentals
-- PostgreSQL 18 disposable lab setup

DROP TABLE IF EXISTS customer_status_history;
DROP TABLE IF EXISTS network_events;
DROP TABLE IF EXISTS billing_transactions;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS plans;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS subscriptions_staging;
DROP TABLE IF EXISTS accounts;

CREATE TABLE customers (
    customer_id BIGINT PRIMARY KEY,
    full_name TEXT NOT NULL,
    province TEXT NOT NULL,
    email TEXT UNIQUE,
    segment TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE plans (
    plan_id INT PRIMARY KEY,
    plan_name TEXT NOT NULL UNIQUE,
    monthly_fee NUMERIC(12,2) NOT NULL CHECK (monthly_fee >= 0),
    plan_type TEXT NOT NULL CHECK (plan_type IN ('prepaid','postpaid'))
);

CREATE TABLE subscriptions (
    subscription_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
    plan_id INT NOT NULL REFERENCES plans(plan_id),
    status TEXT NOT NULL CHECK (status IN ('active','suspended','cancelled')),
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL,
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE billing_transactions (
    transaction_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
    transaction_ts TIMESTAMPTZ NOT NULL,
    amount NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    status TEXT NOT NULL CHECK (status IN ('success','failed','refunded')),
    payment_method TEXT,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE network_events (
    ingest_row_id BIGSERIAL PRIMARY KEY,
    event_id TEXT NOT NULL,
    customer_id BIGINT,
    tower_id INT NOT NULL,
    event_type TEXT NOT NULL,
    event_ts TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL,
    payload_version INT NOT NULL DEFAULT 1,
    signal_dbm NUMERIC(8,2)
);

CREATE TABLE customer_status_history (
    status_history_id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
    status TEXT NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL
);

-- Intentionally unconstrained for Lesson 03 comparison.
CREATE TABLE subscriptions_staging (
    subscription_id BIGINT,
    customer_id BIGINT,
    plan_id INT,
    status TEXT,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ
);

-- Transaction/concurrency lab.
CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    owner_name TEXT NOT NULL,
    balance NUMERIC(14,2) NOT NULL CHECK (balance >= 0)
);

INSERT INTO customers(customer_id, full_name, province, email, segment) VALUES
(1001,'Nguyen An','Ha Noi','an@example.com','mass'),
(1002,'Tran Binh','Ha Noi',NULL,'mass'),
(1003,'Le Chi','Da Nang','chi@example.com','student'),
(1004,'Pham Dung','HCM','dung@example.com','premium'),
(1005,'Hoang Giang','HCM',NULL,'student'),
(1006,'Do Ha','Hai Phong','ha@example.com','mass'),
(1007,'Bui Khanh','Da Nang','k@example.com',NULL),
(1008,'Vu Lan','HCM','lan@example.com','premium');

INSERT INTO plans VALUES
(1,'STUDENT10',100000, 'prepaid'),
(2,'FAMILY30',300000, 'postpaid'),
(3,'PREMIUM80',800000,'postpaid'),
(4,'BASIC5',50000,'prepaid');

INSERT INTO subscriptions VALUES
(2001,1001,2,'active','2025-01-10',NULL,'2026-08-01'),
(2002,1002,4,'cancelled','2025-02-11','2026-06-30','2026-06-30'),
(2003,1002,1,'active','2026-07-01',NULL,'2026-07-29'),
(2004,1003,1,'active','2025-03-05',NULL,'2026-08-02'),
(2005,1004,3,'active','2025-03-18',NULL,'2026-08-03'),
(2006,1005,1,'suspended','2025-04-09',NULL,'2026-08-04'),
(2007,1006,2,'active','2025-06-10',NULL,'2026-08-05'),
(2008,1007,4,'active','2025-07-01',NULL,'2026-08-06'),
(2009,1008,3,'active','2025-08-22',NULL,'2026-08-07');

INSERT INTO billing_transactions VALUES
(3001,1001,'2026-08-01 08:15+07',300000,'success','bank','2026-08-01 08:16+07'),
(3002,1002,'2026-08-01 09:00+07',100000,'success','wallet','2026-08-01 09:00+07'),
(3003,1003,'2026-08-01 10:30+07',100000,'success','wallet','2026-08-01 10:31+07'),
(3004,1004,'2026-08-01 12:00+07',800000,'success','card','2026-08-01 12:00+07'),
(3005,1005,'2026-08-01 13:10+07',100000,'failed',NULL,'2026-08-01 13:11+07'),
(3006,1006,'2026-08-02 08:05+07',300000,'success','bank','2026-08-02 08:06+07'),
(3007,1007,'2026-08-02 11:20+07',50000,'success','wallet','2026-08-02 11:20+07'),
(3008,1008,'2026-08-02 14:00+07',800000,'success','card','2026-08-02 14:01+07');

INSERT INTO network_events(event_id,customer_id,tower_id,event_type,event_ts,ingested_at,payload_version,signal_dbm) VALUES
('e001',1001,501,'call_end','2026-08-05 10:04+07','2026-08-05 10:04:01+07',1,-75),
('e002',1002,501,'call_drop','2026-08-05 10:06+07','2026-08-05 10:06:03+07',1,-105),
('e003',1003,503,'call_drop','2026-08-05 10:10+07','2026-08-05 10:12:30+07',1,-110),
('e003',1003,503,'call_drop','2026-08-05 10:10+07','2026-08-05 10:25:00+07',2,-107);

INSERT INTO customer_status_history(customer_id,status,effective_from,recorded_at) VALUES
(1001,'active','2025-01-10','2025-01-10 09:01+07'),
(1002,'active','2025-02-11','2025-02-11 11:31+07'),
(1002,'inactive','2026-06-30','2026-06-30 18:00+07'),
(1002,'active','2026-07-01','2026-07-01 08:00+07'),
(1005,'active','2025-04-09','2025-04-09 07:31+07'),
(1005,'suspended','2026-08-01','2026-08-01 12:00+07');

INSERT INTO accounts VALUES
(1,'Alice',1000),
(2,'Bob',1000),
(3,'Carol',1000);

-- Scale table for planner/index labs. Distribution intentionally skewed.
CREATE TABLE billing_big AS
SELECT
    1000000 + g AS transaction_id,
    1001 + (g % 8) AS customer_id,
    TIMESTAMPTZ '2026-01-01 00:00:00+07' + (g % 180) * INTERVAL '1 day' + (g % 86400) * INTERVAL '1 second' AS transaction_ts,
    ((g % 5000) + 1)::numeric(14,2) AS amount,
    CASE WHEN g % 100 < 92 THEN 'success'
         WHEN g % 100 < 98 THEN 'failed'
         ELSE 'refunded' END AS status
FROM generate_series(1, 200000) AS g;

ALTER TABLE billing_big ADD PRIMARY KEY (transaction_id);
ANALYZE billing_big;

SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL SELECT 'billing_transactions', COUNT(*) FROM billing_transactions
UNION ALL SELECT 'billing_big', COUNT(*) FROM billing_big;
