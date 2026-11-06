/* =========================================================
   Product Profitability Ranking and Concentration

   Population:
   - Delivered orders only
   - Merchandise profit excludes freight
   ========================================================= */

WITH product_summary AS (
    SELECT
        i.product_id,

        COALESCE(
            p.product_category_name,
            'Unknown'
        ) AS product_category,

        COUNT(DISTINCT i.order_id) AS delivered_orders,
        COUNT(*) AS items_sold,

        SUM(i.catalog_price) AS gross_merchandise_value,
        SUM(i.discount_amount) AS total_discount,
        SUM(i.net_item_revenue) AS net_merchandise_revenue,
        SUM(i.product_cost) AS product_cost,
        SUM(i.merchandise_profit) AS merchandise_profit

    FROM analytics.fact_order_items AS i

    INNER JOIN analytics.dim_products AS p
        ON p.product_id = i.product_id

    WHERE i.is_realized_revenue = TRUE

    GROUP BY
        i.product_id,
        COALESCE(
            p.product_category_name,
            'Unknown'
        )
),

product_metrics AS (
    SELECT
        product_id,
        product_category,
        delivered_orders,
        items_sold,
        gross_merchandise_value,
        total_discount,
        net_merchandise_revenue,
        product_cost,
        merchandise_profit,

        100.0 * total_discount
            / NULLIF(gross_merchandise_value, 0)
            AS discount_rate_pct,

        100.0 * merchandise_profit
            / NULLIF(net_merchandise_revenue, 0)
            AS merchandise_margin_pct,

        100.0 * net_merchandise_revenue
            / NULLIF(
                SUM(net_merchandise_revenue) OVER (),
                0
            ) AS revenue_share_pct,

        100.0 * merchandise_profit
            / NULLIF(
                SUM(merchandise_profit) OVER (),
                0
            ) AS profit_share_pct,

        100.0 * SUM(merchandise_profit) OVER (
            ORDER BY merchandise_profit DESC, product_id
            ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
        )
        / NULLIF(
            SUM(merchandise_profit) OVER (),
            0
        ) AS cumulative_profit_share_pct

    FROM product_summary
)

SELECT
    ROW_NUMBER() OVER (
        ORDER BY merchandise_profit DESC, product_id
    ) AS profit_rank,

    product_id,
    product_category,
    delivered_orders,
    items_sold,

    ROUND(gross_merchandise_value, 2)
        AS gross_merchandise_value,

    ROUND(total_discount, 2)
        AS total_discount,

    ROUND(discount_rate_pct, 2)
        AS discount_rate_pct,

    ROUND(net_merchandise_revenue, 2)
        AS net_merchandise_revenue,

    ROUND(product_cost, 2)
        AS product_cost,

    ROUND(merchandise_profit, 2)
        AS merchandise_profit,

    ROUND(merchandise_margin_pct, 2)
        AS merchandise_margin_pct,

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

    ROUND(revenue_share_pct, 4)
        AS revenue_share_pct,

    ROUND(profit_share_pct, 4)
        AS profit_share_pct,

    ROUND(cumulative_profit_share_pct, 2)
        AS cumulative_profit_share_pct,

    CASE
        WHEN cumulative_profit_share_pct <= 80
            THEN 'Top profit contributors'
        ELSE 'Remaining products'
    END AS profit_contribution_segment

FROM product_metrics

ORDER BY
    merchandise_profit DESC,
    product_id;