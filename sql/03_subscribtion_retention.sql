-- ============================================================
-- SUBSCRIBTION RETENTION ANALYSIS
-- ============================================================
-- Project: Subscribtion Analytics
-- Database: PostgreSQL
--
-- Objective:
-- Analyse subscribtion duration, retention and cancellation
-- patterns across different user segments and subscribtion plans.
-- ============================================================

-- TASK Subscribtion Duration Analysis
-- Calculate how many days each subscribtion lasted.
-- For active subscribtions, use the end of the analysis period.

SELECT
    subscription_id,
    user_id,
    plan_type,
    start_date,
    status,
    cancel_date,
    monthly_price,
    trial_used,

    CASE
        WHEN cancel_date IS NOT NULL
            THEN cancel_date - start_date
        ELSE
            DATE '2026-12-31' - start_date
    END AS subscription_duration_days

FROM subscriptions

ORDER BY subscription_id;

-- TASK Subscription Duration by Plan and Status
-- Compare subscription duration across plans and subscription status.

WITH subscription_duration AS (

    SELECT
        subscription_id,
        user_id,
        plan_type,
        status,

        CASE
            WHEN cancel_date IS NOT NULL
                THEN cancel_date - start_date
            ELSE
                DATE '2026-12-31' - start_date
        END AS duration_days

    FROM subscriptions
)

SELECT
    plan_type,
    status,
    COUNT(*) AS subscriptions,
    ROUND(AVG(duration_days), 2) AS avg_duration_days,
    MIN(duration_days) AS min_duration_days,
    MAX(duration_days) AS max_duration_days

FROM subscription_duration

GROUP BY
    plan_type,
    status

ORDER BY
    plan_type,
    status;

-- TASK Cancellation Rate by Subscription Plan
-- Compare the proportion of cancelled subscriptions across plans.

SELECT
    plan_type,

    COUNT(*) AS total_subscriptions,

    COUNT(*) FILTER (
        WHERE status = 'Cancelled'
    ) AS cancelled_subscriptions,

    ROUND(
        COUNT(*) FILTER (
            WHERE status = 'Cancelled'
        ) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate

FROM subscriptions

GROUP BY
    plan_type

ORDER BY
    cancellation_rate DESC;

-- TASK Trial Usage vs Cancellation
-- Compare cancellation rates between users who used a trial
-- and users who did not use a trial.

SELECT
    trial_used,

    COUNT(*) AS subscriptions,

    COUNT(*) FILTER (
        WHERE status = 'Cancelled'
    ) AS cancelled_subscriptions,

    ROUND(
        COUNT(*) FILTER (
            WHERE status = 'Cancelled'
        ) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate

FROM subscriptions

GROUP BY
    trial_used

ORDER BY
    trial_used;

-- TASK Engagement vs Cancellation
-- Analyze the relationship between user engagement during the first 30 days
-- and subsequent subscription cancellation rates.

WITH user_engagement AS (
    SELECT
        u.user_id,
        COUNT(s.session_id) AS sessions_first_30_days
    FROM users u
    LEFT JOIN sessions s
        ON u.user_id = s.user_id
        AND s.session_date >= u.signup_date
        AND s.session_date < u.signup_date + INTERVAL '30 days'
    GROUP BY u.user_id
),

user_subscription AS (
    SELECT
        u.user_id,
        ue.sessions_first_30_days,
        sub.subscription_id,
        sub.plan_type,
        sub.status,
        sub.start_date,
        sub.cancel_date,
        CASE
            WHEN sub.status = 'cancelled'
              OR sub.cancel_date IS NOT NULL
            THEN 1
            ELSE 0
        END AS cancelled
    FROM users u
    JOIN user_engagement ue
        ON u.user_id = ue.user_id
    JOIN subscriptions sub
        ON u.user_id = sub.user_id
),

engagement_buckets AS (
    SELECT
        *,
        CASE
            WHEN sessions_first_30_days = 0 THEN '0 sessions'
            WHEN sessions_first_30_days BETWEEN 1 AND 2 THEN '1-2 sessions'
            WHEN sessions_first_30_days BETWEEN 3 AND 5 THEN '3-5 sessions'
            WHEN sessions_first_30_days BETWEEN 6 AND 10 THEN '6-10 sessions'
            ELSE '11+ sessions'
        END AS engagement_group
    FROM user_subscription
)

SELECT
    engagement_group,
    COUNT(DISTINCT user_id) AS users,
    COUNT(DISTINCT CASE WHEN cancelled = 1 THEN user_id END) AS cancelled_users,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN cancelled = 1 THEN user_id END)
        / NULLIF(COUNT(DISTINCT user_id), 0),
        2
    ) AS cancellation_rate
FROM engagement_buckets
GROUP BY engagement_group
ORDER BY
    MIN(sessions_first_30_days);

