/*
File: 04_validate_staging_load.sql

Purpose:
Compare raw and staging row counts after the staging load.

Expected result:
row_count_difference = 0 and validation_status = PASS
for all eight tables.

This script is read-only.
*/

WITH raw_counts AS (
    SELECT
        'customers'::text AS table_name,
        COUNT(*)::bigint AS raw_row_count
    FROM raw.customers

    UNION ALL

    SELECT
        'geolocation',
        COUNT(*)
    FROM raw.geolocation

    UNION ALL

    SELECT
        'order_items',
        COUNT(*)
    FROM raw.order_items

    UNION ALL

    SELECT
        'order_payments',
        COUNT(*)
    FROM raw.order_payments

    UNION ALL

    SELECT
        'order_reviews',
        COUNT(*)
    FROM raw.order_reviews

    UNION ALL

    SELECT
        'orders',
        COUNT(*)
    FROM raw.orders

    UNION ALL

    SELECT
        'products',
        COUNT(*)
    FROM raw.products

    UNION ALL

    SELECT
        'sellers',
        COUNT(*)
    FROM raw.sellers
),

staging_counts AS (
    SELECT
        'customers'::text AS table_name,
        COUNT(*)::bigint AS staging_row_count
    FROM staging.customers

    UNION ALL

    SELECT
        'geolocation',
        COUNT(*)
    FROM staging.geolocation

    UNION ALL

    SELECT
        'order_items',
        COUNT(*)
    FROM staging.order_items

    UNION ALL

    SELECT
        'order_payments',
        COUNT(*)
    FROM staging.order_payments

    UNION ALL

    SELECT
        'order_reviews',
        COUNT(*)
    FROM staging.order_reviews

    UNION ALL

    SELECT
        'orders',
        COUNT(*)
    FROM staging.orders

    UNION ALL

    SELECT
        'products',
        COUNT(*)
    FROM staging.products

    UNION ALL

    SELECT
        'sellers',
        COUNT(*)
    FROM staging.sellers
)

SELECT
    r.table_name,
    r.raw_row_count,
    s.staging_row_count,
    s.staging_row_count - r.raw_row_count
        AS row_count_difference,

    CASE
        WHEN s.staging_row_count = r.raw_row_count
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status

FROM raw_counts AS r
INNER JOIN staging_counts AS s
    ON s.table_name = r.table_name
ORDER BY r.table_name;