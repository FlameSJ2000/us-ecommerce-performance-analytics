/*
File: 13_validate_raw_timestamp_sequences.sql

Purpose:
Validate the chronological order of timestamp fields within raw tables.

Expected result:
violation_rows should be 0 for every validation rule.

This script is read-only and does not modify any data.
*/

WITH order_validation AS (
    SELECT
        COUNT(*) FILTER (
            WHERE order_purchase_timestamp::timestamp
                  > order_approved_at::timestamp
        ) AS approved_before_purchase,

        COUNT(*) FILTER (
            WHERE order_purchase_timestamp::timestamp
                  > order_estimated_delivery_date::timestamp
        ) AS estimate_before_purchase,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NOT NULL
              AND order_purchase_timestamp::timestamp
                  > order_delivered_carrier_date::timestamp
        ) AS carrier_before_purchase,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NOT NULL
              AND order_approved_at::timestamp
                  > order_delivered_carrier_date::timestamp
        ) AS carrier_before_approval,

        COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(order_delivered_carrier_date), '') IS NOT NULL
              AND NULLIF(BTRIM(order_delivered_customer_date), '') IS NOT NULL
              AND order_delivered_carrier_date::timestamp
                  > order_delivered_customer_date::timestamp
        ) AS customer_delivery_before_carrier

    FROM raw.orders
),

review_validation AS (
    SELECT
        COUNT(*) FILTER (
            WHERE review_creation_date::timestamp
                  > review_answer_timestamp::timestamp
        ) AS answer_before_review_creation

    FROM raw.order_reviews
),

validation_results AS (
    SELECT
        1 AS rule_order,
        'orders'::text AS table_name,
        'order_approved_at >= order_purchase_timestamp'::text
            AS validation_rule,
        approved_before_purchase AS violation_rows
    FROM order_validation

    UNION ALL

    SELECT
        2,
        'orders',
        'order_estimated_delivery_date >= order_purchase_timestamp',
        estimate_before_purchase
    FROM order_validation

    UNION ALL

    SELECT
        3,
        'orders',
        'order_delivered_carrier_date >= order_purchase_timestamp',
        carrier_before_purchase
    FROM order_validation

    UNION ALL

    SELECT
        4,
        'orders',
        'order_delivered_carrier_date >= order_approved_at',
        carrier_before_approval
    FROM order_validation

    UNION ALL

    SELECT
        5,
        'orders',
        'order_delivered_customer_date >= order_delivered_carrier_date',
        customer_delivery_before_carrier
    FROM order_validation

    UNION ALL

    SELECT
        6,
        'order_reviews',
        'review_answer_timestamp >= review_creation_date',
        answer_before_review_creation
    FROM review_validation
)

SELECT
    table_name,
    validation_rule,
    violation_rows,
    CASE
        WHEN violation_rows = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status
FROM validation_results
ORDER BY rule_order;