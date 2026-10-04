/*
===============================================================================
Script: 02_mart_cleaning.sql
Mục đích: Tối ưu hóa bảng mart.trips sau khi Python hoàn tất việc nạp dữ liệu.
===============================================================================
*/

-- 1. Xóa các dòng rác (Lớp bảo vệ thứ 2, dự phòng nếu Python bỏ sót)
DELETE FROM mart.trips 
WHERE trip_duration_minutes < 1;

-- 2. Đổi kiểu dữ liệu cho các cột ID để tối ưu dung lượng (Python thường cast thành BigInt)
ALTER TABLE mart.trips
    ALTER COLUMN vendor_id TYPE integer,
    ALTER COLUMN rate_code_id TYPE integer,
    ALTER COLUMN pu_location_id TYPE integer,
    ALTER COLUMN do_location_id TYPE integer;

-- 3. Tạo Indexes (Chỉ mục) để tăng tốc độ truy vấn cho Q1-Q15 và Power BI DirectQuery
-- Index cho truy vấn không gian (Spatial/Zone)
CREATE INDEX IF NOT EXISTS idx_mart_trips_pu_location 
    ON mart.trips(pu_location_id);

CREATE INDEX IF NOT EXISTS idx_mart_trips_do_location 
    ON mart.trips(do_location_id);

-- Index cho truy vấn thời gian (Temporal)
CREATE INDEX IF NOT EXISTS idx_mart_trips_pickup_hour 
    ON mart.trips(pickup_hour);

CREATE INDEX IF NOT EXISTS idx_mart_trips_pickup_datetime 
    ON mart.trips(pickup_datetime);

-- Index cho truy vấn kết hợp (Tốc độ, Giá cước)
CREATE INDEX IF NOT EXISTS idx_mart_trips_speed 
    ON mart.trips(avg_speed_mph);