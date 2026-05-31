SET search_path TO flowpay;

WITH base AS (
    SELECT
        -- 🎯 Attempt-stage (ONLY user attempts)
        SUM(CASE WHEN status IN ('SUCCESS','FAILED','FRAUDULENT') THEN amount ELSE 0 END) AS attempted_amount,

        SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0 END) AS success_amount,
        SUM(CASE WHEN status = 'FAILED' THEN amount ELSE 0 END) AS failed_amount,
        SUM(CASE WHEN status = 'FRAUDULENT'  THEN amount ELSE 0 END) AS fraud_amount

    FROM transactions
),

refunds AS (
    SELECT 
        SUM(refund_amount) AS refund_amount
    FROM refunds   -- separate table (important)
)

SELECT
    -- 💰 Stage Values
    b.attempted_amount,
    b.success_amount,
    b.failed_amount,
    b.fraud_amount,
    r.refund_amount,

    -- 💰 Final Output
    (b.success_amount - r.refund_amount) AS net_revenue,

    -- 📊 Funnel Rates (relative to attempted)
    ROUND(100.0 * b.success_amount / b.attempted_amount, 2) AS success_rate,
    ROUND(100.0 * b.failed_amount / b.attempted_amount, 2) AS failure_rate,
    ROUND(100.0 * b.fraud_amount  / b.attempted_amount, 2) AS fraud_rate,

    -- 🔁 Post-success
    ROUND(100.0 * r.refund_amount / NULLIF(b.success_amount, 0), 2) AS refund_rate,

    -- 🏁 Final efficiency
    ROUND(
        100.0 * (b.success_amount - r.refund_amount) / b.attempted_amount,
    2) AS net_revenue_retention

FROM base b
CROSS JOIN refunds r;