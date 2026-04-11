"""
migrate_db_nn.py — TRAWiMe one-time migration script
Chuyển dữ liệu từ locations.category (string) → location_categories (N-N junction table).

Chạy DUY NHẤT 1 LẦN trước khi deploy backend mới:
    python migrate_db_nn.py

Yêu cầu:
    pip install pymysql
"""
import pymysql
import sys

# ─── Config (sửa nếu cần) ────────────────────────────────────────────────────
DB_HOST = "localhost"
DB_PORT = 3306
DB_USER = "root"
DB_PASS = "220104"
DB_NAME = "trawime_db"

DRY_RUN = False  # Set True để preview mà không thực sự thay đổi DB
# ─────────────────────────────────────────────────────────────────────────────


def run():
    print("=" * 55)
    print("  TRAWiMe — Category N-N Migration")
    print(f"  Host: {DB_HOST}:{DB_PORT}  DB: {DB_NAME}")
    print(f"  {'[DRY RUN - Không thay đổi DB]' if DRY_RUN else '[LIVE - Thay đổi DB thật]'}")
    print("=" * 55)

    conn = pymysql.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER,
        password=DB_PASS, database=DB_NAME, charset="utf8mb4"
    )

    try:
        with conn.cursor() as cur:
            # ── Kiểm tra cột `category` còn tồn tại không ──────────────────
            cur.execute("""
                SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'locations' AND COLUMN_NAME = 'category'
            """, (DB_NAME,))
            has_column = cur.fetchone()[0] > 0

            if not has_column:
                print("\n[!] Cột `category` không còn trong bảng `locations`.")
                print("    Migration đã được chạy trước đó hoặc không cần thiết.")
                return

            # ── Đọc toàn bộ locations + category hiện tại ──────────────────
            cur.execute("SELECT id, category FROM locations WHERE category IS NOT NULL AND category != ''")
            locations = cur.fetchall()
            print(f"\n[1/4] Tìm thấy {len(locations)} location cần migrate.")

            # ── Đọc map slug → id từ bảng categories ───────────────────────
            cur.execute("SELECT id, slug FROM categories")
            cat_rows = cur.fetchall()
            slug_to_id = {row[1]: row[0] for row in cat_rows}
            print(f"[2/4] Bảng categories có {len(slug_to_id)} danh mục: {list(slug_to_id.keys())}")

            # ── Kiểm tra location_categories đã có dữ liệu chưa ─────────────
            cur.execute("SELECT COUNT(*) FROM location_categories")
            existing_count = cur.fetchone()[0]
            if existing_count > 0:
                print(f"\n[!] Bảng location_categories đã có {existing_count} bản ghi.")
                answer = input("    Tiếp tục? (y/n): ").strip().lower()
                if answer != "y":
                    print("    Huỷ migration.")
                    return

            # ── Insert vào location_categories ─────────────────────────────
            insert_count = 0
            skip_count = 0
            unknown_slugs = set()

            for loc_id, cat_slug in locations:
                cat_id = slug_to_id.get(cat_slug)
                if cat_id is None:
                    print(f"  [!] Không tìm thấy category slug='{cat_slug}' cho location id={loc_id}, bỏ qua.")
                    unknown_slugs.add(cat_slug)
                    skip_count += 1
                    continue

                if not DRY_RUN:
                    cur.execute("""
                        INSERT IGNORE INTO location_categories (location_id, category_id)
                        VALUES (%s, %s)
                    """, (loc_id, cat_id))
                insert_count += 1

            print(f"[3/4] Đã map {insert_count} location → category. Bỏ qua {skip_count} (slug không tồn tại).")

            if unknown_slugs:
                print(f"  → Slug không nhận ra: {unknown_slugs}")
                # Tự động tạo category thiếu rồi insert lại
                for slug in unknown_slugs:
                    name = slug.replace("-", " ").title()
                    if not DRY_RUN:
                        cur.execute(
                            "INSERT IGNORE INTO categories (slug, name) VALUES (%s, %s)",
                            (slug, name)
                        )
                        cur.execute("SELECT id FROM categories WHERE slug = %s", (slug,))
                        row = cur.fetchone()
                        if row:
                            new_cat_id = row[0]
                            cur.execute("""
                                INSERT IGNORE INTO location_categories (location_id, category_id)
                                SELECT id, %s FROM locations WHERE category = %s
                            """, (new_cat_id, slug))
                    print(f"  [+] Tự tạo và map category: '{slug}' → '{name}'")

            # ── Drop cột `category` ──────────────────────────────────────────
            if not DRY_RUN:
                conn.commit()
                cur.execute("ALTER TABLE locations DROP COLUMN category")
                conn.commit()
                print("[4/4] Đã xoá cột `category` khỏi bảng `locations`.")
            else:
                print("[4/4] DRY RUN: Bỏ qua bước DROP COLUMN và COMMIT.")

        print("\n" + "=" * 55)
        print(f"  {'✅ Migration hoàn tất!' if not DRY_RUN else '👁 Dry run hoàn tất — không có gì thay đổi.'}")
        print("=" * 55)

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] Migration thất bại: {e}")
        print("  → DB đã được rollback, không có gì bị thay đổi.")
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    run()
