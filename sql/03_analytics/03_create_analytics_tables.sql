/*
============================================================
File: 03_create_analytics_tables.sql
Purpose:
  Create the analytics schema, dimensions, and fact tables.

Database: us_ecommerce_analytics
Source schema: staging
Target schema: analytics
============================================================
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;


/* =========================================================
   Drop analytics tables in dependency order
   ========================================================= */

DROP TABLE IF EXISTS analytics.fact_reviews;
DROP TABLE IF EXISTS analytics.fact_payments;
DROP TABLE IF EXISTS analytics.fact_order_items;
DROP TABLE IF EXISTS analytics.fact_orders;

DROP TABLE IF EXISTS analytics.dim_sellers;
DROP TABLE IF EXISTS analytics.dim_products;
DROP TABLE IF EXISTS analytics.dim_customers;
DROP TABLE IF EXISTS analytics.dim_geography;
DROP TABLE IF EXISTS analytics.dim_date;


/* =========================================================
   1. Date dimension
   ========================================================= */

CREATE TABLE analytics.dim_date
(
    date_key          INTEGER PRIMARY KEY,
    full_date         DATE NOT NULL UNIQUE,
    calendar_year     SMALLINT NOT NULL,
    calendar_quarter  SMALLINT NOT NULL,
    calendar_month    SMALLINT NOT NULL,
    month_name        TEXT NOT NULL,
    year_month        TEXT NOT NULL,
    week_of_year      SMALLINT NOT NULL,
    day_of_month      SMALLINT NOT NULL,
    day_of_week       SMALLINT NOT NULL,
    day_name          TEXT NOT NULL,
    is_weekend        BOOLEAN NOT NULL,

    CONSTRAINT chk_dim_date_quarter
        CHECK (calendar_quarter BETWEEN 1 AND 4),

    CONSTRAINT chk_dim_date_month
        CHECK (calendar_month BETWEEN 1 AND 12),

    CONSTRAINT chk_dim_date_day_of_week
        CHECK (day_of_week BETWEEN 1 AND 7)
);


/* =========================================================
   2. Geography dimension

   One row per ZIP-code prefix. Coordinates will represent
   the average location when more than one geolocation record
   exists for the same ZIP-code prefix.
   ========================================================= */

CREATE TABLE analytics.dim_geography
(
    zip_code_prefix  TEXT PRIMARY KEY,
    city             TEXT,
    state            TEXT,
    latitude         NUMERIC,
    longitude        NUMERIC,
    source_row_count INTEGER NOT NULL,

    CONSTRAINT chk_dim_geography_latitude
        CHECK (
            latitude IS NULL
            OR latitude BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_dim_geography_longitude
        CHECK (
            longitude IS NULL
            OR longitude BETWEEN -180 AND 180
        ),

    CONSTRAINT chk_dim_geography_source_count
        CHECK (source_row_count > 0)
);


/* =========================================================
   3. Customer dimension
   ========================================================= */

CREATE TABLE analytics.dim_customers
(
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_name            TEXT NOT NULL,
    customer_gender          TEXT NOT NULL,
    customer_age             SMALLINT NOT NULL,
    customer_zip_code_prefix TEXT NOT NULL,
    customer_city            TEXT NOT NULL,
    customer_state           TEXT NOT NULL,
    customer_segment         TEXT NOT NULL,

    CONSTRAINT fk_dim_customers_geography
        FOREIGN KEY (customer_zip_code_prefix)
        REFERENCES analytics.dim_geography (zip_code_prefix),

    CONSTRAINT chk_dim_customers_age
        CHECK (customer_age BETWEEN 0 AND 120)
);


/* =========================================================
   4. Product dimension
   ========================================================= */

CREATE TABLE analytics.dim_products
(
    product_id            TEXT PRIMARY KEY,
    product_category_name TEXT NOT NULL,
    product_name          TEXT NOT NULL,
    product_brand         TEXT NOT NULL,
    product_weight_g      NUMERIC NOT NULL,
    product_length_cm     NUMERIC NOT NULL,
    product_height_cm     NUMERIC NOT NULL,
    product_width_cm      NUMERIC NOT NULL,
    product_cost          NUMERIC NOT NULL,
    catalog_price         NUMERIC NOT NULL,

    CONSTRAINT chk_dim_products_weight
        CHECK (product_weight_g >= 0),

    CONSTRAINT chk_dim_products_length
        CHECK (product_length_cm >= 0),

    CONSTRAINT chk_dim_products_height
        CHECK (product_height_cm >= 0),

    CONSTRAINT chk_dim_products_width
        CHECK (product_width_cm >= 0),

    CONSTRAINT chk_dim_products_cost
        CHECK (product_cost >= 0),

    CONSTRAINT chk_dim_products_price
        CHECK (catalog_price >= 0)
);


/* =========================================================
   5. Seller dimension
   ========================================================= */

CREATE TABLE analytics.dim_sellers
(
    seller_id              TEXT PRIMARY KEY,
    seller_company_name    TEXT NOT NULL,
    seller_contact_name    TEXT NOT NULL,
    seller_contact_gender  TEXT NOT NULL,
    seller_contact_age     SMALLINT NOT NULL,
    seller_zip_code_prefix TEXT NOT NULL,
    seller_city            TEXT NOT NULL,
    seller_state           TEXT NOT NULL,

    CONSTRAINT fk_dim_sellers_geography
        FOREIGN KEY (seller_zip_code_prefix)
        REFERENCES analytics.dim_geography (zip_code_prefix),

    CONSTRAINT chk_dim_sellers_age
        CHECK (seller_contact_age BETWEEN 0 AND 120)
);


/* =========================================================
   6. Order fact

   Grain: exactly one row per order.

   Financial definitions:
   - gross merchandise value = catalog price before discount
   - net merchandise revenue = order_items.price
   - product cost = products.cost
   - merchandise profit = net revenue - product cost
   - freight is kept separately because the dataset does not
     contain the actual shipping cost
   ========================================================= */

CREATE TABLE analytics.fact_orders
(
    order_id                       TEXT PRIMARY KEY,
    customer_id                    TEXT NOT NULL,
    purchase_date_key              INTEGER NOT NULL,
    order_status                   TEXT NOT NULL,

    order_purchase_timestamp       TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    order_approved_at              TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    order_delivered_carrier_date   TIMESTAMP WITHOUT TIME ZONE,
    order_delivered_customer_date  TIMESTAMP WITHOUT TIME ZONE,
    order_estimated_delivery_date  TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    item_count                     INTEGER NOT NULL,
    payment_record_count           INTEGER NOT NULL,

    gross_merchandise_value        NUMERIC NOT NULL,
    discount_amount                NUMERIC NOT NULL,
    net_merchandise_revenue        NUMERIC NOT NULL,
    freight_charge                 NUMERIC NOT NULL,
    customer_payment               NUMERIC NOT NULL,
    product_cost                   NUMERIC NOT NULL,
    merchandise_profit             NUMERIC NOT NULL,
    merchandise_margin             NUMERIC,

    approval_hours                 NUMERIC,
    carrier_dispatch_days          NUMERIC,
    delivery_days                  NUMERIC,
    estimated_delivery_days        NUMERIC NOT NULL,
    delivery_delay_days            NUMERIC,

    is_delivered                   BOOLEAN NOT NULL,
    is_canceled                    BOOLEAN NOT NULL,
    is_late_delivery               BOOLEAN,
    is_realized_revenue            BOOLEAN NOT NULL,

    CONSTRAINT fk_fact_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES analytics.dim_customers (customer_id),

    CONSTRAINT fk_fact_orders_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES analytics.dim_date (date_key),

    CONSTRAINT chk_fact_orders_item_count
        CHECK (item_count > 0),

    CONSTRAINT chk_fact_orders_payment_count
        CHECK (payment_record_count > 0),

    CONSTRAINT chk_fact_orders_gmv
        CHECK (gross_merchandise_value >= 0),

    CONSTRAINT chk_fact_orders_discount
        CHECK (discount_amount >= 0),

    CONSTRAINT chk_fact_orders_revenue
        CHECK (net_merchandise_revenue >= 0),

    CONSTRAINT chk_fact_orders_freight
        CHECK (freight_charge >= 0),

    CONSTRAINT chk_fact_orders_payment
        CHECK (customer_payment >= 0),

    CONSTRAINT chk_fact_orders_cost
        CHECK (product_cost >= 0),

    CONSTRAINT chk_fact_orders_status_flags
        CHECK (
            NOT (is_delivered AND is_canceled)
        )
);


/* =========================================================
   7. Order-item fact

   Grain: one row per (order_id, order_item_id)
   ========================================================= */

CREATE TABLE analytics.fact_order_items
(
    order_id                 TEXT NOT NULL,
    order_item_id            SMALLINT NOT NULL,
    product_id               TEXT NOT NULL,
    seller_id                TEXT NOT NULL,
    shipping_limit_date      TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    catalog_price            NUMERIC NOT NULL,
    discount_rate            NUMERIC NOT NULL,
    discount_amount          NUMERIC NOT NULL,
    net_item_revenue         NUMERIC NOT NULL,
    freight_charge           NUMERIC NOT NULL,
    customer_item_payment    NUMERIC NOT NULL,
    product_cost             NUMERIC NOT NULL,
    merchandise_profit       NUMERIC NOT NULL,
    merchandise_margin       NUMERIC,

    is_discounted            BOOLEAN NOT NULL,
    is_realized_revenue      BOOLEAN NOT NULL,

    CONSTRAINT pk_fact_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_fact_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES analytics.fact_orders (order_id),

    CONSTRAINT fk_fact_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES analytics.dim_products (product_id),

    CONSTRAINT fk_fact_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES analytics.dim_sellers (seller_id),

    CONSTRAINT chk_fact_order_items_discount_rate
        CHECK (discount_rate BETWEEN 0 AND 1),

    CONSTRAINT chk_fact_order_items_discount_amount
        CHECK (discount_amount >= 0),

    CONSTRAINT chk_fact_order_items_revenue
        CHECK (net_item_revenue >= 0),

    CONSTRAINT chk_fact_order_items_freight
        CHECK (freight_charge >= 0),

    CONSTRAINT chk_fact_order_items_payment
        CHECK (customer_item_payment >= 0),

    CONSTRAINT chk_fact_order_items_cost
        CHECK (product_cost >= 0)
);


/* =========================================================
   8. Payment fact

   Grain: one row per (order_id, payment_sequential)
   ========================================================= */

CREATE TABLE analytics.fact_payments
(
    order_id             TEXT NOT NULL,
    payment_sequential   SMALLINT NOT NULL,
    payment_type         TEXT NOT NULL,
    payment_installments SMALLINT NOT NULL,
    payment_value        NUMERIC NOT NULL,
    is_realized_payment  BOOLEAN NOT NULL,

    CONSTRAINT pk_fact_payments
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_fact_payments_order
        FOREIGN KEY (order_id)
        REFERENCES analytics.fact_orders (order_id),

    CONSTRAINT chk_fact_payments_sequence
        CHECK (payment_sequential >= 1),

    CONSTRAINT chk_fact_payments_installments
        CHECK (payment_installments >= 0),

    CONSTRAINT chk_fact_payments_value
        CHECK (payment_value >= 0)
);


/* =========================================================
   9. Review fact

   Grain: one row per review and, based on profiling,
   one review per reviewed order.
   ========================================================= */

CREATE TABLE analytics.fact_reviews
(
    review_id                TEXT PRIMARY KEY,
    order_id                 TEXT NOT NULL UNIQUE,
    review_score             SMALLINT NOT NULL,
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    review_answer_timestamp  TIMESTAMP WITHOUT TIME ZONE NOT NULL,

    response_hours           NUMERIC NOT NULL,
    is_negative_review       BOOLEAN NOT NULL,
    has_comment              BOOLEAN NOT NULL,

    CONSTRAINT fk_fact_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES analytics.fact_orders (order_id),

    CONSTRAINT chk_fact_reviews_score
        CHECK (review_score BETWEEN 1 AND 5),

    CONSTRAINT chk_fact_reviews_sequence
        CHECK (
            review_answer_timestamp >= review_creation_date
        ),

    CONSTRAINT chk_fact_reviews_response_hours
        CHECK (response_hours >= 0)
);


/* =========================================================
   10. Table descriptions
   ========================================================= */

COMMENT ON TABLE analytics.fact_orders IS
    'Order-level fact table containing financial and delivery metrics.';

COMMENT ON TABLE analytics.fact_order_items IS
    'Item-level fact table containing discount, revenue, cost, profit, and seller details.';

COMMENT ON TABLE analytics.fact_payments IS
    'Payment-level fact table retaining multiple payment records per order.';

COMMENT ON TABLE analytics.fact_reviews IS
    'Review-level fact table containing satisfaction outcomes.';

COMMENT ON COLUMN analytics.fact_orders.merchandise_profit IS
    'Net merchandise revenue minus product cost; freight is excluded.';

COMMENT ON COLUMN analytics.fact_orders.is_realized_revenue IS
    'True only for delivered orders included in realized financial performance.';

COMMENT ON COLUMN analytics.fact_orders.is_late_delivery IS
    'True when customer delivery occurred after estimated delivery date; NULL for undelivered orders.';


COMMIT;