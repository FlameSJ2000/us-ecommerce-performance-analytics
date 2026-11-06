/* =========================================================
   Distance, Freight, and Delivery Performance

   Grain:
   - One row per order-seller route before aggregation
   - Multiple items from the same seller in the same order
     are treated as one shipment route

   Distance:
   - Great-circle distance calculated using coordinates
   - Distance is straight-line distance, not driving distance
   - Unit: miles

   Scope:
   - Delivered orders only
   ========================================================= */

WITH order_seller_routes AS (
    SELECT
        i.order_id,
        i.seller_id,

        COUNT(*) AS items_in_route,

        SUM(i.freight_charge)
            AS route_freight

    FROM analytics.fact_order_items AS i

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

        o.delivery_days,
        o.estimated_delivery_days,
        o.delivery_delay_days,
        o.is_late_delivery,

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

    INNER JOIN analytics.dim_geography AS customer_geo
        ON c.customer_zip_code_prefix =
           customer_geo.zip_code_prefix

    INNER JOIN analytics.dim_geography AS seller_geo
        ON s.seller_zip_code_prefix =
           seller_geo.zip_code_prefix

    WHERE o.is_delivered = TRUE
      AND customer_geo.latitude IS NOT NULL
      AND customer_geo.longitude IS NOT NULL
      AND seller_geo.latitude IS NOT NULL
      AND seller_geo.longitude IS NOT NULL
),

route_distances AS (
    SELECT
        *,

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
        ) AS distance_miles

    FROM route_coordinates
),

distance_bands AS (
    SELECT
        *,

        CASE
            WHEN distance_miles < 100
                THEN 'Under 100 miles'

            WHEN distance_miles < 300
                THEN '100-299 miles'

            WHEN distance_miles < 600
                THEN '300-599 miles'

            WHEN distance_miles < 1000
                THEN '600-999 miles'

            ELSE '1,000+ miles'
        END AS distance_band,

        CASE
            WHEN distance_miles < 100 THEN 1
            WHEN distance_miles < 300 THEN 2
            WHEN distance_miles < 600 THEN 3
            WHEN distance_miles < 1000 THEN 4
            ELSE 5
        END AS distance_band_order

    FROM route_distances
),

band_summary AS (
    SELECT
        distance_band,
        distance_band_order,

        COUNT(*) AS order_seller_routes,

        COUNT(DISTINCT order_id)
            AS distinct_orders,

        SUM(items_in_route)
            AS items_shipped,

        AVG(distance_miles)
            AS average_distance_miles,

        AVG(route_freight)
            AS average_freight_per_route,

        SUM(route_freight)
            / NULLIF(SUM(items_in_route), 0)
            AS average_freight_per_item,

        SUM(route_freight)::double precision
   		 	/ NULLIF(SUM(distance_miles), 0)
    		AS freight_per_route_mile,

        AVG(delivery_days)
            AS average_delivery_days,

        AVG(estimated_delivery_days)
            AS average_estimated_delivery_days,

        AVG(delivery_delay_days)
            AS average_delivery_delay_days,

        COUNT(*) FILTER (
            WHERE is_late_delivery = TRUE
        ) AS late_routes,

        100.0
            * COUNT(*) FILTER (
                WHERE is_late_delivery = TRUE
            )
            / NULLIF(COUNT(*), 0)
            AS late_delivery_rate_pct,

        CORR(
            distance_miles,
            route_freight::double precision
        ) AS distance_freight_correlation,

        CORR(
            distance_miles,
            delivery_days::double precision
        ) AS distance_delivery_correlation

    FROM distance_bands

    GROUP BY
        distance_band,
        distance_band_order
)

SELECT
    distance_band,
    order_seller_routes,
    distinct_orders,
    items_shipped,

    ROUND(
        average_distance_miles::numeric,
        2
    ) AS average_distance_miles,

    ROUND(
        average_freight_per_route::numeric,
        2
    ) AS average_freight_per_route,

    ROUND(
        average_freight_per_item::numeric,
        2
    ) AS average_freight_per_item,

    ROUND(
    	freight_per_route_mile::numeric,
   		4
	) AS freight_per_route_mile,

    ROUND(
        average_delivery_days::numeric,
        2
    ) AS average_delivery_days,

    ROUND(
        average_estimated_delivery_days::numeric,
        2
    ) AS average_estimated_delivery_days,

    ROUND(
        average_delivery_delay_days::numeric,
        2
    ) AS average_delivery_delay_days,

    late_routes,

    ROUND(
        late_delivery_rate_pct::numeric,
        2
    ) AS late_delivery_rate_pct,

    ROUND(
        distance_freight_correlation::numeric,
        4
    ) AS distance_freight_correlation,

    ROUND(
        distance_delivery_correlation::numeric,
        4
    ) AS distance_delivery_correlation

FROM band_summary

ORDER BY
    distance_band_order;