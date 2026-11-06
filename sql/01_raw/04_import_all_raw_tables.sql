/*
Project: U.S. E-Commerce Performance Analytics
File: 04_import_all_raw_tables.sql

Purpose:
Reload all eight source CSV files into the raw schema.

Important:
- Run this file with psql, not pgAdmin Query Tool.
- All existing rows in the eight raw tables are removed first.
- The transaction is committed only after all files load successfully.
- Source CSV files are not modified.
*/

\set ON_ERROR_STOP on
\timing on

\connect us_ecommerce_analytics

SELECT
    current_database() AS database_name,
    current_user AS connected_user;

BEGIN;

TRUNCATE TABLE
    raw.customers,
    raw.geolocation,
    raw.order_items,
    raw.order_payments,
    raw.order_reviews,
    raw.orders,
    raw.products,
    raw.sellers;

\echo Loading customers.csv...
\copy raw.customers (customer_id, customer_unique_id, customer_name, customer_gender, customer_age, customer_zip_code_prefix, customer_city, customer_state, customer_segment) FROM 'S:/us-ecommerce-performance-analytics/data/raw/customers.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading geolocation.csv...
\copy raw.geolocation (zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state) FROM 'S:/us-ecommerce-performance-analytics/data/raw/geolocation.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading order_items.csv...
\copy raw.order_items (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value, discount_rate) FROM 'S:/us-ecommerce-performance-analytics/data/raw/order_items.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading order_payments.csv...
\copy raw.order_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value) FROM 'S:/us-ecommerce-performance-analytics/data/raw/order_payments.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading order_reviews.csv...
\copy raw.order_reviews (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp) FROM 'S:/us-ecommerce-performance-analytics/data/raw/order_reviews.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading orders.csv...
\copy raw.orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date) FROM 'S:/us-ecommerce-performance-analytics/data/raw/orders.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading products.csv...
\copy raw.products (product_id, product_category_name, product_name, product_brand, product_weight_g, product_length_cm, product_height_cm, product_width_cm, cost, price) FROM 'S:/us-ecommerce-performance-analytics/data/raw/products.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

\echo Loading sellers.csv...
\copy raw.sellers (seller_id, seller_company_name, seller_contact_name, seller_contact_gender, seller_contact_age, seller_zip_code_prefix, seller_city, seller_state) FROM 'S:/us-ecommerce-performance-analytics/data/raw/sellers.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

COMMIT;

SELECT 1 AS table_order, 'customers' AS table_name, COUNT(*) AS row_count FROM raw.customers
UNION ALL
SELECT 2, 'geolocation', COUNT(*) FROM raw.geolocation
UNION ALL
SELECT 3, 'order_items', COUNT(*) FROM raw.order_items
UNION ALL
SELECT 4, 'order_payments', COUNT(*) FROM raw.order_payments
UNION ALL
SELECT 5, 'order_reviews', COUNT(*) FROM raw.order_reviews
UNION ALL
SELECT 6, 'orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT 7, 'products', COUNT(*) FROM raw.products
UNION ALL
SELECT 8, 'sellers', COUNT(*) FROM raw.sellers
ORDER BY table_order;