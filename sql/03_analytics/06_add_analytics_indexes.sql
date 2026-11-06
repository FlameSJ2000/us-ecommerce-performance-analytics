/*
============================================================
File: 06_add_analytics_indexes.sql
Purpose:
  Add analytical indexes for financial, logistics,
  satisfaction, geographic, and modeling queries.

Database: us_ecommerce_analytics
============================================================
*/


/* =========================================================
   1. Order fact indexes
   ========================================================= */

CREATE INDEX IF NOT EXISTS idx_fact_orders_purchase_date
    ON analytics.fact_orders (purchase_date_key);

CREATE INDEX IF NOT EXISTS idx_fact_orders_customer
    ON analytics.fact_orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_fact_orders_status
    ON analytics.fact_orders (order_status);

CREATE INDEX IF NOT EXISTS idx_fact_orders_realized_date
    ON analytics.fact_orders (purchase_date_key)
    WHERE is_realized_revenue = TRUE;

CREATE INDEX IF NOT EXISTS idx_fact_orders_late_delivery
    ON analytics.fact_orders (is_late_delivery)
    WHERE is_delivered = TRUE;


/* =========================================================
   2. Order-item fact indexes
   ========================================================= */

CREATE INDEX IF NOT EXISTS idx_fact_order_items_product
    ON analytics.fact_order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_fact_order_items_seller
    ON analytics.fact_order_items (seller_id);

CREATE INDEX IF NOT EXISTS idx_fact_order_items_realized_product
    ON analytics.fact_order_items
       (product_id, seller_id)
    WHERE is_realized_revenue = TRUE;


/* =========================================================
   3. Payment and review indexes
   ========================================================= */

CREATE INDEX IF NOT EXISTS idx_fact_payments_type
    ON analytics.fact_payments (payment_type);

CREATE INDEX IF NOT EXISTS idx_fact_reviews_score
    ON analytics.fact_reviews (review_score);

CREATE INDEX IF NOT EXISTS idx_fact_reviews_negative
    ON analytics.fact_reviews (order_id)
    WHERE is_negative_review = TRUE;


/* =========================================================
   4. Dimension indexes
   ========================================================= */

CREATE INDEX IF NOT EXISTS idx_dim_customers_state_segment
    ON analytics.dim_customers
       (customer_state, customer_segment);

CREATE INDEX IF NOT EXISTS idx_dim_customers_zip
    ON analytics.dim_customers
       (customer_zip_code_prefix);

CREATE INDEX IF NOT EXISTS idx_dim_products_category
    ON analytics.dim_products
       (product_category_name);

CREATE INDEX IF NOT EXISTS idx_dim_sellers_state
    ON analytics.dim_sellers
       (seller_state);

CREATE INDEX IF NOT EXISTS idx_dim_sellers_zip
    ON analytics.dim_sellers
       (seller_zip_code_prefix);

CREATE INDEX IF NOT EXISTS idx_dim_geography_state
    ON analytics.dim_geography (state);


/* =========================================================
   5. Refresh planner statistics
   ========================================================= */

ANALYZE analytics.fact_orders;
ANALYZE analytics.fact_order_items;
ANALYZE analytics.fact_payments;
ANALYZE analytics.fact_reviews;
ANALYZE analytics.dim_customers;
ANALYZE analytics.dim_products;
ANALYZE analytics.dim_sellers;
ANALYZE analytics.dim_geography;


/* =========================================================
   6. Verify analytics indexes
   ========================================================= */

SELECT
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE schemaname = 'analytics'
ORDER BY
    tablename,
    indexname;