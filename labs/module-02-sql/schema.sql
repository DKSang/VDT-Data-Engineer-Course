DROP TABLE IF EXISTS customer_status_history;
DROP TABLE IF EXISTS network_events;
DROP TABLE IF EXISTS billing_transactions;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS cell_towers;
DROP TABLE IF EXISTS plans;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id      BIGINT PRIMARY KEY,
    full_name        TEXT NOT NULL,
    province         TEXT NOT NULL,
    birth_date       DATE,
    registered_at    TIMESTAMP NOT NULL,
    email            TEXT,
    segment          TEXT,
    updated_at       TIMESTAMP NOT NULL
);

CREATE TABLE plans (
    plan_id           INTEGER PRIMARY KEY,
    plan_name         TEXT NOT NULL UNIQUE,
    monthly_fee       NUMERIC(12,2) NOT NULL CHECK (monthly_fee >= 0),
    data_quota_gb     NUMERIC(10,2),
    plan_type         TEXT NOT NULL
);

CREATE TABLE subscriptions (
    subscription_id   BIGINT PRIMARY KEY,
    customer_id       BIGINT NOT NULL REFERENCES customers(customer_id),
    plan_id           INTEGER NOT NULL REFERENCES plans(plan_id),
    started_at        TIMESTAMP NOT NULL,
    ended_at          TIMESTAMP,
    status            TEXT NOT NULL,
    updated_at        TIMESTAMP NOT NULL,
    CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE billing_transactions (
    transaction_id    BIGINT PRIMARY KEY,
    customer_id       BIGINT NOT NULL REFERENCES customers(customer_id),
    transaction_ts    TIMESTAMP NOT NULL,
    amount             NUMERIC(14,2) NOT NULL,
    transaction_type   TEXT NOT NULL,
    payment_method     TEXT,
    status             TEXT NOT NULL,
    updated_at         TIMESTAMP NOT NULL
);

CREATE TABLE cell_towers (
    tower_id           INTEGER PRIMARY KEY,
    tower_name         TEXT NOT NULL,
    province           TEXT NOT NULL,
    technology         TEXT NOT NULL,
    commissioned_at    DATE
);

-- event_id deliberately NOT unique so learners can practice deduplication.
CREATE TABLE network_events (
    ingest_row_id      BIGSERIAL PRIMARY KEY,
    event_id           TEXT NOT NULL,
    tower_id           INTEGER NOT NULL REFERENCES cell_towers(tower_id),
    customer_id        BIGINT,
    event_type         TEXT NOT NULL,
    event_ts           TIMESTAMP NOT NULL,
    ingested_at        TIMESTAMP NOT NULL,
    signal_dbm         NUMERIC(8,2),
    duration_seconds   INTEGER,
    payload_version    INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE customer_status_history (
    status_history_id  BIGSERIAL PRIMARY KEY,
    customer_id        BIGINT NOT NULL REFERENCES customers(customer_id),
    status             TEXT NOT NULL,
    effective_from     TIMESTAMP NOT NULL,
    recorded_at        TIMESTAMP NOT NULL,
    source_system      TEXT NOT NULL
);

-- Intentionally minimal indexes. Lesson 08 asks learners to add and justify indexes.
CREATE INDEX idx_billing_customer_id ON billing_transactions(customer_id);
CREATE INDEX idx_network_tower_id ON network_events(tower_id);
CREATE INDEX idx_status_customer_id ON customer_status_history(customer_id);