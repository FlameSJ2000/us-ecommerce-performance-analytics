/* =========================================================
   Confirm Predictor Columns Match Across Both Model Views
   ========================================================= */

WITH late_predictors AS (
    SELECT
        column_name
    FROM information_schema.columns
    WHERE table_schema = 'modeling'
      AND table_name = 'late_delivery_model_view'
      AND column_name NOT IN (
          'order_id',
          'data_split',
          'target_late_delivery'
      )
),

review_predictors AS (
    SELECT
        column_name
    FROM information_schema.columns
    WHERE table_schema = 'modeling'
      AND table_name = 'negative_review_model_view'
      AND column_name NOT IN (
          'order_id',
          'data_split',
          'target_negative_review'
      )
),

differences AS (
    SELECT
        COALESCE(
            l.column_name,
            r.column_name
        ) AS column_name,

        CASE
            WHEN l.column_name IS NULL
                THEN 'Only in negative-review view'
            WHEN r.column_name IS NULL
                THEN 'Only in late-delivery view'
        END AS difference_type

    FROM late_predictors AS l

    FULL OUTER JOIN review_predictors AS r
        ON l.column_name = r.column_name

    WHERE l.column_name IS NULL
       OR r.column_name IS NULL
)

SELECT
    COUNT(*) AS predictor_differences,

    CASE
        WHEN COUNT(*) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS check_status

FROM differences;