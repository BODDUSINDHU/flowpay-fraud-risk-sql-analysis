SET search_path TO flow_pay;
CREATE VIEW user_base AS
    SELECT 
        user_id,

        COUNT(*) FILTER (WHERE status IN ('SUCCESS','FAILED','FRAUDULENT')) AS total_txns,
        COUNT(*) FILTER (WHERE status = 'SUCCESS') AS success_txns,
        COUNT(*) FILTER (WHERE status = 'FAILED') AS failed_txns,
        COUNT(*) FILTER (WHERE status = 'FRAUDULENT') AS fraud_txns,

        SUM(amount) FILTER (WHERE status = 'SUCCESS') AS total_spend,
        AVG(amount) FILTER (WHERE status = 'SUCCESS') AS avg_txn_value,

        COUNT(DISTINCT device_id) AS device_count,
        COUNT(DISTINCT ip_city) AS city_count,

        MIN(transaction_time) AS first_txn,
        MAX(transaction_time) AS last_txn

    FROM transactions
    GROUP BY user_id;

SELECT 
    ROUND(AVG(total_txns), 2) AS avg_txns,
    ROUND(AVG(total_spend), 2) AS avg_spend,
    ROUND(AVG(device_count), 2) AS avg_devices,

    ROUND(
    AVG(
        EXTRACT(EPOCH FROM (last_txn - first_txn)) 
        / NULLIF(total_txns - 1, 0)
    ) / 86400,
2) AS avg_time_gap_days

FROM user_base;

-- Step 1: Baseline (average transactions)
WITH baseline AS (
    SELECT AVG(total_txns) AS avg_txns
    FROM user_base
),

-- Step 2: User Segmentation
user_segments AS (
    SELECT 
        ub.user_id,
        ub.total_txns,
        ub.total_spend,
        ub.device_count,
        ub.city_count,
        ub.failed_txns,
        ub.fraud_txns,

        CASE 
            WHEN ub.total_txns >= 3 * b.avg_txns THEN 'Extreme Power User'
            WHEN ub.total_txns >= 2 * b.avg_txns THEN 'Power User'
            ELSE 'Normal User'
        END AS user_segment

    FROM user_base ub
    CROSS JOIN baseline b
)

-- Step 3: Aggregated Insights + 🔥 Weighted Risk
SELECT 
    user_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_segments
GROUP BY user_segment
ORDER BY total_revenue DESC;
-- Step 1 + 2: Rank users by spend
WITH ranked_users AS (
    SELECT 
        user_id,
        total_spend,
        total_txns,
        success_txns,
        failed_txns,
        fraud_txns,
        device_count,
        city_count,

        PERCENT_RANK() OVER (ORDER BY total_spend) AS spend_percentile

    FROM user_base
    WHERE total_spend IS NOT NULL
),

-- Step 3: Segment users
user_segments AS (
    SELECT 
        *,
        CASE 
            WHEN spend_percentile >= 0.99 THEN 'Top 1% (Elite)'
            WHEN spend_percentile >= 0.95 THEN 'Top 5% (High Spender)'
            WHEN spend_percentile >= 0.90 THEN 'Top 10% (Mid-High)'
            ELSE 'Normal'
        END AS spender_segment
    FROM ranked_users
)

-- ✅ Step 4 + 5: Aggregation with WEIGHTED risk
SELECT 
    spender_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 WEIGHTED FRAUD RATE
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 WEIGHTED FAILURE RATE
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_segments
GROUP BY spender_segment
ORDER BY total_revenue DESC;

-- 💤 DORMANT & ONE-TIME USER ANALYSIS

-- Step 1: Reference date (latest transaction in dataset)
WITH reference_date AS (
    SELECT MAX(transaction_time) AS max_date
    FROM transactions
),

-- Step 2: Add inactivity calculation
user_activity AS (
    SELECT 
        ub.*,
        rd.max_date,

        -- Inactivity in days
        ROUND(
            EXTRACT(EPOCH FROM (rd.max_date - ub.last_txn)) / 86400,
        2) AS inactivity_days

    FROM user_base ub
    CROSS JOIN reference_date rd
),

-- Step 3: Define user segments
user_segments AS (
    SELECT 
        *,
        CASE 
            WHEN total_txns = 1 THEN '⚠️ One-Time Users'
            WHEN inactivity_days >= 60 THEN '💤 Dormant Users'
            ELSE '🟢 Active Users'
        END AS activity_segment
    FROM user_activity
)
-- Step 4: Aggregate insights
SELECT 
    activity_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_segments
GROUP BY activity_segment
ORDER BY total_revenue DESC;

-- 💤 DORMANT USERS (PERCENTILE-BASED)

-- Step 1: Reference date (same as before)
WITH reference_date AS (
    SELECT MAX(transaction_time) AS max_date
    FROM transactions
),

-- Step 2: Compute inactivity
user_activity AS (
    SELECT 
        ub.*,
        rd.max_date,

        ROUND(
            EXTRACT(EPOCH FROM (rd.max_date - ub.last_txn)) / 86400,
        2) AS inactivity_days

    FROM user_base ub
    CROSS JOIN reference_date rd
),

-- Step 3: Rank users by inactivity (MOST IMPORTANT STEP)
ranked_users AS (
    SELECT 
        *,
        PERCENT_RANK() OVER (ORDER BY inactivity_days) AS inactivity_percentile
    FROM user_activity
),

-- Step 4: Segment based on percentile
user_segments AS (
    SELECT 
        *,
        CASE 
            WHEN total_txns = 1 THEN '⚠️ One-Time Users'
            WHEN inactivity_percentile >= 0.95 THEN '🚨 Highly Dormant (Top 5%)'
            WHEN inactivity_percentile >= 0.90 THEN '💤 Dormant (Top 10%)'
            ELSE '🟢 Active Users'
        END AS activity_segment
    FROM ranked_users
)

-- Step 5: Aggregate insights
SELECT 
    activity_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_segments
GROUP BY activity_segment
ORDER BY total_revenue DESC;

-- 📱 MULTI-DEVICE USER ANALYSIS

WITH user_device_segments AS (
    SELECT 
        user_id,
        total_txns,
        total_spend,
        device_count,
        city_count,
        failed_txns,
        fraud_txns,

        CASE 
            WHEN device_count <= 2 THEN '🟢 Normal (1–2 Devices)'
            WHEN device_count = 3 THEN '🟡 Watchlist (3 Devices)'
            WHEN device_count >= 4 THEN '🚨 Suspicious (4+ Devices)'
        END AS device_segment

    FROM user_base
)

SELECT 
    device_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_device_segments
GROUP BY device_segment
ORDER BY total_revenue DESC;

-- 🌍 MULTI-CITY WITH TIME CONTEXT ANALYSIS

WITH txn_ordered AS (
    SELECT 
        user_id,
        ip_city,
        transaction_time,

        -- Previous city & time
        LAG(ip_city) OVER (
            PARTITION BY user_id 
            ORDER BY transaction_time
        ) AS prev_city,

        LAG(transaction_time) OVER (
            PARTITION BY user_id 
            ORDER BY transaction_time
        ) AS prev_time

    FROM transactions
),

-- Step 2: Detect city switches + time gap
city_transitions AS (
    SELECT 
        user_id,

        ip_city,
        prev_city,

        transaction_time,
        prev_time,

        -- Time gap in minutes
        EXTRACT(EPOCH FROM (transaction_time - prev_time)) / 60 AS time_gap_minutes,

        -- City change flag
        CASE 
            WHEN ip_city IS DISTINCT FROM prev_city THEN 1 
            ELSE 0 
        END AS is_city_change

    FROM txn_ordered
    WHERE prev_time IS NOT NULL
),

-- Step 3: Flag suspicious movement
suspicious_flags AS (
    SELECT 
        user_id,

        is_city_change,

        time_gap_minutes,

        CASE 
            WHEN is_city_change = 1 
             AND time_gap_minutes <= 60  -- ⚡ Threshold (can tweak)
            THEN 1 
            ELSE 0 
        END AS suspicious_movement

    FROM city_transitions
),

-- Step 4: Aggregate at user level
user_city_behavior AS (
    SELECT 
        user_id,

        SUM(is_city_change) AS total_city_changes,
        SUM(suspicious_movement) AS suspicious_city_changes,

        ROUND(
            SUM(suspicious_movement) * 100.0 
            / NULLIF(SUM(is_city_change), 0),
        2) AS suspicious_change_pct

    FROM suspicious_flags
    GROUP BY user_id
),

-- Step 5: Combine with user_base
final_user_data AS (
    SELECT 
        ub.*,
        ucb.total_city_changes,
        ucb.suspicious_city_changes,
        ucb.suspicious_change_pct

    FROM user_base ub
    LEFT JOIN user_city_behavior ucb
    ON ub.user_id = ucb.user_id
),

-- Step 6: Segment users
user_segments AS (
    SELECT 
        *,

        CASE 
            WHEN suspicious_city_changes >= 3 THEN '🚨 High Risk (Frequent Impossible Travel)'
            WHEN suspicious_city_changes >= 1 THEN '🟡 Occasional Suspicious'
            ELSE '🟢 Normal Movement'
        END AS city_behavior_segment

    FROM final_user_data
)

-- Step 7: Aggregate insights
SELECT 
    city_behavior_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_segments
GROUP BY city_behavior_segment
ORDER BY total_revenue DESC;

-- ⚡ VELOCITY ANALYSIS (Corrected + Strong Segmentation)

SET search_path TO flowpay;

-- Step 1: Order transactions & compute time gaps
WITH txn_ordered AS (
    SELECT 
        user_id,
        transaction_time,
        status,

        LAG(transaction_time) OVER (
            PARTITION BY user_id 
            ORDER BY transaction_time
        ) AS prev_time

    FROM transactions
),

-- Step 2: Calculate time gap (seconds)
txn_with_gap AS (
    SELECT 
        *,
        EXTRACT(EPOCH FROM (transaction_time - prev_time)) AS time_gap_sec
    FROM txn_ordered
),

-- Step 3: Define fast transactions (handle NULL properly)
txn_flagged AS (
    SELECT 
        *,
        CASE 
            WHEN prev_time IS NULL THEN 0
            WHEN time_gap_sec <= 300 THEN 1  -- 5 minutes
            ELSE 0 
        END AS is_fast_txn
    FROM txn_with_gap
),

-- Step 4: Group consecutive fast transactions
txn_grouped AS (
    SELECT 
        *,
        SUM(
            CASE 
                WHEN is_fast_txn = 0 THEN 1 
                ELSE 0 
            END
        ) OVER (
            PARTITION BY user_id 
            ORDER BY transaction_time
        ) AS burst_group
    FROM txn_flagged
),

-- Step 5: Count burst sizes
burst_counts AS (
    SELECT 
        user_id,
        burst_group,
        COUNT(*) AS burst_size
    FROM txn_grouped
    WHERE is_fast_txn = 1
    GROUP BY user_id, burst_group
),

-- Step 6: Valid bursts (≥ 2)
valid_bursts AS (
    SELECT 
        user_id,
        COUNT(*) AS total_bursts,
        MAX(burst_size) AS max_burst_size
    FROM burst_counts
    WHERE burst_size >= 2
    GROUP BY user_id
),

-- Step 7: Fast txn ratio per user (FIXED denominator)
fast_txn_stats AS (
    SELECT 
        user_id,

        COUNT(prev_time) AS comparable_txns,  -- excludes first txn
        COUNT(*) FILTER (WHERE is_fast_txn = 1) AS fast_txns,

        ROUND(
            COUNT(*) FILTER (WHERE is_fast_txn = 1) * 100.0 
            / NULLIF(COUNT(prev_time), 0),
        2) AS fast_txn_ratio

    FROM txn_flagged
    GROUP BY user_id
),

-- Step 8: Combine everything
user_velocity AS (
    SELECT 
        ub.user_id,
        ub.total_txns,
        ub.total_spend,
        ub.device_count,
        ub.city_count,
        ub.failed_txns,
        ub.fraud_txns,

        COALESCE(vb.total_bursts, 0) AS total_bursts,
        COALESCE(vb.max_burst_size, 0) AS max_burst_size,
        COALESCE(ft.fast_txn_ratio, 0) AS fast_txn_ratio,

        CASE 
            WHEN vb.total_bursts >= 1 
                 AND ft.fast_txn_ratio >= 10 THEN '🚨 High Velocity'

            WHEN ft.fast_txn_ratio BETWEEN 5 AND 10 THEN '🟡 Medium Velocity'

            ELSE '🟢 Normal'
        END AS velocity_segment

    FROM user_base ub
    LEFT JOIN valid_bursts vb
        ON ub.user_id = vb.user_id
    LEFT JOIN fast_txn_stats ft
        ON ub.user_id = ft.user_id
)

-- Step 9: Final Aggregation
SELECT 
    velocity_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_velocity
GROUP BY velocity_segment
ORDER BY total_revenue DESC;

-- ⚡ VELOCITY ANALYSIS (Using system-generated flag)

SET search_path TO flowpay;

-- Step 1: User-level velocity stats
WITH user_velocity_stats AS (
    SELECT 
        t.user_id,

        COUNT(*) AS total_txns,

        COUNT(*) FILTER (WHERE is_high_velocity) AS high_velocity_txns,

        ROUND(
            COUNT(*) FILTER (WHERE is_high_velocity) * 100.0
            / NULLIF(COUNT(*), 0),
        2) AS high_velocity_ratio

    FROM transactions t
    GROUP BY t.user_id
),

-- Step 2: Combine with user_base
user_velocity AS (
    SELECT 
        ub.user_id,
        ub.total_txns,
        ub.total_spend,
        ub.device_count,
        ub.city_count,
        ub.failed_txns,
        ub.fraud_txns,

        COALESCE(uv.high_velocity_txns, 0) AS high_velocity_txns,
        COALESCE(uv.high_velocity_ratio, 0) AS high_velocity_ratio,

        CASE 
            WHEN uv.high_velocity_ratio >= 10 THEN '🚨 High Velocity'
            WHEN uv.high_velocity_ratio BETWEEN 3 AND 10 THEN '🟡 Medium Velocity'
            ELSE '🟢 Normal'
        END AS velocity_segment

    FROM user_base ub
    LEFT JOIN user_velocity_stats uv
        ON ub.user_id = uv.user_id
)

-- Step 3: Final Aggregation
SELECT 
    velocity_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_velocity
GROUP BY velocity_segment
ORDER BY total_revenue DESC;

-- 🔁 RETRY BEHAVIOR ANALYSIS

SET search_path TO flowpay;

-- 🔹 Step 1: Identify retry transactions & map to original
WITH retry_mapping AS (
    SELECT 
        t.user_id,
        t.transaction_id,
        t.status,

        -- Extract original transaction_id
        REPLACE(t.transaction_id, '_retry', '') AS original_txn_id,

        CASE 
            WHEN t.transaction_id LIKE '%_retry' THEN 1
            ELSE 0
        END AS is_retry

    FROM transactions t
),

-- 🔹 Step 2: Separate original failed transactions
failed_txns AS (
    SELECT 
        user_id,
        transaction_id AS original_txn_id
    FROM transactions
    WHERE status = 'FAILED'
),

-- 🔹 Step 3: Identify valid retries (retry of a failed txn)
valid_retries AS (
    SELECT 
        rm.user_id,
        rm.transaction_id AS retry_txn_id,
        rm.original_txn_id,
        rm.status AS retry_status
    FROM retry_mapping rm
    INNER JOIN failed_txns ft
        ON rm.original_txn_id = ft.original_txn_id
    WHERE rm.is_retry = 1
),

-- 🔹 Step 4: User-level retry metrics
user_retry_stats AS (
    SELECT 
        ub.user_id,

        ub.failed_txns AS total_failed_txns,

        COUNT(DISTINCT vr.retry_txn_id) AS total_retries,

        COUNT(*) FILTER (WHERE vr.retry_status = 'SUCCESS') AS retry_success_count,

        ROUND(
            COUNT(*) FILTER (WHERE vr.retry_status = 'SUCCESS') * 100.0
            / NULLIF(COUNT(vr.retry_txn_id), 0),
        2) AS retry_success_rate

    FROM user_base ub
    LEFT JOIN valid_retries vr
        ON ub.user_id = vr.user_id
    GROUP BY ub.user_id, ub.failed_txns
),

-- 🔹 Step 5: Segment users based on retry behavior
user_segments AS (
    SELECT 
        urs.*,
        ub.total_txns,
        ub.total_spend,
        ub.device_count,
        ub.city_count,
        ub.fraud_txns,
        ub.failed_txns,

        CASE 
            WHEN total_retries = 0 THEN '🟢 No Retry Users'
            WHEN total_retries BETWEEN 1 AND 3 THEN '🟡 Retry Users'
            ELSE '🚨 High Retry Users'
        END AS retry_segment

    FROM user_retry_stats urs
    JOIN user_base ub
        ON urs.user_id = ub.user_id
)

-- 🔹 Step 6: Final Aggregation + Weighted Risk
SELECT 
    retry_segment,

    COUNT(*) AS user_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS user_percentage,

    SUM(total_txns) AS total_transactions,
    ROUND(100.0 * SUM(total_txns) / SUM(SUM(total_txns)) OVER (), 2) AS txn_percentage,

    ROUND(SUM(total_spend), 2) AS total_revenue,
    ROUND(100.0 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 2) AS revenue_percentage,

    ROUND(AVG(device_count), 2) AS avg_devices,
    ROUND(AVG(city_count), 2) AS avg_cities,

    -- 🔥 Retry insight
    ROUND(AVG(COALESCE(retry_success_rate, 0)), 2) AS avg_retry_success_rate,

    -- 🔥 Weighted Fraud Rate
    ROUND(
        SUM(fraud_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_fraud_rate,

    -- 🔥 Weighted Failure Rate
    ROUND(
        SUM(failed_txns) * 100.0 
        / NULLIF(SUM(total_txns), 0),
    2) AS weighted_failure_rate

FROM user_segments
GROUP BY retry_segment
ORDER BY total_revenue DESC;