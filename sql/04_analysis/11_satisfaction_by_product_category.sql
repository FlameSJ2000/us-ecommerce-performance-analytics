/* =========================================================
   Customer Satisfaction by Product Category

   Grain:
   - One row per order-category exposure before aggregation
   - An order containing multiple categories can appear in
     more than one category

   Purpose:
   - Compare review outcomes across product categories
   - Separate on-time negative reviews from late-delivery
     negative reviews
   ========================================================= */

WITH order_categories AS (
    SELECT DISTINCT
        i.order_id,

        p.product_category_name
            AS product_category

    FROM analytics.fact_order_items AS i

    INNER JOIN analytics.dim_products AS p
        ON i.product_id = p.product_id

    WHERE i.is_realized_revenue = TRUE
),

category_reviews AS (
    SELECT
        oc.order_id,
        oc.product_category,

        o.is_late_delivery,
        o.delivery_days,

        r.review_score,
        r.is_negative_review

    FROM order_categories AS oc

    INNER JOIN analytics.fact_orders AS o
        ON oc.order_id = o.order_id

    INNER JOIN analytics.fact_reviews AS r
        ON oc.order_id = r.order_id

    WHERE o.is_delivered = TRUE
),

category_summary AS (
    SELECT
        product_category,

        COUNT(*) AS reviewed_order_category_records,

        COUNT(DISTINCT order_id)
            AS distinct_reviewed_orders,

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
            AS average_delivery_days

    FROM category_reviews

    GROUP BY
        product_category
)

SELECT
    RANK() OVER (
        ORDER BY negative_review_rate_pct DESC
    ) AS negative_review_rank,

    product_category,
    reviewed_order_category_records,
    distinct_reviewed_orders,

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
    ) AS average_delivery_days

FROM category_summary

ORDER BY
    negative_review_rate_pct DESC,
    product_category;