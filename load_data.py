"""
Step 1 - Load the Olist e-commerce dataset into a SQLite database.

Usage:
    1. Download the dataset from Kaggle:
       https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
    2. Unzip all CSV files into a folder named `data/` next to this script.
    3. Run:  python load_data.py
    4. A file `olist.db` is created. Open it with DB Browser for SQLite,
       DBeaver, or query it from Python.
"""

import sqlite3
from pathlib import Path

import pandas as pd

DATA_DIR = Path("data")
DB_PATH = Path("olist.db")

# CSV file  ->  table name in the database
FILES = {
    "olist_customers_dataset.csv": "customers",
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "payments",
    "olist_order_reviews_dataset.csv": "reviews",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "olist_geolocation_dataset.csv": "geolocation",
    "product_category_name_translation.csv": "category_translation",
}

# Columns that hold dates, so they are stored in a consistent format
DATE_COLUMNS = {
    "orders": [
        "order_purchase_timestamp",
        "order_approved_at",
        "order_delivered_carrier_date",
        "order_delivered_customer_date",
        "order_estimated_delivery_date",
    ],
    "order_items": ["shipping_limit_date"],
    "reviews": ["review_creation_date", "review_answer_timestamp"],
}


def main():
    if not DATA_DIR.exists():
        raise SystemExit(f"Folder '{DATA_DIR}' not found. Put the Olist CSV files there first.")

    conn = sqlite3.connect(DB_PATH)

    for csv_name, table in FILES.items():
        csv_path = DATA_DIR / csv_name
        if not csv_path.exists():
            print(f"[skip] {csv_name} not found")
            continue

        # utf-8-sig handles the hidden BOM character some of these files have
        df = pd.read_csv(csv_path, encoding="utf-8-sig")

        for col in DATE_COLUMNS.get(table, []):
            df[col] = pd.to_datetime(df[col], errors="coerce").dt.strftime("%Y-%m-%d %H:%M:%S")

        df.to_sql(table, conn, if_exists="replace", index=False)
        print(f"[ok] {table:<22} {len(df):>8,} rows, {df.shape[1]} columns")

    # Indexes on the join keys make the analysis queries much faster
    indexes = [
        ("orders", "order_id"),
        ("orders", "customer_id"),
        ("order_items", "order_id"),
        ("order_items", "product_id"),
        ("payments", "order_id"),
        ("reviews", "order_id"),
        ("customers", "customer_id"),
        ("products", "product_id"),
    ]
    for table, col in indexes:
        conn.execute(f"CREATE INDEX IF NOT EXISTS idx_{table}_{col} ON {table}({col})")

    conn.commit()
    conn.close()
    print(f"\nDone. Database saved to {DB_PATH.resolve()}")


if __name__ == "__main__":
    main()
