/* =========================================================
   Logistics Performance by Customer State

   Purpose:
   - Compare delivery speed and reliability across states
   - Identify states with high late-delivery rates
   - Include only delivered orders
   ========================================================= */

WITH state_logistics AS (
    SELECT
        c.customer_state,

        COUNT(*) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE f.is_late_delivery = FALSE
        ) AS on_time_orders,

        COUNT(*) FILTER (
            WHERE f.is_late_delivery = TRUE
        ) AS late_orders,

        AVG(f.approval_hours) AS average_approval_hours,
        AVG(f.carrier_dispatch_days) AS average_carrier_dispatch_days,
        AVG(f.delivery_days) AS average_delivery_days,
        AVG(f.estimated_delivery_days) AS average_estimated_delivery_days,
        AVG(f.delivery_delay_days) AS average_delivery_delay_days,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY f.delivery_days
        ) AS median_delivery_days,

        PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY f.delivery_days
        ) AS p90_delivery_days

    FROM analytics.fact_orders AS f

    INNER JOIN analytics.dim_customers AS c
        ON f.customer_id = c.customer_id

    WHERE f.is_delivered = TRUE

    GROUP BY
        c.customer_state
),

state_metrics AS (
    SELECT
        customer_state,
        delivered_orders,
        on_time_orders,
        late_orders,

        100.0 * on_time_orders
            / NULLIF(delivered_orders, 0)
            AS on_time_delivery_rate_pct,

        100.0 * late_orders
            / NULLIF(delivered_orders, 0)
            AS late_delivery_rate_pct,

        average_approval_hours,
        average_carrier_dispatch_days,
        average_delivery_days,
        median_delivery_days,
        p90_delivery_days,
        average_estimated_delivery_days,
        average_delivery_delay_days

    FROM state_logistics
)

SELECT
    RANK() OVER (
        ORDER BY late_delivery_rate_pct DESC
    ) AS late_delivery_rank,

    customer_state,
    delivered_orders,
    on_time_orders,
    late_orders,

    ROUND(on_time_delivery_rate_pct, 2)
        AS on_time_delivery_rate_pct,

    ROUND(late_delivery_rate_pct, 2)
        AS late_delivery_rate_pct,

    ROUND(average_approval_hours, 2)
        AS average_approval_hours,

    ROUND(average_carrier_dispatch_days, 2)
        AS average_carrier_dispatch_days,

    ROUND(average_delivery_days, 2)
        AS average_delivery_days,

    ROUND(median_delivery_days::numeric, 2)
        AS median_delivery_days,

    ROUND(p90_delivery_days::numeric, 2)
        AS p90_delivery_days,

    ROUND(average_estimated_delivery_days, 2)
        AS average_estimated_delivery_days,

    ROUND(average_delivery_delay_days, 2)
        AS average_delivery_delay_days

FROM state_metrics

ORDER BY
    late_delivery_rate_pct DESC,
    delivered_orders DESC,
    customer_state;