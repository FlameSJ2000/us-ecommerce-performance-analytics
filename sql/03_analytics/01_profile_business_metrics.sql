/*
============================================================
File: 01_profile_business_metrics.sql
Purpose:
  Establish evidence-based definitions for revenue, cost,
  profit, freight, discounts, and payment reconciliation
  before building the analytics layer.

Database: us_ecommerce_analytics
Source schema: staging
============================================================
*/

SET search_path TO staging, public;


/* =========================================================
   1. Aggregate item-level financial values to order grain
   ========================================================= */

DROP TABLE IF EXISTS tmp_order_item_totals;

CREATE TEMP TABLE tmp_order_item_totals AS
SELECT
    oi.order_id,
    COUNT(*) AS item_count,
    SUM(oi.price) AS item_price_total,
    SUM(oi.freight_value) AS freight_total,
    SUM(oi.price + oi.freight_value) AS item_plus_freight_total,
    SUM(p.cost) AS product_cost_total
FROM staging.order_items AS oi
INNER JOIN staging.products AS p
    ON p.product_id = oi.product_id
GROUP BY
    oi.order_id;

ANALYZE tmp_order_item_totals;


/* =========================================================
   2. Aggregate payments to order grain

   An order may have multiple payment rows, so payment_value
   must be summed before comparing it with item totals.
   ========================================================= */

DROP TABLE IF EXISTS tmp_order_payment_totals;

CREATE TEMP TABLE tmp_order_payment_totals AS
SELECT
    op.order_id,
    COUNT(*) AS payment_record_count,
    SUM(op.payment_value) AS payment_total
FROM staging.order_payments AS op
GROUP BY
    op.order_id;

ANALYZE tmp_order_payment_totals;


/* =========================================================
   3. Build a temporary order-level reconciliation table
   ========================================================= */

DROP TABLE IF EXISTS tmp_order_financial_profile;

CREATE TEMP TABLE tmp_order_financial_profile AS
SELECT
    o.order_id,
    o.order_status,

    COALESCE(i.item_count, 0) AS item_count,
    COALESCE(i.item_price_total, 0::numeric) AS item_price_total,
    COALESCE(i.freight_total, 0::numeric) AS freight_total,
    COALESCE(
        i.item_plus_freight_total,
        0::numeric
    ) AS item_plus_freight_total,
    COALESCE(i.product_cost_total, 0::numeric) AS product_cost_total,

    COALESCE(p.payment_record_count, 0) AS payment_record_count,
    COALESCE(p.payment_total, 0::numeric) AS payment_total,

    p.payment_total - i.item_price_total
        AS payment_minus_item_price,

    p.payment_total - i.item_plus_freight_total
        AS payment_minus_item_and_freight

FROM staging.orders AS o
LEFT JOIN tmp_order_item_totals AS i
    ON i.order_id = o.order_id
LEFT JOIN tmp_order_payment_totals AS p
    ON p.order_id = o.order_id;

ANALYZE tmp_order_financial_profile;


/* =========================================================
   4. Create one consolidated profiling report
   ========================================================= */

DROP TABLE IF EXISTS tmp_business_metric_report;

CREATE TEMP TABLE tmp_business_metric_report
(
    sort_order       INTEGER,
    metric_group     TEXT,
    metric_name      TEXT,
    metric_value     TEXT,
    interpretation   TEXT
);


/* ---------------------------------------------------------
   A. Order-status distribution
   --------------------------------------------------------- */

INSERT INTO tmp_business_metric_report
SELECT
    100 + ROW_NUMBER() OVER (ORDER BY order_status)::integer,
    'ORDER STATUS',
    order_status,
    COUNT(*)::text,
    ROUND(
        100.0 * COUNT(*)
        / NULLIF(SUM(COUNT(*)) OVER (), 0),
        2
    )::text || '% of all orders'
FROM staging.orders
GROUP BY
    order_status;


/* ---------------------------------------------------------
   B. Transaction price versus product catalog price

   Classification priority:
   1. Discounted formula match when discount_rate > 0
   2. Direct product-price match
   3. Neither formula
   --------------------------------------------------------- */

WITH price_classification AS
(
    SELECT
        oi.order_id,
        oi.order_item_id,
        oi.price AS transaction_price,
        oi.discount_rate,
        p.price AS product_catalog_price,
        p.cost AS product_cost,

        CASE
            WHEN oi.discount_rate > 0
             AND ABS(
                    oi.price
                    - (
                        p.price
                        * (1::numeric - oi.discount_rate)
                      )
                 ) <= 0.01
                THEN 'DISCOUNTED PRODUCT PRICE'

            WHEN ABS(oi.price - p.price) <= 0.01
                THEN 'PRODUCT CATALOG PRICE'

            ELSE 'NEITHER PRICE FORMULA'
        END AS price_classification

    FROM staging.order_items AS oi
    INNER JOIN staging.products AS p
        ON p.product_id = oi.product_id
),
price_summary AS
(
    SELECT
        COUNT(*) AS total_item_rows,

        COUNT(*) FILTER (
            WHERE discount_rate > 0
        ) AS positive_discount_rows,

        COUNT(*) FILTER (
            WHERE price_classification =
                  'DISCOUNTED PRODUCT PRICE'
        ) AS discounted_formula_rows,

        COUNT(*) FILTER (
            WHERE price_classification =
                  'PRODUCT CATALOG PRICE'
        ) AS catalog_price_rows,

        COUNT(*) FILTER (
            WHERE price_classification =
                  'NEITHER PRICE FORMULA'
        ) AS neither_formula_rows,

        COUNT(*) FILTER (
            WHERE transaction_price < product_cost
        ) AS price_below_cost_rows,

        ROUND(
            AVG(ABS(transaction_price - product_catalog_price)),
            2
        ) AS average_catalog_price_difference

    FROM price_classification
)
INSERT INTO tmp_business_metric_report
SELECT
    201,
    'ITEM PRICE',
    'Total order-item rows',
    total_item_rows::text,
    'Population used for price profiling'
FROM price_summary

UNION ALL

SELECT
    202,
    'ITEM PRICE',
    'Rows with discount_rate greater than zero',
    positive_discount_rows::text,
    ROUND(
        100.0 * positive_discount_rows
        / NULLIF(total_item_rows, 0),
        2
    )::text || '% of item rows'
FROM price_summary

UNION ALL

SELECT
    203,
    'ITEM PRICE',
    'Transaction price matches discounted product price',
    discounted_formula_rows::text,
    ROUND(
        100.0 * discounted_formula_rows
        / NULLIF(total_item_rows, 0),
        2
    )::text || '% of item rows'
FROM price_summary

UNION ALL

SELECT
    204,
    'ITEM PRICE',
    'Transaction price matches product catalog price',
    catalog_price_rows::text,
    ROUND(
        100.0 * catalog_price_rows
        / NULLIF(total_item_rows, 0),
        2
    )::text || '% of item rows'
FROM price_summary

UNION ALL

SELECT
    205,
    'ITEM PRICE',
    'Transaction price matches neither formula',
    neither_formula_rows::text,
    ROUND(
        100.0 * neither_formula_rows
        / NULLIF(total_item_rows, 0),
        2
    )::text || '% of item rows'
FROM price_summary

UNION ALL

SELECT
    206,
    'ITEM PRICE',
    'Transaction price below product cost',
    price_below_cost_rows::text,
    ROUND(
        100.0 * price_below_cost_rows
        / NULLIF(total_item_rows, 0),
        2
    )::text || '% of item rows'
FROM price_summary

UNION ALL

SELECT
    207,
    'ITEM PRICE',
    'Average absolute difference from product price',
    average_catalog_price_difference::text,
    'Transaction price compared with products.price'
FROM price_summary;


/* ---------------------------------------------------------
   C. Payment reconciliation

   Tolerance: one cent per order.
   --------------------------------------------------------- */

WITH reconciliation_summary AS
(
    SELECT
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE item_count > 0
              AND payment_record_count > 0
        ) AS comparable_orders,

        COUNT(*) FILTER (
            WHERE item_count > 0
              AND payment_record_count > 0
              AND ABS(payment_minus_item_and_freight) <= 0.01
        ) AS item_freight_match_orders,

        COUNT(*) FILTER (
            WHERE item_count > 0
              AND payment_record_count > 0
              AND ABS(payment_minus_item_price) <= 0.01
        ) AS item_only_match_orders,

        COUNT(*) FILTER (
            WHERE item_count > 0
              AND payment_record_count > 0
              AND ABS(payment_minus_item_and_freight) > 0.01
        ) AS unreconciled_orders,

        COUNT(*) FILTER (
            WHERE item_count = 0
        ) AS orders_without_items,

        COUNT(*) FILTER (
            WHERE payment_record_count = 0
        ) AS orders_without_payments,

        ROUND(
            AVG(
                ABS(payment_minus_item_and_freight)
            ) FILTER (
                WHERE item_count > 0
                  AND payment_record_count > 0
            ),
            2
        ) AS average_absolute_reconciliation_difference

    FROM tmp_order_financial_profile
)
INSERT INTO tmp_business_metric_report
SELECT
    301,
    'PAYMENT RECONCILIATION',
    'Orders with both items and payments',
    comparable_orders::text,
    ROUND(
        100.0 * comparable_orders
        / NULLIF(total_orders, 0),
        2
    )::text || '% of all orders'
FROM reconciliation_summary

UNION ALL

SELECT
    302,
    'PAYMENT RECONCILIATION',
    'Payment matches item price plus freight',
    item_freight_match_orders::text,
    ROUND(
        100.0 * item_freight_match_orders
        / NULLIF(comparable_orders, 0),
        2
    )::text || '% of comparable orders'
FROM reconciliation_summary

UNION ALL

SELECT
    303,
    'PAYMENT RECONCILIATION',
    'Payment matches item price without freight',
    item_only_match_orders::text,
    ROUND(
        100.0 * item_only_match_orders
        / NULLIF(comparable_orders, 0),
        2
    )::text || '% of comparable orders'
FROM reconciliation_summary

UNION ALL

SELECT
    304,
    'PAYMENT RECONCILIATION',
    'Payment does not match item price plus freight',
    unreconciled_orders::text,
    ROUND(
        100.0 * unreconciled_orders
        / NULLIF(comparable_orders, 0),
        2
    )::text || '% of comparable orders'
FROM reconciliation_summary

UNION ALL

SELECT
    305,
    'PAYMENT RECONCILIATION',
    'Orders without item records',
    orders_without_items::text,
    'Potential exclusion or data-quality condition'
FROM reconciliation_summary

UNION ALL

SELECT
    306,
    'PAYMENT RECONCILIATION',
    'Orders without payment records',
    orders_without_payments::text,
    'Potential exclusion or data-quality condition'
FROM reconciliation_summary

UNION ALL

SELECT
    307,
    'PAYMENT RECONCILIATION',
    'Average absolute payment reconciliation difference',
    average_absolute_reconciliation_difference::text,
    'ABS(payment - item price - freight)'
FROM reconciliation_summary;


/* ---------------------------------------------------------
   D. Canceled-order financial records
   --------------------------------------------------------- */

WITH canceled_summary AS
(
    SELECT
        COUNT(*) AS canceled_orders,

        COUNT(*) FILTER (
            WHERE item_count > 0
        ) AS canceled_orders_with_items,

        COUNT(*) FILTER (
            WHERE payment_record_count > 0
        ) AS canceled_orders_with_payments,

        ROUND(SUM(item_price_total), 2)
            AS canceled_item_price_total,

        ROUND(SUM(freight_total), 2)
            AS canceled_freight_total,

        ROUND(SUM(payment_total), 2)
            AS canceled_payment_total

    FROM tmp_order_financial_profile
    WHERE LOWER(BTRIM(order_status)) = 'canceled'
)
INSERT INTO tmp_business_metric_report
SELECT
    401,
    'CANCELED ORDERS',
    'Total canceled orders',
    canceled_orders::text,
    'Candidate population to exclude from completed revenue'
FROM canceled_summary

UNION ALL

SELECT
    402,
    'CANCELED ORDERS',
    'Canceled orders with item records',
    canceled_orders_with_items::text,
    'Shows whether canceled orders contain item value'
FROM canceled_summary

UNION ALL

SELECT
    403,
    'CANCELED ORDERS',
    'Canceled orders with payment records',
    canceled_orders_with_payments::text,
    'Shows whether canceled orders contain payment value'
FROM canceled_summary

UNION ALL

SELECT
    404,
    'CANCELED ORDERS',
    'Canceled item-price total',
    canceled_item_price_total::text,
    'Do not classify as completed revenue yet'
FROM canceled_summary

UNION ALL

SELECT
    405,
    'CANCELED ORDERS',
    'Canceled freight total',
    canceled_freight_total::text,
    'Do not classify as completed freight yet'
FROM canceled_summary

UNION ALL

SELECT
    406,
    'CANCELED ORDERS',
    'Canceled payment total',
    canceled_payment_total::text,
    'Requires status-based business decision'
FROM canceled_summary;


/* =========================================================
   5. Display the consolidated report
   ========================================================= */

SELECT
    metric_group,
    metric_name,
    metric_value,
    interpretation
FROM tmp_business_metric_report
ORDER BY
    sort_order;