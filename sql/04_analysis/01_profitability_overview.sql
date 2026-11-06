/*
============================================================
File: 01_profitability_overview.sql
Analysis:
  Overall realized profitability and revenue performance.

Population:
  Delivered orders only (is_realized_revenue = TRUE)

Important:
  Freight charge is not included in merchandise profit
  because actual shipping cost is unavailable.
============================================================
*/

WITH realized_performance AS
(
    SELECT
        COUNT(*) AS delivered_orders,

        COUNT(DISTINCT c.customer_unique_id)
            AS unique_customers,

        SUM(f.item_count) AS items_sold,

        SUM(f.gross_merchandise_value)
            AS gross_merchandise_value,

        SUM(f.discount_amount)
            AS total_discount,

        SUM(f.net_merchandise_revenue)
            AS net_merchandise_revenue,

        SUM(f.freight_charge)
            AS freight_charged,

        SUM(f.customer_payment)
            AS customer_payment,

        SUM(f.product_cost)
            AS product_cost,

        SUM(f.merchandise_profit)
            AS merchandise_profit

    FROM analytics.fact_orders AS f
    INNER JOIN analytics.dim_customers AS c
        ON c.customer_id = f.customer_id

    WHERE f.is_realized_revenue = TRUE
)

SELECT
    delivered_orders,
    unique_customers,
    items_sold,

    ROUND(gross_merchandise_value, 2)
        AS gross_merchandise_value,

    ROUND(total_discount, 2)
        AS total_discount,

    ROUND(
        100.0 * total_discount
        / NULLIF(gross_merchandise_value, 0),
        2
    ) AS overall_discount_rate_pct,

    ROUND(net_merchandise_revenue, 2)
        AS net_merchandise_revenue,

    ROUND(freight_charged, 2)
        AS freight_charged,

    ROUND(customer_payment, 2)
        AS customer_payment,

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
        / NULLIF(delivered_orders, 0),
        2
    ) AS average_order_value,

    ROUND(
        customer_payment
        / NULLIF(delivered_orders, 0),
        2
    ) AS average_customer_payment,

    ROUND(
        items_sold::numeric
        / NULLIF(delivered_orders, 0),
        2
    ) AS average_items_per_order,

    ROUND(
        freight_charged
        / NULLIF(delivered_orders, 0),
        2
    ) AS average_freight_per_order,

    ROUND(
        100.0 * freight_charged
        / NULLIF(customer_payment, 0),
        2
    ) AS freight_share_of_payment_pct

FROM realized_performance;