-- NYC GREEN TAXI - ETL PIPELINE: RAW -> STAGING

	-- Mục đích: import dữ liệu thô từ CSV, transform sang staging
	-- với kiểu dữ liệu đúng, loại bỏ dòng bẩn/vô lý, có thể truy vết
	-- lại lý do loại bỏ bất cứ lúc nào từ raw layer.


-- ============================================================
-- 1. RAW LAYER - chứa dữ liệu thô, KHÔNG chỉnh sửa/xóa sau khi
--    đã import xong. Đây là "bằng chứng gốc" để truy vết sau này.


CREATE SCHEMA raw;

CREATE TABLE raw.zones (
    location_id    INT PRIMARY KEY,
    borough        VARCHAR(50),
    zone           VARCHAR(100),
    service_zone   VARCHAR(50)
);

CREATE TABLE raw.payment_types (
    payment_type   INT PRIMARY KEY,
    payment_name   VARCHAR(50)
);

-- Lưu ý : raw.trips để TOÀN BỘ cột kiểu TEXT, không đặt PK,
-- không ép kiểu ngay. Lý do: dữ liệu CSV export từ SQL Server 
-- có giá trị rỗng dạng "" (quoted empty string) khiến import
-- bằng kiểu số/ngày tháng bị lỗi (invalid input syntax).

-- Để TEXT giúp import 100% dữ liệu không bị chặn giữa chừng,
-- việc ép kiểu/lọc dữ liệu bẩn sẽ xử lý ở bước staging.
CREATE TABLE raw.trips (
    trip_id                  TEXT,
    vendor_id                TEXT,
    pickup_datetime           TEXT,
    dropoff_datetime          TEXT,
    store_and_fwd_flag        TEXT,
    rate_code_id               TEXT,
    pu_location_id             TEXT,
    do_location_id             TEXT,
    passenger_count            TEXT,
    trip_distance               TEXT,
    fare_amount                  TEXT,
    extra                        TEXT,
    mta_tax                      TEXT,
    tip_amount                   TEXT,
    tolls_amount                  TEXT,
    improvement_surcharge         TEXT,
    congestion_surcharge          TEXT,
    total_amount                  TEXT,
    payment_type                  TEXT,
    trip_type                     TEXT
);

-- Sau bước này: import 3 file CSV vào 3 bảng trên qua
-- pgAdmin Import/Export Data (Header = Yes cho zones/payment_types,
-- Header = No cho trips vì file trips không có dòng tiêu đề).


-- ============================================================
-- 2. KIỂM TRA SAU KHI IMPORT (chạy tay, không phải phần pipeline)


SELECT COUNT(*) FROM raw.zones;          
SELECT COUNT(*) FROM raw.payment_types; 
SELECT COUNT(*) FROM raw.trips;        

-- Test join 3 bảng raw (minh họa: khi raw để TEXT, phải ép kiểu
-- tay ở mọi chỗ join/so sánh - đây là cái giá của việc để raw
-- lỏng lẻo, và là lý do bắt buộc phải có staging layer)
SELECT *
FROM raw.trips t
JOIN raw.zones z1 ON t.pu_location_id::INT = z1.location_id
JOIN raw.zones z2 ON t.do_location_id::INT = z2.location_id
JOIN raw.payment_types p ON t.payment_type::INT = p.payment_type
LIMIT 10;


-- ============================================================
-- 3. STAGING LAYER - dữ liệu đã ép kiểu đúng, đã lọc dòng bẩn,
--    sẵn sàng cho phân tích/Power BI.


CREATE SCHEMA staging;

CREATE TABLE staging.trips (
    trip_id                  INT PRIMARY KEY,
    vendor_id                SMALLINT,
    pickup_datetime           TIMESTAMP,
    dropoff_datetime          TIMESTAMP,
    store_and_fwd_flag        CHAR(1),
    rate_code_id               SMALLINT,
    pu_location_id             INT,
    do_location_id             INT,
    passenger_count            SMALLINT,
    trip_distance               NUMERIC(8,2),
    fare_amount                  NUMERIC(8,2),
    extra                        NUMERIC(8,2),
    mta_tax                      NUMERIC(8,2),
    tip_amount                   NUMERIC(8,2),
    tolls_amount                  NUMERIC(8,2),
    improvement_surcharge         NUMERIC(8,2),
    congestion_surcharge          NUMERIC(8,2),
    total_amount                  NUMERIC(8,2),
    payment_type                  SMALLINT,
    trip_type                     SMALLINT,
    trip_duration_minutes         NUMERIC(10,2) -- cột tính thêm: dropoff - pickup
);


-- ============================================================
-- 4. DATA QUALITY CHECK - chạy TRƯỚC khi insert, để biết
--    trước dữ liệu có vấn đề gì, tránh insert lỗi giữa chừng.


-- Check trùng trip_id (nếu có sẽ vi phạm PRIMARY KEY ở staging)
SELECT trip_id, COUNT(*)
FROM raw.trips
GROUP BY trip_id
HAVING COUNT(*) > 1
LIMIT 10;
-- Kết quả: rỗng -> không có trùng, an toàn để insert với PK.


-- ============================================================
-- 5. TRANSFORM & LOAD: raw -> staging

-- Quy tắc xử lý:
--   - passenger_count rỗng -> gán mặc định = 1 (COALESCE),
--     KHÔNG loại bỏ dòng, vì đây là cột phụ, loại bỏ oan
--     673,138 dòng (10.7% dữ liệu) chỉ vì thiếu 1 cột không
--     ảnh hưởng nhiều đến phân tích doanh thu/thời gian/khu vực.

--   - fare_amount < 0, trip_distance <= 0, dropoff <= pickup
--     -> LOẠI BỎ, vì đây là lỗi logic thật sự, không phải
--     thiếu dữ liệu (đã verify: null_fare=0, null_distance=0,
--     null_pickup=0, null_dropoff=0 -> chắc chắn là sai giá trị,
--     không phải rỗng).

TRUNCATE TABLE staging.trips;

INSERT INTO staging.trips
SELECT
    NULLIF(trip_id, '')::INT,
    NULLIF(vendor_id, '')::SMALLINT,
    NULLIF(pickup_datetime, '')::TIMESTAMP,
    NULLIF(dropoff_datetime, '')::TIMESTAMP,
    NULLIF(store_and_fwd_flag, ''),
    NULLIF(rate_code_id, '')::SMALLINT,
    NULLIF(pu_location_id, '')::INT,
    NULLIF(do_location_id, '')::INT,
    COALESCE(NULLIF(passenger_count, ''), '1')::SMALLINT,
    NULLIF(trip_distance, '')::NUMERIC,
    NULLIF(fare_amount, '')::NUMERIC,
    NULLIF(extra, '')::NUMERIC,
    NULLIF(mta_tax, '')::NUMERIC,
    NULLIF(tip_amount, '')::NUMERIC,
    NULLIF(tolls_amount, '')::NUMERIC,
    NULLIF(improvement_surcharge, '')::NUMERIC,
    NULLIF(congestion_surcharge, '')::NUMERIC,
    NULLIF(total_amount, '')::NUMERIC,
    NULLIF(payment_type, '')::SMALLINT,
    NULLIF(trip_type, '')::SMALLINT,
    EXTRACT(EPOCH FROM (
        NULLIF(dropoff_datetime, '')::TIMESTAMP
        - NULLIF(pickup_datetime, '')::TIMESTAMP
    )) / 60
FROM raw.trips
WHERE NULLIF(fare_amount, '')::NUMERIC >= 0
  AND NULLIF(trip_distance, '')::NUMERIC > 0
  AND NULLIF(dropoff_datetime, '')::TIMESTAMP > NULLIF(pickup_datetime, '')::TIMESTAMP;

SELECT COUNT(*) FROM staging.trips;  -- kết quả: 6,127,325


-- ============================================================
-- 6. AUDIT - truy vết lý do loại bỏ (giá trị tài liệu hóa cao,
--    dùng để giải thích trong report/CV: vì sao mất bao nhiêu %

SELECT
    trip_id,
    fare_amount,
    trip_distance,
    pickup_datetime,
    dropoff_datetime,
    CASE
        WHEN NULLIF(fare_amount, '')::NUMERIC < 0 THEN 'fare âm'
        WHEN NULLIF(trip_distance, '')::NUMERIC <= 0 THEN 'quãng đường = 0'
        WHEN NULLIF(dropoff_datetime, '')::TIMESTAMP <= NULLIF(pickup_datetime, '')::TIMESTAMP
            THEN 'giờ trả <= giờ đón'
        ELSE 'khác'
    END AS ly_do_loai
FROM raw.trips
WHERE NOT (
    NULLIF(fare_amount, '')::NUMERIC >= 0
    AND NULLIF(trip_distance, '')::NUMERIC > 0
    AND NULLIF(dropoff_datetime, '')::TIMESTAMP > NULLIF(pickup_datetime, '')::TIMESTAMP
)
LIMIT 50;

-- Tổng hợp số dòng bị loại theo từng lý do
-- Kết quả thực tế:
--   quãng đường = 0        : 152,193 dòng (87.6%)
--   fare âm                : 19,906 dòng
--   giờ trả <= giờ đón      : 1,561 dòng
SELECT ly_do_loai, COUNT(*)
FROM (
    SELECT
        CASE
            WHEN NULLIF(fare_amount, '')::NUMERIC < 0 THEN 'fare âm'
            WHEN NULLIF(trip_distance, '')::NUMERIC <= 0 THEN 'quãng đường = 0'
            WHEN NULLIF(dropoff_datetime, '')::TIMESTAMP <= NULLIF(pickup_datetime, '')::TIMESTAMP
                THEN 'giờ trả <= giờ đón'
            ELSE 'khác'
        END AS ly_do_loai
    FROM raw.trips
    WHERE NOT (
        NULLIF(fare_amount, '')::NUMERIC >= 0
        AND NULLIF(trip_distance, '')::NUMERIC > 0
        AND NULLIF(dropoff_datetime, '')::TIMESTAMP > NULLIF(pickup_datetime, '')::TIMESTAMP
    )
) sub
GROUP BY ly_do_loai
ORDER BY COUNT(*) DESC;

CREATE SCHEMA mart;





