-- Section 35.3.4
-- Monthly Delivery Outcome Assignment
-- TRAIN only: 2019–2023

SELECT
    DATE_TRUNC(
        'month',
        order_purchase_timestamp
    )::date AS purchase_month,

    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE delivery_delay_days = -2
    ) AS early_orders,

    COUNT(*) FILTER (
        WHERE delivery_delay_days = 5
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delivery_delay_days = 5
        ) / NULLIF(COUNT(*), 0),
        4
    ) AS late_rate_pct

FROM analytics.fact_orders

WHERE order_purchase_timestamp >= TIMESTAMP '2019-01-01'
  AND order_purchase_timestamp < TIMESTAMP '2024-01-01'
  AND order_status = 'delivered'

GROUP BY
    DATE_TRUNC(
        'month',
        order_purchase_timestamp
    )

ORDER BY purchase_month;