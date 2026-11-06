/* =========================================================
   Discount Impact on Profitability

   Comparison:
   - Discounted items
   - Full-price items

   Population:
   - Delivered orders only
   ========================================================= */

WITH discount_summary AS (
    SELECT
        CASE
            WHEN discount_amount > 0
                THEN 'Discounted'
            ELSE 'Full price'
        END AS discount_group,

        COUNT(*) AS items_sold,
        COUNT(DISTINCT order_id) AS delivered_orders,

        SUM(catalog_price) AS gross_merchandise_value,
        SUM(discount_amount) AS total_discount,
        SUM(net_item_revenue) AS net_merchandise_revenue,
        SUM(product_cost) AS product_cost,
        SUM(merchandise_profit) AS merchandise_profit

    FROM analytics.fact_order_items

    WHERE is_realized_revenue = TRUE

    GROUP BY
        CASE
            WHEN discount_amount > 0
                THEN 'Discounted'
            ELSE 'Full price'
        END
)

SELECT
    discount_group,
    items_sold,
    delivered_orders,

    ROUND(
        100.0 * items_sold
        / SUM(items_sold) OVER (),
        2
    ) AS item_share_pct,

    ROUND(gross_merchandise_value, 2)
        AS gross_merchandise_value,

    ROUND(total_discount, 2)
        AS total_discount,

    ROUND(
        100.0 * total_discount
        / NULLIF(gross_merchandise_value, 0),
        2
    ) AS discount_rate_pct,

    ROUND(net_merchandise_revenue, 2)
        AS net_merchandise_revenue,

    ROUND(product_cost, 2)
        AS product_cost,

    ROUND(merchandise_profit, 2)
        AS merchandise_profit,

    ROUND(
        100.0 * merchandise_profit
        / NULLIF(net_merchandise_revenue, 0),
        2
    ) AS merchandise_margin_pct,

    ROUND(
        net_merchandise_revenue
        / NULLIF(items_sold, 0),
        2
    ) AS average_item_revenue,

    ROUND(
        merchandise_profit
        / NULLIF(items_sold, 0),
        2
    ) AS average_profit_per_item,

    ROUND(
        100.0 * net_merchandise_revenue
        / NULLIF(
            SUM(net_merchandise_revenue) OVER (),
            0
        ),
        2
    ) AS revenue_share_pct,

    ROUND(
        100.0 * merchandise_profit
        / NULLIF(
            SUM(merchandise_profit) OVER (),
            0
        ),
        2
    ) AS profit_share_pct

FROM discount_summary

ORDER BY
    CASE
        WHEN discount_group = 'Discounted' THEN 1
        ELSE 2
    END;