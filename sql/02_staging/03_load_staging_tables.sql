/*
File: 03_load_staging_tables.sql

Purpose:
Clean, standardize, cast, and load data from raw tables
into typed staging tables.

Important:
- Raw tables are not modified.
- TRUNCATE affects only staging tables.
- The transaction rolls back entirely if any insert fails.
*/

BEGIN;

/* Make this script safely rerunnable by clearing staging data only. */
TRUNCATE TABLE
    staging.order_items,
    staging.order_payments,
    staging.order_reviews,
    staging.orders,
    staging.customers,
    staging.geolocation,
    staging.products,
    staging.sellers;


/* =========================================================
   1. Customers
   ========================================================= */

INSERT INTO staging.customers (
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
    BTRIM(customer_id),
    BTRIM(customer_unique_id),
    BTRIM(customer_name),
    LOWER(BTRIM(customer_gender)),
    BTRIM(customer_age)::smallint,
    BTRIM(customer_zip_code_prefix),
    INITCAP(BTRIM(customer_city)),
    UPPER(BTRIM(customer_state)),
    LOWER(BTRIM(customer_segment))
FROM raw.customers;


/* =========================================================
   2. Geolocation
   ========================================================= */

INSERT INTO staging.geolocation (
    zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    BTRIM(zip_code_prefix),
    BTRIM(geolocation_lat)::numeric,
    BTRIM(geolocation_lng)::numeric,
    INITCAP(BTRIM(geolocation_city)),
    UPPER(BTRIM(geolocation_state))
FROM raw.geolocation;


/* =========================================================
   3. Products
   ========================================================= */

INSERT INTO staging.products (
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
)
SELECT
    BTRIM(product_id),
    LOWER(BTRIM(product_category_name)),
    BTRIM(product_name),
    BTRIM(product_brand),
    BTRIM(product_weight_g)::numeric,
    BTRIM(product_length_cm)::numeric,
    BTRIM(product_height_cm)::numeric,
    BTRIM(product_width_cm)::numeric,
    BTRIM(cost)::numeric,
    BTRIM(price)::numeric
FROM raw.products;


/* =========================================================
   4. Sellers
   ========================================================= */

INSERT INTO staging.sellers (
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
    BTRIM(seller_id),
    BTRIM(seller_company_name),
    BTRIM(seller_contact_name),
    LOWER(BTRIM(seller_contact_gender)),
    BTRIM(seller_contact_age)::smallint,
    BTRIM(seller_zip_code_prefix),
    INITCAP(BTRIM(seller_city)),
    UPPER(BTRIM(seller_state))
FROM raw.sellers;


/* =========================================================
   5. Orders
   Empty delivery timestamps become NULL.
   ========================================================= */

INSERT INTO staging.orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    BTRIM(order_id),
    BTRIM(customer_id),
    LOWER(BTRIM(order_status)),
    BTRIM(order_purchase_timestamp)::timestamp,
    BTRIM(order_approved_at)::timestamp,

    NULLIF(
        BTRIM(order_delivered_carrier_date),
        ''
    )::timestamp,

    NULLIF(
        BTRIM(order_delivered_customer_date),
        ''
    )::timestamp,

    BTRIM(order_estimated_delivery_date)::timestamp
FROM raw.orders;


/* =========================================================
   6. Order items
   ========================================================= */

INSERT INTO staging.order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    discount_rate
)
SELECT
    BTRIM(order_id),
    BTRIM(order_item_id)::smallint,
    BTRIM(product_id),
    BTRIM(seller_id),
    BTRIM(shipping_limit_date)::timestamp,
    BTRIM(price)::numeric,
    BTRIM(freight_value)::numeric,
    BTRIM(discount_rate)::numeric
FROM raw.order_items;


/* =========================================================
   7. Order payments
   ========================================================= */

INSERT INTO staging.order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    BTRIM(order_id),
    BTRIM(payment_sequential)::smallint,
    LOWER(BTRIM(payment_type)),
    BTRIM(payment_installments)::smallint,
    BTRIM(payment_value)::numeric
FROM raw.order_payments;


/* =========================================================
   8. Order reviews
   ========================================================= */

INSERT INTO staging.order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    BTRIM(review_id),
    BTRIM(order_id),
    BTRIM(review_score)::smallint,
    BTRIM(review_comment_title),
    BTRIM(review_comment_message),
    BTRIM(review_creation_date)::timestamp,
    BTRIM(review_answer_timestamp)::timestamp
FROM raw.order_reviews;

COMMIT;


/* Refresh PostgreSQL statistics after loading. */

ANALYZE staging.customers;
ANALYZE staging.geolocation;
ANALYZE staging.products;
ANALYZE staging.sellers;
ANALYZE staging.orders;
ANALYZE staging.order_items;
ANALYZE staging.order_payments;
ANALYZE staging.order_reviews;