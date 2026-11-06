-- Section 35.3.3
-- Stored Delivery Delay Distribution
-- TRAIN only

SELECT
    delivery_delay_days,
    is_late_delivery,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        4
    ) AS pct_of_train
FROM analytics.fact_orders
WHERE order_purchase_timestamp >= TIMESTAMP '2019-01-01'
  AND order_purchase_timestamp < TIMESTAMP '2024-01-01'
  AND order_status = 'delivered'
GROUP BY
    delivery_delay_days,
    is_late_delivery
ORDER BY
    order_count DESC,
    delivery_delay_days;