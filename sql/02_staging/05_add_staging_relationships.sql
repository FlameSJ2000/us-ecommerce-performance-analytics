/*
File: 05_add_staging_relationships.sql

Purpose:
Add validated foreign-key relationships and supporting indexes
to the staging layer.

Prerequisites:
- Staging tables have been loaded.
- Raw and staging row counts match.
- Relationship validation found no orphan records.

Run this script only once after creating the staging tables.
*/

BEGIN;

/* =========================================================
   1. Orders → Customers
   ========================================================= */

ALTER TABLE staging.orders
ADD CONSTRAINT fk_staging_orders_customer
FOREIGN KEY (customer_id)
REFERENCES staging.customers (customer_id);


/* =========================================================
   2. Order items → Orders, Products, Sellers
   ========================================================= */

ALTER TABLE staging.order_items
ADD CONSTRAINT fk_staging_order_items_order
FOREIGN KEY (order_id)
REFERENCES staging.orders (order_id);

ALTER TABLE staging.order_items
ADD CONSTRAINT fk_staging_order_items_product
FOREIGN KEY (product_id)
REFERENCES staging.products (product_id);

ALTER TABLE staging.order_items
ADD CONSTRAINT fk_staging_order_items_seller
FOREIGN KEY (seller_id)
REFERENCES staging.sellers (seller_id);


/* =========================================================
   3. Order payments → Orders
   ========================================================= */

ALTER TABLE staging.order_payments
ADD CONSTRAINT fk_staging_order_payments_order
FOREIGN KEY (order_id)
REFERENCES staging.orders (order_id);


/* =========================================================
   4. Order reviews → Orders
   ========================================================= */

ALTER TABLE staging.order_reviews
ADD CONSTRAINT fk_staging_order_reviews_order
FOREIGN KEY (order_id)
REFERENCES staging.orders (order_id);

COMMIT;


/* =========================================================
   Supporting indexes for frequent joins
   ========================================================= */

CREATE INDEX IF NOT EXISTS idx_staging_orders_customer_id
    ON staging.orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_staging_order_items_product_id
    ON staging.order_items (product_id);

CREATE INDEX IF NOT EXISTS idx_staging_order_items_seller_id
    ON staging.order_items (seller_id);

CREATE INDEX IF NOT EXISTS idx_staging_order_reviews_order_id
    ON staging.order_reviews (order_id);


/*
Separate indexes are not required for:

- staging.order_items(order_id)
- staging.order_payments(order_id)

because order_id is already the first column of each table's
composite primary-key index.
*/


/* Refresh planner statistics after index creation. */

ANALYZE staging.orders;
ANALYZE staging.order_items;
ANALYZE staging.order_payments;
ANALYZE staging.order_reviews;