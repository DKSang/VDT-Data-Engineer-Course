INSERT INTO customers
(customer_id, full_name, province, birth_date, registered_at, email, segment, updated_at)
VALUES
(1001, 'Nguyen An',  'Ha Noi',   '2001-04-12', '2025-01-10 09:00', 'an@example.com',   'mass',     '2026-08-01 10:00'),
(1002, 'Tran Binh',  'Ha Noi',   '1999-08-20', '2025-02-11 11:30', NULL,               'mass',     '2026-07-29 08:00'),
(1003, 'Le Chi',     'Da Nang',  '2002-01-15', '2025-03-05 14:20', 'chi@example.com',  'student',  '2026-08-02 09:00'),
(1004, 'Pham Dung',  'HCM',      '1997-12-01', '2025-03-18 18:00', 'dung@example.com', 'premium',  '2026-08-03 09:00'),
(1005, 'Hoang Giang','HCM',      '2000-06-30', '2025-04-09 07:30', NULL,               'student',  '2026-08-04 09:00'),
(1006, 'Do Ha',      'Hai Phong','1998-03-22', '2025-06-10 10:00', 'ha@example.com',   'mass',     '2026-08-05 09:00'),
(1007, 'Bui Khanh',  'Da Nang',  '2003-09-17', '2025-07-01 10:00', 'k@example.com',    NULL,       '2026-08-06 09:00'),
(1008, 'Vu Lan',     'HCM',      NULL,         '2025-08-22 16:00', 'lan@example.com',  'premium',  '2026-08-07 09:00');

INSERT INTO plans (plan_id, plan_name, monthly_fee, data_quota_gb, plan_type)
VALUES
(1, 'STUDENT10', 100000, 10, 'prepaid'),
(2, 'FAMILY30',  300000, 30, 'postpaid'),
(3, 'PREMIUM80', 800000, 80, 'postpaid'),
(4, 'BASIC5',     50000,  5, 'prepaid');

INSERT INTO subscriptions
(subscription_id, customer_id, plan_id, started_at, ended_at, status, updated_at)
VALUES
(2001, 1001, 2, '2025-01-10', NULL,         'active',    '2026-08-01'),
(2002, 1002, 4, '2025-02-11', '2026-06-30', 'cancelled', '2026-06-30'),
(2003, 1002, 1, '2026-07-01', NULL,         'active',    '2026-07-29'),
(2004, 1003, 1, '2025-03-05', NULL,         'active',    '2026-08-02'),
(2005, 1004, 3, '2025-03-18', NULL,         'active',    '2026-08-03'),
(2006, 1005, 1, '2025-04-09', NULL,         'suspended', '2026-08-04'),
(2007, 1006, 2, '2025-06-10', NULL,         'active',    '2026-08-05'),
(2008, 1007, 4, '2025-07-01', NULL,         'active',    '2026-08-06'),
(2009, 1008, 3, '2025-08-22', NULL,         'active',    '2026-08-07');

INSERT INTO billing_transactions
(transaction_id, customer_id, transaction_ts, amount, transaction_type, payment_method, status, updated_at)
VALUES
(3001,1001,'2026-08-01 08:15',300000,'monthly_fee','bank','success','2026-08-01 08:16'),
(3002,1002,'2026-08-01 09:00',100000,'topup','wallet','success','2026-08-01 09:00'),
(3003,1003,'2026-08-01 10:30',100000,'monthly_fee','wallet','success','2026-08-01 10:31'),
(3004,1004,'2026-08-01 12:00',800000,'monthly_fee','card','success','2026-08-01 12:00'),
(3005,1005,'2026-08-01 13:10',100000,'monthly_fee',NULL,'failed','2026-08-01 13:11'),
(3006,1006,'2026-08-02 08:05',300000,'monthly_fee','bank','success','2026-08-02 08:06'),
(3007,1007,'2026-08-02 11:20', 50000,'topup','wallet','success','2026-08-02 11:20'),
(3008,1008,'2026-08-02 14:00',800000,'monthly_fee','card','success','2026-08-02 14:01'),
(3009,1001,'2026-08-03 07:45', 50000,'addon','wallet','success','2026-08-03 07:45'),
(3010,1004,'2026-08-03 18:10',100000,'addon','card','refunded','2026-08-04 09:00'),
(3011,1003,'2026-08-04 09:30', 20000,'topup','wallet','success','2026-08-04 09:30'),
(3012,1006,'2026-08-04 10:00', 50000,'addon','bank','success','2026-08-04 10:00'),
(3013,1001,'2026-08-05 09:00', 30000,'topup','wallet','success','2026-08-05 09:00'),
(3014,1002,'2026-08-05 11:00', 40000,'topup','wallet','failed','2026-08-05 11:01'),
(3015,1008,'2026-08-06 15:00',120000,'addon','card','success','2026-08-06 15:00');

INSERT INTO cell_towers (tower_id, tower_name, province, technology, commissioned_at)
VALUES
(501,'HN-CG-01','Ha Noi','5G','2024-01-10'),
(502,'HN-HBT-02','Ha Noi','4G','2021-04-20'),
(503,'DN-HC-01','Da Nang','5G','2025-02-01'),
(504,'HCM-Q1-01','HCM','5G','2024-06-15'),
(505,'HCM-TD-03','HCM','4G','2020-11-01');

INSERT INTO network_events
(event_id,tower_id,customer_id,event_type,event_ts,ingested_at,signal_dbm,duration_seconds,payload_version)
VALUES
('e001',501,1001,'call_start','2026-08-05 10:00:00','2026-08-05 10:00:02',-72,0,1),
('e002',501,1001,'call_end',  '2026-08-05 10:04:00','2026-08-05 10:04:01',-75,240,1),
('e003',501,1002,'call_drop', '2026-08-05 10:06:00','2026-08-05 10:06:03',-105,45,1),
('e004',502,1002,'call_end',  '2026-08-05 10:09:00','2026-08-05 10:09:01',-82,180,1),
('e005',503,1003,'call_drop', '2026-08-05 10:10:00','2026-08-05 10:12:30',-110,30,1),
('e006',503,1007,'call_end',  '2026-08-05 10:11:00','2026-08-05 10:11:01',-80,300,1),
('e007',504,1004,'call_end',  '2026-08-05 10:12:00','2026-08-05 10:12:01',-68,420,1),
('e008',504,1005,'call_drop', '2026-08-05 10:14:00','2026-08-05 10:14:02',-112,20,1),
('e009',505,1008,'call_drop', '2026-08-05 10:15:00','2026-08-05 10:15:05',-108,50,1),
('e010',505,1008,'call_end',  '2026-08-05 10:18:00','2026-08-05 10:18:01',-85,180,1),
-- exact duplicate business event with later ingestion
('e009',505,1008,'call_drop', '2026-08-05 10:15:00','2026-08-05 10:20:00',-108,50,1),
-- same event id, newer payload version: tie-breaker exercise
('e005',503,1003,'call_drop', '2026-08-05 10:10:00','2026-08-05 10:25:00',-107,30,2),
-- late-arriving event: event time is earlier than ingestion by hours
('e011',501,1006,'call_end',  '2026-08-05 08:00:00','2026-08-05 13:00:00',-79,200,1);

INSERT INTO customer_status_history
(customer_id,status,effective_from,recorded_at,source_system)
VALUES
(1001,'active',   '2025-01-10','2025-01-10 09:01','crm'),
(1002,'active',   '2025-02-11','2025-02-11 11:31','crm'),
(1002,'inactive', '2026-06-30','2026-06-30 18:00','crm'),
(1002,'active',   '2026-07-01','2026-07-01 08:00','crm'),
(1003,'active',   '2025-03-05','2025-03-05 14:21','crm'),
(1004,'active',   '2025-03-18','2025-03-18 18:01','crm'),
(1005,'active',   '2025-04-09','2025-04-09 07:31','crm'),
(1005,'suspended','2026-08-01','2026-08-01 12:00','risk'),
(1006,'active',   '2025-06-10','2025-06-10 10:01','crm'),
(1007,'active',   '2025-07-01','2025-07-01 10:01','crm'),
(1008,'active',   '2025-08-22','2025-08-22 16:01','crm');