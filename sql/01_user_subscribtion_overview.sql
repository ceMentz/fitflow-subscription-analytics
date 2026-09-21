-- =========================================================
-- 01 USER & SUBSCRIPTION OVERVIEW
-- =========================================================


-- 1. Total users
SELECT
    COUNT(*) AS total_users
FROM users;


-- 2. Users with at least one subscription
SELECT
    COUNT(DISTINCT user_id) AS subscribed_users
FROM subscriptions;


-- 3. Subscription conversion rate
SELECT
    COUNT(DISTINCT s.user_id) AS subscribed_users,
    COUNT(DISTINCT u.user_id) AS total_users,
    ROUND(
        COUNT(DISTINCT s.user_id) * 100.0
        / COUNT(DISTINCT u.user_id),
        2
    ) AS subscription_conversion_rate
FROM users u
LEFT JOIN subscriptions s
    ON u.user_id = s.user_id;


-- 4. Subscription plan distribution
SELECT
    plan_type,
    COUNT(*) AS subscriptions,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM subscriptions
GROUP BY plan_type
ORDER BY subscriptions DESC;


-- 5. Subscription status
SELECT
    status,
    COUNT(*) AS subscriptions,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM subscriptions
GROUP BY status
ORDER BY subscriptions DESC;


-- 6. Total revenue
SELECT
    ROUND(SUM(amount), 2) AS total_revenue
FROM payments
WHERE payment_status <> 'Paid';