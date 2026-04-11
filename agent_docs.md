# TRAWIME - Comprehensive Agent Guide

Document này dành cho AI Agent / LLM Assistant để hiểu rõ kiến trúc, cấu trúc, luồng hoạt động và các quyết định thiết kế của dự án **TRAWIME** (Ứng dụng du lịch Việt Nam tích hợp AI).

> **Last updated:** 2026-04-11 — Sau các phiên refactor Profile, Avatar Upload, Gateway Proxy, N-N Category Architecture.

---

## 1. Overview

TRAWIME là ứng dụng di động cho phép người dùng khám phá, đánh giá và quản lý các hoạt động du lịch tại Việt Nam, kết hợp AI thông minh (Chatbot + Semantic Recommendation).

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter (Dart) |
| Backend | Microservices — FastAPI (Python 3.11) |
| Database | MySQL (shared DB `trawime_db`) |
| AI Core | Google Gemini API (Flash + Embedding-001) |
| Container | Docker Compose |
| API Proxy | Custom API Gateway (FastAPI + httpx) |

---

## 2. Backend Architecture

### 2.1 Service Map

Tất cả service khởi chạy qua `backend/docker-compose.yml`. Mọi request từ mobile **phải đi qua Gateway (port 8000)**.

| Service | Port | Prefix route | Mô tả |
|---|---|---|---|
| **API Gateway** | 8000 | `/` (tất cả) | Entry point duy nhất. Xác thực JWT, inject headers, reverse proxy |
| **Auth Service** | 8001 | `/api/auth` | Đăng ký, đăng nhập, trả JWT |
| **User Service** | 8002 | `/api/users`, `/uploads` | Profile, avatar upload, favorites |
| **Location Service** | 8003 | `/api/locations`, `/api/categories`, `/media` | Địa điểm, danh mục, ảnh địa điểm |
| **Review Service** | 8004 | `/api/reviews`, `/api/checkins` | Đánh giá, check-in, upload ảnh review |
| **Itinerary Service** | 8005 | `/api/itineraries` | Lịch trình du lịch, tối ưu tuyến đường |
| **AI Service** | 8006 | `/api/ai`, `/api/chat` | Chatbot Gemini, semantic recommendation |
| **Admin Service** | 8007 | `/api/admin` | Quản trị hệ thống, kiểm duyệt |

### 2.2 API Gateway — Chi tiết quan trọng

**File:** `backend/api-gateway/main.py`

**Luồng xử lý:**
1. Request vào → kiểm tra path có trong `PUBLIC_PATHS` hoặc `PUBLIC_PREFIXES` không
2. Nếu không public → decode JWT → extract `sub_id`, `role`, `sub` (email), `name`
3. Build `extra_headers` (X-User-*) với **URL-encoding** cho giá trị chứa Unicode
4. **Sanitize client headers**: loại bỏ hop-by-hop headers (`transfer-encoding`, `connection`, `te`, `upgrade`, `host`, `content-length`)
5. Loại bỏ header client có giá trị non-ASCII (dùng `.encode('ascii')` test)
6. httpx async proxy → stream response

**Các endpoint PUBLIC (không cần JWT):**
- `PUBLIC_PATHS`: `/api/auth/login`, `/api/auth/register`, `/`, `/health`, `/docs`, `/openapi.json`
- `PUBLIC_PREFIXES`: `/uploads/`, `/media/` (static files — ảnh avatar, ảnh địa điểm)

**Headers inject vào downstream:**
```
X-User-Id:    str(payload["sub_id"])
X-User-Role:  str(payload["role"])
X-User-Email: quote(payload["sub"], safe="@.")        # URL-encoded
X-User-Name:  quote(payload["name"], safe="")         # URL-encoded (tránh UnicodeEncodeError)
```

> ⚠️ **QUAN TRỌNG:** HTTP header value phải là ASCII. Tên tiếng Việt (VD: "Nguyễn") phải được `urllib.parse.quote()` trước khi đưa vào header. Service nhận có thể `unquote()` nếu cần tên thật.

### 2.3 Avatar Upload Flow

**Endpoint:** `POST /api/users/avatar` (multipart form, field name: `file`)

**Backend (user-service/main.py):**
- `_save_file()` extract extension từ `upload_file.filename` (có handle `None`)
- Lưu vào `/app/uploads/avatars/<uuid>.<ext>`
- Cập nhật `user.avatar_url = f"{settings.BASE_URL}/uploads/avatars/<uuid>.<ext>"` — **lưu full URL**
- `BASE_URL` đọc từ env var `BASE_URL=http://192.168.100.222:8000` (gateway port)

**Mobile (api_service.dart):**
```dart
final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
final safeFileName = 'avatar.$ext';
MultipartFile.fromFile(filePath, filename: safeFileName)
```
> Phải set `filename` rõ ràng vì một số platform Android không đính kèm filename, backend sẽ không detect được extension.

**Volume mount (docker-compose.yml):** `user_service_uploads:/app/uploads` — files persist qua restart.

### 2.4 Location Categories — N-N Architecture

**Database:**
- Bảng `categories`: `id`, `slug` (unique, VD: `beach`), `name` (VD: `Bãi biển`)
- Bảng `location_categories`: `(location_id FK, category_id FK)` — bảng nối N-N
- Bảng `locations`: **KHÔNG còn cột `category`** (đã xóa)

**Backend (location-service):**
- SQLAlchemy `relationship(..., secondary="location_categories")` cho ORM auto join
- Endpoint nhận `category_slugs: List[str]`
- Khi thêm/sửa địa điểm: tạo Category mới nếu slug chưa tồn tại
- Khi xóa/sửa và category không còn địa điểm nào → tự xóa category đó
- Filter: `Location.categories.any(Category.slug == slug)`
- Response: `categories` là `List[{id, slug, name}]`

**Mobile:**
- Model `Location.categories` là `List<Category>` (không còn `String category`)
- Getter `categoryDisplay` nối tên bằng dấy phẩy
- Danh mục load dynamic từ API, không hardcode

### 2.5 Review Service

- Review và Check-in là **cùng một luồng** (unified workflow)
- Bảng `reviews`: `id`, `user_id`, `location_id`, `rating`, `comment`, `photos` (JSON array URLs), `user_name` (cache), `user_email`, `created_at`
- Khi tạo review → service gọi user-service lấy `full_name` cache vào `user_name`
- Photos lưu dưới dạng full URL: `http://192.168.100.222:8004/uploads/reviews/<uuid>.<ext>`
- Sau khi xóa review → gọi `POST /internal/locations/{id}/recalculate-rating` để cập nhật rating_avg

### 2.6 Admin Service — Reviews Endpoint

`GET /api/admin/reviews`:
- Join `Review` với `Location` để lấy `location_name`
- Trả `user_name`, `photos`, `location_name`, `comment`, `rating`, `created_at`
- Limit: tối đa 500 (thay vì 100 cũ)

---

## 3. Mobile Architecture (Flutter)

### 3.1 Config & Environment

**File:** `mobile/.env` (gitignored, copy từ `.env.example`)
```
APP_NAME=TRAWIME
BASE_URL=http://192.168.100.222:8000
```

**File:** `mobile/lib/config/app_config.dart`
```dart
static String get baseUrl => dotenv.env['BASE_URL'] ?? 'http://192.168.100.222:8000';
static String get appName => dotenv.env['APP_NAME'] ?? 'TRAWIME';
```

> Chỉ cần sửa `.env` để đổi server IP — không cần sửa code.
> Package: `flutter_dotenv: ^5.1.0` — load trong `main()` trước `runApp()`.

### 3.2 State Management

- **`AuthProvider`**: Quản lý auth state, `currentUser`, `isAdmin`
  - `login()` → `getCurrentUser()` → gọi `/api/users/profile` (ưu tiên)
  - Fallback: nếu user-service fail → thử `/api/auth/me`
  - Log lỗi bằng `debugPrint('[AuthProvider] ...')`
- **`LocationProvider`**: Danh sách địa điểm, categories, favorites

### 3.3 User Model (`models/user.dart`)

```dart
factory User.fromJson(Map<String, dynamic> json) {
  // Null-safe: dùng ?? fallback cho mọi field
  fullName: json['full_name'] ?? json['name'] ?? '',
  createdAt: DateTime.tryParse(...) ?? DateTime.now(),
}
```

### 3.4 Screen Map

```
screens/
├── admin/
│   ├── admin_dashboard_screen.dart   — Thống kê tổng quan
│   ├── admin_location_form_screen.dart  — Thêm/sửa địa điểm (admin)
│   ├── admin_locations_screen.dart   — Danh sách địa điểm (admin)
│   ├── admin_reviews_screen.dart     — Kiểm duyệt đánh giá (full: rating, comment, ảnh, tên địa điểm)
│   ├── admin_users_screen.dart       — Quản lý người dùng
│   └── map_picker_screen.dart        — Chọn tọa độ trên bản đồ
├── ai/
│   ├── ai_recommend_screen.dart      — Gợi ý địa điểm bằng AI (semantic search)
│   └── chatbot_screen.dart           — Chat với TRAWIME AI
├── auth/
│   ├── login_screen.dart
│   └── register_screen.dart
├── checkin/
│   └── checkin_screen.dart           — Tạo check-in/review mới
├── home/
│   └── home_screen.dart              — Trang chủ + Bottom nav (4 tab user, 5 tab admin)
├── itinerary/
│   ├── itinerary_detail_screen.dart
│   ├── itinerary_list_screen.dart
│   └── itinerary_route_map_screen.dart
├── locations/
│   ├── location_detail_screen.dart   — Chi tiết địa điểm (admin: nút Edit + Delete trong header)
│   └── location_list_screen.dart
├── map/
│   └── map_screen.dart               — Bản đồ tổng quan
└── profile/
    ├── edit_profile_screen.dart      — Chỉnh sửa thông tin + upload avatar
    ├── favorite_locations_screen.dart
    ├── my_reviews_screen.dart        — Đánh giá của tôi (Edit dialog + Delete)
    └── profile_screen.dart           — Trang cá nhân (không có admin section)
```

### 3.5 Bottom Navigation

**User thường (4 tab):** Trang chủ | Khám phá | AI Chat | Cá nhân

**Admin (5 tab):** Trang chủ | Khám phá | **Quản trị** | AI Chat | Cá nhân

> Admin **không** có section quản trị trong tab Cá nhân nữa — có tab Quản trị riêng.

### 3.6 Profile Screen

- Không dùng `SliverAppBar` (gây che avatar)
- Dùng gradient `Container` + `borderRadius` cong góc dưới
- Hiển thị avatar, tên, email, badge "Quản trị viên" nếu admin
- Menu: Chỉnh sửa thông tin | Yêu thích | Lịch trình | Đánh giá của tôi | Đăng xuất

### 3.7 Location Detail — Admin Actions

```dart
// SliverAppBar actions — chỉ hiện khi isAdmin
Consumer<AuthProvider>(builder: (_, auth, __) {
  if (!auth.isAdmin) return SizedBox.shrink();
  // Nút "✏️ Chỉnh sửa" → AdminLocationFormScreen (trả về true wenn saved)
  // Nút "🗑️ Xóa" → confirmDelete dialog → ApiService.deleteLocation() → pop
})
```

### 3.8 My Reviews Screen

- Danh sách review của user hiện tại (endpoint: `/api/checkins`)
- Mỗi card có: ✏️ Edit (dialog sửa rating + comment) + 🗑️ Delete (confirm)
- Delete: xóa ngay khỏi state list (không reload toàn bộ)

---

## 4. API Endpoints Reference

### Auth
| Method | Path | Auth | Mô tả |
|---|---|---|---|
| POST | `/api/auth/register` | No | Đăng ký |
| POST | `/api/auth/login` | No | Đăng nhập → JWT |
| GET | `/api/auth/me` | Yes | Thông tin user từ JWT |

### Users
| Method | Path | Auth | Mô tả |
|---|---|---|---|
| GET | `/api/users/profile` | Yes | Profile đầy đủ (avatar_url, phone, role) |
| PUT | `/api/users/profile` | Yes | Cập nhật thông tin |
| POST | `/api/users/avatar` | Yes | Upload avatar (multipart, field: `file`) |
| GET | `/api/users/favorites` | Yes | Danh sách yêu thích |
| POST | `/api/users/favorites/{id}` | Yes | Thêm yêu thích |
| DELETE | `/api/users/favorites/{id}` | Yes | Xóa yêu thích |

### Locations & Categories
| Method | Path | Auth | Mô tả |
|---|---|---|---|
| GET | `/api/locations` | No | Danh sách địa điểm |
| GET | `/api/locations/{id}` | No | Chi tiết địa điểm |
| POST | `/api/locations` | Admin | Thêm địa điểm |
| PUT | `/api/locations/{id}` | Admin | Sửa địa điểm |
| DELETE | `/api/locations/{id}` | Admin | Xóa địa điểm |
| POST | `/api/locations/upload-media` | Admin | Upload ảnh địa điểm |
| GET | `/api/categories` | No | Danh sách categories |

### Reviews
| Method | Path | Auth | Mô tả |
|---|---|---|---|
| GET | `/api/reviews/location/{id}` | No | Reviews của địa điểm |
| POST | `/api/reviews` | Yes | Tạo review |
| PUT | `/api/reviews/{id}` | Yes | Sửa review (chỉ chủ sở hữu) |
| DELETE | `/api/reviews/{id}` | Yes | Xóa review (chỉ chủ sở hữu) |
| GET | `/api/checkins` | Yes | Review của tôi |

### Admin
| Method | Path | Auth | Mô tả |
|---|---|---|---|
| GET | `/api/admin/stats` | Admin | Thống kê tổng quan |
| GET | `/api/admin/users` | Admin | Danh sách người dùng |
| PUT | `/api/admin/users/{id}/toggle-active` | Admin | Khóa/mở khóa user |
| GET | `/api/admin/reviews` | Admin | Tất cả reviews (full data) |
| DELETE | `/api/admin/reviews/{id}` | Admin | Xóa review bất kỳ |

### Static Files (không cần auth)
- `GET /uploads/avatars/<filename>` → avatar người dùng (từ user-service)
- `GET /media/<filename>` → ảnh địa điểm (từ location-service)

---

## 5. Common Gotchas & Known Issues

### 5.1 Header Encoding (CRITICAL)
- httpx **từ chối** header value có ký tự non-ASCII (UnicodeEncodeError)
- Gateway dùng `urllib.parse.quote()` cho `X-User-Name` và `X-User-Email`
- Gateway filter bỏ mọi header client có giá trị non-ASCII trước khi forward
- Hop-by-hop headers PHẢI bị loại bỏ: `transfer-encoding`, `connection`, `keep-alive`, `te`, `trailers`, `upgrade`, `host`, `content-length`

### 5.2 Avatar URL Format
- Avatar URL lưu trong DB là **full URL**: `http://192.168.100.222:8000/uploads/avatars/<uuid>.jpg`
- Không dùng relative path (dữ liệu cũ có thể là relative → `@field_validator` trong `UserResponse` auto-normalize)
- `BASE_URL` phải set trong `docker-compose.yml` env cho `user-service`

### 5.3 Mobile → Backend Connectivity
- Device thật dùng IP LAN: `http://192.168.100.222:8000`
- Emulator Android dùng: `http://10.0.2.2:8000`
- Thay đổi trong `mobile/.env`, không sửa code

### 5.4 Flutter Dotenv
- `.env` phải được khai báo trong `pubspec.yaml` assets
- `await dotenv.load(fileName: '.env')` gọi TRƯỚC `runApp()` trong `main()`
- `.env` bị gitignore — copy từ `.env.example` khi setup mới

### 5.5 Admin Reviews — Data Completeness
- `admin-service` có `Review` model riêng — phải khai báo đủ cột `photos`, `user_name`, `user_email`
- Thiếu cột → query trả về null cho các field đó
- `Location.name` cần khai báo trong admin-service model để JOIN lấy tên địa điểm

### 5.6 MultipartFile Filename
- **Luôn set `filename` rõ ràng** khi dùng `MultipartFile.fromFile()` trên Android
- Không set → `upload_file.filename` có thể là `None` ở backend → crash extension detection

---

## 6. Development Commands

### Backend
```bash
# Khởi chạy toàn bộ stack
cd backend
docker compose up -d

# Rebuild một service cụ thể
docker compose build <service-name>
docker compose up -d <service-name>

# Xem log
docker compose logs -f api-gateway
docker compose logs -f user-service
```

### Mobile
```bash
cd mobile
flutter pub get          # sau khi thay đổi pubspec.yaml
flutter run              # chạy trên device/emulator

# Hot reload: nhấn 'r' trong terminal
# Hot restart: nhấn 'R'
```

### Database
- Host: `localhost:3306` (MySQL)
- DB: `trawime_db`
- User/Pass: `root/220104`

---

## 7. App Name Convention

Tên app chính thức: **TRAWIME** (viết hoa toàn bộ)

- Android label: `android:label="TRAWIME"` (`AndroidManifest.xml`)
- iOS display name: `CFBundleDisplayName = TRAWIME` (`Info.plist`)
- Web: title và manifest đều là `TRAWIME`
- Trong code: dùng `AppConfig.appName` (đọc từ `.env`) thay vì hardcode
- **KHÔNG dùng** `TRAWiMe`, `Trawime`, `trawime` trong text hiển thị

---

*Updated by AI Agent — TRAWIME project. For internal use.*
