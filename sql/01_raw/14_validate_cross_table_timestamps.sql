/*
File: 14_validate_cross_table_timestamps.sql

Purpose:
Validate chronological relationships between timestamp columns
stored in different raw tables.

Rules:
1. An item's shipping deadline must not precede its order purchase.
2. A review must not be created before the customer delivery date.

Notes:
- Review dates are compared as calendar dates because
  review_creation_date may be stored at midnight.
- Orders without a customer delivery date are excluded from
  the review timing check.
- This script is read-only and does not modify data.
*/

WITH shipping_limit_validation AS (
    SELECT
        COUNT(*) AS eligible_rows,

        COUNT(*) FILTER (
            WHERE oi.shipping_limit_date::timestamp
                  < o.order_purchase_timestamp::timestamp
        ) AS violation_rows

    FROM raw.order_items AS oi
    INNER JOIN raw.orders AS o
        ON o.order_id = oi.order_id
),

review_creation_validation AS (
    SELECT
        COUNT(*) AS eligible_rows,

        COUNT(*) FILTER (
            WHERE r.review_creation_date::timestamp::date
                  < o.order_delivered_customer_date::timestamp::date
        ) AS violation_rows

    FROM raw.order_reviews AS r
    INNER JOIN raw.orders AS o
        ON o.order_id = r.order_id

    WHERE NULLIF(
        BTRIM(o.order_delivered_customer_date),
        ''
    ) IS NOT NULL
),

validation_results AS (
    SELECT
        1 AS rule_order,
        'order_items + orders'::text AS tables_checked,
        'shipping_limit_date >= order_purchase_timestamp'::text
            AS validation_rule,
        eligible_rows,
        violation_rows
    FROM shipping_limit_validation

    UNION ALL

    SELECT
        2,
        'order_reviews + orders',
        'review_creation_date >= order_delivered_customer_date',
        eligible_rows,
        violation_rows
    FROM review_creation_validation
)

SELECT
    tables_checked,
    validation_rule,
    eligible_rows,
    violation_rows,
    ROUND(
        100.0 * violation_rows / NULLIF(eligible_rows, 0),
        4
    ) AS violation_percentage,

    CASE
        WHEN violation_rows = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status

FROM validation_results
ORDER BY rule_order;