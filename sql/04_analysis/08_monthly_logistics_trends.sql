/* =========================================================
   Monthly Logistics Trends

   Purpose:
   - Track delivery performance over time
   - Measure monthly changes in late-delivery rate
   - Exclude incomplete December 2025 from the final report
   ========================================================= */

WITH monthly_logistics AS (
    SELECT
        DATE_TRUNC(
            'month',
            order_purchase_timestamp
        )::date AS month_start,

        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE is_delivered = TRUE
        ) AS delivered_orders,

        COUNT(*) FILTER (
            WHERE is_canceled = TRUE
        ) AS canceled_orders,

        COUNT(*) FILTER (
            WHERE is_delivered = TRUE
              AND is_late_delivery = FALSE
        ) AS on_time_orders,

        COUNT(*) FILTER (
            WHERE is_delivered = TRUE
              AND is_late_delivery = TRUE
        ) AS late_orders,

        AVG(delivery_days) FILTER (
            WHERE is_delivered = TRUE
        ) AS average_delivery_days,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY delivery_days
        ) FILTER (
            WHERE is_delivered = TRUE
        ) AS median_delivery_days,

        PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY delivery_days
        ) FILTER (
            WHERE is_delivered = TRUE
        ) AS p90_delivery_days,

        AVG(estimated_delivery_days) FILTER (
            WHERE is_delivered = TRUE
        ) AS average_estimated_delivery_days,

        AVG(delivery_delay_days) FILTER (
            WHERE is_delivered = TRUE
        ) AS average_delivery_delay_days

    FROM analytics.fact_orders

    GROUP BY
        DATE_TRUNC(
            'month',
            order_purchase_timestamp
        )::date
),

monthly_metrics AS (
    SELECT
        month_start,
        total_orders,
        delivered_orders,
        canceled_orders,
        on_time_orders,
        late_orders,

        100.0 * canceled_orders
            / NULLIF(total_orders, 0)
            AS cancellation_rate_pct,

        100.0 * on_time_orders
            / NULLIF(delivered_orders, 0)
            AS on_time_delivery_rate_pct,

        100.0 * late_orders
            / NULLIF(delivered_orders, 0)
            AS late_delivery_rate_pct,

        average_delivery_days,
        median_delivery_days,
        p90_delivery_days,
        average_estimated_delivery_days,
        average_delivery_delay_days

    FROM monthly_logistics
),

monthly_with_lags AS (
    SELECT
        *,

        LAG(late_delivery_rate_pct) OVER (
            ORDER BY month_start
        ) AS previous_month_late_rate,

        LAG(average_delivery_days) OVER (
            ORDER BY month_start
        ) AS previous_month_delivery_days

    FROM monthly_metrics
)

SELECT
    TO_CHAR(month_start, 'YYYY-MM') AS year_month,
    EXTRACT(YEAR FROM month_start)::smallint AS calendar_year,
    EXTRACT(MONTH FROM month_start)::smallint AS calendar_month,

    total_orders,
    delivered_orders,
    canceled_orders,
    on_time_orders,
    late_orders,

    ROUND(cancellation_rate_pct, 2)
        AS cancellation_rate_pct,

    ROUND(on_time_delivery_rate_pct, 2)
        AS on_time_delivery_rate_pct,

    ROUND(late_delivery_rate_pct, 2)
        AS late_delivery_rate_pct,

    ROUND(
        late_delivery_rate_pct
        - previous_month_late_rate,
        2
    ) AS late_rate_mom_change_pp,

    ROUND(average_delivery_days, 2)
        AS average_delivery_days,

    ROUND(
        average_delivery_days
        - previous_month_delivery_days,
        2
    ) AS delivery_days_mom_change,

    ROUND(median_delivery_days::numeric, 2)
        AS median_delivery_days,

    ROUND(p90_delivery_days::numeric, 2)
        AS p90_delivery_days,

    ROUND(average_estimated_delivery_days, 2)
        AS average_estimated_delivery_days,

    ROUND(average_delivery_delay_days, 2)
        AS average_delivery_delay_days

FROM monthly_with_lags

WHERE month_start < DATE '2025-12-01'

ORDER BY
    month_start;