import pandas as pd
import os
from sqlalchemy import create_engine

def main():
    # 1. Cấu hình đường dẫn và kết nối Database
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    
    STAGING_PARQUET_PATH = os.path.join(BASE_DIR, 'data', 'dataset', 'staging_trips.parquet')
    MART_PARQUET_PATH = os.path.join(BASE_DIR, 'data', 'dataset', 'mart_trips_filtered.parquet')
    DB_CONNECTION = os.environ.get(
    'TAXI_DB_URL',
    'postgresql://postgres:YOUR_PASSWORD@localhost:5432/NYC_Green_Taxi'
    )
    print("--- BẮT ĐẦU CHẠY ETL PIPELINE ---")
    
    # 2. Đọc dữ liệu Staging
    if not os.path.exists(STAGING_PARQUET_PATH):
        print(f"Lỗi: Không tìm thấy file {STAGING_PARQUET_PATH}")
        return

    print("Đang đọc dữ liệu từ staging...")
    df = pd.read_parquet(STAGING_PARQUET_PATH)
    print(f"Số dòng ban đầu: {len(df):,}")

    # 3. Lọc Outlier (Khoảng cách & Thời gian)
    print("Đang lọc outlier (trip_distance <= 50 & 1 <= trip_duration_minutes <= 180)...")
    df_mart = df[
        (df['trip_distance'] <= 50) & 
        (df['trip_duration_minutes'] >= 1) & 
        (df['trip_duration_minutes'] <= 180)
    ].copy()

    # 4. Feature Engineering: Tốc độ trung bình & Lọc tốc độ ảo
    print("Đang tính toán avg_speed_mph và lọc tốc độ ảo (<= 100 mph)...")
    df_mart['avg_speed_mph'] = df_mart['trip_distance'] / (df_mart['trip_duration_minutes'] / 60)
    df_mart = df_mart[df_mart['avg_speed_mph'] <= 100]

    # 5. Feature Engineering: Khung giờ cao điểm
    print("Đang xác định is_peak_hour...")
    df_mart['pickup_hour'] = df_mart['pickup_datetime'].dt.hour
    df_mart['is_peak_hour'] = df_mart['pickup_hour'].apply(
        lambda h: True if (7 <= h <= 9) or (17 <= h <= 19) else False
    )

    # 6. Feature Engineering: Phân loại quãng đường (Short, Medium, Long)
    print("Đang phân loại trip_category...")
    df_mart['trip_category'] = pd.cut(
        df_mart['trip_distance'], 
        bins=[0, 2, 5, 50], 
        labels=['short', 'medium', 'long']
    )

    # 7. Feature Engineering: Ngày trong tuần
    print("Đang trích xuất pickup_dayofweek...")
    df_mart['pickup_dayofweek'] = df_mart['pickup_datetime'].dt.day_name()

    # 8. Lưu kết quả ra file Parquet (Mart layer)
    print(f"Hoàn tất xử lý! Số dòng cuối cùng: {len(df_mart):,}")
    df_mart.to_parquet(MART_PARQUET_PATH, index=False)
    print(f"Đã lưu file: {MART_PARQUET_PATH}")

    # 9. Đẩy dữ liệu sạch vào PostgreSQL
    print("Đang đẩy dữ liệu vào PostgreSQL (mart.trips)...")
    engine = create_engine(DB_CONNECTION)
    df_mart.to_sql(
        name='trips',
        schema='mart',
        con=engine,
        if_exists='replace',
        index=False,
        chunksize=100000
    )
    print("--- ETL PIPELINE HOÀN TẤT THÀNH CÔNG! ---")

if __name__ == "__main__":
    main()