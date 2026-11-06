/*
Project: U.S. E-Commerce Performance Analytics
File: 05_validate_raw_keys.sql

Purpose:
Inspect candidate keys, missing identifiers, and duplicate identifiers
in the raw source tables before building staging tables.

Important:
- This script is read-only.
- No rows are updated or deleted.
- Duplicate counts are validation results, not automatic cleaning rules.
*/

DO $$
BEGIN
    IF current_database() <> 'us_ecommerce_analytics' THEN
        RAISE EXCEPTION
            'Wrong database: connected to %. Connect to us_ecommerce_analytics.',
            current_database();
    END IF;
END
$$;


/* ============================================================
   1. Single-column candidate keys
   ============================================================ */

SELECT
    'customers.customer_id' AS candidate_key,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_id), '') IS NULL
    ) AS missing_key_rows,
    COUNT(DISTINCT NULLIF(BTRIM(customer_id), '')) AS distinct_nonmissing_keys,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_id), '') IS NOT NULL
    )
    - COUNT(DISTINCT NULLIF(BTRIM(customer_id), '')) AS duplicate_key_rows
FROM raw.customers

UNION ALL

SELECT
    'orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NULL
    ),
    COUNT(DISTINCT NULLIF(BTRIM(order_id), '')),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
    )
    - COUNT(DISTINCT NULLIF(BTRIM(order_id), ''))
FROM raw.orders

UNION ALL

SELECT
    'products.product_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(product_id), '') IS NULL
    ),
    COUNT(DISTINCT NULLIF(BTRIM(product_id), '')),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(product_id), '') IS NOT NULL
    )
    - COUNT(DISTINCT NULLIF(BTRIM(product_id), ''))
FROM raw.products

UNION ALL

SELECT
    'sellers.seller_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(seller_id), '') IS NULL
    ),
    COUNT(DISTINCT NULLIF(BTRIM(seller_id), '')),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(seller_id), '') IS NOT NULL
    )
    - COUNT(DISTINCT NULLIF(BTRIM(seller_id), ''))
FROM raw.sellers

UNION ALL

SELECT
    'order_reviews.review_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(review_id), '') IS NULL
    ),
    COUNT(DISTINCT NULLIF(BTRIM(review_id), '')),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(review_id), '') IS NOT NULL
    )
    - COUNT(DISTINCT NULLIF(BTRIM(review_id), ''))
FROM raw.order_reviews

ORDER BY candidate_key;


/* ============================================================
   2. Composite candidate keys
   ============================================================ */

SELECT
    'order_items.(order_id, order_item_id)' AS candidate_key,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NULL
           OR NULLIF(BTRIM(order_item_id), '') IS NULL
    ) AS missing_key_rows,
    COUNT(DISTINCT (order_id, order_item_id)) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
          AND NULLIF(BTRIM(order_item_id), '') IS NOT NULL
    ) AS distinct_nonmissing_keys,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
          AND NULLIF(BTRIM(order_item_id), '') IS NOT NULL
    )
    - COUNT(DISTINCT (order_id, order_item_id)) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
          AND NULLIF(BTRIM(order_item_id), '') IS NOT NULL
    ) AS duplicate_key_rows
FROM raw.order_items

UNION ALL

SELECT
    'order_payments.(order_id, payment_sequential)',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NULL
           OR NULLIF(BTRIM(payment_sequential), '') IS NULL
    ),
    COUNT(DISTINCT (order_id, payment_sequential)) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
          AND NULLIF(BTRIM(payment_sequential), '') IS NOT NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
          AND NULLIF(BTRIM(payment_sequential), '') IS NOT NULL
    )
    - COUNT(DISTINCT (order_id, payment_sequential)) FILTER (
        WHERE NULLIF(BTRIM(order_id), '') IS NOT NULL
          AND NULLIF(BTRIM(payment_sequential), '') IS NOT NULL
    )
FROM raw.order_payments

ORDER BY candidate_key;