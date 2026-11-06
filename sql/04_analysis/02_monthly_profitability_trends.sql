/*
============================================================
File: 02_monthly_profitability_trends.sql
Analysis:
  Monthly revenue, profit, margin, discount, freight,
  customer, and growth trends.

Population:
  Delivered orders only (is_realized_revenue = TRUE)

Customer definition:
  customer_unique_id represents an actual customer across
  multiple orders.
============================================================
*/

WITH monthly_base AS
(
    SELECT
        DATE_TRUNC(
            'month',
            d.full_date
        )::date AS month_start,

        d.calendar_year,
        d.calendar_month,
        d.year_month,

        COUNT(*) AS delivered_orders,

        COUNT(
            DISTINCT c.customer_unique_id
        ) AS unique_customers,

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

    INNER JOIN analytics.dim_date AS d
        ON d.date_key = f.purchase_date_key

    INNER JOIN analytics.dim_customers AS c
        ON c.customer_id = f.customer_id

    WHERE f.is_realized_revenue = TRUE

    GROUP BY
        DATE_TRUNC('month', d.full_date)::date,
        d.calendar_year,
        d.calendar_month,
        d.year_month
),
monthly_with_lags AS
(
    SELECT
        *,

        LAG(net_merchandise_revenue) OVER
        (
            ORDER BY month_start
        ) AS previous_month_revenue,

        LAG(merchandise_profit) OVER
        (
            ORDER BY month_start
        ) AS previous_month_profit,

        LAG(delivered_orders) OVER
        (
            ORDER BY month_start
        ) AS previous_month_orders

    FROM monthly_base
)

SELECT
    year_month,
    calendar_year,
    calendar_month,

    delivered_orders,
    unique_customers,
    items_sold,

    ROUND(net_merchandise_revenue, 2)
        AS net_merchandise_revenue,

    ROUND(
        100.0
        * (
            net_merchandise_revenue
            - previous_month_revenue
          )
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS revenue_mom_growth_pct,

    ROUND(merchandise_profit, 2)
        AS merchandise_profit,

    ROUND(
        100.0
        * (
            merchandise_profit
            - previous_month_profit
          )
        / NULLIF(previous_month_profit, 0),
        2
    ) AS profit_mom_growth_pct,

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

    ROUND(total_discount, 2)
        AS total_discount,

    ROUND(
        100.0 * total_discount
        / NULLIF(gross_merchandise_value, 0),
        2
    ) AS discount_rate_pct,

    ROUND(freight_charged, 2)
        AS freight_charged,

    ROUND(
        100.0 * freight_charged
        / NULLIF(customer_payment, 0),
        2
    ) AS freight_share_of_payment_pct,

    ROUND(
        100.0
        * (
            delivered_orders
            - previous_month_orders
          )
        / NULLIF(previous_month_orders, 0),
        2
    ) AS orders_mom_growth_pct

FROM monthly_with_lags
WHERE month_start < DATE '2025-12-01'
ORDER BY
    month_start;

	/* =========================================================
   Validation: Check whether the date range covers full months
   ========================================================= */


SELECT
    MIN(order_purchase_timestamp)::date AS first_order_date,
    MAX(order_purchase_timestamp)::date AS last_order_date,
    COUNT(DISTINCT DATE_TRUNC('month', order_purchase_timestamp))
        AS month_count
FROM staging.orders
WHERE order_status = 'delivered';