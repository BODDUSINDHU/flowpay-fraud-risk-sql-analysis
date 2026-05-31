SET search_path TO flowpay;

-- 🔍 FRAUD TYPE DISTRIBUTION

SELECT 
    fraud_type,
    COUNT(*) AS cases,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM fraud_reports
GROUP BY fraud_type
ORDER BY cases DESC;

-- 🔍 REFUND REASON DISTRIBUTION

SELECT 
    refund_reason,
    COUNT(*) AS cases,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM refunds
GROUP BY refund_reason
ORDER BY cases DESC;