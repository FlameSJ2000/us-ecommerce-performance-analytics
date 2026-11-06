/*
File: 06_verify_staging_relationships.sql

Purpose:
Verify that all expected staging foreign keys and supporting indexes
exist and that each foreign key has been validated.

This script is read-only.
*/

WITH expected_foreign_keys AS (
    SELECT *
    FROM (
        VALUES
            (
                'orders',
                'fk_staging_orders_customer'
            ),
            (
                'order_items',
                'fk_staging_order_items_order'
            ),
            (
                'order_items',
                'fk_staging_order_items_product'
            ),
            (
                'order_items',
                'fk_staging_order_items_seller'
            ),
            (
                'order_payments',
                'fk_staging_order_payments_order'
            ),
            (
                'order_reviews',
                'fk_staging_order_reviews_order'
            )
    ) AS e (
        table_name,
        object_name
    )
),

actual_foreign_keys AS (
    SELECT
        child_table.relname AS table_name,
        constraint_info.conname AS object_name,
        constraint_info.convalidated
    FROM pg_constraint AS constraint_info
    INNER JOIN pg_class AS child_table
        ON child_table.oid = constraint_info.conrelid
    INNER JOIN pg_namespace AS schema_info
        ON schema_info.oid = child_table.relnamespace
    WHERE schema_info.nspname = 'staging'
      AND constraint_info.contype = 'f'
),

foreign_key_results AS (
    SELECT
        'FOREIGN KEY'::text AS object_type,
        expected.table_name,
        expected.object_name,

        CASE
            WHEN actual.object_name IS NULL
                THEN 'MISSING'
            WHEN actual.convalidated = FALSE
                THEN 'NOT VALIDATED'
            ELSE 'PASS'
        END AS validation_status

    FROM expected_foreign_keys AS expected
    LEFT JOIN actual_foreign_keys AS actual
        ON actual.table_name = expected.table_name
       AND actual.object_name = expected.object_name
),

index_results AS (
    SELECT
        'INDEX'::text AS object_type,
        expected.table_name,
        expected.object_name,

        CASE
            WHEN TO_REGCLASS(
                'staging.' || expected.object_name
            ) IS NOT NULL
                THEN 'PASS'
            ELSE 'MISSING'
        END AS validation_status

    FROM (
        VALUES
            (
                'orders',
                'idx_staging_orders_customer_id'
            ),
            (
                'order_items',
                'idx_staging_order_items_product_id'
            ),
            (
                'order_items',
                'idx_staging_order_items_seller_id'
            ),
            (
                'order_reviews',
                'idx_staging_order_reviews_order_id'
            )
    ) AS expected (
        table_name,
        object_name
    )
)

SELECT
    object_type,
    table_name,
    object_name,
    validation_status
FROM foreign_key_results

UNION ALL

SELECT
    object_type,
    table_name,
    object_name,
    validation_status
FROM index_results

ORDER BY
    object_type,
    table_name,
    object_name;