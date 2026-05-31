SET search_path TO flow_pay;
-- =====================================================
-- Payment Method Analysis
-- File: 06_payment_analysis.sql
-- Purpose: Analyze performance across payment methods
-- =====================================================
-- -----------------------------------------------------
-- 1. Transaction Volume by Payment Method
-- Total payment attempts (excludes refunds)
-- -----------------------------------------------------

SELECT 
    payment_method,
    COUNT(*) AS transaction_volume
FROM transactions
WHERE status IN ('SUCCESS', 'FAILED', 'FRAUDULENT')
GROUP BY payment_method
ORDER BY transaction_volume DESC;





-- -----------------------------------------------------
-- 2. Success Rate by Payment Method
-- -----------------------------------------------------

SELECT 
    payment_method,
    ROUND(
        COUNT(*) FILTER (WHERE status = 'SUCCESS') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS success_rate
FROM transactions
GROUP BY payment_method
ORDER BY success_rate DESC;


-- -----------------------------------------------------
-- 3. Failure Rate by Payment Method
-- -----------------------------------------------------

SELECT 
    payment_method,
    ROUND(
        COUNT(*) FILTER (WHERE status = 'FAILED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS failure_rate
FROM transactions
GROUP BY payment_method
ORDER BY failure_rate DESC;


-- -----------------------------------------------------
-- 4. Revenue Contribution by Payment Method (GPV)
-- Only successful transactions
-- -----------------------------------------------------

SELECT 
    payment_method,
    SUM(amount) AS revenue_contribution
FROM transactions
WHERE status = 'SUCCESS'
GROUP BY payment_method
ORDER BY revenue_contribution DESC;


-- -----------------------------------------------------
-- 5. Average Transaction Value (ATV) by Payment Method
-- Only successful transactions
-- -----------------------------------------------------

SELECT 
    payment_method,
    ROUND(AVG(amount), 2) AS avg_transaction_value
FROM transactions
WHERE status = 'SUCCESS'
GROUP BY payment_method
ORDER BY avg_transaction_value DESC;


-- -----------------------------------------------------
-- 6. Failure Rate by Device Type
-- -----------------------------------------------------

SELECT 
    d.device_type,
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FAILED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS failure_rate
FROM transactions t
JOIN devices d ON t.device_id = d.device_id
GROUP BY d.device_type
ORDER BY failure_rate DESC;


-- -----------------------------------------------------
-- 7. Failure Rate by City
-- -----------------------------------------------------

SELECT 
    u.city,
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FAILED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS failure_rate
FROM transactions t
JOIN users u ON t.user_id = u.user_id
GROUP BY u.city
ORDER BY failure_rate DESC;


-- -----------------------------------------------------
-- 8. Transaction Outcomes by Payment Method
-- Distribution of all outcomes
-- -----------------------------------------------------

SELECT 
    payment_method,
    COUNT(*) FILTER (WHERE status = 'SUCCESS') AS success_count,
    COUNT(*) FILTER (WHERE status = 'FAILED') AS failure_count,
    COUNT(*) FILTER (WHERE status = 'FRAUDULENT') AS fraud_count,
    COUNT(*) FILTER (WHERE status = 'REFUNDED') AS refund_count
FROM transactions
GROUP BY payment_method
ORDER BY payment_method;


-- -----------------------------------------------------
-- 9. High-Value Transactions: Success vs Failure
-- Example threshold: amount > 10000
-- -----------------------------------------------------

SELECT 
    CASE 
        WHEN amount > 10000 THEN 'High Value'
        ELSE 'Regular'
    END AS transaction_type,
    
    COUNT(*) FILTER (WHERE status = 'SUCCESS') AS success_count,
    COUNT(*) FILTER (WHERE status = 'FAILED') AS failure_count,
    COUNT(*) FILTER (WHERE status = 'FRAUDULENT') AS fraud_count

FROM transactions
WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')
GROUP BY transaction_type;


