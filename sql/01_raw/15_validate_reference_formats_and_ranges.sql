/*
File: 15_validate_reference_formats_and_ranges.sql

Purpose:
Validate numeric formats and acceptable ranges in reference tables
before casting values into typed staging tables.

This script is read-only.
*/

WITH customer_results AS (
    SELECT
        'customers'::text AS table_name,
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max,
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NULL
        ) AS missing_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(v.raw_value),
                  v.target_type
              )
        ) AS invalid_format_rows,

        COUNT(*) FILTER (
            WHERE
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END < v.expected_min
        ) AS below_range_rows,

        COUNT(*) FILTER (
            WHERE v.expected_max IS NOT NULL
              AND
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END > v.expected_max
        ) AS above_range_rows,

        MIN(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_max

    FROM raw.customers AS c
    CROSS JOIN LATERAL (
        VALUES
            (
                'customer_age'::text,
                'smallint'::text,
                0::numeric,
                120::numeric,
                c.customer_age
            )
    ) AS v (
        column_name,
        target_type,
        expected_min,
        expected_max,
        raw_value
    )

    GROUP BY
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max
),

geolocation_results AS (
    SELECT
        'geolocation'::text AS table_name,
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max,
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NULL
        ) AS missing_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(v.raw_value),
                  v.target_type
              )
        ) AS invalid_format_rows,

        COUNT(*) FILTER (
            WHERE
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END < v.expected_min
        ) AS below_range_rows,

        COUNT(*) FILTER (
            WHERE v.expected_max IS NOT NULL
              AND
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END > v.expected_max
        ) AS above_range_rows,

        MIN(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_max

    FROM raw.geolocation AS g
    CROSS JOIN LATERAL (
        VALUES
            (
                'geolocation_lat'::text,
                'numeric'::text,
                (-90)::numeric,
                90::numeric,
                g.geolocation_lat
            ),
            (
                'geolocation_lng'::text,
                'numeric'::text,
                (-180)::numeric,
                180::numeric,
                g.geolocation_lng
            )
    ) AS v (
        column_name,
        target_type,
        expected_min,
        expected_max,
        raw_value
    )

    GROUP BY
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max
),

product_results AS (
    SELECT
        'products'::text AS table_name,
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max,
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NULL
        ) AS missing_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(v.raw_value),
                  v.target_type
              )
        ) AS invalid_format_rows,

        COUNT(*) FILTER (
            WHERE
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END < v.expected_min
        ) AS below_range_rows,

        COUNT(*) FILTER (
            WHERE v.expected_max IS NOT NULL
              AND
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END > v.expected_max
        ) AS above_range_rows,

        MIN(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_max

    FROM raw.products AS p
    CROSS JOIN LATERAL (
        VALUES
            ('product_weight_g',  'numeric', 0::numeric, NULL::numeric, p.product_weight_g),
            ('product_length_cm', 'numeric', 0::numeric, NULL::numeric, p.product_length_cm),
            ('product_height_cm', 'numeric', 0::numeric, NULL::numeric, p.product_height_cm),
            ('product_width_cm',  'numeric', 0::numeric, NULL::numeric, p.product_width_cm),
            ('cost',              'numeric', 0::numeric, NULL::numeric, p.cost),
            ('price',             'numeric', 0::numeric, NULL::numeric, p.price)
    ) AS v (
        column_name,
        target_type,
        expected_min,
        expected_max,
        raw_value
    )

    GROUP BY
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max
),

seller_results AS (
    SELECT
        'sellers'::text AS table_name,
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max,
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NULL
        ) AS missing_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(v.raw_value), '') IS NOT NULL
              AND NOT pg_input_is_valid(
                  BTRIM(v.raw_value),
                  v.target_type
              )
        ) AS invalid_format_rows,

        COUNT(*) FILTER (
            WHERE
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END < v.expected_min
        ) AS below_range_rows,

        COUNT(*) FILTER (
            WHERE v.expected_max IS NOT NULL
              AND
                CASE
                    WHEN pg_input_is_valid(
                        BTRIM(v.raw_value),
                        v.target_type
                    )
                    THEN BTRIM(v.raw_value)::numeric
                END > v.expected_max
        ) AS above_range_rows,

        MIN(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_min,

        MAX(
            CASE
                WHEN pg_input_is_valid(
                    BTRIM(v.raw_value),
                    v.target_type
                )
                THEN BTRIM(v.raw_value)::numeric
            END
        ) AS observed_max

    FROM raw.sellers AS s
    CROSS JOIN LATERAL (
        VALUES
            (
                'seller_contact_age'::text,
                'smallint'::text,
                0::numeric,
                120::numeric,
                s.seller_contact_age
            )
    ) AS v (
        column_name,
        target_type,
        expected_min,
        expected_max,
        raw_value
    )

    GROUP BY
        v.column_name,
        v.target_type,
        v.expected_min,
        v.expected_max
),

combined_results AS (
    SELECT * FROM customer_results
    UNION ALL
    SELECT * FROM geolocation_results
    UNION ALL
    SELECT * FROM product_results
    UNION ALL
    SELECT * FROM seller_results
)

SELECT
    table_name,
    column_name,
    target_type,
    expected_min,
    expected_max,
    total_rows,
    missing_rows,
    invalid_format_rows,
    below_range_rows,
    above_range_rows,
    observed_min,
    observed_max,

    CASE
        WHEN missing_rows = 0
         AND invalid_format_rows = 0
         AND below_range_rows = 0
         AND above_range_rows = 0
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status

FROM combined_results
ORDER BY
    table_name,
    column_name;