/*
File: 02_verify_staging_tables.sql

Purpose:
Verify staging table existence, column counts, and primary-key columns
before loading data from the raw schema.

This script is read-only.
*/

WITH expected_tables AS (
    SELECT *
    FROM (
        VALUES
            ('customers',       9, 1),
            ('geolocation',     5, 0),
            ('order_items',     8, 2),
            ('order_payments',  5, 2),
            ('order_reviews',   7, 1),
            ('orders',          8, 1),
            ('products',       10, 1),
            ('sellers',         8, 1)
    ) AS e (
        table_name,
        expected_column_count,
        expected_pk_column_count
    )
),

actual_columns AS (
    SELECT
        table_name,
        COUNT(*)::integer AS actual_column_count
    FROM information_schema.columns
    WHERE table_schema = 'staging'
    GROUP BY table_name
),

actual_primary_keys AS (
    SELECT
        t.relname AS table_name,
        COUNT(a.attname)::integer AS actual_pk_column_count
    FROM pg_constraint AS c
    INNER JOIN pg_class AS t
        ON t.oid = c.conrelid
    INNER JOIN pg_namespace AS n
        ON n.oid = t.relnamespace
    INNER JOIN LATERAL
        UNNEST(c.conkey) AS key_columns(attnum)
        ON TRUE
    INNER JOIN pg_attribute AS a
        ON a.attrelid = t.oid
       AND a.attnum = key_columns.attnum
    WHERE n.nspname = 'staging'
      AND c.contype = 'p'
    GROUP BY t.relname
)

SELECT
    e.table_name,
    e.expected_column_count,
    COALESCE(ac.actual_column_count, 0) AS actual_column_count,
    e.expected_pk_column_count,
    COALESCE(ap.actual_pk_column_count, 0) AS actual_pk_column_count,

    CASE
        WHEN ac.table_name IS NULL THEN 'TABLE MISSING'
        WHEN ac.actual_column_count <> e.expected_column_count
            THEN 'COLUMN COUNT REVIEW'
        WHEN COALESCE(ap.actual_pk_column_count, 0)
             <> e.expected_pk_column_count
            THEN 'PRIMARY KEY REVIEW'
        ELSE 'PASS'
    END AS validation_status

FROM expected_tables AS e
LEFT JOIN actual_columns AS ac
    ON ac.table_name = e.table_name
LEFT JOIN actual_primary_keys AS ap
    ON ap.table_name = e.table_name
ORDER BY e.table_name;