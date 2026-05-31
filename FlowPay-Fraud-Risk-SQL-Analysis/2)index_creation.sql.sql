SET search_path TO flow_pay;

CREATE INDEX idx_transactions_user
ON transactions(user_id);

CREATE INDEX idx_transactions_merchant
ON transactions(merchant_id);

CREATE INDEX idx_transactions_time
ON transactions(transaction_time);

CREATE INDEX idx_transactions_status
ON transactions(status);

CREATE INDEX idx_devices_user
ON devices(user_id);

CREATE INDEX idx_fraud_transaction
ON fraud_reports(transaction_id);

CREATE INDEX idx_refund_transaction
ON refunds(transaction_id);