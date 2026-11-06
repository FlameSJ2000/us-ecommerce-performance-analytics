-- Section 35.3.2
-- Locate original delivery timestamp columns
-- Metadata inspection only

SELECT
    table_schema,
    table_name,
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE
    table_name ILIKE '%order%'
    AND (
        column_name ILIKE '%deliver%'
        OR column_name ILIKE '%ship%'
        OR column_name ILIKE '%carrier%'
        OR column_name ILIKE '%purchase%'
        OR column_name ILIKE '%status%'
    )
    AND table_schema NOT IN (
        'pg_catalog',
        'information_schema'
    )
ORDER BY
    table_schema,
    table_name,
    ordinal_position;
