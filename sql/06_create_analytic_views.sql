-- VIEW: Cohort Retention
-- Purpose:
-- Prepare monthly subscription cohort retention data
-- for reporting and visualization in Power BI.

CREATE OR REPLACE VIEW vw_cohort_retention AS

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
    ON ca.cohort_month = cs.cohort_month;

-- VIEW: A/B Test Results by Variant
-- Purpose:
-- Prepare experiment conversion metrics for Power BI.

CREATE OR REPLACE VIEW public.vw_ab_test_results AS

WITH conversion_flag AS (

    SELECT
        e.experiment_id,
        e.user_id,
        e.experiment_name,
        e.variant,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM subscriptions s
                WHERE s.user_id = e.user_id
                  AND s.start_date >= e.assigned_date
                  AND s.start_date < e.assigned_date + INTERVAL '30 days'
            )
            THEN 1
            ELSE 0
        END AS converted

    FROM experiments e
)

SELECT
    experiment_name,
    variant,

    COUNT(DISTINCT user_id) AS assigned_users,

    COUNT(DISTINCT CASE
        WHEN converted = 1 THEN user_id
    END) AS converted_users,

    ROUND(
        100.0
        * COUNT(DISTINCT CASE
            WHEN converted = 1 THEN user_id
        END)
        / NULLIF(COUNT(DISTINCT user_id), 0),
        2
    ) AS conversion_rate

FROM conversion_flag

GROUP BY
    experiment_name,
    variant;
-- VIEW: A/B Test Summary
-- Purpose:
-- Prepare uplift and statistical significance results
-- for reporting in Power BI.

CREATE OR REPLACE VIEW public.vw_ab_test_summary AS

WITH variant_results AS (

    SELECT *
    FROM public.vw_ab_test_results
),

comparison AS (

    SELECT
        experiment_name,

        MAX(CASE
            WHEN variant = 'Control'
            THEN assigned_users
        END) AS control_users,

        MAX(CASE
            WHEN variant = 'Control'
            THEN converted_users
        END) AS control_converted,

        MAX(CASE
            WHEN variant = 'Variant_A'
            THEN assigned_users
        END) AS variant_users,

        MAX(CASE
            WHEN variant = 'Variant_A'
            THEN converted_users
        END) AS variant_converted

    FROM variant_results

    GROUP BY experiment_name
),

rates AS (

    SELECT
        *,

        control_converted::numeric
            / NULLIF(control_users, 0) AS control_rate,

        variant_converted::numeric
            / NULLIF(variant_users, 0) AS variant_rate,

        (control_converted + variant_converted)::numeric
            / NULLIF(control_users + variant_users, 0) AS pooled_rate

    FROM comparison
),

test_statistics AS (

    SELECT
        *,

        variant_rate - control_rate AS rate_difference,

        SQRT(
            pooled_rate
            * (1 - pooled_rate)
            * (
                1.0 / control_users
                + 1.0 / variant_users
            )
        ) AS pooled_standard_error,

        SQRT(
            control_rate * (1 - control_rate) / control_users
            +
            variant_rate * (1 - variant_rate) / variant_users
        ) AS difference_standard_error

    FROM rates
),

z_test AS (

    SELECT
        *,

        rate_difference
            / NULLIF(pooled_standard_error, 0) AS z_score

    FROM test_statistics
)

SELECT
    experiment_name,

    ROUND(control_rate * 100, 2)
        AS control_conversion_rate,

    ROUND(variant_rate * 100, 2)
        AS variant_conversion_rate,

    ROUND(rate_difference * 100, 2)
        AS absolute_uplift_pp,

    ROUND(
        ((variant_rate / NULLIF(control_rate, 0)) - 1) * 100,
        2
    ) AS relative_uplift_pct,

    ROUND(z_score, 3)
        AS z_score,

    ROUND(
        (rate_difference - 1.96 * difference_standard_error) * 100,
        2
    ) AS ci_95_lower_pp,

    ROUND(
        (rate_difference + 1.96 * difference_standard_error) * 100,
        2
    ) AS ci_95_upper_pp,

    CASE
        WHEN ABS(z_score) >= 1.96
            THEN 'Statistically significant'
        ELSE 'Not statistically significant'
    END AS significance_result

FROM z_test;
