/*
File: 11_validate_raw_formats_and_ranges.sql

Purpose:
Validate whether raw TEXT values can safely be converted
to numeric data types and whether they fall within expected
business ranges.

This script is read-only.
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
   Section 1: Transactional numeric fields
   ========================================================= */

WITH item_validation AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(
                BTRIM(order_item_id),
                'integer'
            )
        ) AS item_id_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(BTRIM(order_item_id), 'integer')
                THEN BTRIM(order_item_id)::numeric
            END
        ) AS item_id_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(BTRIM(order_item_id), 'integer')
                THEN BTRIM(order_item_id)::numeric
            END
        ) AS item_id_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(order_item_id), 'integer')
              AND BTRIM(order_item_id)::numeric < 1
        ) AS item_id_below_range,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(BTRIM(price), 'numeric')
        ) AS price_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(BTRIM(price), 'numeric')
                THEN BTRIM(price)::numeric
            END
        ) AS price_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(BTRIM(price), 'numeric')
                THEN BTRIM(price)::numeric
            END
        ) AS price_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(price), 'numeric')
              AND BTRIM(price)::numeric < 0
        ) AS price_below_range,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(BTRIM(freight_value), 'numeric')
        ) AS freight_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(BTRIM(freight_value), 'numeric')
                THEN BTRIM(freight_value)::numeric
            END
        ) AS freight_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(BTRIM(freight_value), 'numeric')
                THEN BTRIM(freight_value)::numeric
            END
        ) AS freight_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(freight_value), 'numeric')
              AND BTRIM(freight_value)::numeric < 0
        ) AS freight_below_range,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(BTRIM(discount_rate), 'numeric')
        ) AS discount_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(BTRIM(discount_rate), 'numeric')
                THEN BTRIM(discount_rate)::numeric
            END
        ) AS discount_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(BTRIM(discount_rate), 'numeric')
                THEN BTRIM(discount_rate)::numeric
            END
        ) AS discount_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(discount_rate), 'numeric')
              AND BTRIM(discount_rate)::numeric < 0
        ) AS discount_below_range,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(discount_rate), 'numeric')
              AND BTRIM(discount_rate)::numeric > 1
        ) AS discount_above_range

    FROM raw.order_items
),

item_results AS (
    SELECT v.*
    FROM item_validation AS i
    CROSS JOIN LATERAL (
        VALUES
            (
                'order_items',
                'order_item_id',
                'integer',
                1::numeric,
                NULL::numeric,
                i.item_id_invalid,
                i.item_id_below_range,
                0::bigint,
                i.item_id_min,
                i.item_id_max,
                i.total_rows
            ),
            (
                'order_items',
                'price',
                'numeric',
                0::numeric,
                NULL::numeric,
                i.price_invalid,
                i.price_below_range,
                0::bigint,
                i.price_min,
                i.price_max,
                i.total_rows
            ),
            (
                'order_items',
                'freight_value',
                'numeric',
                0::numeric,
                NULL::numeric,
                i.freight_invalid,
                i.freight_below_range,
                0::bigint,
                i.freight_min,
                i.freight_max,
                i.total_rows
            ),
            (
                'order_items',
                'discount_rate',
                'numeric',
                0::numeric,
                1::numeric,
                i.discount_invalid,
                i.discount_below_range,
                i.discount_above_range,
                i.discount_min,
                i.discount_max,
                i.total_rows
            )
    ) AS v(
        table_name,
        column_name,
        target_type,
        expected_min,
        expected_max,
        invalid_format_rows,
        below_range_rows,
        above_range_rows,
        observed_min,
        observed_max,
        total_rows
    )
),

payment_validation AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(
                BTRIM(payment_sequential),
                'integer'
            )
        ) AS sequential_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(payment_sequential),
                    'integer'
                )
                THEN BTRIM(payment_sequential)::numeric
            END
        ) AS sequential_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(payment_sequential),
                    'integer'
                )
                THEN BTRIM(payment_sequential)::numeric
            END
        ) AS sequential_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(
                    BTRIM(payment_sequential),
                    'integer'
                  )
              AND BTRIM(payment_sequential)::numeric < 1
        ) AS sequential_below_range,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(
                BTRIM(payment_installments),
                'integer'
            )
        ) AS installments_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(payment_installments),
                    'integer'
                )
                THEN BTRIM(payment_installments)::numeric
            END
        ) AS installments_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(payment_installments),
                    'integer'
                )
                THEN BTRIM(payment_installments)::numeric
            END
        ) AS installments_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(
                    BTRIM(payment_installments),
                    'integer'
                  )
              AND BTRIM(payment_installments)::numeric < 0
        ) AS installments_below_range,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(
                BTRIM(payment_value),
                'numeric'
            )
        ) AS value_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(BTRIM(payment_value), 'numeric')
                THEN BTRIM(payment_value)::numeric
            END
        ) AS value_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(BTRIM(payment_value), 'numeric')
                THEN BTRIM(payment_value)::numeric
            END
        ) AS value_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(payment_value), 'numeric')
              AND BTRIM(payment_value)::numeric < 0
        ) AS value_below_range

    FROM raw.order_payments
),

payment_results AS (
    SELECT v.*
    FROM payment_validation AS p
    CROSS JOIN LATERAL (
        VALUES
            (
                'order_payments',
                'payment_sequential',
                'integer',
                1::numeric,
                NULL::numeric,
                p.sequential_invalid,
                p.sequential_below_range,
                0::bigint,
                p.sequential_min,
                p.sequential_max,
                p.total_rows
            ),
            (
                'order_payments',
                'payment_installments',
                'integer',
                0::numeric,
                NULL::numeric,
                p.installments_invalid,
                p.installments_below_range,
                0::bigint,
                p.installments_min,
                p.installments_max,
                p.total_rows
            ),
            (
                'order_payments',
                'payment_value',
                'numeric',
                0::numeric,
                NULL::numeric,
                p.value_invalid,
                p.value_below_range,
                0::bigint,
                p.value_min,
                p.value_max,
                p.total_rows
            )
    ) AS v(
        table_name,
        column_name,
        target_type,
        expected_min,
        expected_max,
        invalid_format_rows,
        below_range_rows,
        above_range_rows,
        observed_min,
        observed_max,
        total_rows
    )
),

review_validation AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NOT pg_input_is_valid(BTRIM(review_score), 'integer')
        ) AS score_invalid,

        MIN(
            CASE
                WHEN pg_input_is_valid(BTRIM(review_score), 'integer')
                THEN BTRIM(review_score)::numeric
            END
        ) AS score_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(BTRIM(review_score), 'integer')
                THEN BTRIM(review_score)::numeric
            END
        ) AS score_max,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(review_score), 'integer')
              AND BTRIM(review_score)::numeric < 1
        ) AS score_below_range,

        COUNT(*) FILTER (
            WHERE pg_input_is_valid(BTRIM(review_score), 'integer')
              AND BTRIM(review_score)::numeric > 5
        ) AS score_above_range

    FROM raw.order_reviews
),

review_results AS (
    SELECT v.*
    FROM review_validation AS r
    CROSS JOIN LATERAL (
        VALUES
            (
                'order_reviews',
                'review_score',
                'integer',
                1::numeric,
                5::numeric,
                r.score_invalid,
                r.score_below_range,
                r.score_above_range,
                r.score_min,
                r.score_max,
                r.total_rows
            )
    ) AS v(
        table_name,
        column_name,
        target_type,
        expected_min,
        expected_max,
        invalid_format_rows,
        below_range_rows,
        above_range_rows,
        observed_min,
        observed_max,
        total_rows
    )
)

SELECT * FROM item_results

UNION ALL

SELECT * FROM payment_results

UNION ALL

SELECT * FROM review_results

ORDER BY table_name, column_name;