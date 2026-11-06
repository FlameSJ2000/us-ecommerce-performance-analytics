/* =========================================================
   Create Modeling Schema

   Grain:
   One row per delivered order

   Prediction timing:
   Features must be available at or shortly after checkout.

   Targets:
   - target_late_delivery
   - target_negative_review
   ========================================================= */

CREATE SCHEMA IF NOT EXISTS modeling;


/* =========================================================
   Create Order-Level Modeling Dataset

   Grain:
   One row per delivered order

   Included period:
   2019-01-01 through 2025-11-30

   Excluded:
   December 2025 because it is incomplete.

   Important:
   order_id and customer_id are retained for auditing only.
   They must not be used as model predictors.
   ========================================================= */

DROP TABLE IF EXISTS modeling.order_level_features;

CREATE TABLE modeling.order_level_features AS

WITH item_summary AS (
    SELECT
        i.order_id,

        COUNT(*) AS item_count,

        COUNT(DISTINCT i.product_id)
            AS unique_product_count,

        COUNT(DISTINCT i.seller_id)
            AS seller_count,

        COUNT(DISTINCT p.product_category_name)
            AS product_category_count,

        COUNT(*) FILTER (
            WHERE i.is_discounted = TRUE
        ) AS discounted_item_count,

        AVG(i.discount_rate)
            AS average_discount_rate,

        AVG(p.product_weight_g)
            AS average_product_weight_g,

        SUM(p.product_weight_g)
            AS total_product_weight_g,

        AVG(
            p.product_length_cm
            * p.product_height_cm
            * p.product_width_cm
        ) AS average_product_volume_cm3

    FROM analytics.fact_order_items AS i

    LEFT JOIN analytics.dim_products AS p
        ON i.product_id = p.product_id

    WHERE i.is_realized_revenue = TRUE

    GROUP BY
        i.order_id
),

payment_summary AS (
    SELECT
        order_id,

        COUNT(*) AS payment_record_count,

        COUNT(DISTINCT payment_type)
            AS payment_type_count,

        MAX(payment_installments)
            AS maximum_payment_installments,

        AVG(payment_installments::numeric)
            AS average_payment_installments,

        BOOL_OR(payment_type = 'credit_card')
            AS used_credit_card,

        BOOL_OR(payment_type = 'debit_card')
            AS used_debit_card,

        BOOL_OR(payment_type = 'paypal')
            AS used_paypal,

        BOOL_OR(payment_type = 'apple_pay')
            AS used_apple_pay,

        BOOL_OR(payment_type = 'bank_transfer')
            AS used_bank_transfer,

        BOOL_OR(payment_type = 'voucher')
            AS used_voucher,

        BOOL_OR(payment_type = 'boleto')
            AS used_boleto

    FROM analytics.fact_payments

    WHERE is_realized_payment = TRUE

    GROUP BY
        order_id
)

SELECT
    /* Audit identifiers. Do not use as predictors. */
    o.order_id,
    o.customer_id,

    /* Chronological split variables */
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date
        AS order_purchase_date,

    EXTRACT(YEAR FROM o.order_purchase_timestamp)::smallint
        AS purchase_year,

    EXTRACT(MONTH FROM o.order_purchase_timestamp)::smallint
        AS purchase_month,

    EXTRACT(DOW FROM o.order_purchase_timestamp)::smallint
        AS purchase_day_of_week,

    EXTRACT(HOUR FROM o.order_purchase_timestamp)::smallint
        AS purchase_hour,

    CASE
        WHEN EXTRACT(DOW FROM o.order_purchase_timestamp)
             IN (0, 6)
            THEN TRUE
        ELSE FALSE
    END AS is_weekend_purchase,

    CASE
        WHEN o.order_purchase_timestamp >= TIMESTAMP '2019-01-01'
         AND o.order_purchase_timestamp <  TIMESTAMP '2024-01-01'
            THEN 'train'

        WHEN o.order_purchase_timestamp >= TIMESTAMP '2024-01-01'
         AND o.order_purchase_timestamp <  TIMESTAMP '2025-01-01'
            THEN 'validation'

        WHEN o.order_purchase_timestamp >= TIMESTAMP '2025-01-01'
         AND o.order_purchase_timestamp <  TIMESTAMP '2025-12-01'
            THEN 'test'
    END AS data_split,

    /* Customer features */
    c.customer_gender,
    c.customer_age,
    c.customer_state,
    c.customer_segment,

    /* Order and cart features */
    i.item_count,
    i.unique_product_count,
    i.seller_count,
    i.product_category_count,
    i.discounted_item_count,

    i.discounted_item_count::numeric
        / NULLIF(i.item_count, 0)
        AS discounted_item_share,

    i.average_discount_rate,
    i.average_product_weight_g,
    i.total_product_weight_g,
    i.average_product_volume_cm3,

    /* Financial features known at checkout */
    o.gross_merchandise_value,
    o.discount_amount,
    o.net_merchandise_revenue,
    o.freight_charge,
    o.customer_payment,
    o.product_cost,
    o.merchandise_profit,
    o.merchandise_margin,

    o.freight_charge
        / NULLIF(o.net_merchandise_revenue, 0)
        AS freight_to_revenue_ratio,

    o.discount_amount
        / NULLIF(o.gross_merchandise_value, 0)
        AS order_discount_rate,

    /* Promised delivery information */
    o.estimated_delivery_days,

    /* Payment features */
    COALESCE(pay.payment_record_count, 0)
        AS payment_record_count,

    COALESCE(pay.payment_type_count, 0)
        AS payment_type_count,

    COALESCE(pay.maximum_payment_installments, 0)
        AS maximum_payment_installments,

    COALESCE(pay.average_payment_installments, 0)
        AS average_payment_installments,

    COALESCE(pay.used_credit_card, FALSE)
        AS used_credit_card,

    COALESCE(pay.used_debit_card, FALSE)
        AS used_debit_card,

    COALESCE(pay.used_paypal, FALSE)
        AS used_paypal,

    COALESCE(pay.used_apple_pay, FALSE)
        AS used_apple_pay,

    COALESCE(pay.used_bank_transfer, FALSE)
        AS used_bank_transfer,

    COALESCE(pay.used_voucher, FALSE)
        AS used_voucher,

    COALESCE(pay.used_boleto, FALSE)
        AS used_boleto,

    /* Targets. Never use these as predictors. */
    o.is_late_delivery::integer
        AS target_late_delivery,

    r.is_negative_review::integer
        AS target_negative_review

FROM analytics.fact_orders AS o

INNER JOIN analytics.dim_customers AS c
    ON o.customer_id = c.customer_id

INNER JOIN item_summary AS i
    ON o.order_id = i.order_id

LEFT JOIN payment_summary AS pay
    ON o.order_id = pay.order_id

INNER JOIN analytics.fact_reviews AS r
    ON o.order_id = r.order_id

WHERE o.is_delivered = TRUE
  AND o.order_purchase_timestamp >= TIMESTAMP '2019-01-01'
  AND o.order_purchase_timestamp <  TIMESTAMP '2025-12-01';

CREATE UNIQUE INDEX
    idx_modeling_order_level_features_order_id
ON modeling.order_level_features (order_id);

CREATE INDEX
    idx_modeling_order_level_features_split
ON modeling.order_level_features (data_split);

CREATE INDEX
    idx_modeling_order_level_features_late_target
ON modeling.order_level_features (target_late_delivery);

CREATE INDEX
    idx_modeling_order_level_features_review_target
ON modeling.order_level_features (target_negative_review);

ANALYZE modeling.order_level_features;
  