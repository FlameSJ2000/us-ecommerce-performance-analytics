-- Project: U.S. E-Commerce Performance Analytics
-- Purpose: Create schemas for raw, staging, and analytical data.
-- Required database: us_ecommerce_analytics
-- This script is safe to run repeatedly.

DO $$
BEGIN
    IF current_database() <> 'us_ecommerce_analytics' THEN
        RAISE EXCEPTION
            'Wrong database: connected to %. Connect to us_ecommerce_analytics.',
            current_database();
    END IF;
END
$$;

CREATE SCHEMA IF NOT EXISTS raw AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS staging AUTHORIZATION postgres;
CREATE SCHEMA IF NOT EXISTS analytics AUTHORIZATION postgres;

COMMENT ON SCHEMA raw IS
    'Original data imported from source CSV files with minimal transformation.';

COMMENT ON SCHEMA staging IS
    'Cleaned and standardized data prepared from the raw schema.';

COMMENT ON SCHEMA analytics IS
    'Order-level analytical datasets, engineered features, and analysis views.';