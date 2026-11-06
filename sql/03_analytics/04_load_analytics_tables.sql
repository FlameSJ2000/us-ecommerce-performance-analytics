/*
============================================================
File: 04_load_analytics_tables.sql
Purpose:
  Load dimensions and fact tables in the analytics schema.

Database: us_ecommerce_analytics
Source schema: staging
Target schema: analytics
============================================================
*/

BEGIN;


/* =========================================================
   1. Empty analytics tables for a repeatable full refresh
   ========================================================= */

TRUNCATE TABLE
    analytics.fact_reviews,
    analytics.fact_payments,
    analytics.fact_order_items,
    analytics.fact_orders,
    analytics.dim_sellers,
    analytics.dim_products,
    analytics.dim_customers,
    analytics.dim_geography,
    analytics.dim_date;


/* =========================================================
   2. Validate geography coverage before loading

   Stop the transaction if customer or seller ZIP prefixes
   cannot be found in staging.geolocation.
   ========================================================= */

DO
$$
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM staging.customers AS c
        LEFT JOIN staging.geolocation AS g
            ON g.zip_code_prefix =
               c.customer_zip_code_prefix
        WHERE g.zip_code_prefix IS NULL
    )
    THEN
        RAISE EXCEPTION
            'Customer ZIP-code prefixes are missing from staging.geolocation.';
    END IF;

    IF EXISTS
    (
        SELECT 1
        FROM staging.sellers AS s
        LEFT JOIN staging.geolocation AS g
            ON g.zip_code_prefix =
               s.seller_zip_code_prefix
        WHERE g.zip_code_prefix IS NULL
    )
    THEN
        RAISE EXCEPTION
            'Seller ZIP-code prefixes are missing from staging.geolocation.';
    END IF;
END;
$$;


/* =========================================================
   3. Load date dimension

   The range covers every timestamp found in the transactional
   tables, not only purchase dates.
   ========================================================= */

WITH all_event_dates AS
(
    SELECT order_purchase_timestamp::date AS event_date
    FROM staging.orders

    UNION ALL

    SELECT order_approved_at::date
    FROM staging.orders

    UNION ALL

    SELECT order_delivered_carrier_date::date
    FROM staging.orders
    WHERE order_delivered_carrier_date IS NOT NULL

    UNION ALL

    SELECT order_delivered_customer_date::date
    FROM staging.orders
    WHERE order_delivered_customer_date IS NOT NULL

    UNION ALL

    SELECT order_estimated_delivery_date::date
    FROM staging.orders

    UNION ALL

    SELECT shipping_limit_date::date
    FROM staging.order_items

    UNION ALL

    SELECT review_creation_date::date
    FROM staging.order_reviews

    UNION ALL

    SELECT review_answer_timestamp::date
    FROM staging.order_reviews
),
date_bounds AS
(
    SELECT
        MIN(event_date) AS minimum_date,
        MAX(event_date) AS maximum_date
    FROM all_event_dates
)
INSERT INTO analytics.dim_date
(
    date_key,
    full_date,
    calendar_year,
    calendar_quarter,
    calendar_month,
    month_name,
    year_month,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
)
SELECT
    TO_CHAR(d.full_date, 'YYYYMMDD')::integer,
    d.full_date::date,
    EXTRACT(YEAR FROM d.full_date)::smallint,
    EXTRACT(QUARTER FROM d.full_date)::smallint,
    EXTRACT(MONTH FROM d.full_date)::smallint,
    TRIM(TO_CHAR(d.full_date, 'Month')),
    TO_CHAR(d.full_date, 'YYYY-MM'),
    EXTRACT(WEEK FROM d.full_date)::smallint,
    EXTRACT(DAY FROM d.full_date)::smallint,
    EXTRACT(ISODOW FROM d.full_date)::smallint,
    TRIM(TO_CHAR(d.full_date, 'Day')),
    EXTRACT(ISODOW FROM d.full_date) IN (6, 7)
FROM date_bounds AS b
CROSS JOIN LATERAL GENERATE_SERIES
(
    b.minimum_date,
    b.maximum_date,
    INTERVAL '1 day'
) AS d(full_date);


/* =========================================================
   4. Load geography dimension

   When a ZIP prefix contains multiple coordinate records,
   average coordinates are used as the ZIP centroid.
   ========================================================= */

INSERT INTO analytics.dim_geography
(
    zip_code_prefix,
    city,
    state,
    latitude,
    longitude,
    source_row_count
)
SELECT
    zip_code_prefix,
    MODE() WITHIN GROUP (
        ORDER BY geolocation_city
    ) AS city,
    MODE() WITHIN GROUP (
        ORDER BY geolocation_state
    ) AS state,
    AVG(geolocation_lat) AS latitude,
    AVG(geolocation_lng) AS longitude,
    COUNT(*)::integer AS source_row_count
FROM staging.geolocation
GROUP BY
    zip_code_prefix;


/* =========================================================
   5. Load customer dimension
   ========================================================= */

INSERT INTO analytics.dim_customers
(
    customer_id,
    customer_unique_id,
    customer_name,
    customer_gender,
    customer_age,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    customer_segment
)
SELECT
    customer_id,
    customer_unique_id,
    customer_name,
    customer_gender,
    customer_age,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    customer_segment
FROM staging.customers;


/* =========================================================
   6. Load product dimension
   ========================================================= */

INSERT INTO analytics.dim_products
(
    product_id,
    product_category_name,
    product_name,
    product_brand,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_cost,
    catalog_price
)
SELECT
    product_id,
    product_category_name,
    product_name,
    product_brand,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    cost,
    price
FROM staging.products;


/* =========================================================
   7. Load seller dimension
   ========================================================= */

INSERT INTO analytics.dim_sellers
(
    seller_id,
    seller_company_name,
    seller_contact_name,
    seller_contact_gender,
    seller_contact_age,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    seller_company_name,
    seller_contact_name,
    seller_contact_gender,
    seller_contact_age,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM staging.sellers;


/* =========================================================
   8. Load order fact

   Grain: one row per order.
   ========================================================= */

WITH item_totals AS
(
    SELECT
        oi.order_id,
        COUNT(*)::integer AS item_count,

        SUM(p.price) AS gross_merchandise_value,

        SUM(
            p.price - oi.price
        ) AS discount_amount,

        SUM(oi.price) AS net_merchandise_revenue,

        SUM(oi.freight_value) AS freight_charge,

        SUM(p.cost) AS product_cost,

        SUM(
            oi.price - p.cost
        ) AS merchandise_profit

    FROM staging.order_items AS oi
    INNER JOIN staging.products AS p
        ON p.product_id = oi.product_id

    GROUP BY
        oi.order_id
),
payment_totals AS
(
    SELECT
        order_id,
        COUNT(*)::integer AS payment_record_count,
        SUM(payment_value) AS customer_payment
    FROM staging.order_payments
    GROUP BY
        order_id
)
INSERT INTO analytics.fact_orders
(
    order_id,
    customer_id,
    purchase_date_key,
    order_status,

    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    item_count,
    payment_record_count,

    gross_merchandise_value,
    discount_amount,
    net_merchandise_revenue,
    freight_charge,
    customer_payment,
    product_cost,
    merchandise_profit,
    merchandise_margin,

    approval_hours,
    carrier_dispatch_days,
    delivery_days,
    estimated_delivery_days,
    delivery_delay_days,

    is_delivered,
    is_canceled,
    is_late_delivery,
    is_realized_revenue
)
SELECT
    o.order_id,
    o.customer_id,

    TO_CHAR(
        o.order_purchase_timestamp,
        'YYYYMMDD'
    )::integer AS purchase_date_key,

    o.order_status,

    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    i.item_count,
    p.payment_record_count,

    i.gross_merchandise_value,
    i.discount_amount,
    i.net_merchandise_revenue,
    i.freight_charge,
    p.customer_payment,
    i.product_cost,
    i.merchandise_profit,

    ROUND(
        100.0 * i.merchandise_profit
        / NULLIF(i.net_merchandise_revenue, 0),
        4
    ) AS merchandise_margin,

    ROUND(
        EXTRACT(
            EPOCH FROM
            (
                o.order_approved_at
                - o.order_purchase_timestamp
            )
        ) / 3600.0,
        4
    ) AS approval_hours,

    CASE
        WHEN o.order_delivered_carrier_date IS NULL
            THEN NULL
        ELSE
            ROUND(
                EXTRACT(
                    EPOCH FROM
                    (
                        o.order_delivered_carrier_date
                        - o.order_purchase_timestamp
                    )
                ) / 86400.0,
                4
            )
    END AS carrier_dispatch_days,

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN NULL
        ELSE
            ROUND(
                EXTRACT(
                    EPOCH FROM
                    (
                        o.order_delivered_customer_date
                        - o.order_purchase_timestamp
                    )
                ) / 86400.0,
                4
            )
    END AS delivery_days,

    ROUND(
        EXTRACT(
            EPOCH FROM
            (
                o.order_estimated_delivery_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0,
        4
    ) AS estimated_delivery_days,

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN NULL
        ELSE
            ROUND(
                EXTRACT(
                    EPOCH FROM
                    (
                        o.order_delivered_customer_date
                        - o.order_estimated_delivery_date
                    )
                ) / 86400.0,
                4
            )
    END AS delivery_delay_days,

    o.order_status = 'delivered'
        AS is_delivered,

    o.order_status = 'canceled'
        AS is_canceled,

    CASE
        WHEN o.order_delivered_customer_date IS NULL
            THEN NULL
        ELSE
            o.order_delivered_customer_date
                > o.order_estimated_delivery_date
    END AS is_late_delivery,

    o.order_status = 'delivered'
        AS is_realized_revenue

FROM staging.orders AS o
INNER JOIN item_totals AS i
    ON i.order_id = o.order_id
INNER JOIN payment_totals AS p
    ON p.order_id = o.order_id;


/* =========================================================
   9. Load order-item fact

   Grain: one row per (order_id, order_item_id).
   ========================================================= */

INSERT INTO analytics.fact_order_items
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,

    catalog_price,
    discount_rate,
    discount_amount,
    net_item_revenue,
    freight_charge,
    customer_item_payment,
    product_cost,
    merchandise_profit,
    merchandise_margin,

    is_discounted,
    is_realized_revenue
)
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,

    p.catalog_price,
    oi.discount_rate,

    p.catalog_price - oi.price
        AS discount_amount,

    oi.price AS net_item_revenue,
    oi.freight_value AS freight_charge,

    oi.price + oi.freight_value
        AS customer_item_payment,

    p.product_cost,

    oi.price - p.product_cost
        AS merchandise_profit,

    ROUND(
        100.0 * (oi.price - p.product_cost)
        / NULLIF(oi.price, 0),
        4
    ) AS merchandise_margin,

    oi.discount_rate > 0
        AS is_discounted,

    o.is_realized_revenue

FROM staging.order_items AS oi
INNER JOIN analytics.dim_products AS p
    ON p.product_id = oi.product_id
INNER JOIN analytics.fact_orders AS o
    ON o.order_id = oi.order_id;


/* =========================================================
   10. Load payment fact

   Grain: one row per (order_id, payment_sequential).
   ========================================================= */

INSERT INTO analytics.fact_payments
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    is_realized_payment
)
SELECT
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    o.is_realized_revenue
FROM staging.order_payments AS p
INNER JOIN analytics.fact_orders AS o
    ON o.order_id = p.order_id;


/* =========================================================
   11. Load review fact

   Negative review definition:
   review score of 1 or 2.
   ========================================================= */

INSERT INTO analytics.fact_reviews
(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    response_hours,
    is_negative_review,
    has_comment
)
SELECT
    r.review_id,
    r.order_id,
    r.review_score,
    NULLIF(BTRIM(r.review_comment_title), ''),
    NULLIF(BTRIM(r.review_comment_message), ''),
    r.review_creation_date,
    r.review_answer_timestamp,

    ROUND(
        EXTRACT(
            EPOCH FROM
            (
                r.review_answer_timestamp
                - r.review_creation_date
            )
        ) / 3600.0,
        4
    ) AS response_hours,

    r.review_score <= 2
        AS is_negative_review,

    (
        NULLIF(BTRIM(r.review_comment_title), '') IS NOT NULL
        OR
        NULLIF(BTRIM(r.review_comment_message), '') IS NOT NULL
    ) AS has_comment

FROM staging.order_reviews AS r;


/* =========================================================
   12. Complete transaction
   ========================================================= */

COMMIT;


/* =========================================================
   13. Refresh PostgreSQL statistics
   ========================================================= */

ANALYZE analytics.dim_date;
ANALYZE analytics.dim_geography;
ANALYZE analytics.dim_customers;
ANALYZE analytics.dim_products;
ANALYZE analytics.dim_sellers;
ANALYZE analytics.fact_orders;
ANALYZE analytics.fact_order_items;
ANALYZE analytics.fact_payments;
ANALYZE analytics.fact_reviews;