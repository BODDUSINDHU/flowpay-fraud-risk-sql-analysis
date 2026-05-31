SET search_path TO flowpay;

-- =========================================
-- MASTER REVENUE LOSS KPI TABLE
-- =========================================

WITH txn_base AS (
    -- ✅ ONLY user attempts (exclude refund rows)
    SELECT 
        transaction_id,
        amount,
        status
    FROM transactions
    WHERE status IN ('SUCCESS', 'FAILED', 'FRAUDULENT')
),

refunds_agg AS (
    -- ✅ Refunds are separate flow
    SELECT 
        SUM(refund_amount) AS refund_amount
    FROM refunds
),

agg AS (
    SELECT 
        SUM(amount) AS total_attempted,

        SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END) AS success_amount,
        SUM(CASE WHEN status = 'FAILED' THEN amount ELSE 0 END) AS failed_amount,
        SUM(CASE WHEN status = 'FRAUDULENT' THEN amount ELSE 0 END) AS fraud_amount

    FROM txn_base
),

final AS (
    SELECT 
        a.total_attempted,
        a.success_amount,
        a.failed_amount,
        a.fraud_amount,
        COALESCE(r.refund_amount, 0) AS refund_amount,

        -- 💰 Net Revenue
        (a.success_amount - COALESCE(r.refund_amount, 0)) AS net_revenue,

        -- 🔴 Attempt-stage loss
        (a.failed_amount + a.fraud_amount) AS attempt_stage_loss,

        -- 🟡 Post-success loss
        COALESCE(r.refund_amount, 0) AS post_success_loss,

        -- 🔥 Total loss (for contribution only)
        (a.failed_amount + a.fraud_amount + COALESCE(r.refund_amount, 0)) AS total_loss

    FROM agg a
    CROSS JOIN refunds_agg r
)

SELECT 
    -- ===============================
    -- SECTION 1: REVENUE FLOW
    -- ===============================
    total_attempted,
    success_amount,
    failed_amount,
    fraud_amount,
    refund_amount,
    net_revenue,

    -- ===============================
    -- SECTION 2: LOSS METRICS
    -- ===============================
    ROUND(failed_amount * 100.0 / NULLIF(total_attempted, 0), 2) AS failure_loss_rate,
    ROUND(fraud_amount * 100.0 / NULLIF(total_attempted, 0), 2) AS fraud_rate,

    ROUND(
        refund_amount * 100.0 
        / NULLIF(success_amount, 0), 2
    ) AS refund_rate,

    ROUND(
        net_revenue * 100.0 
        / NULLIF(total_attempted, 0), 2
    ) AS net_revenue_retention,

    -- ===============================
    -- SECTION 3: LOSS CONTRIBUTION
    -- ===============================
    ROUND(failed_amount * 100.0 / NULLIF(total_loss, 0), 2) AS failure_loss_pct,
    ROUND(fraud_amount * 100.0 / NULLIF(total_loss, 0), 2) AS fraud_loss_pct,
    ROUND(refund_amount * 100.0 / NULLIF(total_loss, 0), 2) AS refund_loss_pct

FROM final;

-- =========================================
-- LOSS BREAKDOWN BY PAYMENT METHOD
-- =========================================
WITH txn_base AS (
    SELECT *
    FROM transactions
    WHERE status IN ('SUCCESS', 'FAILED', 'FRAUDULENT')
),

refunds_agg AS (
    SELECT 
        t.payment_method,
        SUM(r.refund_amount) AS refund_amount
    FROM refunds r
    JOIN transactions t 
        ON r.transaction_id = t.transaction_id
    GROUP BY t.payment_method
)

SELECT 
    t.payment_method,

    SUM(t.amount) AS total_attempted,

    SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END) AS success_amount,
    SUM(CASE WHEN status = 'FAILED' THEN amount ELSE 0 END) AS failed_amount,
    SUM(CASE WHEN status = 'FRAUDULENT' THEN amount ELSE 0 END) AS fraud_amount,

    COALESCE(r.refund_amount, 0) AS refund_amount,

    -- Net revenue
    SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END)
    - COALESCE(r.refund_amount, 0) AS net_revenue,

    -- Rates
    ROUND(SUM(CASE WHEN status = 'FAILED' THEN amount ELSE 0 END) * 100.0 
        / NULLIF(SUM(t.amount), 0), 2) AS failure_rate,

    ROUND(SUM(CASE WHEN status = 'FRAUDULENT' THEN amount ELSE 0 END) * 100.0 
        / NULLIF(SUM(t.amount), 0), 2) AS fraud_rate,

    ROUND(COALESCE(r.refund_amount, 0) * 100.0 
        / NULLIF(SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END), 0), 2) AS refund_rate,

    -- 🔥 Retention
    ROUND(
        (
            SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END)
            - COALESCE(r.refund_amount, 0)
        ) * 100.0
        / NULLIF(SUM(t.amount), 0), 2
    ) AS net_revenue_retention

FROM txn_base t
LEFT JOIN refunds_agg r 
    ON t.payment_method = r.payment_method
GROUP BY t.payment_method, r.refund_amount
ORDER BY total_attempted DESC;

-- 💰 Revenue Loss by Merchant Category

SELECT 
    m.merchant_category AS merchant_category,

    -- Core amounts
    SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END) AS total_attempted,

    SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END) AS success_amount,
    SUM(CASE WHEN t.status = 'FAILED' THEN t.amount ELSE 0 END) AS failed_amount,
    SUM(CASE WHEN t.status = 'FRAUDULENT' THEN t.amount ELSE 0 END) AS fraud_amount,
    SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END) AS refund_amount,

    -- Net revenue
    SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END)
    - SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END) AS net_revenue,

    -- Rates
    ROUND(
        SUM(CASE WHEN t.status = 'FAILED' THEN t.amount ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END), 0),
    2) AS failure_rate,

    ROUND(
        SUM(CASE WHEN t.status = 'FRAUDULENT' THEN t.amount ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END), 0),
    2) AS fraud_rate,

    ROUND(
        SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END), 0),
    2) AS refund_rate,

    ROUND(
        (SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END)
        - SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END)) * 100.0
        / NULLIF(SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END), 0),
    2) AS net_revenue_retention

FROM transactions t
JOIN merchants m 
    ON t.merchant_id = m.merchant_id

GROUP BY m.merchant_category
ORDER BY net_revenue DESC;

-- 💰 Revenue Loss by User Segments

WITH baseline AS (
    SELECT AVG(total_txns) AS avg_txns
    FROM user_base
),

activity_segment AS (
    SELECT 
        ub.*,

        CASE 
            WHEN ub.total_txns >= 2 * b.avg_txns THEN 'High Activity'
            ELSE 'Low Activity'
        END AS activity_segment

    FROM user_base ub
    CROSS JOIN baseline b
),

spend_segment AS (
    SELECT 
        user_id,

        CASE 
            WHEN PERCENT_RANK() OVER (ORDER BY total_spend) >= 0.95 THEN 'High Spend'
            ELSE 'Low Spend'
        END AS spend_segment

    FROM user_base
),

combined_users AS (
    SELECT 
        a.user_id,
        a.activity_segment,
        s.spend_segment,

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

SELECT 
    cu.final_segment,

    -- Core amounts
    SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END) AS total_attempted,

    SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END) AS success_amount,
    SUM(CASE WHEN t.status = 'FAILED' THEN t.amount ELSE 0 END) AS failed_amount,
    SUM(CASE WHEN t.status = 'FRAUDULENT' THEN t.amount ELSE 0 END) AS fraud_amount,
    SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END) AS refund_amount,

    -- Net revenue
    SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END)
    - SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END) AS net_revenue,

    -- Rates
    ROUND(
        SUM(CASE WHEN t.status = 'FAILED' THEN t.amount ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END), 0),
    2) AS failure_rate,

    ROUND(
        SUM(CASE WHEN t.status = 'FRAUDULENT' THEN t.amount ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END), 0),
    2) AS fraud_rate,

    ROUND(
        SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END), 0),
    2) AS refund_rate,

    ROUND(
        (SUM(CASE WHEN t.status = 'SUCCESS' THEN t.amount ELSE 0 END)
        - SUM(CASE WHEN t.status = 'REFUNDED' THEN t.amount ELSE 0 END)) * 100.0
        / NULLIF(SUM(CASE WHEN t.status IN ('SUCCESS','FAILED','FRAUDULENT') THEN t.amount ELSE 0 END), 0),
    2) AS net_revenue_retention

FROM transactions t
JOIN combined_users cu
    ON t.user_id = cu.user_id

GROUP BY cu.final_segment
ORDER BY net_revenue DESC;

-- 💰 LOSS ANALYSIS BY TRANSACTION SIZE

WITH txn_base AS (
    SELECT 
        t.transaction_id,
        t.amount,
        t.status,

        -- 🎯 Size Buckets
        CASE 
            WHEN t.amount < 500 THEN '🟢 Small (<500)'
            WHEN t.amount BETWEEN 500 AND 2000 THEN '🟡 Medium (500-2K)'
            WHEN t.amount BETWEEN 2000 AND 10000 THEN '🟠 Large (2K-10K)'
            ELSE '🚨 High Value (>10K)'
        END AS txn_size_segment

    FROM transactions t
),

size_agg AS (
    SELECT 
        txn_size_segment,

        -- 💰 Core amounts
        SUM(amount) FILTER (WHERE status IN ('SUCCESS', 'FAILED', 'FRAUDULENT')) AS total_attempted,

        SUM(amount) FILTER (WHERE status = 'SUCCESS') AS success_amount,
        SUM(amount) FILTER (WHERE status = 'FAILED') AS failed_amount,
        SUM(amount) FILTER (WHERE status = 'FRAUDULENT') AS fraud_amount,
        SUM(amount) FILTER (WHERE status = 'REFUNDED') AS refund_amount,

        -- 💰 Net revenue
        SUM(amount) FILTER (WHERE status = 'SUCCESS')
        - SUM(amount) FILTER (WHERE status = 'REFUNDED') AS net_revenue

    FROM txn_base
    GROUP BY txn_size_segment
),

final AS (
    SELECT 
        txn_size_segment,

        total_attempted,
        success_amount,
        failed_amount,
        fraud_amount,
        refund_amount,
        net_revenue,

        -- 📊 Rates
        ROUND(failed_amount * 100.0 / NULLIF(total_attempted, 0), 2) AS failure_rate,
        ROUND(fraud_amount * 100.0 / NULLIF(total_attempted, 0), 2) AS fraud_rate,
        ROUND(refund_amount * 100.0 / NULLIF(success_amount, 0), 2) AS refund_rate,

        ROUND(net_revenue * 100.0 / NULLIF(total_attempted, 0), 2) AS net_revenue_retention

    FROM size_agg
)

SELECT *
FROM final
ORDER BY total_attempted DESC;

-- 💰 RETRY RECOVERY & FAILURE LOSS ANALYSIS

SET search_path TO flowpay;

WITH retry_mapping AS (
    SELECT 
        t.user_id,
        t.transaction_id,
        t.amount,
        t.status,

        REPLACE(t.transaction_id, '_retry', '') AS original_txn_id,

        CASE 
            WHEN t.transaction_id LIKE '%_retry' THEN 1
            ELSE 0
        END AS is_retry

    FROM transactions t
),

-- 🔹 Original failed transactions
failed_txns AS (
    SELECT 
        transaction_id AS original_txn_id,
        user_id,
        amount AS failed_amount
    FROM transactions
    WHERE status = 'FAILED'
),

-- 🔹 Valid retries
valid_retries AS (
    SELECT 
        rm.original_txn_id,
        rm.transaction_id AS retry_txn_id,
        rm.amount AS retry_amount,
        rm.status AS retry_status
    FROM retry_mapping rm
    INNER JOIN failed_txns ft
        ON rm.original_txn_id = ft.original_txn_id
    WHERE rm.is_retry = 1
),

-- 🔹 Recovery mapping (only successful retries)
recovered_txns AS (
    SELECT 
        vr.original_txn_id,
        MAX(vr.retry_amount) FILTER (WHERE vr.retry_status = 'SUCCESS') AS recovered_amount
    FROM valid_retries vr
    GROUP BY vr.original_txn_id
),

-- 🔹 Combine failed + recovery
final AS (
    SELECT 
        ft.original_txn_id,
        ft.failed_amount,
        COALESCE(rt.recovered_amount, 0) AS recovered_amount
    FROM failed_txns ft
    LEFT JOIN recovered_txns rt
        ON ft.original_txn_id = rt.original_txn_id
)

-- 🔥 Final Metrics
SELECT 

    -- 💰 Core amounts
    SUM(failed_amount) AS total_failed_amount,
    SUM(recovered_amount) AS retry_recovered_amount,

    -- 💣 True loss
    SUM(failed_amount) - SUM(recovered_amount) AS unrecovered_failed_amount,

    -- 📊 Recovery rate
    ROUND(
        SUM(recovered_amount) * 100.0 
        / NULLIF(SUM(failed_amount), 0),
    2) AS recovery_rate,

    -- 📉 Net failure loss rate
    ROUND(
        (SUM(failed_amount) - SUM(recovered_amount)) * 100.0
        / NULLIF(SUM(failed_amount), 0),
    2) AS net_failure_loss_rate

FROM final;