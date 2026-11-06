/* =========================================================
   Profitability by Product Category

   Business definitions:
   - Includes delivered orders only
   - Net revenue excludes freight
   - Merchandise profit = net revenue - product cost
   ========================================================= */

WITH category_summary AS (
    SELECT
        COALESCE(
            p.product_category_name,
            'Unknown'
        ) AS product_category,

        COUNT(DISTINCT i.product_id) AS product_count,
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
        COALESCE(
            p.product_category_name,
            'Unknown'
        )
),

category_metrics AS (
    SELECT
        product_category,
        product_count,
        delivered_orders,
        items_sold,

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

    FROM category_summary
)

SELECT
    DENSE_RANK() OVER (
        ORDER BY merchandise_profit DESC
    ) AS profit_rank,

    product_category,
    product_count,
    delivered_orders,
    items_sold,
    gross_merchandise_value,
    total_discount,
    discount_rate_pct,
    net_merchandise_revenue,
    product_cost,
    merchandise_profit,
    merchandise_margin_pct,
    average_item_revenue,
    revenue_share_pct,
    profit_share_pct

FROM category_metrics

ORDER BY
    merchandise_profit DESC,
    product_category;