/*
Project: U.S. E-Commerce Performance Analytics
File: 01_import_sellers.sql

Purpose:
Reload sellers.csv into raw.sellers using PostgreSQL psql \copy.

Important:
- This file must be run with psql, not pgAdmin Query Tool.
- TRUNCATE removes existing rows from raw.sellers before reloading.
- It does not remove the table.
- It does not affect staging, analytics, or superstore_analytics.
*/

\set ON_ERROR_STOP on

\connect us_ecommerce_analytics

SELECT
    current_database() AS database_name,
    current_user AS connected_user;

TRUNCATE TABLE raw.sellers;

\copy raw.sellers (seller_id, seller_company_name, seller_contact_name, seller_contact_gender, seller_contact_age, seller_zip_code_prefix, seller_city, seller_state) FROM 'S:/us-ecommerce-performance-analytics/data/raw/sellers.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8')

SELECT
    COUNT(*) AS imported_row_count
FROM raw.sellers;

SELECT
    seller_id,
    seller_company_name,
    seller_contact_name,
    seller_contact_gender,
    seller_contact_age,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM raw.sellers
LIMIT 5;