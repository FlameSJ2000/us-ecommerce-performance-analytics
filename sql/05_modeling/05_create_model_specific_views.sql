/* =========================================================
   Create Model-Specific Views

   Purpose:
   - Define predictors separately for each model
   - Prevent target leakage
   - Retain order_id only for auditing
   - Retain data_split for chronological modeling

   Important:
   order_id and data_split are not predictors.
   ========================================================= */


/* =========================================================
   View 1: Late-Delivery Prediction

   Prediction point:
   At or shortly after checkout

   Target:
   target_late_delivery

   Excluded:
   - target_negative_review
   - review information
   - actual delivery information
   - post-delivery information
   ========================================================= */

CREATE OR REPLACE VIEW
    modeling.late_delivery_model_view
AS

SELECT
    /* Audit and split variables. Do not use as predictors. */
    order_id,
    data_split,

    /* Purchase-time features */
    purchase_year,
    purchase_month,
    purchase_day_of_week,
    purchase_hour,
    is_weekend_purchase,

    /* Customer features */
    customer_gender,
    customer_age,
    customer_state,
    customer_segment,

    /* Order and cart features */
    item_count,
    unique_product_count,
    seller_count,
    product_category_count,
    discounted_item_count,
    discounted_item_share,
    average_discount_rate,
    average_product_weight_g,
    total_product_weight_g,
    average_product_volume_cm3,

    /* Financial features available at checkout */
    gross_merchandise_value,
    discount_amount,
    net_merchandise_revenue,
    freight_charge,
    customer_payment,
    product_cost,
    merchandise_profit,
    merchandise_margin,
    freight_to_revenue_ratio,
    order_discount_rate,

    /* Promised-delivery feature */
    estimated_delivery_days,

    /* Payment features */
    payment_record_count,
    payment_type_count,
    maximum_payment_installments,
    average_payment_installments,
    used_credit_card,
    used_debit_card,
    used_paypal,
    used_apple_pay,
    used_bank_transfer,
    used_voucher,
    used_boleto,

    /* Route and distance features */
    shipment_route_count,
    item_weighted_distance_miles,
    distance_band,
    is_distance_missing,

    /* Target */
    target_late_delivery

FROM modeling.final_order_modeling_dataset;


/* =========================================================
   View 2: Negative-Review Prediction

   Prediction point:
   At or shortly after checkout

   Target:
   target_negative_review

   Excluded:
   - target_late_delivery
   - review score
   - review text
   - actual delivery information
   - post-delivery information

   Note:
   target_late_delivery is excluded because this view predicts
   risk using checkout-time information only.
   ========================================================= */

CREATE OR REPLACE VIEW
    modeling.negative_review_model_view
AS

SELECT
    /* Audit and split variables. Do not use as predictors. */
    order_id,
    data_split,

    /* Purchase-time features */
    purchase_year,
    purchase_month,
    purchase_day_of_week,
    purchase_hour,
    is_weekend_purchase,

    /* Customer features */
    customer_gender,
    customer_age,
    customer_state,
    customer_segment,

    /* Order and cart features */
    item_count,
    unique_product_count,
    seller_count,
    product_category_count,
    discounted_item_count,
    discounted_item_share,
    average_discount_rate,
    average_product_weight_g,
    total_product_weight_g,
    average_product_volume_cm3,

    /* Financial features available at checkout */
    gross_merchandise_value,
    discount_amount,
    net_merchandise_revenue,
    freight_charge,
    customer_payment,
    product_cost,
    merchandise_profit,
    merchandise_margin,
    freight_to_revenue_ratio,
    order_discount_rate,

    /* Promised-delivery feature */
    estimated_delivery_days,

    /* Payment features */
    payment_record_count,
    payment_type_count,
    maximum_payment_installments,
    average_payment_installments,
    used_credit_card,
    used_debit_card,
    used_paypal,
    used_apple_pay,
    used_bank_transfer,
    used_voucher,
    used_boleto,

    /* Route and distance features */
    shipment_route_count,
    item_weighted_distance_miles,
    distance_band,
    is_distance_missing,

    /* Target */
    target_negative_review

FROM modeling.final_order_modeling_dataset;


SELECT
    'late_delivery_model_view' AS view_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT order_id)
        AS duplicate_order_rows,
    COUNT(*) FILTER (
        WHERE data_split IS NULL
    ) AS missing_split,
    COUNT(*) FILTER (
        WHERE target_late_delivery IS NULL
    ) AS missing_target
FROM modeling.late_delivery_model_view

UNION ALL

SELECT
    'negative_review_model_view',
    COUNT(*),
    COUNT(DISTINCT order_id),
    COUNT(*) - COUNT(DISTINCT order_id),
    COUNT(*) FILTER (
        WHERE data_split IS NULL
    ),
    COUNT(*) FILTER (
        WHERE target_negative_review IS NULL
    )
FROM modeling.negative_review_model_view;

/* =========================================================
   Validate Model Views for Target Leakage
   ========================================================= */

WITH prohibited_columns AS (

    /* Prohibited in the late-delivery model */
    SELECT
        'late_delivery_model_view'::text AS view_name,
        unnest(
            ARRAY[
                'target_negative_review',
                'is_negative_review',
                'review_score',
                'review_text',
                'actual_delivery_days',
                'delivery_delay_days',
                'order_delivered_timestamp'
            ]
        ) AS prohibited_column

    UNION ALL

    /* Prohibited in the negative-review model */
    SELECT
        'negative_review_model_view'::text AS view_name,
        unnest(
            ARRAY[
                'target_late_delivery',
                'is_late_delivery',
                'review_score',
                'review_text',
                'actual_delivery_days',
                'delivery_delay_days',
                'order_delivered_timestamp'
            ]
        ) AS prohibited_column
),

detected_leakage AS (
    SELECT
        p.view_name,
        p.prohibited_column
    FROM prohibited_columns AS p

    INNER JOIN information_schema.columns AS c
        ON c.table_schema = 'modeling'
       AND c.table_name = p.view_name
       AND c.column_name = p.prohibited_column
)

SELECT
    p.view_name,

    COUNT(d.prohibited_column)
        AS prohibited_columns_found,

    COALESCE(
        STRING_AGG(
            d.prohibited_column,
            ', '
            ORDER BY d.prohibited_column
        ),
        'None'
    ) AS detected_columns,

    CASE
        WHEN COUNT(d.prohibited_column) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS check_status

FROM (
    SELECT DISTINCT view_name
    FROM prohibited_columns
) AS p

LEFT JOIN detected_leakage AS d
    ON p.view_name = d.view_name

GROUP BY
    p.view_name

ORDER BY
    p.view_name;