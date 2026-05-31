SET search_path TO flow_pay;
CREATE TABLE users (
    user_id        TEXT PRIMARY KEY,
    signup_date    DATE NOT NULL,
    city           TEXT NOT NULL,
    state          TEXT NOT NULL,
    age            INTEGER NOT NULL CHECK (age BETWEEN 18 AND 60),
    kyc_verified   BOOLEAN NOT NULL,
    risk_score     INTEGER NOT NULL CHECK (risk_score BETWEEN 0 AND 100),
    signup_channel TEXT NOT NULL CHECK (signup_channel IN ('organic','referral','ads'))
);

SET search_path TO flow_pay;
CREATE TABLE merchants (
    merchant_id       TEXT PRIMARY KEY,
    merchant_name     TEXT NOT NULL,
    merchant_category TEXT NOT NULL,
    city              TEXT NOT NULL,
    onboard_date      DATE NOT NULL,
    risk_level        TEXT NOT NULL CHECK (risk_level IN ('low','medium','high'))
);


SET search_path TO flow_pay;
CREATE TABLE devices (
    device_id          TEXT PRIMARY KEY,
    user_id            TEXT NOT NULL,
    device_type        TEXT NOT NULL CHECK (device_type IN ('Android','iOS')),
    device_brand       TEXT NOT NULL,
    first_seen         TIMESTAMP NOT NULL,
    last_seen          TIMESTAMP NOT NULL,
    is_new_device_flag BOOLEAN NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);



SET search_path TO flow_pay;
CREATE TABLE transactions (
    transaction_id   TEXT PRIMARY KEY,
    user_id          TEXT NOT NULL,
    merchant_id      TEXT NOT NULL,
    device_id        TEXT,
    transaction_time TIMESTAMP NOT NULL,
    amount           NUMERIC(10,2) NOT NULL,
    payment_method   TEXT NOT NULL CHECK (payment_method IN ('UPI','Wallet','Credit Card','Debit Card')),
    status           TEXT NOT NULL CHECK (status IN ('SUCCESS','FAILED','FRAUDULENT','REFUNDED')),
    ip_city          TEXT NOT NULL,
    is_high_velocity BOOLEAN NOT NULL,
    is_cross_city    BOOLEAN NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id),
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);



SET search_path TO flow_pay;
CREATE TABLE fraud_reports (
    fraud_id             TEXT PRIMARY KEY,
    transaction_id       TEXT NOT NULL,
    fraud_type           TEXT NOT NULL,
    reported_time        TIMESTAMP NOT NULL,
    fraud_score          INTEGER NOT NULL CHECK (fraud_score BETWEEN 0 AND 100),
    investigation_status TEXT NOT NULL CHECK (investigation_status IN ('Open','Under Review','Confirmed Fraud','Closed')),
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
);



SET search_path TO flow_pay;
CREATE TABLE refunds (
    refund_id     TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    refund_amount  NUMERIC(10,2) NOT NULL,
    refund_reason  TEXT NOT NULL,
    refund_time    TIMESTAMP NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id)
);
