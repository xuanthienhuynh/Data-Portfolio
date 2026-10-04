DROP TABLE IF EXISTS mart.surge_alerts;

CREATE TABLE mart.surge_alerts AS
WITH zone_hour_day AS (
    SELECT 
        z.zone,
        t.pickup_hour,
        t.pickup_dayofweek,
        AVG(t.fare_amount / t.trip_distance) AS avg_fare_per_mile,
        COUNT(*) AS trip_count
    FROM mart.trips t
    JOIN raw.zones z ON t.pu_location_id = z.location_id
    WHERE t.trip_distance >= 0.5
    GROUP BY z.zone, t.pickup_hour, t.pickup_dayofweek
    HAVING COUNT(*) >= 10
),
stats AS (
    SELECT 
        zone, pickup_hour,
        AVG(avg_fare_per_mile) AS mean_fpm,
        STDDEV(avg_fare_per_mile) AS stddev_fpm,
        COUNT(*) AS days_with_data,
        SUM(trip_count) AS total_trips
    FROM zone_hour_day
    GROUP BY zone, pickup_hour
    HAVING COUNT(*) = 7
)
SELECT 
    zone, pickup_hour,
    ROUND(mean_fpm::NUMERIC, 2) AS avg_fare_per_mile,
    ROUND(stddev_fpm::NUMERIC, 2) AS stddev_fare_per_mile,
    ROUND((stddev_fpm / NULLIF(mean_fpm, 0) * 100)::NUMERIC, 2) AS coefficient_of_variation_pct,
    total_trips
FROM stats
WHERE (stddev_fpm / NULLIF(mean_fpm, 0)) > 0.20
ORDER BY coefficient_of_variation_pct DESC
LIMIT 20;