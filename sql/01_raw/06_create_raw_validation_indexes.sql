/*
File: 06_create_raw_validation_indexes.sql

Purpose:
Create non-unique indexes on parent key columns used for
raw-data relationship validation.

The indexes improve lookup performance but do not change
the values stored in the raw tables.
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


/* Index used to match orders with customers. */
CREATE INDEX IF NOT EXISTS idx_raw_customers_customer_id
    ON raw.customers (customer_id);


/* Index used to match items, payments, and reviews with orders. */
CREATE INDEX IF NOT EXISTS idx_raw_orders_order_id
    ON raw.orders (order_id);


/* Index used to match order items with products. */
CREATE INDEX IF NOT EXISTS idx_raw_products_product_id
    ON raw.products (product_id);


/* Index used to match order items with sellers. */
CREATE INDEX IF NOT EXISTS idx_raw_sellers_seller_id
    ON raw.sellers (seller_id);


/*
Update PostgreSQL statistics so the query planner can
choose an efficient execution method.
*/
ANALYZE raw.customers;
ANALYZE raw.orders;
ANALYZE raw.products;
ANALYZE raw.sellers;


/* Verify that the four validation indexes exist. */
SELECT
    schemaname,
    tablename,
    indexname
FROM pg_indexes
WHERE schemaname = 'raw'
  AND indexname IN (
      'idx_raw_customers_customer_id',
      'idx_raw_orders_order_id',
      'idx_raw_products_product_id',
      'idx_raw_sellers_seller_id'
  )
ORDER BY tablename, indexname;