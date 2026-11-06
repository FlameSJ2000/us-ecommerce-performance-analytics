/*
File: 09_profile_transaction_missing_values.sql

Purpose:
Profile NULL values and blank strings in the three
transaction-level raw tables:

1. order_items
2. order_payments
3. order_reviews

The script scans each table once and does not modify data.
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
   1. Profile raw.order_items
   ========================================================= */

WITH item_counts AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
        ) AS order_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_item_id), '') IS NULL
        ) AS order_item_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_id), '') IS NULL
        ) AS product_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_id), '') IS NULL
        ) AS seller_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(shipping_limit_date), '') IS NULL
        ) AS shipping_limit_date_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(price), '') IS NULL
        ) AS price_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(freight_value), '') IS NULL
        ) AS freight_value_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(discount_rate), '') IS NULL
        ) AS discount_rate_missing

    FROM raw.order_items
),

item_profile AS (
    SELECT
        'order_items'::text AS table_name,
        v.column_name,
        i.total_rows,
        v.missing_rows
    FROM item_counts AS i
    CROSS JOIN LATERAL (
        VALUES
            ('order_id', i.order_id_missing),
            ('order_item_id', i.order_item_id_missing),
            ('product_id', i.product_id_missing),
            ('seller_id', i.seller_id_missing),
            ('shipping_limit_date', i.shipping_limit_date_missing),
            ('price', i.price_missing),
            ('freight_value', i.freight_value_missing),
            ('discount_rate', i.discount_rate_missing)
    ) AS v(column_name, missing_rows)
),


/* =========================================================
   2. Profile raw.order_payments
   ========================================================= */

payment_counts AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
        ) AS order_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(payment_sequential), '') IS NULL
        ) AS payment_sequential_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(payment_type), '') IS NULL
        ) AS payment_type_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(payment_installments), '') IS NULL
        ) AS payment_installments_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(payment_value), '') IS NULL
        ) AS payment_value_missing

    FROM raw.order_payments
),

payment_profile AS (
    SELECT
        'order_payments'::text AS table_name,
        v.column_name,
        p.total_rows,
        v.missing_rows
    FROM payment_counts AS p
    CROSS JOIN LATERAL (
        VALUES
            ('order_id', p.order_id_missing),
            ('payment_sequential', p.payment_sequential_missing),
            ('payment_type', p.payment_type_missing),
            ('payment_installments', p.payment_installments_missing),
            ('payment_value', p.payment_value_missing)
    ) AS v(column_name, missing_rows)
),


/* =========================================================
   3. Profile raw.order_reviews
   ========================================================= */

review_counts AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_id), '') IS NULL
        ) AS review_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
        ) AS order_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_score), '') IS NULL
        ) AS review_score_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_comment_title), '') IS NULL
        ) AS review_comment_title_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_comment_message), '') IS NULL
        ) AS review_comment_message_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_creation_date), '') IS NULL
        ) AS review_creation_date_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(review_answer_timestamp), '') IS NULL
        ) AS review_answer_timestamp_missing

    FROM raw.order_reviews
),

review_profile AS (
    SELECT
        'order_reviews'::text AS table_name,
        v.column_name,
        r.total_rows,
        v.missing_rows
    FROM review_counts AS r
    CROSS JOIN LATERAL (
        VALUES
            ('review_id', r.review_id_missing),
            ('order_id', r.order_id_missing),
            ('review_score', r.review_score_missing),
            ('review_comment_title', r.review_comment_title_missing),
            ('review_comment_message', r.review_comment_message_missing),
            ('review_creation_date', r.review_creation_date_missing),
            ('review_answer_timestamp', r.review_answer_timestamp_missing)
    ) AS v(column_name, missing_rows)
),


/* Combine the three profiles into one result. */

combined_profile AS (
    SELECT * FROM item_profile

    UNION ALL

    SELECT * FROM payment_profile

    UNION ALL

    SELECT * FROM review_profile
)

SELECT
    table_name,
    column_name,
    total_rows,
    missing_rows,
    total_rows - missing_rows AS nonmissing_rows,
    ROUND(
        100.0 * missing_rows / NULLIF(total_rows, 0),
        2
    ) AS missing_percentage
FROM combined_profile
ORDER BY table_name, column_name;