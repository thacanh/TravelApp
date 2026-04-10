"""
seed_data.py — TRAWiMe demo data seeder

Cách dùng:
    python seed_data.py

Yêu cầu:
    - Docker đang chạy (docker compose up -d)
    - pip install requests pymysql

Môi trường mặc định: http://192.168.100.222:8000
Đổi BASE_URL / DB_* bên dưới nếu cần.
"""

import sys
import time
import requests
import pymysql

# ─── Config ───────────────────────────────────────────────────────────────────
BASE_URL       = "http://192.168.100.222:8000"
ADMIN_EMAIL    = "admin@trawime.com"
ADMIN_PASSWORD = "Admin@123"
ADMIN_NAME     = "Admin TRAWiMe"

# Kết nối DB trực tiếp để set role=admin (auth-service không có endpoint đổi role)
DB_HOST = "192.168.100.222"
DB_PORT = 3306
DB_USER = "root"
DB_PASS = "220104"
DB_NAME = "trawime_db"

# ─── Data ─────────────────────────────────────────────────────────────────────

CATEGORIES = [
    {"slug": "beach",      "name": "Bãi biển"},
    {"slug": "mountain",   "name": "Núi"},
    {"slug": "city",       "name": "Thành phố"},
    {"slug": "cultural",   "name": "Văn hóa"},
    {"slug": "nature",     "name": "Thiên nhiên"},
    {"slug": "historical", "name": "Lịch sử"},
    {"slug": "food",       "name": "Ẩm thực"},
    {"slug": "waterfall",  "name": "Thác nước"},
    {"slug": "island",     "name": "Đảo"},
]

LOCATIONS = [
    {
        "name": "Vịnh Hạ Long",
        "description": "Vịnh Hạ Long là một trong những kỳ quan thiên nhiên thế giới, nổi tiếng với hàng nghìn hòn đảo đá vôi nổi trên vùng nước xanh ngọc bích. Đây là điểm đến lý tưởng để du thuyền, tắm biển, khám phá hang động và trải nghiệm văn hóa ngư dân địa phương.",
        "category": "nature",
        "city": "Quảng Ninh",
        "address": "Vịnh Hạ Long, Quảng Ninh, Việt Nam",
        "latitude": 20.9101,
        "longitude": 107.1839,
    },
    {
        "name": "Phố Cổ Hội An",
        "description": "Hội An là đô thị cổ được UNESCO công nhận là Di sản Văn hóa Thế giới. Thành phố nhỏ bên bờ sông Thu Bồn nổi tiếng với những ngôi nhà cổ kính, đèn lồng rực rỡ và ẩm thực đặc sắc như Cao Lầu, Mì Quảng, Bánh Mì Hội An.",
        "category": "cultural",
        "city": "Hội An",
        "address": "Phố Cổ Hội An, Quảng Nam, Việt Nam",
        "latitude": 15.8801,
        "longitude": 108.3380,
    },
    {
        "name": "Bãi Sao Phú Quốc",
        "description": "Bãi Sao là một trong những bãi biển đẹp nhất Việt Nam, tọa lạc ở phía đông nam đảo Phú Quốc. Bãi biển có cát trắng mịn, nước trong xanh, lý tưởng cho lặn ngắm san hô, kayaking và nghỉ dưỡng cao cấp.",
        "category": "beach",
        "city": "Phú Quốc",
        "address": "Bãi Sao, An Thới, Phú Quốc, Kiên Giang",
        "latitude": 10.0128,
        "longitude": 104.0237,
    },
    {
        "name": "Đà Lạt",
        "description": "Đà Lạt được mệnh danh là 'Thành phố Ngàn hoa' và 'Paris của Đông Dương'. Khí hậu mát mẻ quanh năm, những đồi thông xanh mướt, hồ thơ mộng và kiến trúc Pháp cổ kính tạo nên không khí lãng mạn và dễ chịu. Đây là điểm đến yêu thích cho tuần trăng mật và du lịch nghỉ dưỡng.",
        "category": "city",
        "city": "Đà Lạt",
        "address": "Thành phố Đà Lạt, Lâm Đồng, Việt Nam",
        "latitude": 11.9404,
        "longitude": 108.4583,
    },
    {
        "name": "Thác Bản Giốc",
        "description": "Thác Bản Giốc là thác nước tự nhiên lớn nhất Đông Nam Á và nằm trên đường biên giới Việt Nam - Trung Quốc. Thác có chiều rộng 300m và cao 53m, tạo nên khung cảnh hùng vĩ giữa núi rừng Cao Bằng xanh tươi. Mùa nước lớn từ tháng 8 đến tháng 10 là thời điểm đẹp nhất.",
        "category": "waterfall",
        "city": "Cao Bằng",
        "address": "Xã Đàm Thủy, Trùng Khánh, Cao Bằng",
        "latitude": 22.8562,
        "longitude": 106.7072,
    },
    {
        "name": "Hoàng Thành Thăng Long",
        "description": "Hoàng Thành Thăng Long là quần thể di tích lịch sử nằm tại trung tâm Hà Nội, là nơi ghi dấu lịch sử hơn 1000 năm trị vì của các triều đại phong kiến Việt Nam từ thời nhà Lý đến nhà Nguyễn. Được UNESCO công nhận là Di sản Văn hóa Thế giới năm 2010.",
        "category": "historical",
        "city": "Hà Nội",
        "address": "19C Hoàng Diệu, Ba Đình, Hà Nội",
        "latitude": 21.0358,
        "longitude": 105.8354,
    },
    {
        "name": "Núi Fansipan",
        "description": "Fansipan là ngọn núi cao nhất Đông Dương với độ cao 3143 mét so với mực nước biển, được mệnh danh là 'Nóc nhà Đông Dương'. Du khách có thể lên đỉnh bằng hệ thống cáp treo hiện đại hoặc trekking 2-3 ngày qua những cánh rừng nguyên sinh đa dạng sinh học.",
        "category": "mountain",
        "city": "Sapa",
        "address": "Dãy Hoàng Liên Sơn, Sa Pa, Lào Cai",
        "latitude": 22.3030,
        "longitude": 103.7760,
    },
    {
        "name": "Phố Đi Bộ Hồ Gươm",
        "description": "Khu vực Hồ Hoàn Kiếm và phố đi bộ Đinh Tiên Hoàng là trái tim của Hà Nội. Nơi đây nổi tiếng với Tháp Rùa, cầu Thê Húc, đền Ngọc Sơn và không khí sôi động cuối tuần. Phố đi bộ mở cửa từ tối thứ 6 đến tối chủ nhật hằng tuần.",
        "category": "city",
        "city": "Hà Nội",
        "address": "Hồ Hoàn Kiếm, Hoàn Kiếm, Hà Nội",
        "latitude": 21.0285,
        "longitude": 105.8521,
    },
    {
        "name": "Chợ Bến Thành",
        "description": "Chợ Bến Thành là biểu tượng văn hóa và ẩm thực của Thành phố Hồ Chí Minh. Nổi tiếng với đồ lưu niệm, vải vóc và đặc sản miền Nam, chợ còn là thiên đường ẩm thực với hàng trăm gian hàng cơm tấm, bún thịt nướng, hủ tiếu và các món ăn địa phương đặc sắc.",
        "category": "food",
        "city": "Hồ Chí Minh",
        "address": "Phạm Ngũ Lão, Quận 1, Thành phố Hồ Chí Minh",
        "latitude": 10.7722,
        "longitude": 106.6983,
    },
    {
        "name": "Đảo Cô Tô",
        "description": "Cô Tô là quần đảo ngoài khơi tỉnh Quảng Ninh, nổi tiếng với bãi biển hoang sơ, nước trong xanh và hải sản tươi ngon. Đây là điểm đến lý tưởng cho những ai muốn tránh xa đám đông để tận hưởng không khí yên bình của biển đảo và khám phá cuộc sống ngư dân địa phương.",
        "category": "island",
        "city": "Quảng Ninh",
        "address": "Huyện Cô Tô, Quảng Ninh",
        "latitude": 20.9833,
        "longitude": 107.7667,
    },
    {
        "name": "Làng Cổ Đường Lâm",
        "description": "Đường Lâm là ngôi làng cổ đầu tiên được Nhà nước công nhận là Di tích Lịch sử Văn hóa Quốc gia. Nằm cách Hà Nội 50km, làng còn lưu giữ nhiều ngôi nhà đá ong hàng trăm năm tuổi, đình làng cổ kính và là quê hương của hai vị vua Việt Nam - Phùng Hưng và Ngô Quyền.",
        "category": "historical",
        "city": "Hà Nội",
        "address": "Đường Lâm, Sơn Tây, Hà Nội",
        "latitude": 21.1406,
        "longitude": 105.4597,
    },
    {
        "name": "Mũi Né",
        "description": "Mũi Né là điểm đến nổi tiếng với những đồi cát vàng và cát đỏ tuyệt đẹp, bãi biển dài và làng chài rực rỡ. Nơi đây còn được mệnh danh là thủ đô lướt sóng, lướt ván diều của Việt Nam nhờ gió mạnh và thuận lợi. Suối Tiên và bãi đá Ông Địa là những điểm check-in ưa thích.",
        "category": "beach",
        "city": "Phan Thiết",
        "address": "Thị trấn Mũi Né, Phan Thiết, Bình Thuận",
        "latitude": 10.9438,
        "longitude": 108.2855,
    },
    {
        "name": "Tháp Chàm Mỹ Sơn",
        "description": "Thánh địa Mỹ Sơn là quần thể đền tháp Chăm Pa cổ kính, được UNESCO công nhận là Di sản Văn hóa Thế giới năm 1999. Nằm trong thung lũng bao quanh bởi rừng núi hùng vĩ tại Quảng Nam, Mỹ Sơn là minh chứng cho nền văn minh Chăm Pa rực rỡ từ thế kỷ 4 đến thế kỷ 13.",
        "category": "cultural",
        "city": "Quảng Nam",
        "address": "Xã Duy Phú, Huyện Duy Xuyên, Quảng Nam",
        "latitude": 15.7667,
        "longitude": 108.1194,
    },
    {
        "name": "Vườn Quốc Gia Phong Nha - Kẻ Bàng",
        "description": "Phong Nha - Kẻ Bàng là Vườn Quốc gia và Di sản Thiên nhiên Thế giới UNESCO, nổi tiếng với hệ thống hang động kỳ vĩ nhất thế giới. Hang Sơn Đoòng - hang động lớn nhất thế giới, hang Phong Nha và động Thiên Đường là những điểm khám phá không thể bỏ qua.",
        "category": "nature",
        "city": "Quảng Bình",
        "address": "Huyện Bố Trạch, Quảng Bình",
        "latitude": 17.5411,
        "longitude": 106.1469,
    },
    {
        "name": "Núi Bà Đen",
        "description": "Núi Bà Đen là ngọn núi cao nhất Nam Bộ với độ cao 986 mét, nằm ở tây bắc tỉnh Tây Ninh. Đây là điểm hành hương tâm linh nổi tiếng với ngôi chùa trên đỉnh núi và hệ thống cáp treo hiện đại. Du khách còn có thể cắm trại và ngắm toàn cảnh đồng bằng sông Cửu Long từ trên cao.",
        "category": "mountain",
        "city": "Tây Ninh",
        "address": "Núi Bà Đen, Thành phố Tây Ninh, Tây Ninh",
        "latitude": 11.3982,
        "longitude": 106.0783,
    },
]

NORMAL_USERS = [
    {"email": "nguyen.an@gmail.com",   "password": "Pass@123", "full_name": "Nguyễn An",        "phone": "0901234567"},
    {"email": "tran.bich@gmail.com",   "password": "Pass@123", "full_name": "Trần Thị Bích",    "phone": "0912345678"},
    {"email": "le.minh@gmail.com",     "password": "Pass@123", "full_name": "Lê Minh Khoa",     "phone": "0923456789"},
    {"email": "pham.hoa@gmail.com",    "password": "Pass@123", "full_name": "Phạm Thanh Hoa",   "phone": "0934567890"},
    {"email": "hoang.duc@gmail.com",   "password": "Pass@123", "full_name": "Hoàng Đức Thắng",  "phone": "0945678901"},
]

REVIEWS_TEMPLATE = [
    {"rating": 5.0, "comment": "Nơi tuyệt vời, phong cảnh hùng vĩ và đẹp mê hồn! Nhất định phải ghé thêm lần nữa."},
    {"rating": 4.5, "comment": "Rất đẹp, hướng dẫn viên nhiệt tình. Giá tour hơi cao nhưng xứng đáng với trải nghiệm."},
    {"rating": 4.0, "comment": "Cảnh đẹp, không khí trong lành. Đường đi hơi xa và khó đi nhưng đáng để khám phá."},
    {"rating": 4.8, "comment": "Trải nghiệm đáng nhớ trong cuộc đời. Nơi đây không lời nào tả hết được vẻ đẹp."},
    {"rating": 3.5, "comment": "Đẹp nhưng khá đông khách du lịch. Nên đi vào mùa thấp điểm để tận hưởng trọn vẹn hơn."},
]

# ─── HTTP helpers ──────────────────────────────────────────────────────────────

def _post(path, data, token=None, as_form=False):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if as_form:
        resp = requests.post(f"{BASE_URL}{path}", data=data, headers=headers, timeout=30)
    else:
        resp = requests.post(f"{BASE_URL}{path}", json=data, headers=headers, timeout=30)
    return resp

def _get(path, token=None, params=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return requests.get(f"{BASE_URL}{path}", headers=headers, params=params, timeout=30)

def _login(email, password):
    resp = _post("/api/auth/login", {"username": email, "password": password}, as_form=True)
    if resp.status_code == 200:
        return resp.json()["access_token"]
    print(f"  ✗ Đăng nhập thất bại ({email}): {resp.text}")
    return None

# ─── Steps ────────────────────────────────────────────────────────────────────

def step_create_admin():
    """Tạo tài khoản admin nếu chưa có, sau đó set role=admin trực tiếp trong DB."""
    print("\n[0/6] Kiểm tra tài khoản admin...")

    # Thử đăng nhập trước
    token = _login(ADMIN_EMAIL, ADMIN_PASSWORD)
    if token:
        print(f"  ✓ Admin đã có: {ADMIN_EMAIL}")
        return

    # Đăng ký tài khoản mới
    resp = _post("/api/auth/register", {
        "email": ADMIN_EMAIL,
        "password": ADMIN_PASSWORD,
        "full_name": ADMIN_NAME,
    })
    if resp.status_code not in (200, 201):
        print(f"  ✗ Không thể đăng ký admin: {resp.text}")
        print("  → Tạo thủ công qua MySQL hoặc kiểm tra backend.")
        sys.exit(1)

    # Set role=admin qua DB trực tiếp
    try:
        conn = pymysql.connect(host=DB_HOST, port=DB_PORT, user=DB_USER,
                               password=DB_PASS, database=DB_NAME, charset="utf8mb4")
        with conn.cursor() as cur:
            cur.execute("UPDATE users SET role='admin' WHERE email=%s", (ADMIN_EMAIL,))
        conn.commit()
        conn.close()
        print(f"  ✓ Tạo admin thành công: {ADMIN_EMAIL}")
    except Exception as e:
        print(f"  ✗ Không thể set role=admin qua DB: {e}")
        print("  → Tự chạy: UPDATE users SET role='admin' WHERE email='admin@trawime.com';")

def step_admin_token():
    print("\n[1/6] Đăng nhập admin...")
    token = _login(ADMIN_EMAIL, ADMIN_PASSWORD)
    if not token:
        print("  ✗ Không thể đăng nhập admin. Kiểm tra lại email/password trong DATABASE.")
        sys.exit(1)
    print(f"  ✓ Đăng nhập thành công: {ADMIN_EMAIL}")
    return token

def step_categories(admin_token):
    print("\n[2/6] Tạo danh mục...")
    # Xem các category đã có
    existing = set()
    resp = _get("/api/categories", admin_token)
    if resp.status_code == 200:
        for c in resp.json():
            existing.add(c["slug"])

    created = 0
    for cat in CATEGORIES:
        if cat["slug"] in existing:
            print(f"  – Đã có: {cat['name']} ({cat['slug']})")
            continue
        resp = _post("/api/categories", cat, admin_token)
        if resp.status_code in (200, 201):
            print(f"  ✓ Tạo: {cat['name']}")
            created += 1
        else:
            print(f"  ✗ Lỗi tạo {cat['slug']}: {resp.text}")
    print(f"  → Tổng mới: {created} | Đã có: {len(existing)}")
    # Trả về map slug→id
    resp = _get("/api/categories", admin_token)
    return {c["slug"]: c["id"] for c in resp.json()} if resp.status_code == 200 else {}

def step_locations(admin_token):
    print("\n[3/6] Tạo địa điểm...")
    # Xem location đã có
    resp = _get("/api/locations", admin_token, params={"limit": 100})
    existing_names = set()
    if resp.status_code == 200:
        for loc in resp.json():
            existing_names.add(loc["name"])

    location_ids = []
    for loc in LOCATIONS:
        if loc["name"] in existing_names:
            print(f"  – Đã có: {loc['name']}")
            # Lấy id để embed sau
            resp2 = _get("/api/locations", admin_token, params={"search": loc["name"], "limit": 1})
            if resp2.status_code == 200 and resp2.json():
                location_ids.append(resp2.json()[0]["id"])
            continue
        resp = _post("/api/locations", loc, admin_token)
        if resp.status_code in (200, 201):
            loc_id = resp.json().get("id")
            location_ids.append(loc_id)
            print(f"  ✓ Tạo: {loc['name']} (id={loc_id})")
        else:
            print(f"  ✗ Lỗi tạo {loc['name']}: {resp.text}")
        time.sleep(0.2)  # Gentle rate limit
    print(f"  → Tổng địa điểm: {len(location_ids)}")
    return location_ids

def step_users():
    print("\n[4/6] Tạo user thường...")
    user_tokens = []
    for u in NORMAL_USERS:
        # Thử đăng nhập trước
        token = _login(u["email"], u["password"])
        if token:
            print(f"  – Đã có: {u['full_name']}")
            user_tokens.append(token)
            continue
        # Đăng ký mới
        resp = _post("/api/auth/register", {
            "email": u["email"],
            "password": u["password"],
            "full_name": u["full_name"],
            "phone": u.get("phone"),
        })
        if resp.status_code in (200, 201):
            token = _login(u["email"], u["password"])
            if token:
                user_tokens.append(token)
                print(f"  ✓ Tạo: {u['full_name']}")
        else:
            print(f"  ✗ Lỗi tạo {u['email']}: {resp.text}")
    print(f"  → Tổng users: {len(user_tokens)}")
    return user_tokens

def step_reviews(user_tokens, location_ids):
    print("\n[5/6] Tạo đánh giá...")
    if not user_tokens:
        print("  ! Không có user token, bỏ qua bước này.")
        return
    total = 0
    for i, loc_id in enumerate(location_ids):
        # Mỗi location lấy 2-3 review từ users khác nhau
        for j, token in enumerate(user_tokens[:3]):
            review = REVIEWS_TEMPLATE[(i + j) % len(REVIEWS_TEMPLATE)]
            resp = _post("/api/reviews", {
                "location_id": loc_id,
                "rating": review["rating"],
                "comment": review["comment"],
                "photos": [],
            }, token)
            if resp.status_code in (200, 201):
                total += 1
            else:
                # Có thể đã review rồi, im lặng
                pass
            time.sleep(0.1)
    print(f"  ✓ Tổng review tạo được: {total}")

def step_embeddings(admin_token):
    print("\n[6/6] Tạo embedding cho tất cả địa điểm...")
    resp = requests.post(
        f"{BASE_URL}/api/ai/generate-embeddings",
        headers={"Authorization": f"Bearer {admin_token}"},
        timeout=120,
    )
    if resp.status_code == 200:
        data = resp.json()
        print(f"  ✓ {data.get('message', 'Xong')}")
        if data.get("errors", 0) > 0:
            print(f"  ! {data['errors']} lỗi embedding (kiểm tra GEMINI_API_KEY)")
    elif resp.status_code == 503:
        print("  ! Gemini API không khả dụng — bỏ qua embedding.")
        print("    Thêm GEMINI_API_KEY vào .env và chạy lại để có AI gợi ý chính xác.")
    else:
        print(f"  ✗ Lỗi embedding: {resp.status_code} — {resp.text[:200]}")

# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print("  TRAWiMe — Seed Data Script")
    print(f"  Server: {BASE_URL}")
    print("=" * 55)

    # Kiểm tra server còn sống không
    try:
        resp = requests.get(f"{BASE_URL}/health", timeout=5)
        print(f"\n  Server: {'OK ✓' if resp.status_code == 200 else 'Lỗi ✗'}")
    except Exception as e:
        print(f"\n  ✗ Không kết nối được server: {e}")
        print("  → Đảm bảo Docker đang chạy: docker compose up -d")
        sys.exit(1)

    step_create_admin()
    admin_token  = step_admin_token()
    step_categories(admin_token)
    location_ids = step_locations(admin_token)
    user_tokens  = step_users()
    step_reviews(user_tokens, location_ids)
    step_embeddings(admin_token)

    print("\n" + "=" * 55)
    print("  ✅ Seed hoàn tất!")
    print(f"  Địa điểm: {len(location_ids)}")
    print(f"  Users   : {len(user_tokens)}")
    print(f"  Admin   : {ADMIN_EMAIL} / {ADMIN_PASSWORD}")
    print("=" * 55)

if __name__ == "__main__":
    main()
