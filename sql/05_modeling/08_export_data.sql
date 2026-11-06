SELECT
    v.*,
    f.order_purchase_timestamp
FROM modeling.late_delivery_model_view AS v
INNER JOIN modeling.final_order_modeling_dataset AS f
    ON v.order_id = f.order_id
ORDER BY
    f.order_purchase_timestamp,
    v.order_id;