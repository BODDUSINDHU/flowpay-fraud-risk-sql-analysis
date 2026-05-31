SET search_path TO flow_pay;
-- =====================================================
-- Platform Health Overview 
-- File: 05_platform_health.sql
-- Purpose: Evaluate overall platform performance
-- =====================================================
-- ----------------------------------------------------
-- 1. Total Payment Attempts
-- Includes all attempt outcomes: SUCCESS, FAILED, FRAUDULENT
-- -----------------------------------------------------

SELECT 
    COUNT(*) AS total_payment_attempts
FROM transactions
WHERE status IN ('SUCCESS', 'FAILED', 'FRAUDULENT');


-- -----------------------------------------------------
-- 2. Gross Payment Volume (GPV) & Net Revenue Processed
-- -----------------------------------------------------

SELECT
    SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END) AS gpv,
    SUM(CASE WHEN status = 'REFUNDED' THEN amount ELSE 0 END) AS total_refunds,
    SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END)
    - SUM(CASE WHEN status = 'REFUNDED' THEN amount ELSE 0 END) AS net_revenue_processed
FROM transactions;


-- -----------------------------------------------------
-- 3. Monthly Payment Attempts
-- -----------------------------------------------------

SELECT 
    DATE_TRUNC('month', transaction_time) AS transaction_month,
    COUNT(*) AS monthly_payment_attempts
FROM transactions
WHERE status IN ('SUCCESS', 'FAILED', 'FRAUDULENT')
GROUP BY transaction_month
ORDER BY transaction_month;


-- -----------------------------------------------------
-- 4. Active Users
-- -----------------------------------------------------

SELECT 
    COUNT(DISTINCT user_id) AS active_users
FROM transactions
WHERE status = 'SUCCESS';


-- -----------------------------------------------------
-- 5. Average Transaction Value (ATV)
-- -----------------------------------------------------

SELECT
    AVG(amount) AS avg_transaction_value
FROM transactions
WHERE status = 'SUCCESS';


-- -----------------------------------------------------
-- 6. Success Rate
-- -----------------------------------------------------

SELECT
    ROUND(
        COUNT(*) FILTER (WHERE status = 'SUCCESS') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS success_rate
FROM transactions;


-- -----------------------------------------------------
-- 7. Failure Rate
-- -----------------------------------------------------

SELECT 
    ROUND(
        COUNT(*) FILTER (WHERE status = 'FAILED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS failure_rate
FROM transactions;


-- -----------------------------------------------------
-- 8. Refund Rate
-- -----------------------------------------------------

SELECT
    ROUND(
        COUNT(*) FILTER (WHERE status = 'REFUNDED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE status = 'SUCCESS'), 0),
        2
    ) AS refund_rate
FROM transactions;


-- -----------------------------------------------------
-- 9. Fraud Rate (FINAL CORRECT)
-- -----------------------------------------------------

SELECT 
    ROUND(
        COUNT(*) FILTER (WHERE status = 'FRAUDULENT') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS fraud_rate
FROM transactions;


-- -----------------------------------------------------
-- 10. Monthly GPV Trend
-- -----------------------------------------------------

SELECT
    DATE_TRUNC('month', transaction_time) AS month,
    SUM(amount) AS gpv
FROM transactions
WHERE status = 'SUCCESS'
GROUP BY month
ORDER BY month;