/* =========================================================
   Create Final Order-Level Modeling Dataset

   Grain:
   One row per delivered order

   Row count expected:
   904,366

   Important:
   - IDs are retained for auditing only.
   - Targets must never be used as predictors.
   ========================================================= */

DROP TABLE IF EXISTS modeling.final_order_modeling_dataset;

CREATE TABLE modeling.final_order_modeling_dataset AS

SELECT
    m.*,

    d.shipment_route_count,
    d.routes_with_distance,
    d.routes_missing_distance,
    d.average_route_distance_miles,
    d.minimum_route_distance_miles,
    d.maximum_route_distance_miles,
    d.item_weighted_distance_miles,
    d.distance_band,
    d.is_distance_missing

FROM modeling.order_level_features AS m

INNER JOIN modeling.order_distance_features AS d
    ON m.order_id = d.order_id;


CREATE UNIQUE INDEX
    idx_final_modeling_order_id
ON modeling.final_order_modeling_dataset (order_id);

CREATE INDEX
    idx_final_modeling_split
ON modeling.final_order_modeling_dataset (data_split);

CREATE INDEX
    idx_final_modeling_late_target
ON modeling.final_order_modeling_dataset (
    target_late_delivery
);

CREATE INDEX
    idx_final_modeling_review_target
ON modeling.final_order_modeling_dataset (
    target_negative_review
);

CREATE INDEX
    idx_final_modeling_distance_band
ON modeling.final_order_modeling_dataset (
    distance_band
);

ANALYZE modeling.final_order_modeling_dataset;



SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT order_id)
        AS distinct_orders,

    COUNT(*) - COUNT(DISTINCT order_id)
        AS duplicate_order_rows,

    COUNT(*) FILTER (
        WHERE data_split IS NULL
    ) AS missing_split,

    COUNT(*) FILTER (
        WHERE target_late_delivery IS NULL
    ) AS missing_late_target,

    COUNT(*) FILTER (
        WHERE target_negative_review IS NULL
    ) AS missing_review_target,

    COUNT(*) FILTER (
        WHERE item_weighted_distance_miles IS NULL
    ) AS missing_distance

FROM modeling.final_order_modeling_dataset;
