/* =========================================================
   Modeling Readiness Checks

   Project:
   U.S. E-Commerce Performance Analytics

   Planned targets:
   1. Late-delivery prediction
   2. Negative-review prediction

   Purpose:
   - Confirm order-level grain
   - Check target availability
   - Check class balance
   - Confirm chronological split sizes
   - Identify missing review outcomes
   ========================================================= */


/* ---------------------------------------------------------
   1. Confirm fact_orders grain
   Expected:
   total_rows = distinct_orders
   duplicate_order_rows = 0
   --------------------------------------------------------- */

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id)
        AS duplicate_order_rows
FROM analytics.fact_orders;


/* ---------------------------------------------------------
   2. Check order outcome counts
   --------------------------------------------------------- */

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
    ) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE is_canceled = TRUE
    ) AS canceled_orders,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
          AND is_late_delivery = TRUE
    ) AS late_delivered_orders,

    COUNT(*) FILTER (
        WHERE is_delivered = TRUE
          AND is_late_delivery = FALSE
    ) AS on_time_delivered_orders

FROM analytics.fact_orders;


/* ---------------------------------------------------------
   3. Late-delivery target balance

   Scope:
   Delivered orders only

   Target:
   1 = late delivery
   0 = on-time delivery
   --------------------------------------------------------- */

SELECT
    is_late_delivery AS target_late_delivery,
    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(
            SUM(COUNT(*)) OVER (),
            0
        ),
        2
    ) AS target_share_pct

FROM analytics.fact_orders

WHERE is_delivered = TRUE

GROUP BY
    is_late_delivery

ORDER BY
    is_late_delivery;


/* ---------------------------------------------------------
   4. Check review grain and order coverage
   --------------------------------------------------------- */

SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT order_id) AS reviewed_orders,
    COUNT(*) - COUNT(DISTINCT order_id)
        AS duplicate_review_order_rows,

    COUNT(*) FILTER (
        WHERE is_negative_review = TRUE
    ) AS negative_reviews,

    COUNT(*) FILTER (
        WHERE is_negative_review = FALSE
    ) AS non_negative_reviews

FROM analytics.fact_reviews;


/* ---------------------------------------------------------
   5. Negative-review target balance
   --------------------------------------------------------- */

SELECT
    is_negative_review AS target_negative_review,
    COUNT(*) AS review_count,

    ROUND(
        100.0 * COUNT(*)
        / NULLIF(
            SUM(COUNT(*)) OVER (),
            0
        ),
        2
    ) AS target_share_pct

FROM analytics.fact_reviews

GROUP BY
    is_negative_review

ORDER BY
    is_negative_review;


/* ---------------------------------------------------------
   6. Check delivered-order review coverage
   --------------------------------------------------------- */

SELECT
    COUNT(*) AS delivered_orders,

    COUNT(r.order_id) AS delivered_orders_with_review,

    COUNT(*) - COUNT(r.order_id)
        AS delivered_orders_without_review,

    ROUND(
        100.0 * COUNT(r.order_id)
        / NULLIF(COUNT(*), 0),
        2
    ) AS review_coverage_pct

FROM analytics.fact_orders AS o

LEFT JOIN analytics.fact_reviews AS r
    ON o.order_id = r.order_id

WHERE o.is_delivered = TRUE;


/* ---------------------------------------------------------
   7. Chronological modeling splits
   --------------------------------------------------------- */

WITH split_data AS (
    SELECT
        CASE
            WHEN order_purchase_timestamp >= TIMESTAMP '2019-01-01'
             AND order_purchase_timestamp <  TIMESTAMP '2024-01-01'
                THEN 'train_2019_2023'

            WHEN order_purchase_timestamp >= TIMESTAMP '2024-01-01'
             AND order_purchase_timestamp <  TIMESTAMP '2025-01-01'
                THEN 'validation_2024'

            WHEN order_purchase_timestamp >= TIMESTAMP '2025-01-01'
             AND order_purchase_timestamp <  TIMESTAMP '2025-12-01'
                THEN 'test_2025_jan_nov'

            ELSE 'excluded'
        END AS data_split,

        CASE
            WHEN order_purchase_timestamp >= TIMESTAMP '2019-01-01'
             AND order_purchase_timestamp <  TIMESTAMP '2024-01-01'
                THEN 1

            WHEN order_purchase_timestamp >= TIMESTAMP '2024-01-01'
             AND order_purchase_timestamp <  TIMESTAMP '2025-01-01'
                THEN 2

            WHEN order_purchase_timestamp >= TIMESTAMP '2025-01-01'
             AND order_purchase_timestamp <  TIMESTAMP '2025-12-01'
                THEN 3

            ELSE 4
        END AS split_order,

        is_late_delivery

    FROM analytics.fact_orders

    WHERE is_delivered = TRUE
)

SELECT
    data_split,
    COUNT(*) AS delivered_orders,

    COUNT(*) FILTER (
        WHERE is_late_delivery = TRUE
    ) AS late_orders,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE is_late_delivery = TRUE
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate_pct

FROM split_data

GROUP BY
    data_split,
    split_order

ORDER BY
    split_order;

/* ---------------------------------------------------------
   8. Negative-review target by modeling split
   --------------------------------------------------------- */

WITH split_data AS (
    SELECT
        CASE
            WHEN o.order_purchase_timestamp >= TIMESTAMP '2019-01-01'
             AND o.order_purchase_timestamp <  TIMESTAMP '2024-01-01'
                THEN 'train_2019_2023'

            WHEN o.order_purchase_timestamp >= TIMESTAMP '2024-01-01'
             AND o.order_purchase_timestamp <  TIMESTAMP '2025-01-01'
                THEN 'validation_2024'

            WHEN o.order_purchase_timestamp >= TIMESTAMP '2025-01-01'
             AND o.order_purchase_timestamp <  TIMESTAMP '2025-12-01'
                THEN 'test_2025_jan_nov'

            ELSE 'excluded'
        END AS data_split,

        CASE
            WHEN o.order_purchase_timestamp >= TIMESTAMP '2019-01-01'
             AND o.order_purchase_timestamp <  TIMESTAMP '2024-01-01'
                THEN 1

            WHEN o.order_purchase_timestamp >= TIMESTAMP '2024-01-01'
             AND o.order_purchase_timestamp <  TIMESTAMP '2025-01-01'
                THEN 2

            WHEN o.order_purchase_timestamp >= TIMESTAMP '2025-01-01'
             AND o.order_purchase_timestamp <  TIMESTAMP '2025-12-01'
                THEN 3

            ELSE 4
        END AS split_order,

        r.is_negative_review

    FROM analytics.fact_orders AS o

    INNER JOIN analytics.fact_reviews AS r
        ON o.order_id = r.order_id

    WHERE o.is_delivered = TRUE
)

SELECT
    data_split,
    COUNT(*) AS reviewed_delivered_orders,

    COUNT(*) FILTER (
        WHERE is_negative_review = TRUE
    ) AS negative_reviews,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE is_negative_review = TRUE
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS negative_review_rate_pct

FROM split_data

GROUP BY
    data_split,
    split_order

ORDER BY
    split_order;