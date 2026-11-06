/*
File: 12_validate_raw_timestamps.sql

Purpose:
Validate timestamp formats in the raw transactional tables before
converting TEXT columns to TIMESTAMP in the staging layer.

Notes:
- Empty strings are counted as missing values.
- Missing delivery timestamps are allowed for canceled orders.
- This script does not modify any data.
*/

WITH timestamp_validation AS (

    /* =========================================================
       raw.orders
       ========================================================= */

    SELECT
        'orders'::text AS table_name,
        'order_purchase_timestamp'::text AS column_name,
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_purchase_timestamp), '') IS NULL
        ) AS missing_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_purchase_timestamp), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(order_purchase_timestamp),
                  'timestamp without time zone'
              )
        ) AS invalid_format_rows
    FROM raw.orders

    UNION ALL

    SELECT
        'orders',
        'order_approved_at',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_approved_at), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_approved_at), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(order_approved_at),
                  'timestamp without time zone'
              )
        )
    FROM raw.orders

    UNION ALL

    SELECT
        'orders',
        'order_delivered_carrier_date',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(order_delivered_carrier_date),
                  'timestamp without time zone'
              )
        )
    FROM raw.orders

    UNION ALL

    SELECT
        'orders',
        'order_delivered_customer_date',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_customer_date), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(order_delivered_customer_date),
                  'timestamp without time zone'
              )
        )
    FROM raw.orders

    UNION ALL

    SELECT
        'orders',
        'order_estimated_delivery_date',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_estimated_delivery_date), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_estimated_delivery_date), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(order_estimated_delivery_date),
                  'timestamp without time zone'
              )
        )
    FROM raw.orders

    /* =========================================================
       raw.order_items
       ========================================================= */

    UNION ALL

    SELECT
        'order_items',
        'shipping_limit_date',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(shipping_limit_date), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(shipping_limit_date), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(shipping_limit_date),
                  'timestamp without time zone'
              )
        )
    FROM raw.order_items

    /* =========================================================
       raw.order_reviews
       ========================================================= */

    UNION ALL

    SELECT
        'order_reviews',
        'review_creation_date',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_creation_date), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_creation_date), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(review_creation_date),
                  'timestamp without time zone'
              )
        )
    FROM raw.order_reviews

    UNION ALL

    SELECT
        'order_reviews',
        'review_answer_timestamp',
        COUNT(*),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_answer_timestamp), '') IS NULL
        ),
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_answer_timestamp), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(review_answer_timestamp),
                  'timestamp without time zone'
              )
        )
    FROM raw.order_reviews
)

SELECT
    table_name,
    column_name,
    total_rows,
    missing_rows,
    total_rows - missing_rows AS nonmissing_rows,
    invalid_format_rows
FROM timestamp_validation
ORDER BY
    table_name,
    column_name;