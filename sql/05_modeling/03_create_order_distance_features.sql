/* =========================================================
   Create Order-Level Distance Features

   Grain:
   One row per modeled order

   Route definition:
   One order-seller combination represents one shipment route.

   Distance:
   Great-circle distance between customer and seller ZIP
   coordinates, measured in miles.
   ========================================================= */

DROP TABLE IF EXISTS modeling.order_distance_features;

CREATE TABLE modeling.order_distance_features AS

WITH order_seller_routes AS (
    SELECT
        i.order_id,
        i.seller_id,
        COUNT(*) AS items_in_route,
        SUM(i.freight_charge) AS route_freight

    FROM analytics.fact_order_items AS i

    INNER JOIN modeling.order_level_features AS m
        ON i.order_id = m.order_id

    WHERE i.is_realized_revenue = TRUE

    GROUP BY
        i.order_id,
        i.seller_id
),

route_coordinates AS (
    SELECT
        r.order_id,
        r.seller_id,
        r.items_in_route,
        r.route_freight,

        customer_geo.latitude::double precision
            AS customer_latitude,

        customer_geo.longitude::double precision
            AS customer_longitude,

        seller_geo.latitude::double precision
            AS seller_latitude,

        seller_geo.longitude::double precision
            AS seller_longitude

    FROM order_seller_routes AS r

    INNER JOIN analytics.fact_orders AS o
        ON r.order_id = o.order_id

    INNER JOIN analytics.dim_customers AS c
        ON o.customer_id = c.customer_id

    INNER JOIN analytics.dim_sellers AS s
        ON r.seller_id = s.seller_id

    LEFT JOIN analytics.dim_geography AS customer_geo
        ON c.customer_zip_code_prefix =
           customer_geo.zip_code_prefix

    LEFT JOIN analytics.dim_geography AS seller_geo
        ON s.seller_zip_code_prefix =
           seller_geo.zip_code_prefix
),

route_distances AS (
    SELECT
        order_id,
        seller_id,
        items_in_route,
        route_freight,

        CASE
            WHEN customer_latitude IS NULL
              OR customer_longitude IS NULL
              OR seller_latitude IS NULL
              OR seller_longitude IS NULL
                THEN NULL

            ELSE
                3958.7613 * ACOS(
                    LEAST(
                        1.0,
                        GREATEST(
                            -1.0,

                            SIN(RADIANS(customer_latitude))
                                * SIN(RADIANS(seller_latitude))

                            +

                            COS(RADIANS(customer_latitude))
                                * COS(RADIANS(seller_latitude))
                                * COS(
                                    RADIANS(
                                        seller_longitude
                                        - customer_longitude
                                    )
                                )
                        )
                    )
                )
        END AS distance_miles

    FROM route_coordinates
),

order_distance_summary AS (
    SELECT
        order_id,

        COUNT(*) AS shipment_route_count,

        COUNT(distance_miles)
            AS routes_with_distance,

        COUNT(*) - COUNT(distance_miles)
            AS routes_missing_distance,

        AVG(distance_miles)
            AS average_route_distance_miles,

        MIN(distance_miles)
            AS minimum_route_distance_miles,

        MAX(distance_miles)
            AS maximum_route_distance_miles,

        SUM(
            distance_miles * items_in_route
        )
        / NULLIF(
            SUM(items_in_route) FILTER (
                WHERE distance_miles IS NOT NULL
            ),
            0
        ) AS item_weighted_distance_miles

    FROM route_distances

    GROUP BY
        order_id
)

SELECT
    m.order_id,

    COALESCE(d.shipment_route_count, 0)
        AS shipment_route_count,

    COALESCE(d.routes_with_distance, 0)
        AS routes_with_distance,

    COALESCE(d.routes_missing_distance, 0)
        AS routes_missing_distance,

    d.average_route_distance_miles,
    d.minimum_route_distance_miles,
    d.maximum_route_distance_miles,
    d.item_weighted_distance_miles,

    CASE
        WHEN d.item_weighted_distance_miles IS NULL
            THEN 'Missing distance'

        WHEN d.item_weighted_distance_miles < 100
            THEN 'Under 100 miles'

        WHEN d.item_weighted_distance_miles < 300
            THEN '100-299 miles'

        WHEN d.item_weighted_distance_miles < 600
            THEN '300-599 miles'

        WHEN d.item_weighted_distance_miles < 1000
            THEN '600-999 miles'

        ELSE '1,000+ miles'
    END AS distance_band,

    CASE
        WHEN d.item_weighted_distance_miles IS NULL
            THEN TRUE
        ELSE FALSE
    END AS is_distance_missing

FROM modeling.order_level_features AS m

LEFT JOIN order_distance_summary AS d
    ON m.order_id = d.order_id;

CREATE UNIQUE INDEX
    idx_order_distance_features_order_id
ON modeling.order_distance_features (order_id);

ANALYZE modeling.order_distance_features;

/* =========================================================
   Validate Order-Level Distance Features
   ========================================================= */

SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT order_id)
        AS distinct_orders,

    COUNT(*) - COUNT(DISTINCT order_id)
        AS duplicate_order_rows,

    COUNT(*) FILTER (
        WHERE shipment_route_count = 0
    ) AS orders_without_routes,

    COUNT(*) FILTER (
        WHERE is_distance_missing = TRUE
    ) AS orders_missing_distance,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE is_distance_missing = TRUE
        )
        / NULLIF(COUNT(*), 0),
        4
    ) AS missing_distance_pct,

    ROUND(
        MIN(item_weighted_distance_miles)::numeric,
        2
    ) AS minimum_distance_miles,

    ROUND(
        AVG(item_weighted_distance_miles)::numeric,
        2
    ) AS average_distance_miles,

    ROUND(
        MAX(item_weighted_distance_miles)::numeric,
        2
    ) AS maximum_distance_miles

FROM modeling.order_distance_features;


SELECT
    distance_band,
    COUNT(*) AS order_count,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS order_share_pct

FROM modeling.order_distance_features

GROUP BY
    distance_band

ORDER BY
    CASE distance_band
        WHEN 'Under 100 miles' THEN 1
        WHEN '100-299 miles' THEN 2
        WHEN '300-599 miles' THEN 3
        WHEN '600-999 miles' THEN 4
        WHEN '1,000+ miles' THEN 5
        ELSE 6
    END;





