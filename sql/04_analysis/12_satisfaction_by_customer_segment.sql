/* =========================================================
   Customer Satisfaction by Customer Segment

   Purpose:
   - Compare satisfaction across customer segments
   - Separate dissatisfaction associated with late delivery
     from negative reviews among on-time orders

   Grain:
   - One row per reviewed delivered order
   ========================================================= */

WITH segment_reviews AS (
    SELECT
        o.order_id,

        COALESCE(
            c.customer_segment,
            'Unknown'
        ) AS customer_segment,

        o.is_late_delivery,
        o.delivery_days,
        o.delivery_delay_days,

        r.review_score,
        r.is_negative_review

    FROM analytics.fact_orders AS o

    INNER JOIN analytics.dim_customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN analytics.fact_reviews AS r
        ON o.order_id = r.order_id

    WHERE o.is_delivered = TRUE
),

segment_summary AS (
    SELECT
        customer_segment,

        COUNT(*) AS reviewed_orders,

        AVG(review_score)
            AS average_review_score,

        COUNT(*) FILTER (
            WHERE is_negative_review = TRUE
        ) AS negative_reviews,

        100.0 * COUNT(*) FILTER (
            WHERE is_negative_review = TRUE
        ) / NULLIF(COUNT(*), 0)
            AS negative_review_rate_pct,

        COUNT(*) FILTER (
            WHERE is_late_delivery = TRUE
        ) AS late_deliveries,

        100.0 * COUNT(*) FILTER (
            WHERE is_late_delivery = TRUE
        ) / NULLIF(COUNT(*), 0)
            AS late_delivery_rate_pct,

        100.0 * COUNT(*) FILTER (
            WHERE is_late_delivery = FALSE
              AND is_negative_review = TRUE
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE is_late_delivery = FALSE
            ),
            0
        ) AS on_time_negative_review_rate_pct,

        100.0 * COUNT(*) FILTER (
            WHERE is_late_delivery = TRUE
              AND is_negative_review = TRUE
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE is_late_delivery = TRUE
            ),
            0
        ) AS late_negative_review_rate_pct,

        AVG(delivery_days)
            AS average_delivery_days,

        AVG(delivery_delay_days)
            AS average_delivery_delay_days

    FROM segment_reviews

    GROUP BY
        customer_segment
)

SELECT
    RANK() OVER (
        ORDER BY negative_review_rate_pct DESC
    ) AS negative_review_rank,

    customer_segment,
    reviewed_orders,

    ROUND(
        average_review_score,
        2
    ) AS average_review_score,

    negative_reviews,

    ROUND(
        negative_review_rate_pct,
        2
    ) AS negative_review_rate_pct,

    late_deliveries,

    ROUND(
        late_delivery_rate_pct,
        2
    ) AS late_delivery_rate_pct,

    ROUND(
        on_time_negative_review_rate_pct,
        2
    ) AS on_time_negative_review_rate_pct,

    ROUND(
        late_negative_review_rate_pct,
        2
    ) AS late_negative_review_rate_pct,

    ROUND(
        average_delivery_days,
        2
    ) AS average_delivery_days,

    ROUND(
        average_delivery_delay_days,
        2
    ) AS average_delivery_delay_days

FROM segment_summary

ORDER BY
    negative_review_rate_pct DESC,
    customer_segment;