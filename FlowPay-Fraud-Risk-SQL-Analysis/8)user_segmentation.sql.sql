SET search_path TO flow_pay;
-- Step 1: Activity Segmentation (Power Users)
WITH baseline AS (
    SELECT AVG(total_txns) AS avg_txns
    FROM user_base
),

activity_segment AS (
    SELECT 
        ub.user_id,
        ub.total_txns,
        ub.total_spend,
        ub.device_count,
        ub.city_count,
        ub.failed_txns,
        ub.fraud_txns,

        CASE 
            WHEN ub.total_txns >= 3 * b.avg_txns THEN 'High Activity'
            WHEN ub.total_txns >= 2 * b.avg_txns THEN 'High Activity'
            ELSE 'Low Activity'
        END AS activity_segment

    FROM user_base ub
    CROSS JOIN baseline b
),

-- Step 2: Spend Segmentation
spend_segment AS (
    SELECT 
        user_id,

        CASE 
            WHEN PERCENT_RANK() OVER (ORDER BY total_spend) >= 0.95 THEN 'High Spend'
            ELSE 'Low Spend'
        END AS spend_segment

    FROM user_base
    WHERE total_spend IS NOT NULL
),

-- Step 3: Combine Both
combined_users AS (
    SELECT 
        a.user_id,
        a.total_txns,
        a.total_spend,
        a.device_count,
        a.city_count,
        a.failed_txns,
        a.fraud_txns,
        a.activity_segment,
        s.spend_segment,

        -- 🔥 FINAL SEGMENT
        CASE 
            WHEN a.activity_segment = 'High Activity' AND s.spend_segment = 'High Spend'
                THEN '💎 Valuable Users'

            WHEN a.activity_segment = 'High Activity' AND s.spend_segment = 'Low Spend'
                THEN '🤖 High Activity - Low Value'

            WHEN a.activity_segment = 'Low Activity' AND s.spend_segment = 'High Spend'
                THEN '🚨 High Value - Low Activity'

            ELSE '🟢 Normal Users'
        END AS final_segment

    FROM activity_segment a
    JOIN spend_segment s 
        ON a.user_id = s.user_id
)

-- Step 4: Final Aggregation
SELECT 
    final_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Risk
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM combined_users
GROUP BY final_segment
ORDER BY total_revenue DESC;