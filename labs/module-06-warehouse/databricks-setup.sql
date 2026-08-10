-- Module 06 – Databricks / Delta dimensional-modeling lab
-- Run in a catalog where you have CREATE SCHEMA / CREATE TABLE permission.
-- If needed, first run: USE CATALOG <your_catalog>;

CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold_finance;
CREATE SCHEMA IF NOT EXISTS gold_network;

-- ============================================================
-- SILVER: trusted, detailed, source-integrated layer
-- ============================================================

CREATE OR REPLACE TABLE silver.customer_history (
  customer_id BIGINT,
  full_name STRING,
  province STRING,
  segment STRING,
  effective_from TIMESTAMP,
  effective_to TIMESTAMP,
  is_current BOOLEAN,
  source_updated_at TIMESTAMP
) USING DELTA;

INSERT INTO silver.customer_history VALUES
(1001,'Nguyen An','Ha Noi','mass',    TIMESTAMP '2026-01-01 00:00:00',TIMESTAMP '2026-08-05 00:00:00',false,TIMESTAMP '2026-08-05 08:00:00'),
(1001,'Nguyen An','Ha Noi','premium', TIMESTAMP '2026-08-05 00:00:00',NULL,                              true, TIMESTAMP '2026-08-05 08:00:00'),
(1002,'Tran Binh','Ha Noi','mass',     TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-01 09:00:00'),
(1003,'Le Chi','Da Nang','student',    TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-02 09:00:00'),
(1004,'Pham Dung','HCM','premium',     TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-03 09:00:00'),
(1005,'Hoang Giang','HCM','student',   TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-04 09:00:00'),
(1006,'Do Ha','Hai Phong','mass',      TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-05 09:00:00'),
(1007,'Bui Khanh','Da Nang',NULL,      TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-06 09:00:00'),
(1008,'Vu Lan','HCM','premium',        TIMESTAMP '2026-01-01 00:00:00',NULL,                              true, TIMESTAMP '2026-08-07 09:00:00');

CREATE OR REPLACE TABLE silver.plan (
  plan_id INT,
  plan_name STRING,
  monthly_fee DECIMAL(12,2),
  data_quota_gb DECIMAL(10,2),
  plan_type STRING,
  updated_at TIMESTAMP
) USING DELTA;

INSERT INTO silver.plan VALUES
(1,'STUDENT10',100000.00,10.00,'prepaid', TIMESTAMP '2026-08-01 00:00:00'),
(2,'FAMILY30', 300000.00,30.00,'postpaid',TIMESTAMP '2026-08-01 00:00:00'),
(3,'PREMIUM80',800000.00,80.00,'postpaid',TIMESTAMP '2026-08-01 00:00:00'),
(4,'BASIC5',    50000.00, 5.00,'prepaid', TIMESTAMP '2026-08-01 00:00:00');

CREATE OR REPLACE TABLE silver.billing_transaction (
  transaction_id BIGINT,
  customer_id BIGINT,
  plan_id INT,
  transaction_ts TIMESTAMP,
  amount DECIMAL(14,2),
  payment_method STRING,
  transaction_type STRING,
  status STRING,
  source_updated_at TIMESTAMP
) USING DELTA;

INSERT INTO silver.billing_transaction VALUES
(3001,1001,2,TIMESTAMP '2026-08-01 08:15:00',300000.00,'bank','monthly_fee','success',TIMESTAMP '2026-08-01 08:16:00'),
(3002,1002,1,TIMESTAMP '2026-08-01 09:00:00',100000.00,'wallet','topup','success',TIMESTAMP '2026-08-01 09:00:00'),
(3003,1003,1,TIMESTAMP '2026-08-01 10:30:00',100000.00,'wallet','monthly_fee','success',TIMESTAMP '2026-08-01 10:31:00'),
(3004,1004,3,TIMESTAMP '2026-08-01 12:00:00',800000.00,'card','monthly_fee','success',TIMESTAMP '2026-08-01 12:00:00'),
(3005,1005,1,TIMESTAMP '2026-08-01 13:10:00',100000.00,NULL,'monthly_fee','failed',TIMESTAMP '2026-08-01 13:11:00'),
(3006,1006,2,TIMESTAMP '2026-08-02 08:05:00',300000.00,'bank','monthly_fee','success',TIMESTAMP '2026-08-02 08:06:00'),
(3007,1007,4,TIMESTAMP '2026-08-02 11:20:00', 50000.00,'wallet','topup','success',TIMESTAMP '2026-08-02 11:20:00'),
(3008,1008,3,TIMESTAMP '2026-08-02 14:00:00',800000.00,'card','monthly_fee','success',TIMESTAMP '2026-08-02 14:01:00'),
(3009,1001,2,TIMESTAMP '2026-08-06 07:45:00', 50000.00,'wallet','addon','success',TIMESTAMP '2026-08-06 07:45:00'),
(3010,1004,3,TIMESTAMP '2026-08-03 18:10:00',100000.00,'card','addon','refunded',TIMESTAMP '2026-08-04 09:00:00'),
(3011,1003,1,TIMESTAMP '2026-08-04 09:30:00', 20000.00,'wallet','topup','success',TIMESTAMP '2026-08-04 09:30:00'),
(3012,1006,2,TIMESTAMP '2026-08-04 10:00:00', 50000.00,'bank','addon','success',TIMESTAMP '2026-08-04 10:00:00'),
(3013,9999,4,TIMESTAMP '2026-08-05 09:00:00', 30000.00,'wallet','topup','success',TIMESTAMP '2026-08-05 09:00:00');

CREATE OR REPLACE TABLE silver.tower (
  tower_id INT,
  tower_name STRING,
  province STRING,
  technology STRING,
  commissioned_at DATE
) USING DELTA;

INSERT INTO silver.tower VALUES
(501,'HN-CG-01','Ha Noi','5G',DATE '2024-01-10'),
(502,'HN-HBT-02','Ha Noi','4G',DATE '2021-04-20'),
(503,'DN-HC-01','Da Nang','5G',DATE '2025-02-01'),
(504,'HCM-Q1-01','HCM','5G',DATE '2024-06-15'),
(505,'HCM-TD-03','HCM','4G',DATE '2020-11-01');

CREATE OR REPLACE TABLE silver.network_event (
  event_id STRING,
  tower_id INT,
  customer_id BIGINT,
  event_type STRING,
  event_ts TIMESTAMP,
  ingested_at TIMESTAMP,
  payload_version INT,
  duration_seconds INT
) USING DELTA;

INSERT INTO silver.network_event VALUES
('e001',501,1001,'call_end', TIMESTAMP '2026-08-05 10:04:00',TIMESTAMP '2026-08-05 10:04:01',1,240),
('e002',501,1002,'call_drop',TIMESTAMP '2026-08-05 10:06:00',TIMESTAMP '2026-08-05 10:06:03',1,45),
('e003',502,1002,'call_end', TIMESTAMP '2026-08-05 10:09:00',TIMESTAMP '2026-08-05 10:09:01',1,180),
('e004',503,1003,'call_drop',TIMESTAMP '2026-08-05 10:10:00',TIMESTAMP '2026-08-05 10:12:30',1,30),
('e004',503,1003,'call_drop',TIMESTAMP '2026-08-05 10:10:00',TIMESTAMP '2026-08-05 10:25:00',2,30),
('e005',503,1007,'call_end', TIMESTAMP '2026-08-05 10:11:00',TIMESTAMP '2026-08-05 10:11:01',1,300),
('e006',504,1004,'call_end', TIMESTAMP '2026-08-05 10:12:00',TIMESTAMP '2026-08-05 10:12:01',1,420),
('e007',504,1005,'call_drop',TIMESTAMP '2026-08-05 10:14:00',TIMESTAMP '2026-08-05 10:14:02',1,20),
('e008',505,1008,'call_drop',TIMESTAMP '2026-08-05 10:15:00',TIMESTAMP '2026-08-05 10:15:05',1,50),
('e009',505,1008,'call_end', TIMESTAMP '2026-08-05 10:18:00',TIMESTAMP '2026-08-05 10:18:01',1,180),
('e010',501,1006,'call_end', TIMESTAMP '2026-08-05 08:00:00',TIMESTAMP '2026-08-05 13:00:00',1,200);

-- ============================================================
-- GOLD starter structures
-- Learners populate/transform these tables in lessons.
-- ============================================================

CREATE OR REPLACE TABLE gold_finance.dim_date (
  date_key INT,
  calendar_date DATE,
  year INT,
  quarter INT,
  month INT,
  month_name STRING,
  day_of_month INT,
  day_of_week INT,
  is_weekend BOOLEAN
) USING DELTA;

-- Generate a bounded calendar for the lab.
INSERT INTO gold_finance.dim_date
SELECT
  CAST(date_format(d, 'yyyyMMdd') AS INT) AS date_key,
  d AS calendar_date,
  year(d) AS year,
  quarter(d) AS quarter,
  month(d) AS month,
  date_format(d, 'MMMM') AS month_name,
  day(d) AS day_of_month,
  dayofweek(d) AS day_of_week,
  dayofweek(d) IN (1,7) AS is_weekend
FROM (
  SELECT explode(sequence(DATE '2026-01-01', DATE '2026-12-31', INTERVAL 1 DAY)) AS d
);

CREATE OR REPLACE TABLE gold_finance.dim_customer (
  customer_key BIGINT,
  customer_id BIGINT,
  full_name STRING,
  province STRING,
  segment STRING,
  effective_from TIMESTAMP,
  effective_to TIMESTAMP,
  is_current BOOLEAN
) USING DELTA;

-- Explicit unknown member.
INSERT INTO gold_finance.dim_customer VALUES
(0,NULL,'Unknown','Unknown','Unknown',TIMESTAMP '1900-01-01 00:00:00',NULL,true);

CREATE OR REPLACE TABLE gold_finance.dim_plan (
  plan_key BIGINT,
  plan_id INT,
  plan_name STRING,
  plan_type STRING,
  monthly_fee DECIMAL(12,2),
  is_current BOOLEAN
) USING DELTA;

INSERT INTO gold_finance.dim_plan VALUES
(0,NULL,'Unknown','Unknown',NULL,true);

CREATE OR REPLACE TABLE gold_finance.fact_billing_transaction (
  transaction_id BIGINT,
  date_key INT,
  customer_key BIGINT,
  plan_key BIGINT,
  amount DECIMAL(14,2),
  transaction_count INT,
  payment_method STRING,
  transaction_type STRING,
  transaction_status STRING,
  transaction_ts TIMESTAMP
) USING DELTA;

CREATE OR REPLACE TABLE gold_network.dim_tower (
  tower_key BIGINT,
  tower_id INT,
  tower_name STRING,
  province STRING,
  technology STRING,
  commissioned_at DATE
) USING DELTA;

INSERT INTO gold_network.dim_tower VALUES
(0,NULL,'Unknown','Unknown','Unknown',NULL);

CREATE OR REPLACE TABLE gold_network.fact_network_daily (
  date_key INT,
  tower_key BIGINT,
  total_calls BIGINT,
  drops BIGINT,
  total_duration_seconds BIGINT
) USING DELTA;

-- ============================================================
-- Starter validation queries
-- ============================================================

-- Silver SCD overlap/current checks
SELECT customer_id, COUNT(*) AS current_rows
FROM silver.customer_history
WHERE is_current
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Duplicate event business keys for dedup exercise
SELECT event_id, COUNT(*) AS versions
FROM silver.network_event
GROUP BY event_id
HAVING COUNT(*) > 1;

-- Early-arriving fact example: customer_id 9999 has no Silver dimension member
SELECT DISTINCT b.customer_id
FROM silver.billing_transaction b
LEFT ANTI JOIN silver.customer_history c
  ON c.customer_id = b.customer_id;

-- Source revenue baseline for later Gold reconciliation
SELECT SUM(amount) AS source_success_revenue
FROM silver.billing_transaction
WHERE status = 'success';
