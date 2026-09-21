-- TASK 6.7: Subscription Cohort Retention
-- Objective:
-- Measure how well subscription cohorts are retained over time.
--
-- Method:
-- Users are grouped into cohorts based on the month their subscription started.
-- Each subscription is expanded into the months during which it remained active.
-- Retention rate is calculated as the percentage of the original cohort
-- that is still active in each subsequent month.
--
-- Note:
-- Active subscriptions are evaluated up to 2026-12-31,
-- which represents the end of the available dataset.

WITH subscription_base AS (

    SELECT
        subscription_id,
        user_id,
        start_date,
        cancel_date,

        DATE_TRUNC('month', start_date)::date AS cohort_month,

        COALESCE(
            cancel_date,
            DATE '2026-12-31'
        ) AS subscription_end_date

    FROM subscriptions

),

cohort_sizes AS (

    SELECT
        cohort_month,
        COUNT(DISTINCT user_id) AS cohort_size

    FROM subscription_base

    GROUP BY cohort_month

),

subscription_months AS (

    SELECT
        sb.user_id,
        sb.cohort_month,

        GENERATE_SERIES(
            DATE_TRUNC('month', sb.start_date),
            DATE_TRUNC('month', sb.subscription_end_date),
            INTERVAL '1 month'
        )::date AS activity_month

    FROM subscription_base sb

),

cohort_activity AS (

    SELECT
        cohort_month,
        activity_month,

        (
            EXTRACT(YEAR FROM AGE(activity_month, cohort_month)) * 12
            +
            EXTRACT(MONTH FROM AGE(activity_month, cohort_month))
        )::int AS months_since_start,

        COUNT(DISTINCT user_id) AS retained_users

    FROM subscription_months

    GROUP BY
        cohort_month,
        activity_month

)

SELECT
    ca.cohort_month,
    ca.months_since_start,
    cs.cohort_size,
    ca.retained_users,

    ROUND(
        100.0 * ca.retained_users
        / NULLIF(cs.cohort_size, 0),
        2
    ) AS retention_rate

FROM cohort_activity ca

JOIN cohort_sizes cs
    ON ca.cohort_month = cs.cohort_month

ORDER BY
    ca.cohort_month,
    ca.months_since_start;

-- TASK 6.8: Cohort Retention Milestones
-- Objective:
-- Summarize retention at key lifecycle milestones
-- so cohorts can be compared more easily.

WITH subscription_base AS (

    SELECT
        subscription_id,
        user_id,
        start_date,
        cancel_date,
        DATE_TRUNC('month', start_date)::date AS cohort_month,
        COALESCE(cancel_date, DATE '2026-12-31') AS subscription_end_date

    FROM subscriptions

),

cohort_sizes AS (

    SELECT
        cohort_month,
        COUNT(DISTINCT user_id) AS cohort_size

    FROM subscription_base

    GROUP BY cohort_month

),

subscription_months AS (

    SELECT
        sb.user_id,
        sb.cohort_month,

        GENERATE_SERIES(
            DATE_TRUNC('month', sb.start_date),
            DATE_TRUNC('month', sb.subscription_end_date),
            INTERVAL '1 month'
        )::date AS activity_month

    FROM subscription_base sb

),

cohort_activity AS (

    SELECT
        cohort_month,

        (
            EXTRACT(YEAR FROM AGE(activity_month, cohort_month)) * 12
            +
            EXTRACT(MONTH FROM AGE(activity_month, cohort_month))
        )::int AS months_since_start,

        COUNT(DISTINCT user_id) AS retained_users

    FROM subscription_months

    GROUP BY
        cohort_month,
        activity_month

),

retention_rates AS (

    SELECT
        ca.cohort_month,
        ca.months_since_start,

        ROUND(
            100.0 * ca.retained_users
            / NULLIF(cs.cohort_size, 0),
            2
        ) AS retention_rate

    FROM cohort_activity ca

    JOIN cohort_sizes cs
        ON ca.cohort_month = cs.cohort_month
)

SELECT
    cohort_month,

    MAX(CASE WHEN months_since_start = 1 THEN retention_rate END) AS month_1_retention,
    MAX(CASE WHEN months_since_start = 3 THEN retention_rate END) AS month_3_retention,
    MAX(CASE WHEN months_since_start = 6 THEN retention_rate END) AS month_6_retention,
    MAX(CASE WHEN months_since_start = 12 THEN retention_rate END) AS month_12_retention

FROM retention_rates

GROUP BY cohort_month

ORDER BY cohort_month;
