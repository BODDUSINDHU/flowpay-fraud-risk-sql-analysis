SET search_path TO flow_pay;
-- =====================================================
-- Merchant Analysis
-- File: 07_merchant_analysis.sql
-- Purpose: Identify revenue drivers, fraud risk, and merchant behavior
-- =====================================================

SET search_path TO flowpay;

-- =====================================================
-- A. Merchant Contribution & Scale
-- =====================================================

-- 1. Top Merchants by Revenue (GPV)
SELECT 
    m.merchant_id,
    m.merchant_name,
    SUM(t.amount) AS gpv
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
WHERE t.status = 'SUCCESS'
GROUP BY m.merchant_id, m.merchant_name
ORDER BY gpv DESC
LIMIT 20;


-- 2. Transaction Volume by Merchant (All Attempts)
SELECT 
    m.merchant_id,
    m.merchant_name,
    COUNT(*) AS transaction_volume
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')
GROUP BY m.merchant_id, m.merchant_name
ORDER BY transaction_volume DESC;


-- 3. Average Transaction Value (ATV)
SELECT 
    m.merchant_id,
    m.merchant_name,
    ROUND(AVG(t.amount), 2) AS avg_transaction_value
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
WHERE t.status = 'SUCCESS'
GROUP BY m.merchant_id, m.merchant_name
ORDER BY avg_transaction_value DESC;


-- =====================================================
-- B. Fraud Risk Analysis
-- =====================================================

-- 4. Fraud Rate by Merchant
SELECT 
    m.merchant_id,
    m.merchant_name,
    COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') AS fraud_transactions,
    COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')) AS total_attempts,
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS fraud_rate
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY fraud_rate DESC;


-- 5. Fraud Exposure (₹)
SELECT 
    m.merchant_id,
    m.merchant_name,
    SUM(t.amount) FILTER (WHERE t.status = 'FRAUDULENT') AS fraud_exposure
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY fraud_exposure DESC;


-- 6. Fraud by Merchant Category
SELECT 
    m.merchant_category,
    COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') AS fraud_transactions,
    COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')) AS total_attempts,
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS fraud_rate
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_category
ORDER BY fraud_rate DESC;


-- 7. High-Risk Merchants (Above Avg + Volume Threshold)
WITH merchant_stats AS (
    SELECT 
        m.merchant_id,
        m.merchant_name,
        COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') AS fraud_txns,
        COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')) AS total_attempts,
        ROUND(
            COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
            2
        ) AS fraud_rate
    FROM transactions t
    JOIN merchants m 
        ON t.merchant_id = m.merchant_id
    GROUP BY m.merchant_id, m.merchant_name
),
platform_avg AS (
    SELECT 
        ROUND(
            COUNT(*) FILTER (WHERE status = 'FRAUDULENT') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
            2
        ) AS avg_fraud_rate
    FROM transactions
)

SELECT ms.*
FROM merchant_stats ms, platform_avg pa
WHERE ms.total_attempts >= 1000
AND ms.fraud_rate > pa.avg_fraud_rate
ORDER BY ms.fraud_rate DESC;


-- =====================================================
-- C. Refund Analysis
-- =====================================================

-- 8. Refund Rate by Merchant
SELECT 
    m.merchant_id,
    m.merchant_name,
    COUNT(*) FILTER (WHERE t.status = 'REFUNDED') AS refund_count,
    COUNT(*) FILTER (WHERE t.status = 'SUCCESS') AS success_count,
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'REFUNDED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status = 'SUCCESS'), 0),
        2
    ) AS refund_rate
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY refund_rate DESC;


-- 9. Refund Exposure
SELECT 
    m.merchant_id,
    m.merchant_name,
    SUM(t.amount) FILTER (WHERE t.status = 'REFUNDED') AS refund_exposure
FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY refund_exposure DESC;


-- =====================================================
-- D. Merchant Risk Segmentation
-- =====================================================

WITH merchant_metrics AS (
    SELECT 
        m.merchant_id,
        m.merchant_name,
        COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')) AS total_attempts,
        SUM(t.amount) FILTER (WHERE t.status = 'SUCCESS') AS gpv,

        ROUND(
            COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
            2
        ) AS fraud_rate,

        ROUND(
            COUNT(*) FILTER (WHERE t.status = 'REFUNDED') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE t.status = 'SUCCESS'), 0),
            2
        ) AS refund_rate

    FROM transactions t
    JOIN merchants m 
        ON t.merchant_id = m.merchant_id
    GROUP BY m.merchant_id, m.merchant_name
)

SELECT *,
    CASE
        WHEN fraud_rate > 3 AND total_attempts >= 1000 THEN 'High Fraud + High Volume'
        WHEN refund_rate > 4 AND gpv > 5000000 THEN 'High Refund + High Revenue'
        ELSE 'Normal'
    END AS risk_segment
FROM merchant_metrics
ORDER BY fraud_rate DESC;

-- =====================================================
-- E. Revenue vs Risk TradeOffs
-- =====================================================

-- Revenue vs Risk Analysis

SELECT 
    m.merchant_id,
    m.merchant_name,

    -- Revenue
    SUM(t.amount) FILTER (WHERE t.status = 'SUCCESS') AS gpv,

    -- Fraud Risk
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS fraud_rate,

    -- Refund Risk
    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'REFUNDED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status = 'SUCCESS'), 0),
        2
    ) AS refund_rate

FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY gpv DESC;

-- =====================================================
-- F. Outliers
-- =====================================================

-- Extremely High Fraud vs Category

WITH category_avg AS (
    SELECT 
        m.merchant_category,
        ROUND(
            COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
            2
        ) AS category_fraud_rate
    FROM transactions t
    JOIN merchants m 
        ON t.merchant_id = m.merchant_id
    GROUP BY m.merchant_category
),

merchant_fraud AS (
    SELECT 
        m.merchant_id,
        m.merchant_name,
        m.merchant_category,
        ROUND(
            COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
            2
        ) AS fraud_rate
    FROM transactions t
    JOIN merchants m 
        ON t.merchant_id = m.merchant_id
    GROUP BY m.merchant_id, m.merchant_name, m.merchant_category
)

SELECT *
FROM merchant_fraud mf
JOIN category_avg ca
    ON mf.merchant_category = ca.merchant_category
WHERE mf.fraud_rate > ca.category_fraud_rate + 2
ORDER BY mf.fraud_rate DESC;

--very high atv vs peers

WITH category_avg AS (
    SELECT 
        m.merchant_category,
        AVG(t.amount) FILTER (WHERE t.status = 'SUCCESS') AS category_atv
    FROM transactions t
    JOIN merchants m 
        ON t.merchant_id = m.merchant_id
    GROUP BY m.merchant_category
),

merchant_atv AS (
    SELECT 
        m.merchant_id,
        m.merchant_name,
        m.merchant_category,
        AVG(t.amount) FILTER (WHERE t.status = 'SUCCESS') AS merchant_atv
    FROM transactions t
    JOIN merchants m 
        ON t.merchant_id = m.merchant_id
    GROUP BY m.merchant_id, m.merchant_name, m.merchant_category
)

SELECT 
    ma.*,
    ca.category_atv,
    ROUND(ma.merchant_atv - ca.category_atv, 2) AS atv_difference
FROM merchant_atv ma
JOIN category_avg ca
    ON ma.merchant_category = ca.merchant_category
WHERE ma.merchant_atv > ca.category_atv * 1.2   -- threshold (50% higher)
ORDER BY atv_difference DESC;

--High Failure + High Fraud (Danger Zone)

SELECT 
    m.merchant_id,
    m.merchant_name,

    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FAILED') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS failure_rate,

    ROUND(
        COUNT(*) FILTER (WHERE t.status = 'FRAUDULENT') * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE t.status IN ('SUCCESS','FAILED','FRAUDULENT')), 0),
        2
    ) AS fraud_rate

FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_id, m.merchant_name
ORDER BY fraud_rate DESC, failure_rate DESC;

