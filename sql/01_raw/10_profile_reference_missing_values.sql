/*
File: 10_profile_reference_missing_values.sql

Purpose:
Profile NULL values and blank strings in:
- customers
- products
- sellers
- geolocation

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
   1. Customers
   ========================================================= */

WITH customer_counts AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_id), '') IS NULL
        ) AS customer_id_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_unique_id), '') IS NULL
        ) AS customer_unique_id_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_name), '') IS NULL
        ) AS customer_name_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_gender), '') IS NULL
        ) AS customer_gender_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_age), '') IS NULL
        ) AS customer_age_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_zip_code_prefix), '') IS NULL
        ) AS customer_zip_code_prefix_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_city), '') IS NULL
        ) AS customer_city_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_state), '') IS NULL
        ) AS customer_state_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_segment), '') IS NULL
        ) AS customer_segment_missing
    FROM raw.customers
),

customer_profile AS (
    SELECT
        'customers'::text AS table_name,
        v.column_name,
        c.total_rows,
        v.missing_rows
    FROM customer_counts AS c
    CROSS JOIN LATERAL (
        VALUES
            ('customer_id', c.customer_id_missing),
            ('customer_unique_id', c.customer_unique_id_missing),
            ('customer_name', c.customer_name_missing),
            ('customer_gender', c.customer_gender_missing),
            ('customer_age', c.customer_age_missing),
            ('customer_zip_code_prefix',
                c.customer_zip_code_prefix_missing),
            ('customer_city', c.customer_city_missing),
            ('customer_state', c.customer_state_missing),
            ('customer_segment', c.customer_segment_missing)
    ) AS v(column_name, missing_rows)
),


/* =========================================================
   2. Products
   ========================================================= */

product_counts AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_id), '') IS NULL
        ) AS product_id_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_category_name), '') IS NULL
        ) AS product_category_name_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_name), '') IS NULL
        ) AS product_name_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_brand), '') IS NULL
        ) AS product_brand_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_weight_g), '') IS NULL
        ) AS product_weight_g_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_length_cm), '') IS NULL
        ) AS product_length_cm_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_height_cm), '') IS NULL
        ) AS product_height_cm_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(product_width_cm), '') IS NULL
        ) AS product_width_cm_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(cost), '') IS NULL
        ) AS cost_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(price), '') IS NULL
        ) AS price_missing
    FROM raw.products
),

product_profile AS (
    SELECT
        'products'::text AS table_name,
        v.column_name,
        p.total_rows,
        v.missing_rows
    FROM product_counts AS p
    CROSS JOIN LATERAL (
        VALUES
            ('product_id', p.product_id_missing),
            ('product_category_name',
                p.product_category_name_missing),
            ('product_name', p.product_name_missing),
            ('product_brand', p.product_brand_missing),
            ('product_weight_g', p.product_weight_g_missing),
            ('product_length_cm', p.product_length_cm_missing),
            ('product_height_cm', p.product_height_cm_missing),
            ('product_width_cm', p.product_width_cm_missing),
            ('cost', p.cost_missing),
            ('price', p.price_missing)
    ) AS v(column_name, missing_rows)
),


/* =========================================================
   3. Sellers
   ========================================================= */

seller_counts AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_id), '') IS NULL
        ) AS seller_id_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_company_name), '') IS NULL
        ) AS seller_company_name_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_contact_name), '') IS NULL
        ) AS seller_contact_name_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_contact_gender), '') IS NULL
        ) AS seller_contact_gender_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_contact_age), '') IS NULL
        ) AS seller_contact_age_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_zip_code_prefix), '') IS NULL
        ) AS seller_zip_code_prefix_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_city), '') IS NULL
        ) AS seller_city_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(seller_state), '') IS NULL
        ) AS seller_state_missing
    FROM raw.sellers
),

seller_profile AS (
    SELECT
        'sellers'::text AS table_name,
        v.column_name,
        s.total_rows,
        v.missing_rows
    FROM seller_counts AS s
    CROSS JOIN LATERAL (
        VALUES
            ('seller_id', s.seller_id_missing),
            ('seller_company_name', s.seller_company_name_missing),
            ('seller_contact_name', s.seller_contact_name_missing),
            ('seller_contact_gender',
                s.seller_contact_gender_missing),
            ('seller_contact_age', s.seller_contact_age_missing),
            ('seller_zip_code_prefix',
                s.seller_zip_code_prefix_missing),
            ('seller_city', s.seller_city_missing),
            ('seller_state', s.seller_state_missing)
    ) AS v(column_name, missing_rows)
),


/* =========================================================
   4. Geolocation
   ========================================================= */

geolocation_counts AS (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(zip_code_prefix), '') IS NULL
        ) AS zip_code_prefix_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(geolocation_lat), '') IS NULL
        ) AS geolocation_lat_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(geolocation_lng), '') IS NULL
        ) AS geolocation_lng_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(geolocation_city), '') IS NULL
        ) AS geolocation_city_missing,
        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(geolocation_state), '') IS NULL
        ) AS geolocation_state_missing
    FROM raw.geolocation
),

geolocation_profile AS (
    SELECT
        'geolocation'::text AS table_name,
        v.column_name,
        g.total_rows,
        v.missing_rows
    FROM geolocation_counts AS g
    CROSS JOIN LATERAL (
        VALUES
            ('zip_code_prefix', g.zip_code_prefix_missing),
            ('geolocation_lat', g.geolocation_lat_missing),
            ('geolocation_lng', g.geolocation_lng_missing),
            ('geolocation_city', g.geolocation_city_missing),
            ('geolocation_state', g.geolocation_state_missing)
    ) AS v(column_name, missing_rows)
),


/* Combine all four table profiles. */

combined_profile AS (
    SELECT * FROM customer_profile

    UNION ALL

    SELECT * FROM product_profile

    UNION ALL

    SELECT * FROM seller_profile

    UNION ALL

    SELECT * FROM geolocation_profile
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