import time
from datetime import datetime

import pandas as pd
from google_play_scraper import reviews, Sort

APP_ID = "com.shopee.vn"
CUTOFF = datetime(2026, 1, 1)
BATCH_SIZE = 200
SLEEP_SECONDS = 3
OUTPUT_PATH = "data/raw/shopee_reviews_raw_2026-11-21.csv"
COLUMNS = [
    "content",
    "score",
    "at",
    "thumbsUpCount",
    "appVersion",
    "replyContent",
    "repliedAt",
]

all_reviews = []


def save(rows):
    df = pd.DataFrame(rows)
    df = df[df["at"] >= CUTOFF]
    df = df[COLUMNS]
    df.to_csv(OUTPUT_PATH, index=False, encoding="utf-8-sig")
    print(f"Đã lưu {len(df)} dòng vào {OUTPUT_PATH}")


token = None

try:
    while True:
        batch, token = reviews(
            APP_ID,
            lang="vi",
            country="vn",
            sort=Sort.NEWEST,
            count=BATCH_SIZE,
            continuation_token=token,
        )

        if not batch:
            break

        all_reviews.extend(batch)
        oldest = min(review["at"] for review in batch)
        print(f"Đã thu {len(all_reviews)} review, cũ nhất trong batch: {oldest}")

        if oldest < CUTOFF or token is None:
            break

        time.sleep(SLEEP_SECONDS)

except Exception as error:
    print(f"Lỗi khi thu thập: {error}")

finally:
    if all_reviews:
        save(all_reviews)
    else:
        print("Không có dữ liệu để lưu")