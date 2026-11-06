/*
Project: U.S. E-Commerce Performance Analytics
File: 02_verify_raw_tables.sql

Purpose:
Verify that all eight raw tables exist and that their column counts
match the source CSV structures before importing any data.
*/

SELECT
    current_database() AS database_name,
    table_schema,
    table_name,
    COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'raw'
GROUP BY
    table_schema,
    table_name
ORDER BY
    table_name;