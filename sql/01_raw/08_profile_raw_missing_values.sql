/*
File: 08_profile_raw_missing_values.sql

Purpose:
Profile NULL values and blank strings in raw source columns.

Important:
Raw columns are stored as TEXT, so both actual NULL values
and empty/whitespace-only strings are treated as missing.

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
   Section 1: Missing-value profile for raw.orders
   ========================================================= */

WITH orders_missing AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_id), '') IS NULL
        ) AS order_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(customer_id), '') IS NULL
        ) AS customer_id_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_status), '') IS NULL
        ) AS order_status_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_purchase_timestamp), '') IS NULL
        ) AS order_purchase_timestamp_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_approved_at), '') IS NULL
        ) AS order_approved_at_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
        ) AS order_delivered_carrier_date_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
        ) AS order_delivered_customer_date_missing,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_estimated_delivery_date), '') IS NULL
        ) AS order_estimated_delivery_date_missing

    FROM raw.orders
),

orders_long AS (
    SELECT
        'orders'::text AS table_name,
        v.column_name,
        o.total_rows,
        v.missing_rows
    FROM orders_missing AS o
    CROSS JOIN LATERAL (
        VALUES
            ('order_id', o.order_id_missing),
            ('customer_id', o.customer_id_missing),
            ('order_status', o.order_status_missing),
            ('order_purchase_timestamp',
                o.order_purchase_timestamp_missing),
            ('order_approved_at',
                o.order_approved_at_missing),
            ('order_delivered_carrier_date',
                o.order_delivered_carrier_date_missing),
            ('order_delivered_customer_date',
                o.order_delivered_customer_date_missing),
            ('order_estimated_delivery_date',
                o.order_estimated_delivery_date_missing)
    ) AS v(column_name, missing_rows)
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
FROM orders_long
ORDER BY column_name;

/* =========================================================
   Section 2: Missing order dates grouped by order status

   Purpose:
   Determine whether missing delivery dates are expected
   based on the business status of each order.
   ========================================================= */

SELECT
    LOWER(BTRIM(order_status)) AS order_status,
    COUNT(*) AS order_count,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_approved_at), '') IS NULL
    ) AS missing_approved_at,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
    ) AS missing_carrier_date,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
    ) AS missing_customer_delivery_date,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
          AND NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
    ) AS both_delivery_dates_missing,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NULL
          AND NULLIF(BTRIM(order_delivered_customer_date), '') IS NOT NULL
    ) AS carrier_missing_only,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NOT NULL
          AND NULLIF(BTRIM(order_delivered_customer_date), '') IS NULL
    ) AS customer_delivery_missing_only

FROM raw.orders
GROUP BY LOWER(BTRIM(order_status))
ORDER BY order_count DESC;