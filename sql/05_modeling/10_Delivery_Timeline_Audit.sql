-- Section 35.3.3
-- Actual vs Estimated Delivery Delay Audit
-- TRAIN only: 2019–2023

WITH train_orders AS (
    SELECT
        order_purchase_timestamp,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        delivery_days,
        estimated_delivery_days,
        delivery_delay_days,
        is_late_delivery
    FROM analytics.fact_orders
    WHERE order_purchase_timestamp >= TIMESTAMP '2019-01-01'
      AND order_purchase_timestamp < TIMESTAMP '2024-01-01'
      AND order_status = 'delivered'
),
audit AS (
    SELECT
        *,
        ROUND(
            (
                EXTRACT(EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )) / 86400.0
            )::numeric,
            4
        ) AS reconstructed_delay_days,

        (
            order_delivered_customer_date
            > order_estimated_delivery_date
        ) AS reconstructed_late
    FROM train_orders
)
SELECT
    COUNT(*) AS train_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
           OR order_estimated_delivery_date IS NULL
    ) AS missing_delivery_dates,

    COUNT(DISTINCT delivery_delay_days)
        AS distinct_stored_delay_values,

    COUNT(DISTINCT reconstructed_delay_days)
        AS distinct_reconstructed_delay_values,

    COUNT(*) FILTER (
        WHERE ABS(
            delivery_delay_days
            - reconstructed_delay_days
        ) > 0.0001
    ) AS delay_value_mismatches,

    COUNT(*) FILTER (
        WHERE is_late_delivery IS DISTINCT FROM reconstructed_late
    ) AS late_target_mismatches,

    MIN(delivery_delay_days) AS min_delay_days,
    MAX(delivery_delay_days) AS max_delay_days,

    COUNT(*) FILTER (
        WHERE is_late_delivery = TRUE
    ) AS late_orders,

    COUNT(*) FILTER (
        WHERE is_late_delivery = FALSE
    ) AS on_time_orders
FROM audit;