/* =========================================================
   Seller Delivery and Satisfaction Risk

   Grain:
   - One row per order-seller combination before aggregation

   Important:
   - Delivery and review outcomes exist at order level
   - For multi-seller orders, the same outcome is associated
     with every participating seller
   - Results show association, not sole seller responsibility
   ========================================================= */

WITH order_sellers AS (
    SELECT
        i.order_id,
        i.seller_id,

        COUNT(*) AS items_sold,

        SUM(i.freight_charge)
            AS freight_charged

    FROM analytics.fact_order_items AS i

    WHERE i.is_realized_revenue = TRUE

    GROUP BY
        i.order_id,
        i.seller_id
),

seller_order_outcomes AS (
    SELECT
        os.order_id,
        os.seller_id,
        os.items_sold,
        os.freight_charged,

        s.seller_company_name,
        s.seller_state,

        o.is_late_delivery,
        o.delivery_days,
        o.delivery_delay_days,

        r.review_score,
        r.is_negative_review

    FROM order_sellers AS os

    INNER JOIN analytics.dim_sellers AS s
        ON os.seller_id = s.seller_id

    INNER JOIN analytics.fact_orders AS o
        ON os.order_id = o.order_id

    INNER JOIN analytics.fact_reviews AS r
        ON os.order_id = r.order_id

    WHERE o.is_delivered = TRUE
),

seller_summary AS (
    SELECT
        seller_id,
        seller_company_name,
        seller_state,

        COUNT(*) AS order_seller_routes,

        COUNT(DISTINCT order_id)
            AS distinct_orders,

        SUM(items_sold)
            AS items_sold,

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

        AVG(delivery_days)
            AS average_delivery_days,

        AVG(delivery_delay_days)
            AS average_delivery_delay_days,

        AVG(freight_charged)
            AS average_freight_per_order_route

    FROM seller_order_outcomes

    GROUP BY
        seller_id,
        seller_company_name,
        seller_state

    HAVING COUNT(*) >= 500
)

SELECT
    RANK() OVER (
        ORDER BY negative_review_rate_pct DESC
    ) AS seller_risk_rank,

    seller_id,
    seller_company_name,
    seller_state,
    distinct_orders,
    items_sold,

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
        average_delivery_days,
        2
    ) AS average_delivery_days,

    ROUND(
        average_delivery_delay_days,
        2
    ) AS average_delivery_delay_days,

    ROUND(
        average_freight_per_order_route,
        2
    ) AS average_freight_per_order_route

FROM seller_summary

ORDER BY
    negative_review_rate_pct DESC,
    distinct_orders DESC,
    seller_id

LIMIT 25;