/*
File: 01_create_staging_tables.sql

Purpose:
Create typed staging tables for cleaned and standardized data.

Design:
- IDs and ZIP codes remain TEXT.
- Numeric fields use SMALLINT or NUMERIC.
- Date/time fields use TIMESTAMP WITHOUT TIME ZONE.
- Canceled orders may retain NULL delivery timestamps.
- Primary keys are added only where raw-key validation passed.
- Foreign keys will be added after staging data is loaded and verified.

This script does not modify the raw schema.
*/

BEGIN;

/* =========================================================
   1. Customers
   ========================================================= */

CREATE TABLE staging.customers (
    customer_id              TEXT NOT NULL,
    customer_unique_id       TEXT NOT NULL,
    customer_name            TEXT NOT NULL,
    customer_gender          TEXT NOT NULL,
    customer_age             SMALLINT NOT NULL,
    customer_zip_code_prefix TEXT NOT NULL,
    customer_city            TEXT NOT NULL,
    customer_state           TEXT NOT NULL,
    customer_segment         TEXT NOT NULL,

    CONSTRAINT pk_staging_customers
        PRIMARY KEY (customer_id),

    CONSTRAINT chk_staging_customers_age
        CHECK (customer_age >= 0)
);

COMMENT ON TABLE staging.customers IS
    'Cleaned and typed customer records sourced from raw.customers.';


/* =========================================================
   2. Geolocation
   No primary key because multiple coordinates may share a ZIP.
   ========================================================= */

CREATE TABLE staging.geolocation (
    zip_code_prefix  TEXT NOT NULL,
    geolocation_lat  NUMERIC(10, 7) NOT NULL,
    geolocation_lng  NUMERIC(10, 7) NOT NULL,
    geolocation_city TEXT NOT NULL,
    geolocation_state TEXT NOT NULL,

    CONSTRAINT chk_staging_geolocation_lat
        CHECK (geolocation_lat BETWEEN -90 AND 90),

    CONSTRAINT chk_staging_geolocation_lng
        CHECK (geolocation_lng BETWEEN -180 AND 180)
);

COMMENT ON TABLE staging.geolocation IS
    'Cleaned and typed geolocation records sourced from raw.geolocation.';


/* =========================================================
   3. Products
   ========================================================= */

CREATE TABLE staging.products (
    product_id            TEXT NOT NULL,
    product_category_name TEXT NOT NULL,
    product_name          TEXT NOT NULL,
    product_brand         TEXT NOT NULL,
    product_weight_g      NUMERIC(12, 2) NOT NULL,
    product_length_cm     NUMERIC(12, 2) NOT NULL,
    product_height_cm     NUMERIC(12, 2) NOT NULL,
    product_width_cm      NUMERIC(12, 2) NOT NULL,
    cost                   NUMERIC(14, 2) NOT NULL,
    price                  NUMERIC(14, 2) NOT NULL,

    CONSTRAINT pk_staging_products
        PRIMARY KEY (product_id),

    CONSTRAINT chk_staging_products_weight
        CHECK (product_weight_g >= 0),

    CONSTRAINT chk_staging_products_length
        CHECK (product_length_cm >= 0),

    CONSTRAINT chk_staging_products_height
        CHECK (product_height_cm >= 0),

    CONSTRAINT chk_staging_products_width
        CHECK (product_width_cm >= 0),

    CONSTRAINT chk_staging_products_cost
        CHECK (cost >= 0),

    CONSTRAINT chk_staging_products_price
        CHECK (price >= 0)
);

COMMENT ON TABLE staging.products IS
    'Cleaned and typed product records sourced from raw.products.';


/* =========================================================
   4. Sellers
   ========================================================= */

CREATE TABLE staging.sellers (
    seller_id              TEXT NOT NULL,
    seller_company_name    TEXT NOT NULL,
    seller_contact_name    TEXT NOT NULL,
    seller_contact_gender  TEXT NOT NULL,
    seller_contact_age     SMALLINT NOT NULL,
    seller_zip_code_prefix TEXT NOT NULL,
    seller_city            TEXT NOT NULL,
    seller_state           TEXT NOT NULL,

    CONSTRAINT pk_staging_sellers
        PRIMARY KEY (seller_id),

    CONSTRAINT chk_staging_sellers_age
        CHECK (seller_contact_age >= 0)
);

COMMENT ON TABLE staging.sellers IS
    'Cleaned and typed seller records sourced from raw.sellers.';


/* =========================================================
   5. Orders
   Delivery timestamps remain nullable for canceled orders.
   ========================================================= */

CREATE TABLE staging.orders (
    order_id                       TEXT NOT NULL,
    customer_id                    TEXT NOT NULL,
    order_status                   TEXT NOT NULL,
    order_purchase_timestamp       TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    order_approved_at              TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    order_delivered_carrier_date   TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_customer_date  TIMESTAMP WITHOUT TIME ZONE,
    order_estimated_delivery_date  TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    CONSTRAINT pk_staging_orders
        PRIMARY KEY (order_id),

    CONSTRAINT chk_staging_orders_approval_sequence
        CHECK (
            order_approved_at >= order_purchase_timestamp
        ),

    CONSTRAINT chk_staging_orders_estimate_sequence
        CHECK (
            order_estimated_delivery_date >= order_purchase_timestamp
        ),

    CONSTRAINT chk_staging_orders_carrier_sequence
        CHECK (
            order_delivered_carrier_date IS NULL
            OR order_delivered_carrier_date >= order_approved_at
        ),

    CONSTRAINT chk_staging_orders_customer_delivery_sequence
        CHECK (
            order_delivered_customer_date IS NULL
            OR order_delivered_carrier_date IS NULL
            OR order_delivered_customer_date >= order_delivered_carrier_date
        )
);

COMMENT ON TABLE staging.orders IS
    'Cleaned and typed order records sourced from raw.orders.';


/* =========================================================
   6. Order items
   ========================================================= */

CREATE TABLE staging.order_items (
    order_id            TEXT NOT NULL,
    order_item_id       SMALLINT NOT NULL,
    product_id          TEXT NOT NULL,
    seller_id           TEXT NOT NULL,
    shipping_limit_date TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    price               NUMERIC(14, 2) NOT NULL,
    freight_value       NUMERIC(14, 2) NOT NULL,
    discount_rate       NUMERIC(6, 5) NOT NULL,

    CONSTRAINT pk_staging_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT chk_staging_order_items_id
        CHECK (order_item_id >= 1),

    CONSTRAINT chk_staging_order_items_price
        CHECK (price >= 0),

    CONSTRAINT chk_staging_order_items_freight
        CHECK (freight_value >= 0),

    CONSTRAINT chk_staging_order_items_discount
        CHECK (discount_rate BETWEEN 0 AND 1)
);

COMMENT ON TABLE staging.order_items IS
    'Cleaned and typed order-item records sourced from raw.order_items.';


/* =========================================================
   7. Order payments
   ========================================================= */

CREATE TABLE staging.order_payments (
    order_id             TEXT NOT NULL,
    payment_sequential   SMALLINT NOT NULL,
    payment_type         TEXT NOT NULL,
    payment_installments SMALLINT NOT NULL,
    payment_value        NUMERIC(14, 2) NOT NULL,

    CONSTRAINT pk_staging_order_payments
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT chk_staging_payments_sequence
        CHECK (payment_sequential >= 1),

    CONSTRAINT chk_staging_payments_installments
        CHECK (payment_installments >= 0),

    CONSTRAINT chk_staging_payments_value
        CHECK (payment_value >= 0)
);

COMMENT ON TABLE staging.order_payments IS
    'Cleaned and typed payment records sourced from raw.order_payments.';


/* =========================================================
   8. Order reviews
   ========================================================= */

CREATE TABLE staging.order_reviews (
    review_id               TEXT NOT NULL,
    order_id                TEXT NOT NULL,
    review_score            SMALLINT NOT NULL,
    review_comment_title    TEXT NOT NULL,
    review_comment_message  TEXT NOT NULL,
    review_creation_date    TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    review_answer_timestamp TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    CONSTRAINT pk_staging_order_reviews
        PRIMARY KEY (review_id),

    CONSTRAINT chk_staging_reviews_score
        CHECK (review_score BETWEEN 1 AND 5),

    CONSTRAINT chk_staging_reviews_timestamp_sequence
        CHECK (
            review_answer_timestamp >= review_creation_date
        )
);

COMMENT ON TABLE staging.order_reviews IS
    'Cleaned and typed review records sourced from raw.order_reviews.';

COMMIT;