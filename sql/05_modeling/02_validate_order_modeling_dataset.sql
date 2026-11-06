/* =========================================================
   Validate Order-Level Modeling Dataset

   Expected grain:
   One row per delivered order

   Expected total:
   904,366 rows
   ========================================================= */

WITH validation_stats AS (
    SELECT
        COUNT(*) AS total_rows,

        COUNT(DISTINCT order_id)
            AS distinct_orders,

        COUNT(*) - COUNT(DISTINCT order_id)
            AS duplicate_order_rows,

        COUNT(*) FILTER (
            WHERE data_split = 'train'
        ) AS train_rows,

        COUNT(*) FILTER (
            WHERE data_split = 'validation'
        ) AS validation_rows,

        COUNT(*) FILTER (
            WHERE data_split = 'test'
        ) AS test_rows,

        COUNT(*) FILTER (
            WHERE data_split IS NULL
        ) AS missing_split_rows,

        COUNT(*) FILTER (
            WHERE target_late_delivery IS NULL
        ) AS missing_late_target,

        COUNT(*) FILTER (
            WHERE target_negative_review IS NULL
        ) AS missing_review_target,

        COUNT(*) FILTER (
            WHERE target_late_delivery NOT IN (0, 1)
        ) AS invalid_late_target,

        COUNT(*) FILTER (
            WHERE target_negative_review NOT IN (0, 1)
        ) AS invalid_review_target,

        COUNT(*) FILTER (
            WHERE item_count IS NULL
               OR item_count <= 0
        ) AS invalid_item_count,

        COUNT(*) FILTER (
            WHERE estimated_delivery_days IS NULL
        ) AS missing_estimated_delivery_days,

        COUNT(*) FILTER (
            WHERE customer_state IS NULL
        ) AS missing_customer_state,

        COUNT(*) FILTER (
            WHERE customer_segment IS NULL
        ) AS missing_customer_segment

    FROM modeling.order_level_features
)

SELECT
    check_name,
    actual_value,
    expected_value,

    CASE
        WHEN actual_value = expected_value
            THEN 'PASS'
        ELSE 'FAIL'
    END AS check_status

FROM (
    SELECT
        'Total rows' AS check_name,
        total_rows AS actual_value,
        904366::bigint AS expected_value
    FROM validation_stats

    UNION ALL

    SELECT
        'Distinct orders',
        distinct_orders,
        904366::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Duplicate order rows',
        duplicate_order_rows,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Train rows',
        train_rows,
        461744::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Validation rows',
        validation_rows,
        214365::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Test rows',
        test_rows,
        228257::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Missing split',
        missing_split_rows,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Missing late-delivery target',
        missing_late_target,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Missing negative-review target',
        missing_review_target,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Invalid late-delivery target',
        invalid_late_target,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Invalid negative-review target',
        invalid_review_target,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Invalid item count',
        invalid_item_count,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Missing estimated delivery days',
        missing_estimated_delivery_days,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Missing customer state',
        missing_customer_state,
        0::bigint
    FROM validation_stats

    UNION ALL

    SELECT
        'Missing customer segment',
        missing_customer_segment,
        0::bigint
    FROM validation_stats
) AS checks

ORDER BY
    CASE
        WHEN actual_value = expected_value THEN 2
        ELSE 1
    END,
    check_name;