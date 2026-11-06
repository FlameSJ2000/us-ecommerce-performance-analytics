/*
============================================================
File: 05_validate_analytics_load.sql
Purpose:
  Validate row counts, financial measures, status flags,
  delivery metrics, and review outcomes after loading the
  analytics layer.

Database: us_ecommerce_analytics
============================================================
*/


/* =========================================================
   1. Create temporary validation report
   ========================================================= */

DROP TABLE IF EXISTS tmp_analytics_validation;

CREATE TEMP TABLE tmp_analytics_validation
(
    sort_order         INTEGER,
    validation_group   TEXT,
    validation_rule    TEXT,
    expected_value     TEXT,
    actual_value       TEXT,
    validation_status  TEXT
);


/* =========================================================
   2. Dimension and fact row counts
   ========================================================= */

WITH row_count_results AS
(
    SELECT
        101 AS sort_order,
        'dim_customers'::text AS table_name,
        (SELECT COUNT(*) FROM staging.customers)::bigint
            AS expected_rows,
        (SELECT COUNT(*) FROM analytics.dim_customers)::bigint
            AS actual_rows

    UNION ALL

    SELECT
        102,
        'dim_products',
        (SELECT COUNT(*) FROM staging.products)::bigint,
        (SELECT COUNT(*) FROM analytics.dim_products)::bigint

    UNION ALL

    SELECT
        103,
        'dim_sellers',
        (SELECT COUNT(*) FROM staging.sellers)::bigint,
        (SELECT COUNT(*) FROM analytics.dim_sellers)::bigint

    UNION ALL

    SELECT
        104,
        'dim_geography',
        (
            SELECT COUNT(DISTINCT zip_code_prefix)
            FROM staging.geolocation
        )::bigint,
        (
            SELECT COUNT(*)
            FROM analytics.dim_geography
        )::bigint

    UNION ALL

    SELECT
        105,
        'fact_orders',
        (SELECT COUNT(*) FROM staging.orders)::bigint,
        (SELECT COUNT(*) FROM analytics.fact_orders)::bigint

    UNION ALL

    SELECT
        106,
        'fact_order_items',
        (SELECT COUNT(*) FROM staging.order_items)::bigint,
        (
            SELECT COUNT(*)
            FROM analytics.fact_order_items
        )::bigint

    UNION ALL

    SELECT
        107,
        'fact_payments',
        (
            SELECT COUNT(*)
            FROM staging.order_payments
        )::bigint,
        (
            SELECT COUNT(*)
            FROM analytics.fact_payments
        )::bigint

    UNION ALL

    SELECT
        108,
        'fact_reviews',
        (
            SELECT COUNT(*)
            FROM staging.order_reviews
        )::bigint,
        (
            SELECT COUNT(*)
            FROM analytics.fact_reviews
        )::bigint
)
INSERT INTO tmp_analytics_validation
SELECT
    sort_order,
    'ROW COUNT',
    table_name || ' row count',
    expected_rows::text,
    actual_rows::text,
    CASE
        WHEN expected_rows = actual_rows THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM row_count_results;


/* =========================================================
   3. Validate financial identities inside fact_order_items
   ========================================================= */

WITH item_validation AS
(
    SELECT
        COUNT(*) FILTER
        (
            WHERE ABS(
                catalog_price
                - discount_amount
                - net_item_revenue
            ) > 0.01
        ) AS invalid_revenue_formula_rows,

        COUNT(*) FILTER
        (
            WHERE ABS(
                net_item_revenue
                - product_cost
                - merchandise_profit
            ) > 0.01
        ) AS invalid_profit_formula_rows,

        COUNT(*) FILTER
        (
            WHERE ABS(
                net_item_revenue
                + freight_charge
                - customer_item_payment
            ) > 0.01
        ) AS invalid_payment_formula_rows,

        COUNT(*) FILTER
        (
            WHERE
                (
                    discount_rate > 0
                    AND is_discounted = FALSE
                )
                OR
                (
                    discount_rate = 0
                    AND is_discounted = TRUE
                )
        ) AS invalid_discount_flag_rows

    FROM analytics.fact_order_items
)
INSERT INTO tmp_analytics_validation
SELECT
    201,
    'ITEM FINANCIAL FORMULA',
    'catalog price - discount = net item revenue',
    '0',
    invalid_revenue_formula_rows::text,
    CASE
        WHEN invalid_revenue_formula_rows = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM item_validation

UNION ALL

SELECT
    202,
    'ITEM FINANCIAL FORMULA',
    'net item revenue - cost = merchandise profit',
    '0',
    invalid_profit_formula_rows::text,
    CASE
        WHEN invalid_profit_formula_rows = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM item_validation

UNION ALL

SELECT
    203,
    'ITEM FINANCIAL FORMULA',
    'net item revenue + freight = customer payment',
    '0',
    invalid_payment_formula_rows::text,
    CASE
        WHEN invalid_payment_formula_rows = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM item_validation

UNION ALL

SELECT
    204,
    'ITEM FINANCIAL FORMULA',
    'discount flag agrees with discount rate',
    '0',
    invalid_discount_flag_rows::text,
    CASE
        WHEN invalid_discount_flag_rows = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM item_validation;


/* =========================================================
   4. Reaggregate item and payment facts to order grain
   ========================================================= */

DROP TABLE IF EXISTS tmp_analytics_item_totals;

CREATE TEMP TABLE tmp_analytics_item_totals AS
SELECT
    order_id,
    COUNT(*)::integer AS item_count,
    SUM(catalog_price) AS gross_merchandise_value,
    SUM(discount_amount) AS discount_amount,
    SUM(net_item_revenue) AS net_merchandise_revenue,
    SUM(freight_charge) AS freight_charge,
    SUM(customer_item_payment) AS item_customer_payment,
    SUM(product_cost) AS product_cost,
    SUM(merchandise_profit) AS merchandise_profit
FROM analytics.fact_order_items
GROUP BY
    order_id;

ANALYZE tmp_analytics_item_totals;


DROP TABLE IF EXISTS tmp_analytics_payment_totals;

CREATE TEMP TABLE tmp_analytics_payment_totals AS
SELECT
    order_id,
    COUNT(*)::integer AS payment_record_count,
    SUM(payment_value) AS payment_total
FROM analytics.fact_payments
GROUP BY
    order_id;

ANALYZE tmp_analytics_payment_totals;


/* =========================================================
   5. Compare item/payment aggregates with fact_orders
   ========================================================= */

WITH order_reconciliation AS
(
    SELECT
        COUNT(*) FILTER
        (
            WHERE f.item_count <> i.item_count
        ) AS invalid_item_count_orders,

        COUNT(*) FILTER
        (
            WHERE f.payment_record_count
                  <> p.payment_record_count
        ) AS invalid_payment_count_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.gross_merchandise_value
                - i.gross_merchandise_value
            ) > 0.01
        ) AS invalid_gmv_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.discount_amount
                - i.discount_amount
            ) > 0.01
        ) AS invalid_discount_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.net_merchandise_revenue
                - i.net_merchandise_revenue
            ) > 0.01
        ) AS invalid_revenue_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.freight_charge
                - i.freight_charge
            ) > 0.01
        ) AS invalid_freight_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.product_cost
                - i.product_cost
            ) > 0.01
        ) AS invalid_cost_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.merchandise_profit
                - i.merchandise_profit
            ) > 0.01
        ) AS invalid_profit_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                f.customer_payment
                - p.payment_total
            ) > 0.01
        ) AS invalid_payment_orders,

        COUNT(*) FILTER
        (
            WHERE ABS(
                i.item_customer_payment
                - p.payment_total
            ) > 0.01
        ) AS invalid_item_payment_orders

    FROM analytics.fact_orders AS f
    INNER JOIN tmp_analytics_item_totals AS i
        ON i.order_id = f.order_id
    INNER JOIN tmp_analytics_payment_totals AS p
        ON p.order_id = f.order_id
)
INSERT INTO tmp_analytics_validation
SELECT
    301,
    'ORDER RECONCILIATION',
    'order item count agrees with item fact',
    '0',
    invalid_item_count_orders::text,
    CASE
        WHEN invalid_item_count_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    302,
    'ORDER RECONCILIATION',
    'payment count agrees with payment fact',
    '0',
    invalid_payment_count_orders::text,
    CASE
        WHEN invalid_payment_count_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    303,
    'ORDER RECONCILIATION',
    'order GMV agrees with item fact',
    '0',
    invalid_gmv_orders::text,
    CASE
        WHEN invalid_gmv_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    304,
    'ORDER RECONCILIATION',
    'order discount agrees with item fact',
    '0',
    invalid_discount_orders::text,
    CASE
        WHEN invalid_discount_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    305,
    'ORDER RECONCILIATION',
    'order net revenue agrees with item fact',
    '0',
    invalid_revenue_orders::text,
    CASE
        WHEN invalid_revenue_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    306,
    'ORDER RECONCILIATION',
    'order freight agrees with item fact',
    '0',
    invalid_freight_orders::text,
    CASE
        WHEN invalid_freight_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    307,
    'ORDER RECONCILIATION',
    'order product cost agrees with item fact',
    '0',
    invalid_cost_orders::text,
    CASE
        WHEN invalid_cost_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    308,
    'ORDER RECONCILIATION',
    'order profit agrees with item fact',
    '0',
    invalid_profit_orders::text,
    CASE
        WHEN invalid_profit_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    309,
    'ORDER RECONCILIATION',
    'order customer payment agrees with payment fact',
    '0',
    invalid_payment_orders::text,
    CASE
        WHEN invalid_payment_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation

UNION ALL

SELECT
    310,
    'ORDER RECONCILIATION',
    'item revenue plus freight agrees with payment fact',
    '0',
    invalid_item_payment_orders::text,
    CASE
        WHEN invalid_item_payment_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM order_reconciliation;


/* =========================================================
   6. Validate order-status and delivery flags
   ========================================================= */

WITH flag_validation AS
(
    SELECT
        COUNT(*) FILTER
        (
            WHERE
                (
                    order_status = 'delivered'
                    AND (
                        is_delivered = FALSE
                        OR is_canceled = TRUE
                        OR is_realized_revenue = FALSE
                    )
                )
                OR
                (
                    order_status = 'canceled'
                    AND (
                        is_delivered = TRUE
                        OR is_canceled = FALSE
                        OR is_realized_revenue = TRUE
                    )
                )
        ) AS invalid_status_flag_rows,

        COUNT(*) FILTER
        (
            WHERE is_delivered = TRUE
              AND (
                    delivery_days IS NULL
                    OR delivery_delay_days IS NULL
                    OR is_late_delivery IS NULL
                  )
        ) AS delivered_orders_missing_delivery_metrics,

        COUNT(*) FILTER
        (
            WHERE is_canceled = TRUE
              AND (
                    delivery_days IS NOT NULL
                    OR delivery_delay_days IS NOT NULL
                    OR is_late_delivery IS NOT NULL
                  )
        ) AS canceled_orders_with_delivery_metrics,

        COUNT(*) FILTER
        (
            WHERE is_realized_revenue = TRUE
        ) AS realized_order_count,

        COUNT(*) FILTER
        (
            WHERE order_status = 'delivered'
        ) AS delivered_order_count

    FROM analytics.fact_orders
)
INSERT INTO tmp_analytics_validation
SELECT
    401,
    'ORDER FLAGS',
    'status flags agree with order status',
    '0',
    invalid_status_flag_rows::text,
    CASE
        WHEN invalid_status_flag_rows = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM flag_validation

UNION ALL

SELECT
    402,
    'ORDER FLAGS',
    'delivered orders missing delivery metrics',
    '0',
    delivered_orders_missing_delivery_metrics::text,
    CASE
        WHEN delivered_orders_missing_delivery_metrics = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM flag_validation

UNION ALL

SELECT
    403,
    'ORDER FLAGS',
    'canceled orders containing delivery metrics',
    '0',
    canceled_orders_with_delivery_metrics::text,
    CASE
        WHEN canceled_orders_with_delivery_metrics = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM flag_validation

UNION ALL

SELECT
    404,
    'ORDER FLAGS',
    'realized revenue count equals delivered count',
    delivered_order_count::text,
    realized_order_count::text,
    CASE
        WHEN realized_order_count = delivered_order_count
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM flag_validation;


/* =========================================================
   7. Validate review-derived fields
   ========================================================= */

WITH review_validation AS
(
    SELECT
        COUNT(*) FILTER
        (
            WHERE
                (
                    review_score <= 2
                    AND is_negative_review = FALSE
                )
                OR
                (
                    review_score > 2
                    AND is_negative_review = TRUE
                )
        ) AS invalid_negative_review_flags,

        COUNT(*) FILTER
        (
            WHERE response_hours < 0
        ) AS negative_response_time_rows,

        COUNT(*) FILTER
        (
            WHERE f.is_delivered = FALSE
        ) AS reviews_attached_to_undelivered_orders

    FROM analytics.fact_reviews AS r
    INNER JOIN analytics.fact_orders AS f
        ON f.order_id = r.order_id
)
INSERT INTO tmp_analytics_validation
SELECT
    501,
    'REVIEW VALIDATION',
    'negative-review flag agrees with score',
    '0',
    invalid_negative_review_flags::text,
    CASE
        WHEN invalid_negative_review_flags = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM review_validation

UNION ALL

SELECT
    502,
    'REVIEW VALIDATION',
    'reviews with negative response time',
    '0',
    negative_response_time_rows::text,
    CASE
        WHEN negative_response_time_rows = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM review_validation

UNION ALL

SELECT
    503,
    'REVIEW VALIDATION',
    'reviews attached to undelivered orders',
    '0',
    reviews_attached_to_undelivered_orders::text,
    CASE
        WHEN reviews_attached_to_undelivered_orders = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END
FROM review_validation;


/* =========================================================
   8. Final consolidated validation report
   ========================================================= */

SELECT
    validation_group,
    validation_rule,
    expected_value,
    actual_value,
    validation_status
FROM tmp_analytics_validation
ORDER BY
    sort_order;