/* =========================================================
   Check Target Distribution by Chronological Split

   Purpose:
   - Confirm row counts
   - Measure class imbalance
   - Check target stability over time
   ========================================================= */


WITH target_distribution AS (

    SELECT
        'late_delivery'::text AS model_name,
        data_split,
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE target_late_delivery = 1
        ) AS positive_orders,

        COUNT(*) FILTER (
            WHERE target_late_delivery = 0
        ) AS negative_orders,

        ROUND(
            100.0
            * COUNT(*) FILTER (
                WHERE target_late_delivery = 1
            )
            / NULLIF(COUNT(*), 0),
            2
        ) AS positive_rate_pct

    FROM modeling.late_delivery_model_view

    GROUP BY
        data_split

    UNION ALL

    SELECT
        'negative_review'::text AS model_name,
        data_split,
        COUNT(*) AS total_orders,

        COUNT(*) FILTER (
            WHERE target_negative_review = 1
        ) AS positive_orders,

        COUNT(*) FILTER (
            WHERE target_negative_review = 0
        ) AS negative_orders,

        ROUND(
            100.0
            * COUNT(*) FILTER (
                WHERE target_negative_review = 1
            )
            / NULLIF(COUNT(*), 0),
            2
        ) AS positive_rate_pct

    FROM modeling.negative_review_model_view

    GROUP BY
        data_split
)

SELECT
    model_name,
    data_split,
    total_orders,
    positive_orders,
    negative_orders,
    positive_rate_pct

FROM target_distribution

ORDER BY
    model_name,

    CASE data_split
        WHEN 'train' THEN 1
        WHEN 'validation' THEN 2
        WHEN 'test' THEN 3
        ELSE 4
    END;