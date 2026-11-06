-- Project: U.S. E-Commerce Performance Analytics
-- Purpose: Verify the active PostgreSQL database, user, and version.
-- Expected database: us_ecommerce_analytics
SELECT
    current_database() AS database_name,
    current_user AS connected_user,
    current_setting('server_version') AS postgres_version;