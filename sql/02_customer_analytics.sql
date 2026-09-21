-- =========================================================
-- 02 CUSTOMER ANALYTICS
-- =========================================================

-- Users with events
SELECT
    COUNT(DISTINCT user_id) AS users_with_activity
FROM events;

-- Users with sessions
SELECT
    COUNT(DISTINCT user_id) AS users_with_sessions
FROM sessions;

-- Users with succesful payments

SELECT
    COUNT(DISTINCT user_id) AS users_with_payments
FROM payments
WHERE payment_status <> 'Failed';

-- 4. User engagement segmentation

WITH user_events AS (
    SELECT
        user_id,
        COUNT(*) AS event_count
    FROM events
    GROUP BY user_id
),

segmented_users AS (
    SELECT
        user_id,
        event_count,
        CASE
            WHEN event_count < 20 THEN 'Low'
            WHEN event_count < 50 THEN 'Medium'
            ELSE 'High'
        END AS engagement_segment
    FROM user_events
)

SELECT
    engagement_segment,
    COUNT(*) AS users,
    ROUND(AVG(event_count), 2) AS avg_events
FROM segmented_users
GROUP BY engagement_segment
ORDER BY
    CASE engagement_segment
        WHEN 'Low' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'High' THEN 3
    END;

-- 5. Engagement segment vs subscription conversion

WITH user_events AS (
    SELECT
        user_id,
        COUNT(*) AS event_count
    FROM events
    GROUP BY user_id
),

segmented_users AS (
    SELECT
        user_id,
        event_count,
        CASE
            WHEN event_count < 20 THEN 'Low'
            WHEN event_count < 50 THEN 'Medium'
            ELSE 'High'
        END AS engagement_segment
    FROM user_events
),

subscription_users AS (
    SELECT DISTINCT
        user_id
    FROM subscriptions
)

SELECT
    su.engagement_segment,
    COUNT(*) AS users,
    COUNT(su2.user_id) AS subscribers,
    ROUND(
        COUNT(su2.user_id) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate
FROM segmented_users su
LEFT JOIN subscription_users su2
    ON su.user_id = su2.user_id
GROUP BY su.engagement_segment
ORDER BY
    CASE su.engagement_segment
        WHEN 'Low' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'High' THEN 3
    END;

-- 6. Pre-subscription engagement

WITH first_subscription AS (
    SELECT
        user_id,
        MIN(start_date) AS subscription_date
    FROM subscriptions
    GROUP BY user_id
),

pre_subscription_events AS (
    SELECT
        e.user_id,
        COUNT(*) AS events_before_subscription
    FROM events e
    JOIN first_subscription s
        ON e.user_id = s.user_id
    WHERE e.event_date < s.subscription_date
    GROUP BY e.user_id
)

SELECT
    COUNT(*) AS subscribers_with_pre_subscription_activity,

    ROUND(
        AVG(events_before_subscription)::numeric,
        2
    ) AS avg_events_before_subscription,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY events_before_subscription
        )::numeric,
        2
    ) AS median_events_before_subscription

FROM pre_subscription_events;

-- 7. Early engagement vs subscription conversion

WITH user_activity AS (
    SELECT
        u.user_id,
        CASE
            WHEN s.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS converted,

        COUNT(e.event_id) AS events_first_30_days

    FROM users u

    LEFT JOIN subscriptions s
        ON u.user_id = s.user_id

    LEFT JOIN events e
        ON u.user_id = e.user_id
        AND e.event_date >= u.signup_date 
        AND e.event_date < u.signup_date + INTERVAL '30 days'

    GROUP BY
        u.user_id,
        CASE
            WHEN s.user_id IS NOT NULL THEN 1
            ELSE 0
        END
)

SELECT
    CASE
        WHEN converted = 1 THEN 'Subscriber'
        ELSE 'Non-subscriber'
    END AS user_type,

    COUNT(*) AS users,

    ROUND(
        AVG(events_first_30_days)::numeric,
        2
    ) AS avg_events_first_30_days,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY events_first_30_days
        )::numeric,
        2
    ) AS median_events_first_30_days

FROM user_activity

GROUP BY converted

ORDER BY converted DESC;

-- 8. Early engagement buckets vs conversion

WITH user_activity AS (
    SELECT
        u.user_id,

        CASE
            WHEN s.user_id IS NOT NULL THEN 1
            ELSE 0
        END AS converted,

        COUNT(e.event_id) AS events_first_30_days

    FROM users u

    LEFT JOIN subscriptions s
        ON u.user_id = s.user_id

    LEFT JOIN events e
        ON u.user_id = e.user_id
        AND e.event_date >= u.signup_date 
        AND e.event_date < u.signup_date + INTERVAL '30 days'

    GROUP BY
        u.user_id,
        CASE
            WHEN s.user_id IS NOT NULL THEN 1
            ELSE 0
        END
),

engagement_buckets AS (
    SELECT
        user_id,
        converted,

        CASE
            WHEN events_first_30_days = 0 THEN '0 events'
            WHEN events_first_30_days BETWEEN 1 AND 2 THEN '1-2 events'
            WHEN events_first_30_days BETWEEN 3 AND 5 THEN '3-5 events'
            WHEN events_first_30_days BETWEEN 6 AND 10 THEN '6-10 events'
            ELSE '11+ events'
        END AS engagement_bucket

    FROM user_activity
)

SELECT
    engagement_bucket,
    COUNT(*) AS users,
    SUM(converted) AS subscribers,

    ROUND(
        SUM(converted) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate

FROM engagement_buckets

GROUP BY engagement_bucket

ORDER BY
    CASE engagement_bucket
        WHEN '0 events' THEN 1
        WHEN '1-2 events' THEN 2
        WHEN '3-5 events' THEN 3
        WHEN '6-10 events' THEN 4
        WHEN '11+ events' THEN 5
    END;

-- 9. Every user first 30 days session count

SELECT
    u.user_id,
    COUNT(s.user_id) AS sessions_first_30_days
FROM users u
LEFT JOIN sessions s
    ON u.user_id = s.user_id
    AND s.session_date >= u.signup_date 
    AND s.session_date < u.signup_date + INTERVAL '30 days'
GROUP BY u.user_id
ORDER BY u.user_id;

-- 10. SESSION ENGAGEMENT VS SUBSCRIPTION CONVERSION
WITH subscriber_status AS (

    SELECT
        user_id,
        1 AS converted

    FROM subscriptions

    GROUP BY user_id

),

user_activity AS (

    SELECT
        u.user_id,

        COALESCE(ss.converted, 0) AS converted,

        COUNT(sess.user_id) AS sessions_first_30_days

    FROM users u

    LEFT JOIN subscriber_status ss
        ON u.user_id = ss.user_id

    LEFT JOIN sessions sess
        ON u.user_id = sess.user_id
        AND sess.session_date >= u.signup_date
        AND sess.session_date < u.signup_date + INTERVAL '30 days'

    GROUP BY
        u.user_id,
        ss.converted

),

session_buckets AS (

    SELECT
        user_id,
        converted,

        CASE
            WHEN sessions_first_30_days = 0
                THEN '0 sessions'

            WHEN sessions_first_30_days BETWEEN 1 AND 2
                THEN '1-2 sessions'

            WHEN sessions_first_30_days BETWEEN 3 AND 5
                THEN '3-5 sessions'

            WHEN sessions_first_30_days BETWEEN 6 AND 10
                THEN '6-10 sessions'

            ELSE '11+ sessions'

        END AS session_bucket

    FROM user_activity

)

SELECT
    session_bucket,

    COUNT(*) AS users,

    SUM(converted) AS subscribers,

    ROUND(
        SUM(converted) * 100.0 / COUNT(*),
        2
    ) AS conversion_rate

FROM session_buckets

GROUP BY session_bucket

ORDER BY
    CASE session_bucket
        WHEN '0 sessions' THEN 1
        WHEN '1-2 sessions' THEN 2
        WHEN '3-5 sessions' THEN 3
        WHEN '6-10 sessions' THEN 4
        WHEN '11+ sessions' THEN 5
    END;

-- 11. Session Engagement Quality Analysis

WITH user_sessions AS (
    SELECT
        u.user_id,

        COUNT(sess.user_id) AS sessions_first_30_days,

        COALESCE(AVG(sess.duration_minutes ), 0) AS avg_session_duration,

        COALESCE(SUM(sess.duration_minutes), 0) AS total_session_minutes

    FROM users u

    LEFT JOIN sessions sess
        ON u.user_id = sess.user_id
        AND sess.session_date >= u.signup_date
        AND sess.session_date < u.signup_date + INTERVAL '30 days'

    GROUP BY
        u.user_id
)

SELECT
    user_id,
    sessions_first_30_days,
    avg_session_duration,
    total_session_minutes

FROM user_sessions

ORDER BY user_id;

-- 12. Session Duration by Engagement Bucket

WITH user_sessions AS (
    SELECT
        u.user_id,

        COUNT(sess.user_id) AS sessions_first_30_days,

        COALESCE(AVG(sess.duration_minutes ), 0) AS avg_session_duration,

        COALESCE(SUM(sess.duration_minutes), 0) AS total_session_minutes

    FROM users u

    LEFT JOIN sessions sess
        ON u.user_id = sess.user_id
        AND sess.session_date >= u.signup_date
        AND sess.session_date < u.signup_date + INTERVAL '30 days'

    GROUP BY
        u.user_id
),

session_buckets AS (
    SELECT
        user_id,
        sessions_first_30_days,
        avg_session_duration,
        total_session_minutes,

        CASE
            WHEN sessions_first_30_days = 0 THEN '0 sessions'
            WHEN sessions_first_30_days BETWEEN 1 AND 2 THEN '1-2 sessions'
            WHEN sessions_first_30_days BETWEEN 3 AND 5 THEN '3-5 sessions'
            WHEN sessions_first_30_days BETWEEN 6 AND 10 THEN '6-10 sessions'
            ELSE '11+ sessions'
        END AS session_bucket

    FROM user_sessions
)

SELECT
    session_bucket,

    COUNT(*) AS users,

    ROUND(AVG(sessions_first_30_days),2) AS avg_sessions,

    ROUND(AVG(avg_session_duration), 2) AS avg_session_duration,

    ROUND(AVG(total_session_minutes),2) AS avg_total_session_minutes

FROM session_buckets

GROUP BY
    session_bucket

ORDER BY
    CASE session_bucket
        WHEN '0 sessions' THEN 1
        WHEN '1-2 sessions' THEN 2
        WHEN '3-5 sessions' THEN 3
        WHEN '6-10 sessions' THEN 4
        WHEN '11+ sessions' THEN 5
    END;

