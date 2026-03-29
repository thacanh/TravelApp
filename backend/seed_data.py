"""
Seed data for database
Run this script to populate database with sample data.
Safe to re-run — uses upsert logic (checks before inserting).

Usage:
  python seed_data.py          # Add data if not exists
  python seed_data.py --reset  # Drop all data and re-seed
"""
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal, engine, Base
from app.models import User, Location, Review, Itinerary, ItineraryDay, ItineraryActivity, Category, LocationCategory
from app.utils.security import get_password_hash
from datetime import datetime, timedelta


def seed_database(reset=False):
    # Create tables
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()

    try:
        if reset:
            print("🔄 Resetting database...")
            from app.models import Favorite, ItineraryDay, ItineraryActivity
            from app.models.chat import ChatMessage, ChatSession
            db.query(ChatMessage).delete()
            db.query(ChatSession).delete()
            db.query(ItineraryActivity).delete()
            db.query(ItineraryDay).delete()
            db.query(Review).delete()
            db.query(Itinerary).delete()
            db.query(Favorite).delete()
            db.query(LocationCategory).delete()
            db.query(Location).delete()
            db.query(Category).delete()
            db.query(User).delete()
            db.commit()
            print("   ✅ All data deleted")

        # ── Users ──────────────────────────────
        users_data = [
            {
                "email": "admin@trawime.com",
                "password": "admin123",
                "full_name": "Admin TRAWiMe",
                "role": "admin",
            },
            {
                "email": "user@test.com",
                "password": "user123",
                "full_name": "Nguyễn Văn A",
                "phone": "0901234567",
                "role": "user",
            },
        ]

        created_users = {}
        for u in users_data:
            existing = db.query(User).filter(User.email == u["email"]).first()
            if existing:
                print(f"   ⏭ User {u['email']} already exists")
                created_users[u["email"]] = existing
            else:
                user = User(
                    email=u["email"],
                    password_hash=get_password_hash(u["password"]),
                    full_name=u["full_name"],
                    phone=u.get("phone"),
                    role=u["role"],
                    is_active=True,
                )
                db.add(user)
                db.commit()
                db.refresh(user)
                created_users[u["email"]] = user
                print(f"   ✅ Created user {u['email']}")

        admin = created_users["admin@trawime.com"]
        user = created_users["user@test.com"]

        # ── Categories ─────────────────────────
        categories_data = [
            {"slug": "beach", "name": "Bãi biển", "icon": "beach_access"},
            {"slug": "mountain", "name": "Núi", "icon": "terrain"},
            {"slug": "city", "name": "Thành phố", "icon": "location_city"},
            {"slug": "cultural", "name": "Văn hóa", "icon": "account_balance"},
            {"slug": "nature", "name": "Thiên nhiên", "icon": "park"},
            {"slug": "resort", "name": "Nghỉ dưỡng", "icon": "spa"},
        ]
        
        created_categories = {}
        for cat_data in categories_data:
            existing = db.query(Category).filter(Category.slug == cat_data["slug"]).first()
            if existing:
                created_categories[cat_data["slug"]] = existing
            else:
                cat = Category(**cat_data)
                db.add(cat)
                db.commit()
                db.refresh(cat)
                created_categories[cat_data["slug"]] = cat
        print(f"   ✅ Created {len(created_categories)} categories")

        # ── Locations ──────────────────────────
        locations_data = [
            {
                "name": "Vịnh Hạ Long",
                "description": "Di sản thiên nhiên thế giới với hàng nghìn hòn đảo đá vôi nổi trên mặt nước biển xanh ngọc bích. Đến Hạ Long, bạn có thể đi thuyền kayak, tham quan hang Sửng Sốt, và ngắm hoàng hôn từ du thuyền.",
                "category": "nature",
                "categories": ["nature", "beach"],
                "address": "Quảng Ninh",
                "city": "Quảng Ninh",
                "country": "Vietnam",
                "latitude": 20.9101,
                "longitude": 107.1839,
                "images": ["https://images.unsplash.com/photo-1528127269322-539801943592"],
                "rating_avg": 4.8,
                "total_reviews": 1250,
            },
            {
                "name": "Phố Cổ Hội An",
                "description": "Phố cổ với kiến trúc độc đáo, pha trộn văn hóa Việt Nam, Trung Quốc và Nhật Bản. Đêm đến, hàng nghìn đèn lồng rực rỡ chiếu sáng khắp phố cổ. Nổi tiếng với ẩm thực đường phố và may đo áo dài.",
                "category": "cultural",
                "categories": ["cultural", "city"],
                "address": "Hội An",
                "city": "Quảng Nam",
                "country": "Vietnam",
                "latitude": 15.8801,
                "longitude": 108.3380,
                "images": ["https://images.unsplash.com/photo-1583417319070-4a69db38a482"],
                "rating_avg": 4.7,
                "total_reviews": 980,
            },
            {
                "name": "Đà Lạt",
                "description": "Thành phố ngàn hoa với khí hậu mát mẻ quanh năm, cảnh quan thơ mộng. Nổi tiếng với các đồi chè, vườn hoa, thác nước và kiến trúc Pháp. Thích hợp cho các cặp đôi và gia đình.",
                "category": "city",
                "categories": ["city", "mountain", "nature"],
                "address": "Đà Lạt",
                "city": "Lâm Đồng",
                "country": "Vietnam",
                "latitude": 11.9404,
                "longitude": 108.4583,
                "images": ["https://images.unsplash.com/photo-1559592413-7cec4d0cae2b"],
                "rating_avg": 4.6,
                "total_reviews": 1100,
            },
            {
                "name": "Đảo Phú Quốc",
                "description": "Đảo ngọc với bãi biển đẹp, nước biển trong xanh và hệ sinh thái phong phú. Bãi Dài và Bãi Sao là những bãi biển đẹp nhất. Còn có cáp treo vượt biển dài nhất thế giới.",
                "category": "beach",
                "categories": ["beach", "nature", "resort"],
                "address": "Phú Quốc",
                "city": "Kiên Giang",
                "country": "Vietnam",
                "latitude": 10.2899,
                "longitude": 103.9840,
                "images": ["https://images.unsplash.com/photo-1559592413-7cec4d0cae2b"],
                "rating_avg": 4.5,
                "total_reviews": 875,
            },
            {
                "name": "Sapa",
                "description": "Vùng núi cao với ruộng bậc thang tuyệt đẹp và văn hóa dân tộc đặc sắc. Trekking qua các bản làng, ngắm đỉnh Fansipan và thưởng thức ẩm thực vùng cao.",
                "category": "mountain",
                "categories": ["mountain", "cultural", "nature"],
                "address": "Sapa",
                "city": "Lào Cai",
                "country": "Vietnam",
                "latitude": 22.3363,
                "longitude": 103.8438,
                "images": ["https://images.unsplash.com/photo-1583417319070-4a69db38a482"],
                "rating_avg": 4.4,
                "total_reviews": 720,
            },
            {
                "name": "Nha Trang",
                "description": "Thành phố biển nổi tiếng với bãi biển dài, nước trong và nhiều hoạt động thể thao nước. Lặn biển ngắm san hô, tham quan Vinpearl Land và tháp Ponagar.",
                "category": "beach",
                "categories": ["beach", "city", "resort"],
                "address": "Nha Trang",
                "city": "Khánh Hòa",
                "country": "Vietnam",
                "latitude": 12.2388,
                "longitude": 109.1967,
                "images": ["https://images.unsplash.com/photo-1528127269322-539801943592"],
                "rating_avg": 4.3,
                "total_reviews": 950,
            },
            {
                "name": "Cố Đô Huế",
                "description": "Cố đô với kiến trúc cung điện, lăng tẩm và văn hóa Việt Nam đậm đà. Di sản thế giới UNESCO với Đại Nội, lăng Minh Mạng, Khải Định và sông Hương thơ mộng.",
                "category": "cultural",
                "categories": ["cultural", "city"],
                "address": "Huế",
                "city": "Thừa Thiên Huế",
                "country": "Vietnam",
                "latitude": 16.4637,
                "longitude": 107.5909,
                "images": ["https://images.unsplash.com/photo-1583417319070-4a69db38a482"],
                "rating_avg": 4.5,
                "total_reviews": 680,
            },
            {
                "name": "Phong Nha - Kẻ Bàng",
                "description": "Vườn quốc gia với hệ thống hang động kỳ vĩ nhất thế giới. Sơn Đoòng - hang động lớn nhất hành tinh, Thiên Đường, Phong Nha và nhiều hang động tuyệt đẹp khác.",
                "category": "nature",
                "categories": ["nature", "mountain"],
                "address": "Bố Trạch",
                "city": "Quảng Bình",
                "country": "Vietnam",
                "latitude": 17.5821,
                "longitude": 106.2859,
                "images": ["https://images.unsplash.com/photo-1559592413-7cec4d0cae2b"],
                "rating_avg": 4.9,
                "total_reviews": 550,
            },
        ]

        locations = []
        for loc_data in locations_data:
            cat_slugs = loc_data.pop("categories", [])
            existing = db.query(Location).filter(Location.name == loc_data["name"]).first()
            if existing:
                print(f"   ⏭ Location '{loc_data['name']}' already exists")
                locations.append(existing)
            else:
                location = Location(**loc_data)
                db.add(location)
                db.commit()
                db.refresh(location)
                locations.append(location)
                print(f"   ✅ Created location '{loc_data['name']}'")
                
                # Add categories
                for slug in cat_slugs:
                    cat = created_categories.get(slug)
                    if cat:
                        db.add(LocationCategory(location_id=location.id, category_id=cat.id))
                db.commit()

        # ── Reviews ────────────────────────────
        existing_reviews = db.query(Review).count()
        if existing_reviews == 0:
            reviews_data = [
                {"location_idx": 0, "rating": 5, "comment": "Cảnh đẹp tuyệt vời! Vịnh Hạ Long xứng đáng là kỳ quan thiên nhiên"},
                {"location_idx": 0, "rating": 4, "comment": "Đẹp nhưng hơi đông người vào mùa du lịch"},
                {"location_idx": 1, "rating": 5, "comment": "Phố cổ Hội An thật lãng mạn, đặc biệt vào buổi tối với đèn lồng"},
                {"location_idx": 2, "rating": 4, "comment": "Đà Lạt mát mẻ, thích hợp đi dạo và chụp ảnh"},
                {"location_idx": 3, "rating": 5, "comment": "Bãi biển Phú Quốc đẹp như mơ! Nước trong vắt"},
            ]

            for rev_data in reviews_data:
                idx = rev_data.pop("location_idx")
                review = Review(
                    user_id=user.id,
                    location_id=locations[idx].id,
                    **rev_data,
                )
                db.add(review)

            db.commit()
            print(f"   ✅ Created {len(reviews_data)} reviews")
        else:
            print(f"   ⏭ Reviews already exist ({existing_reviews})")

        # ── Itinerary ──────────────────────────
        existing_itineraries = db.query(Itinerary).count()
        if existing_itineraries == 0:
            itinerary = Itinerary(
                user_id=user.id,
                title="Du lịch miền Trung 7 ngày",
                description="Hành trình khám phá miền Trung từ Huế đến Hội An",
                start_date=datetime.now() + timedelta(days=30),
                end_date=datetime.now() + timedelta(days=37),
                status="planned",
            )
            db.add(itinerary)
            db.flush()

            # Ngày 1 – Huế
            day1 = ItineraryDay(
                itinerary_id=itinerary.id,
                day_number=1,
                title="Khám phá Cố Đô Huế",
                description="Tham quan các di tích lịch sử tại Huế",
            )
            db.add(day1)
            db.flush()
            db.add(ItineraryActivity(
                day_id=day1.id, location_id=locations[6].id,
                title="Tham quan Đại Nội",
                description="Kinh thành Huế và các công trình hoàng gia",
                start_time=datetime.strptime("08:00", "%H:%M").time(),
                end_time=datetime.strptime("11:30", "%H:%M").time(),
                note="Mua vé trước online",
            ))
            db.add(ItineraryActivity(
                day_id=day1.id, location_id=locations[6].id,
                title="Thuyền trên sông Hương",
                description="Ngắm hoàng hôn trên sông Hương",
                start_time=datetime.strptime("16:00", "%H:%M").time(),
                end_time=datetime.strptime("18:00", "%H:%M").time(),
                cost_estimate=150000,
            ))

            # Ngày 2 – Hội An
            day2 = ItineraryDay(
                itinerary_id=itinerary.id,
                day_number=2,
                title="Dạo Phố Cổ Hội An",
                description="Khám phá phố cổ và ẩm thực Hội An",
            )
            db.add(day2)
            db.flush()
            db.add(ItineraryActivity(
                day_id=day2.id, location_id=locations[1].id,
                title="Tham quan phố cổ buổi sáng",
                description="Đi bộ qua các con phố cổ kính",
                start_time=datetime.strptime("07:30", "%H:%M").time(),
                end_time=datetime.strptime("11:00", "%H:%M").time(),
            ))
            db.add(ItineraryActivity(
                day_id=day2.id, location_id=None,
                title="Ăn Cao Lầu và Bánh Mì Phượng",
                description="Thưởng thức ẩm thực đặc trưng Hội An",
                start_time=datetime.strptime("12:00", "%H:%M").time(),
                end_time=datetime.strptime("13:00", "%H:%M").time(),
                cost_estimate=100000,
                note="Bánh mì Phượng – 2B Phan Châu Trinh",
            ))
            db.add(ItineraryActivity(
                day_id=day2.id, location_id=locations[1].id,
                title="Phố đèn lồng buổi tối",
                description="Thả đèn hoa đăng và ngắm phố cổ về đêm",
                start_time=datetime.strptime("19:00", "%H:%M").time(),
                end_time=datetime.strptime("21:30", "%H:%M").time(),
                cost_estimate=30000,
            ))

            db.commit()
            print("   ✅ Created 1 itinerary with 2 days and 5 activities")
        else:
            print(f"   ⏭ Itineraries already exist ({existing_itineraries})")


        print("\n✅ Database seeded successfully!")
        print(f"   - {len(locations)} locations")
        print("   - Accounts: admin@trawime.com / admin123, user@test.com / user123")

    except Exception as e:
        print(f"\n❌ Error seeding database: {e}")
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    reset = "--reset" in sys.argv
    seed_database(reset=reset)
