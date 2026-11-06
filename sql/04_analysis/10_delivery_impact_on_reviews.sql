/* =========================================================
   Impact of Delivery Performance on Customer Reviews

   Purpose:
   - Compare customer satisfaction between on-time and
     late deliveries
   - Measure negative-review rates and score distribution
   - Analyze association only; results do not establish
     that late delivery caused the review outcome

   Scope:
   - Delivered orders with a review record
   ========================================================= */

WITH reviewed_deliveries AS (
    SELECT
        o.order_id,
        o.delivery_days,
        o.estimated_delivery_days,
        o.delivery_delay_days,
        o.is_late_delivery,

        r.review_score,
        r.response_hours,
        r.is_negative_review,
        r.has_comment,

        CASE
            WHEN o.is_late_delivery = TRUE
                THEN 'Late delivery'
            ELSE 'On-time delivery'
        END AS delivery_status,

        CASE
            WHEN o.is_late_delivery = TRUE THEN 2
            ELSE 1
        END AS delivery_status_order

    FROM analytics.fact_orders AS o

    INNER JOIN analytics.fact_reviews AS r
        ON o.order_id = r.order_id

    WHERE o.is_delivered = TRUE
),

delivery_review_summary AS (
    SELECT
        delivery_status,
        delivery_status_order,

        COUNT(*) AS reviewed_orders,

        AVG(review_score)
            AS average_review_score,

        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY review_score
        ) AS median_review_score,

        COUNT(*) FILTER (
            WHERE is_negative_review = TRUE
        ) AS negative_reviews,

        100.0 * COUNT(*) FILTER (
            WHERE is_negative_review = TRUE
        ) / NULLIF(COUNT(*), 0)
            AS negative_review_rate_pct,

        100.0 * COUNT(*) FILTER (
            WHERE review_score = 1
        ) / NULLIF(COUNT(*), 0)
            AS score_1_pct,

        100.0 * COUNT(*) FILTER (
            WHERE review_score = 2
        ) / NULLIF(COUNT(*), 0)
            AS score_2_pct,

        100.0 * COUNT(*) FILTER (
            WHERE review_score = 3
        ) / NULLIF(COUNT(*), 0)
            AS score_3_pct,

        100.0 * COUNT(*) FILTER (
            WHERE review_score = 4
        ) / NULLIF(COUNT(*), 0)
            AS score_4_pct,

        100.0 * COUNT(*) FILTER (
            WHERE review_score = 5
        ) / NULLIF(COUNT(*), 0)
            AS score_5_pct,

        100.0 * COUNT(*) FILTER (
            WHERE has_comment = TRUE
        ) / NULLIF(COUNT(*), 0)
            AS comment_rate_pct,

        AVG(response_hours)
            AS average_response_hours,

        AVG(delivery_days)
            AS average_delivery_days,

        AVG(estimated_delivery_days)
            AS average_estimated_delivery_days,

        AVG(delivery_delay_days)
            AS average_delivery_delay_days

    FROM reviewed_deliveries

    GROUP BY
        delivery_status,
        delivery_status_order
)

SELECT
    delivery_status,
    reviewed_orders,

    ROUND(
        average_review_score,
        2
    ) AS average_review_score,

    ROUND(
        median_review_score::numeric,
        2
    ) AS median_review_score,

    negative_reviews,

    ROUND(
        negative_review_rate_pct,
        2
    ) AS negative_review_rate_pct,

    ROUND(
        score_1_pct,
        2
    ) AS score_1_pct,

    ROUND(
        score_2_pct,
        2
    ) AS score_2_pct,

    ROUND(
        score_3_pct,
        2
    ) AS score_3_pct,

    ROUND(
        score_4_pct,
        2
    ) AS score_4_pct,

    ROUND(
        score_5_pct,
        2
    ) AS score_5_pct,

    ROUND(
        comment_rate_pct,
        2
    ) AS comment_rate_pct,

    ROUND(
        average_response_hours,
        2
    ) AS average_response_hours,

    ROUND(
        average_delivery_days,
        2
    ) AS average_delivery_days,

    ROUND(
        average_estimated_delivery_days,
        2
    ) AS average_estimated_delivery_days,

    ROUND(
        average_delivery_delay_days,
        2
    ) AS average_delivery_delay_days

FROM delivery_review_summary

ORDER BY
    delivery_status_order;