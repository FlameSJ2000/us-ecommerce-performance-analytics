/*
File: 06_validate_raw_relationships.sql

Purpose:
Check whether foreign-key-like columns in the raw tables
can be matched to their corresponding parent records.

This script is read-only. It does not modify any data.
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


/* =========================================================
   Validate relationships between the raw tables
   ========================================================= */

SELECT
    'orders.customer_id -> customers.customer_id' AS relationship_name,
    COUNT(*) AS child_rows,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(o.customer_id), '') IS NULL
    ) AS missing_foreign_key_rows,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(o.customer_id), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.customers AS c
              WHERE c.customer_id = o.customer_id
          )
    ) AS orphan_rows
FROM raw.orders AS o

UNION ALL

SELECT
    'order_items.order_id -> orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(oi.order_id), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(oi.order_id), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.orders AS o
              WHERE o.order_id = oi.order_id
          )
    )
FROM raw.order_items AS oi

UNION ALL

SELECT
    'order_items.product_id -> products.product_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(oi.product_id), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(oi.product_id), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.products AS p
              WHERE p.product_id = oi.product_id
          )
    )
FROM raw.order_items AS oi

UNION ALL

SELECT
    'order_items.seller_id -> sellers.seller_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(oi.seller_id), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(oi.seller_id), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.sellers AS s
              WHERE s.seller_id = oi.seller_id
          )
    )
FROM raw.order_items AS oi

UNION ALL

SELECT
    'order_payments.order_id -> orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(op.order_id), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(op.order_id), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.orders AS o
              WHERE o.order_id = op.order_id
          )
    )
FROM raw.order_payments AS op

UNION ALL

SELECT
    'order_reviews.order_id -> orders.order_id',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(r.order_id), '') IS NULL
    ),
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(r.order_id), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.orders AS o
              WHERE o.order_id = r.order_id
          )
    )
FROM raw.order_reviews AS r

ORDER BY relationship_name;