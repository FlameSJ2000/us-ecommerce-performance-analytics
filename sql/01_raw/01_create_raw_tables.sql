/*
Project: U.S. E-Commerce Performance Analytics
File: 01_create_raw_tables.sql

Purpose:
Create raw tables that mirror the source CSV files.
All source columns use TEXT so the original values can be imported
without type-conversion failures or unintended data loss.

Important:
- Run only in us_ecommerce_analytics.
- Do not add primary keys or foreign keys at the raw layer.
- Data types and constraints will be applied in the staging layer
  after data-quality validation.
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


CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id TEXT,
    customer_unique_id TEXT,
    customer_name TEXT,
    customer_gender TEXT,
    customer_age TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT,
    customer_segment TEXT
);


CREATE TABLE IF NOT EXISTS raw.geolocation (
    zip_code_prefix TEXT,
    geolocation_lat TEXT,
    geolocation_lng TEXT,
    geolocation_city TEXT,
    geolocation_state TEXT
);


CREATE TABLE IF NOT EXISTS raw.order_items (
    order_id TEXT,
    order_item_id TEXT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price TEXT,
    freight_value TEXT,
    discount_rate TEXT
);


CREATE TABLE IF NOT EXISTS raw.order_payments (
    order_id TEXT,
    payment_sequential TEXT,
    payment_type TEXT,
    payment_installments TEXT,
    payment_value TEXT
);


CREATE TABLE IF NOT EXISTS raw.order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score TEXT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT
);


CREATE TABLE IF NOT EXISTS raw.orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);


CREATE TABLE IF NOT EXISTS raw.products (
    product_id TEXT,
    product_category_name TEXT,
    product_name TEXT,
    product_brand TEXT,
    product_weight_g TEXT,
    product_length_cm TEXT,
    product_height_cm TEXT,
    product_width_cm TEXT,
    cost TEXT,
    price TEXT
);


CREATE TABLE IF NOT EXISTS raw.sellers (
    seller_id TEXT,
    seller_company_name TEXT,
    seller_contact_name TEXT,
    seller_contact_gender TEXT,
    seller_contact_age TEXT,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT
);


COMMENT ON TABLE raw.customers IS
    'Unmodified customer records imported from customers.csv.';

COMMENT ON TABLE raw.geolocation IS
    'Unmodified geolocation records imported from geolocation.csv.';

COMMENT ON TABLE raw.order_items IS
    'Unmodified order-item records imported from order_items.csv.';

COMMENT ON TABLE raw.order_payments IS
    'Unmodified payment records imported from order_payments.csv.';

COMMENT ON TABLE raw.order_reviews IS
    'Unmodified review records imported from order_reviews.csv.';

COMMENT ON TABLE raw.orders IS
    'Unmodified order records imported from orders.csv.';

COMMENT ON TABLE raw.products IS
    'Unmodified product records imported from products.csv.';

COMMENT ON TABLE raw.sellers IS
    'Unmodified seller records imported from sellers.csv.';