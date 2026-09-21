-- TASK 7.1: A/B Test Conversion Rate by Variant
-- Objective:
-- Compare subscription conversion rates between experiment variants.
--
-- Conversion definition:
-- A user is considered converted if they started a subscription
-- within 30 days after being assigned to an experiment variant.
--
-- Notes:
-- - Subscriptions started before the experiment assignment are ignored.
-- - EXISTS is used to avoid counting users multiple times
--   if they have more than one subscription record.

WITH experiment_users AS (

    SELECT
        experiment_id,
        user_id,
        experiment_name,
        variant,
        assigned_date
    FROM experiments

),

conversion_flag AS (

    SELECT
        e.experiment_id,
        e.user_id,
        e.experiment_name,
        e.variant,
        e.assigned_date,

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

    FROM experiment_users e

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
    variant

ORDER BY
    experiment_name,
    variant;

-- TASK 7.2: A/B Test Uplift
-- Objective:
-- Compare Variant_A performance against the Control group
-- and calculate absolute and relative conversion uplift.

WITH experiment_users AS (

    SELECT
        experiment_id,
        user_id,
        experiment_name,
        variant,
        assigned_date
    FROM experiments

),

conversion_flag AS (

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

    FROM experiment_users e

),

variant_results AS (

    SELECT
        experiment_name,
        variant,
        COUNT(DISTINCT user_id) AS assigned_users,
        COUNT(DISTINCT CASE
            WHEN converted = 1 THEN user_id
        END) AS converted_users

    FROM conversion_flag

    GROUP BY
        experiment_name,
        variant
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
)

SELECT
    experiment_name,

    control_users,
    control_converted,

    ROUND(
        100.0 * control_converted
        / NULLIF(control_users, 0),
        2
    ) AS control_conversion_rate,

    variant_users,
    variant_converted,

    ROUND(
        100.0 * variant_converted
        / NULLIF(variant_users, 0),
        2
    ) AS variant_conversion_rate,

    -- Absolute uplift in percentage points.
    ROUND(
        100.0 * (
            variant_converted::numeric / NULLIF(variant_users, 0)
            -
            control_converted::numeric / NULLIF(control_users, 0)
        ),
        2
    ) AS absolute_uplift_pp,

    -- Relative uplift compared with the Control conversion rate.
    ROUND(
        100.0 * (
            (
                variant_converted::numeric / NULLIF(variant_users, 0)
            )
            /
            NULLIF(
                control_converted::numeric / NULLIF(control_users, 0),
                0
            )
            - 1
        ),
        2
    ) AS relative_uplift_pct

FROM comparison;

-- TASK 7.3: A/B Test Statistical Significance
-- Objective:
-- Test whether the difference in subscription conversion rates
-- between Control and Variant_A is statistically significant.
--
-- Method:
-- Two-proportion z-test using a 95% confidence level.
-- If the absolute z-score is >= 1.96, the difference is considered
-- statistically significant at alpha = 0.05.

WITH experiment_users AS (

    SELECT
        experiment_id,
        user_id,
        experiment_name,
        variant,
        assigned_date
    FROM experiments
),

conversion_flag AS (

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

    FROM experiment_users e
),

variant_results AS (

    SELECT
        experiment_name,
        variant,
        COUNT(DISTINCT user_id) AS assigned_users,
        COUNT(DISTINCT CASE
            WHEN converted = 1 THEN user_id
        END) AS converted_users

    FROM conversion_flag

    GROUP BY
        experiment_name,
        variant
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
        experiment_name,
        control_users,
        control_converted,
        variant_users,
        variant_converted,

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

    ROUND(control_rate * 100, 2) AS control_conversion_rate,
    ROUND(variant_rate * 100, 2) AS variant_conversion_rate,

    ROUND(rate_difference * 100, 2) AS difference_percentage_points,

    ROUND(z_score, 3) AS z_score,

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