/* =========================================================
   Logistics Performance Overview

   Definitions:
   - Late delivery: actual delivery occurred after estimated date
   - Negative delivery_delay_days means delivered early
   - Positive delivery_delay_days means delivered late
   ========================================================= */

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE is_canceled = TRUE
    ) AS cancelled_orders,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
          AND is_late_delivery = FALSE
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
          AND is_late_delivery = TRUE
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_delivered = TRUE
              AND is_late_delivery = FALSE
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE is_delivered = TRUE
            ),
            0
        ),
        2
    ) AS on_time_delivery_rate_pct,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_delivered = TRUE
              AND is_late_delivery = TRUE
        )
        / NULLIF(
            COUNT(*) FILTER (
                WHERE is_delivered = TRUE
            ),
            0
        ),
        2
    ) AS late_delivery_rate_pct,

    ROUND(
        AVG(approval_hours) FILTER (
            WHERE is_delivered = TRUE
        ),
        2
    ) AS average_approval_hours,

    ROUND(
        AVG(carrier_dispatch_days) FILTER (
            WHERE is_delivered = TRUE
        ),
        2
    ) AS average_carrier_dispatch_days,

    ROUND(
        AVG(delivery_days) FILTER (
            WHERE is_delivered = TRUE
        ),
        2
    ) AS average_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY delivery_days
        ) FILTER (
            WHERE is_delivered = TRUE
        )::numeric,
        2
    ) AS median_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY delivery_days
        ) FILTER (
            WHERE is_delivered = TRUE
        )::numeric,
        2
    ) AS p90_delivery_days,

    ROUND(
        AVG(estimated_delivery_days) FILTER (
            WHERE is_delivered = TRUE
        ),
        2
    ) AS average_estimated_delivery_days,

    ROUND(
        AVG(delivery_delay_days) FILTER (
            WHERE is_delivered = TRUE
        ),
        2
    ) AS average_delivery_delay_days,

    ROUND(
        AVG(-delivery_delay_days) FILTER (
            WHERE is_delivered = TRUE
              AND delivery_delay_days < 0
        ),
        2
    ) AS average_days_early,

    ROUND(
        AVG(delivery_delay_days) FILTER (
            WHERE is_delivered = TRUE
              AND delivery_delay_days > 0
        ),
        2
    ) AS average_days_late,

    ROUND(
        MAX(delivery_delay_days) FILTER (
            WHERE is_delivered = TRUE
        ),
        2
    ) AS maximum_days_late,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
          AND (
              delivery_days IS NULL
              OR estimated_delivery_days IS NULL
              OR delivery_delay_days IS NULL
          )
    ) AS delivered_orders_missing_metrics

FROM analytics.fact_orders;