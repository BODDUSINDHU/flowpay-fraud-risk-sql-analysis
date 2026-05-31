SET search_path TO flowpay;


CREATE VIEW velocity_users AS
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

SELECT 
    user_id,
    velocity_segment
FROM user_velocity;


CREATE VIEW retry_users AS

-- 🔹 Step 1: Identify retry transactions & map to original
WITH retry_mapping AS (
    SELECT 
        t.user_id,
        t.transaction_id,
        t.status,
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

-- 🔹 Step 3: Identify valid retries
valid_retries AS (
    SELECT 
        rm.user_id,
        rm.transaction_id AS retry_txn_id
    FROM retry_mapping rm
    INNER JOIN failed_txns ft
        ON rm.original_txn_id = ft.original_txn_id
    WHERE rm.is_retry = 1
),

-- 🔹 Step 4: User-level retry count
user_retry_stats AS (
    SELECT 
        ub.user_id,
        COUNT(DISTINCT vr.retry_txn_id) AS total_retries
    FROM user_base ub
    LEFT JOIN valid_retries vr
        ON ub.user_id = vr.user_id
    GROUP BY ub.user_id
),

-- 🔹 Step 5: Segment users
user_segments AS (
    SELECT 
        user_id,
        total_retries,

        CASE 
            WHEN total_retries = 0 THEN '🟢 No Retry Users'
            WHEN total_retries BETWEEN 1 AND 3 THEN '🟡 Retry Users'
            ELSE '🚨 High Retry Users'
        END AS retry_segment

    FROM user_retry_stats
)

-- ✅ FINAL OUTPUT (USER LEVEL ONLY)
SELECT 
    user_id,
    retry_segment
FROM user_segments;

CREATE VIEW city_users AS

WITH txn_ordered AS (
    SELECT 
        user_id,
        ip_city,
        transaction_time,

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

city_transitions AS (
    SELECT 
        user_id,

        EXTRACT(EPOCH FROM (transaction_time - prev_time)) / 60 AS time_gap_minutes,

        CASE 
            WHEN ip_city IS DISTINCT FROM prev_city THEN 1 
            ELSE 0 
        END AS is_city_change

    FROM txn_ordered
    WHERE prev_time IS NOT NULL
),

suspicious_flags AS (
    SELECT 
        user_id,

        CASE 
            WHEN is_city_change = 1 
             AND time_gap_minutes <= 60
            THEN 1 
            ELSE 0 
        END AS suspicious_movement

    FROM city_transitions
),

user_city_behavior AS (
    SELECT 
        user_id,

        SUM(suspicious_movement) AS suspicious_city_changes

    FROM suspicious_flags
    GROUP BY user_id
),

final_users AS (
    SELECT 
        ub.user_id,
        COALESCE(ucb.suspicious_city_changes, 0) AS suspicious_city_changes

    FROM user_base ub
    LEFT JOIN user_city_behavior ucb
        ON ub.user_id = ucb.user_id
),

user_segments AS (
    SELECT 
        user_id,

        CASE 
            WHEN suspicious_city_changes >= 3 THEN '🚨 High Risk'
            WHEN suspicious_city_changes >= 1 THEN '🟡 Suspicious'
            ELSE '🟢 Normal'
        END AS city_segment

    FROM final_users
)

SELECT 
    user_id,
    city_segment
FROM user_segments;

CREATE VIEW segment_users AS

-- Step 1: Activity Segmentation
WITH baseline AS (
    SELECT AVG(total_txns) AS avg_txns
    FROM user_base
),

activity_segment AS (
    SELECT 
        ub.user_id,
        ub.total_txns,
        ub.total_spend,

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
            WHEN PERCENT_RANK() OVER (ORDER BY total_spend) >= 0.95 
                THEN 'High Spend'
            ELSE 'Low Spend'
        END AS spend_segment
    FROM user_base
    WHERE total_spend IS NOT NULL
),

-- Step 3: Combine
combined_users AS (
    SELECT 
        a.user_id,

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

-- ✅ FINAL OUTPUT
SELECT 
    user_id,
    final_segment
FROM combined_users;

-- 🧠 FINAL RISK SCORING MODEL

CREATE VIEW risk_scoring_model as

WITH base AS (
    SELECT 
        user_id,
        total_txns,
        failed_txns,
        fraud_txns,
        device_count,

        ROUND(
            failed_txns * 100.0 
            / NULLIF(total_txns, 0),
        2) AS failure_rate

    FROM user_base
),

final_join AS (
    SELECT 
        b.user_id,
        b.fraud_txns,
        b.failure_rate,
        b.device_count,

        v.velocity_segment,
        r.retry_segment,
        c.city_segment,
        s.final_segment

    FROM base b

    LEFT JOIN velocity_users v ON b.user_id = v.user_id
    LEFT JOIN retry_users r    ON b.user_id = r.user_id
    LEFT JOIN city_users c     ON b.user_id = c.user_id
    LEFT JOIN segment_users s  ON b.user_id = s.user_id
),

scored AS (
    SELECT 
        *,

        -- 🔥 FINAL RISK SCORE
        (
            -- Fraud
            CASE WHEN fraud_txns > 0 THEN 40 ELSE 0 END

            -- Failure
            + CASE WHEN failure_rate > 12 THEN 20 ELSE 0 END

            -- Velocity
            + CASE 
                WHEN velocity_segment = '🚨 High Velocity' THEN 25
                WHEN velocity_segment = '🟡 Medium Velocity' THEN 10
                ELSE 0
              END

            -- Retry
            + CASE 
                WHEN retry_segment = '🚨 High Retry Users' THEN 10
                ELSE 0
              END

            -- Device
            + CASE 
                WHEN device_count >= 4 THEN 10
                ELSE 0
              END

            -- City
            + CASE 
                WHEN city_segment = '🚨 High Risk' THEN 15
                ELSE 0
              END

            -- Segment
            + CASE 
                WHEN final_segment = '🤖 High Activity - Low Value' THEN 20
                WHEN final_segment = '🚨 High Value - Low Activity' THEN 10
                WHEN final_segment = '💎 Valuable Users' THEN -10
                ELSE 0
              END

        ) AS risk_score

    FROM final_join
),

final_output AS (
    SELECT 
        user_id,
        risk_score,

        CASE 
            WHEN risk_score >= 60 THEN '🚨 High Risk'
            WHEN risk_score >= 30 THEN '🟡 Medium Risk'
            ELSE '🟢 Low Risk'
        END AS risk_level

    FROM scored
)

SELECT * FROM final_output;

SELECT risk_level, COUNT(*)
FROM risk_scoring_model
GROUP BY risk_level;

SELECT 
    r.risk_level,

    COUNT(*) AS users,

    ROUND(AVG(ub.fraud_txns * 100.0 / NULLIF(ub.total_txns,0)),2) AS fraud_rate,

    ROUND(AVG(ub.failed_txns * 100.0 / NULLIF(ub.total_txns,0)),2) AS failure_rate

FROM risk_scoring_model r
JOIN user_base ub ON r.user_id = ub.user_id

GROUP BY r.risk_level
ORDER BY risk_level;

SELECT 
    risk_level,
    COUNT(*) AS users,
    ROUND(SUM(ub.total_spend),2) AS revenue
FROM risk_scoring_model r
JOIN user_base ub ON r.user_id = ub.user_id
GROUP BY risk_level;

CREATE VIEW fraud_labels AS

SELECT 
    t.user_id,

    CASE 
        WHEN COUNT(fr.transaction_id) > 0 THEN 1
        ELSE 0
    END AS is_reported_fraud

FROM transactions t
LEFT JOIN fraud_reports fr
    ON t.transaction_id = fr.transaction_id

GROUP BY t.user_id;

SELECT 
    r.risk_level,

    COUNT(*) AS users,

    SUM(f.is_reported_fraud) AS fraud_users,

    ROUND(
        SUM(f.is_reported_fraud) * 100.0 
        / COUNT(*),
    2) AS fraud_rate

FROM risk_scoring_model r
JOIN fraud_labels f 
    ON r.user_id = f.user_id

GROUP BY r.risk_level
ORDER BY r.risk_level;

SELECT 
    r.risk_level,
    f.is_reported_fraud,
    COUNT(*) AS users
FROM risk_scoring_model r
JOIN fraud_labels f 
ON r.user_id = f.user_id
GROUP BY r.risk_level, f.is_reported_fraud;