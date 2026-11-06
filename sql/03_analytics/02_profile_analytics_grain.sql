/*
============================================================
File: 02_profile_analytics_grain.sql
Purpose:
  Validate table grain and relationship cardinality before
  creating analytics fact tables and dimensions.

Database: us_ecommerce_analytics
Source schema: staging
============================================================
*/

SET search_path TO staging, public;

WITH grain_results AS
(
    /* 1. Orders */
    SELECT
        1 AS sort_order,
        'orders'::text AS table_name,
        'order_id'::text AS tested_grain,
        COUNT(*)::bigint AS total_rows,
        COUNT(DISTINCT order_id)::bigint AS distinct_grain_keys,
        (
            COUNT(*) - COUNT(DISTINCT order_id)
        )::bigint AS duplicate_rows,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT order_id)
                THEN 'PASS'
            ELSE 'REVIEW'
        END::text AS validation_status
    FROM staging.orders

    UNION ALL

    /* 2. Order items */
    SELECT
        2,
        'order_items',
        '(order_id, order_item_id)',
        COUNT(*)::bigint,
        COUNT(
            DISTINCT (order_id, order_item_id)
        )::bigint,
        (
            COUNT(*)
            - COUNT(DISTINCT (order_id, order_item_id))
        )::bigint,
        CASE
            WHEN COUNT(*) =
                 COUNT(DISTINCT (order_id, order_item_id))
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.order_items

    UNION ALL

    /* 3. Payments */
    SELECT
        3,
        'order_payments',
        '(order_id, payment_sequential)',
        COUNT(*)::bigint,
        COUNT(
            DISTINCT (order_id, payment_sequential)
        )::bigint,
        (
            COUNT(*)
            - COUNT(
                DISTINCT (order_id, payment_sequential)
              )
        )::bigint,
        CASE
            WHEN COUNT(*) =
                 COUNT(
                     DISTINCT (order_id, payment_sequential)
                 )
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.order_payments

    UNION ALL

    /* 4. Reviews by review_id */
    SELECT
        4,
        'order_reviews',
        'review_id',
        COUNT(*)::bigint,
        COUNT(DISTINCT review_id)::bigint,
        (
            COUNT(*) - COUNT(DISTINCT review_id)
        )::bigint,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT review_id)
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.order_reviews

    UNION ALL

    /* 5. Reviews at order grain */
    SELECT
        5,
        'order_reviews',
        'order_id',
        COUNT(*)::bigint,
        COUNT(DISTINCT order_id)::bigint,
        (
            COUNT(*) - COUNT(DISTINCT order_id)
        )::bigint,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT order_id)
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.order_reviews

    UNION ALL

    /* 6. Customers */
    SELECT
        6,
        'customers',
        'customer_id',
        COUNT(*)::bigint,
        COUNT(DISTINCT customer_id)::bigint,
        (
            COUNT(*) - COUNT(DISTINCT customer_id)
        )::bigint,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT customer_id)
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.customers

    UNION ALL

    /* 7. Products */
    SELECT
        7,
        'products',
        'product_id',
        COUNT(*)::bigint,
        COUNT(DISTINCT product_id)::bigint,
        (
            COUNT(*) - COUNT(DISTINCT product_id)
        )::bigint,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT product_id)
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.products

    UNION ALL

    /* 8. Sellers */
    SELECT
        8,
        'sellers',
        'seller_id',
        COUNT(*)::bigint,
        COUNT(DISTINCT seller_id)::bigint,
        (
            COUNT(*) - COUNT(DISTINCT seller_id)
        )::bigint,
        CASE
            WHEN COUNT(*) = COUNT(DISTINCT seller_id)
                THEN 'PASS'
            ELSE 'REVIEW'
        END
    FROM staging.sellers
)

SELECT
    table_name,
    tested_grain,
    total_rows,
    distinct_grain_keys,
    duplicate_rows,
    validation_status
FROM grain_results
ORDER BY
    sort_order;


/* =========================================================
   Payment and item multiplicity per order
   ========================================================= */

WITH item_counts AS
(
    SELECT
        order_id,
        COUNT(*) AS records_per_order
    FROM staging.order_items
    GROUP BY order_id
),
payment_counts AS
(
    SELECT
        order_id,
        COUNT(*) AS records_per_order
    FROM staging.order_payments
    GROUP BY order_id
),
review_counts AS
(
    SELECT
        order_id,
        COUNT(*) AS records_per_order
    FROM staging.order_reviews
    GROUP BY order_id
),
multiplicity_results AS
(
    SELECT
        1 AS sort_order,
        'order_items'::text AS table_name,
        MIN(records_per_order)::bigint
            AS minimum_records_per_order,
        ROUND(AVG(records_per_order), 4)
            AS average_records_per_order,
        MAX(records_per_order)::bigint
            AS maximum_records_per_order,
        COUNT(*) FILTER (
            WHERE records_per_order > 1
        )::bigint AS orders_with_multiple_records
    FROM item_counts

    UNION ALL

    SELECT
        2,
        'order_payments',
        MIN(records_per_order)::bigint,
        ROUND(AVG(records_per_order), 4),
        MAX(records_per_order)::bigint,
        COUNT(*) FILTER (
            WHERE records_per_order > 1
        )::bigint
    FROM payment_counts

    UNION ALL

    SELECT
        3,
        'order_reviews',
        MIN(records_per_order)::bigint,
        ROUND(AVG(records_per_order), 4),
        MAX(records_per_order)::bigint,
        COUNT(*) FILTER (
            WHERE records_per_order > 1
        )::bigint
    FROM review_counts
)

SELECT
    table_name,
    minimum_records_per_order,
    average_records_per_order,
    maximum_records_per_order,
    orders_with_multiple_records
FROM multiplicity_results
ORDER BY
    sort_order;