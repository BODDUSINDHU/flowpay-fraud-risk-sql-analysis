-- =====================================================
-- FlowPay Data Validation Script
-- File: sql/04_data_validation.sql
-- Purpose: Validate data integrity before analysis
-- =====================================================

SET search_path TO flowpay;

-- Dataset size check
SELECT COUNT(*) FROM transactions;

-- =====================================================
-- Step 1 — Validate Table Relationships
-- =====================================================

-- Check 1: Transactions referencing missing users
SELECT t.transaction_id, t.user_id
FROM transactions t
LEFT JOIN users u
ON t.user_id = u.user_id
WHERE u.user_id IS NULL;

-- Check 2: Transactions referencing missing merchants
SELECT t.transaction_id, t.merchant_id
FROM transactions t
LEFT JOIN merchants m
ON t.merchant_id = m.merchant_id
WHERE m.merchant_id IS NULL;

-- Check 3: Transactions referencing missing devices
SELECT t.transaction_id, t.device_id
FROM transactions t
LEFT JOIN devices d
ON t.device_id = d.device_id
WHERE t.device_id IS NOT NULL
AND d.device_id IS NULL;

-- Check 4: Fraud reports referencing missing transactions
SELECT
    f.fraud_id,
    f.transaction_id
FROM fraud_reports f
LEFT JOIN transactions t
ON f.transaction_id = t.transaction_id
WHERE t.transaction_id IS NULL;


-- Check 5: Refunds referencing missing transactions
SELECT
    r.refund_id,
    r.transaction_id
FROM refunds r
LEFT JOIN transactions t
ON r.transaction_id = t.transaction_id
WHERE t.transaction_id IS NULL;

-- =====================================================
-- Step 2 — Duplicate Record Checks
-- =====================================================

-- Check duplicate transactions
SELECT
    transaction_id,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Check duplicate users
SELECT
    user_id,
    COUNT(*) AS duplicate_count
FROM users
GROUP BY user_id
HAVING COUNT(*) > 1;

-- Check duplicate fraud reports
SELECT
    transaction_id,
    COUNT(*) AS duplicate_reports
FROM fraud_reports
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Advanced duplicate check (business-level duplicates)
SELECT
    user_id,
    merchant_id,
    transaction_time,
    amount,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY
    user_id,
    merchant_id,
    transaction_time,
    amount
HAVING COUNT(*) > 1;

-- =====================================================
-- Step 3 — Transaction Amount Validation
-- =====================================================

-- Negative transaction amounts
SELECT *
FROM transactions
WHERE amount < 0;

-- Zero-value transactions
SELECT *
FROM transactions
WHERE amount = 0;

-- Transaction amount distribution
SELECT
    MIN(amount) AS min_transaction,
    MAX(amount) AS max_transaction,
    AVG(amount) AS avg_transaction
FROM transactions;

-- =====================================================
-- Step 4 — Device Data Quality
-- =====================================================

-- Transactions missing device_id
SELECT COUNT(*) AS transactions_missing_device
FROM transactions
WHERE device_id IS NULL;

-- Devices assigned to multiple users
SELECT
    device_id,
    COUNT(DISTINCT user_id) AS user_count
FROM devices
GROUP BY device_id
HAVING COUNT(DISTINCT user_id) > 1;

-- Users with many devices
SELECT
    user_id,
    COUNT(device_id) AS device_count
FROM devices
GROUP BY user_id
ORDER BY device_count DESC;

-- =====================================================
-- Step 5 — Fraud Data Consistency
-- =====================================================

-- Fraud reports for transactions marked SUCCESS
SELECT
    t.transaction_id,
    t.status,
    f.fraud_id,
    f.fraud_type
FROM transactions t
JOIN fraud_reports f
ON t.transaction_id = f.transaction_id
WHERE t.status = 'SUCCESS';

-- Transactions marked FRAUDULENT but no fraud report exists
SELECT
    t.transaction_id,
    t.status
FROM transactions t
LEFT JOIN fraud_reports f
ON t.transaction_id = f.transaction_id
WHERE t.status = 'FRAUDULENT'
AND f.transaction_id IS NULL;

-- Fraud score outside expected range
SELECT *
FROM fraud_reports
WHERE fraud_score < 0
OR fraud_score > 100;

-- =====================================================
-- Step 6 — Refund Consistency
-- =====================================================

-- Refund exists but transaction failed
SELECT
    r.refund_id,
    r.transaction_id,
    t.status
FROM refunds r
JOIN transactions t
ON r.transaction_id = t.transaction_id
WHERE t.status = 'FAILED';

-- Refund amount greater than transaction amount
SELECT
    r.refund_id,
    r.transaction_id,
    r.refund_amount,
    t.amount AS transaction_amount
FROM refunds r
JOIN transactions t
ON r.transaction_id = t.transaction_id
WHERE r.refund_amount > t.amount;

-- Multiple refunds for one transaction
SELECT
    transaction_id,
    COUNT(*) AS refund_count
FROM refunds
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- =====================================================
-- Step 7 — Fraud Rate Sanity Check
-- =====================================================

SELECT
    COUNT(*) AS total_transactions,
    COUNT(CASE WHEN status = 'FRAUDULENT' THEN 1 END) AS fraudulent_transactions,
    ROUND(
        COUNT(CASE WHEN status = 'FRAUDULENT' THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS fraud_rate_percent
FROM transactions;

-- =====================================================
-- Step 8-  Transactions occurring before user signup
-- =====================================================

SELECT
    t.transaction_id,
    t.user_id,
    u.signup_date,
    t.transaction_time
FROM transactions t
JOIN users u
ON t.user_id = u.user_id
WHERE t.transaction_time < u.signup_date;