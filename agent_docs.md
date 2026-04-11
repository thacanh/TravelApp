# TRAWIME - Comprehensive Agent Guide

Document này dành cho AI Agent / LLM Assistant để hiểu rõ kiến trúc, cấu trúc, luồng hoạt động và các quyết định thiết kế của dự án **TRAWIME** (Ứng dụng du lịch Việt Nam tích hợp AI).

> **Last updated:** 2026-04-11 — Sau các phiên: Map Navigation, AI Chat Sessions, Itinerary AI Suggestions, Markdown rendering, url_launcher fix.

---

## 1. Overview

TRAWIME là ứng dụng di động cho phép người dùng khám phá, đánh giá và quản lý các hoạt động du lịch tại Việt Nam, kết hợp AI thông minh (Chatbot + Semantic Recommendation + Itinerary AI).

| Layer | Technology |
|---|---|
| Mobile Frontend | Flutter (Dart) |
| Backend | Microservices — FastAPI (Python 3.11) |
| Database | MySQL (shared DB `trawime_db`) |
| AI Core | Google Gemini API (`gemini-3.1-flash-lite` với ThinkingConfig) |
| Container | Docker Compose |
| API Proxy | Custom API Gateway (FastAPI + httpx) |
| Maps | OpenStreetMap (flutter_map) + OSRM routing |

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
| **AI Service** | 8006 | `/api/ai`, `/api/chat` | Chatbot Gemini, semantic recommendation, chat sessions |
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

### 2.3 AI Service — Chat Sessions & Gemini Config

**File:** `backend/ai-service/main.py`

**Model:** `gemini-2.0-flash-lite` với `ThinkingConfig(thinking_budget=0)` (tắt thinking để phản hồi nhanh)

**Chat Sessions:**
- Lưu lịch sử chat theo `session_id` (UUID)
- Endpoint: `POST /api/chat/message` — gửi tin nhắn + nhận phản hồi
- Endpoint: `GET /api/chat/sessions` — danh sách phiên chat
- Endpoint: `GET /api/chat/sessions/{id}/messages` — lịch sử một phiên
- Endpoint: `DELETE /api/chat/sessions/{id}` — xóa phiên
- System instruction: "Bạn là trợ lý du lịch AI của ứng dụng TRAWIME..."

**AI Chat endpoint (simple, no session):**
- `POST /api/ai/chat` — dùng cho: Itinerary AI suggestions (không cần lưu lịch sử)
- Body: `{"message": "...", "session_id": null}`
- Response: `{"response": "...", "suggestions": [...]}`

**Offline fallback (`_mock_chat`):** hoạt động khi Gemini API không khả dụng.

### 2.4 Avatar Upload Flow

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

### 2.5 Location Categories — N-N Architecture

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

### 2.6 Review Service

- Review và Check-in là **cùng một luồng** (unified workflow)
- Bảng `reviews`: `id`, `user_id`, `location_id`, `rating`, `comment`, `photos` (JSON array URLs), `user_name` (cache), `user_email`, `created_at`
- Khi tạo review → service gọi user-service lấy `full_name` cache vào `user_name`
- Photos lưu dưới dạng full URL: `http://192.168.100.222:8004/uploads/reviews/<uuid>.<ext>`
- Sau khi xóa review → gọi `POST /internal/locations/{id}/recalculate-rating` để cập nhật rating_avg

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
static double get defaultLatitude => 16.0544; // Đà Nẵng
static double get defaultLongitude => 108.2022;
```

> Chỉ cần sửa `.env` để đổi server IP — không cần sửa code.
> Package: `flutter_dotenv: ^5.1.0` — load trong `main()` trước `runApp()`.

### 3.2 State Management

- **`AuthProvider`**: Quản lý auth state, `currentUser`, `isAdmin`
  - `login()` → `getCurrentUser()` → gọi `/api/users/profile` (ưu tiên)
  - Fallback: nếu user-service fail → thử `/api/auth/me`
  - Log lỗi bằng `debugPrint('[AuthProvider] ...')`
- **`LocationProvider`**: Danh sách địa điểm, categories, favorites

### 3.3 Screen Map

```
screens/
├── admin/
│   ├── admin_dashboard_screen.dart
│   ├── admin_location_form_screen.dart
│   ├── admin_locations_screen.dart
│   ├── admin_reviews_screen.dart
│   ├── admin_users_screen.dart
│   └── map_picker_screen.dart
├── ai/
│   ├── ai_recommend_screen.dart      — Gợi ý địa điểm bằng semantic search
│   └── chatbot_screen.dart           — Chat với TRAWIME AI (có session, markdown render)
├── auth/
│   ├── login_screen.dart
│   └── register_screen.dart
├── checkin/
│   └── checkin_screen.dart
├── home/
│   └── home_screen.dart
├── itinerary/
│   ├── itinerary_detail_screen.dart
│   ├── itinerary_list_screen.dart
│   └── itinerary_route_map_screen.dart  — Bản đồ lộ trình (OSRM + AI suggestions)
├── locations/
│   ├── location_detail_screen.dart
│   └── location_list_screen.dart
├── map/
│   └── map_screen.dart               — Bản đồ tổng quan (tìm kiếm + chỉ đường)
└── profile/
    ├── edit_profile_screen.dart
    ├── favorite_locations_screen.dart
    ├── my_reviews_screen.dart
    └── profile_screen.dart
```

### 3.4 Map Screen (`map_screen.dart`)

- **OpenStreetMap** tiles qua `flutter_map` + `TileLayer`
- **Tìm kiếm địa điểm**: Nominatim API (free, no key) → hiển thị dropdown kết quả
- **Chỉ đường**: OSRM API (free, no key) → vẽ polyline trên map
- **Google Maps button**: `url_launcher` mở `geo:lat,lng` hoặc `https://maps.google.com/...`
- Markers: các địa điểm từ backend, marker đang chọn được highlight

> ⚠️ **Android manifest cần `<queries>`** cho `url_launcher` (Android 11+):
> ```xml
> <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="https" /></intent>
> <intent><action android:name="android.intent.action.VIEW" /><data android:scheme="geo" /></intent>
> ```

### 3.5 Itinerary Route Map (`itinerary_route_map_screen.dart`)

- Nhận `ItineraryRouteArgs` (danh sách activities với tọa độ)
- **Nearest-neighbor sort** để tối ưu thứ tự các điểm dừng
- `Future.wait([fetchOSRM(), fetchAISuggestions()])` — chạy song song khi load
- **AI Suggestions**: gọi `/api/ai/chat` với prompt có tên các địa điểm → gợi ý must-try + checklist
- **Fallback AI**: nếu API fail → dùng `_kFallbackAI` (nội dung tĩnh tiếng Việt về du lịch VN)
- **DraggableScrollableSheet**: panel dưới kéo được (snap 33% ↔ 70%)
- **2 tabs**: "Lộ trình" (cards ngang, highlight khi chọn) | "Điều nên làm" (AI text)
- `_selectedStopIndex` state để highlight card + marker đang chọn (marker đỏ)

> ⚠️ **Card overflow fix**: `AnimatedContainer(height: 115)` cố định để tránh Column overflow trong horizontal ListView. Không dùng `Spacer()` bên trong card Column khi height bị constrain.

### 3.6 AI Markdown Rendering

Các nơi hiển thị response AI cần parse markdown đơn giản:

**Chatbot screen**: hàm `_buildAiMessageContent(String text)` (top-level function, ngoài class)

**Itinerary screen**: method `_buildAIContent(String text)`

**Logic render:**
```
** bất kỳ → strip bỏ (không render bold)
## Tiêu đề → Text in đậm, fontSize 13.5-14.5
* nội dung → Row(Icon circle, Text) — bullet
- nội dung → Row(Icon circle, Text) — bullet
text thường → Text bình thường
```

**AI Prompt guideline (thêm vào cuối prompt):**
```
Quy tắc định dạng:
- Chỉ dùng * (dấu sao đơn) cho gạch đầu dòng, KHÔNG dùng **
- Tiêu đề dùng ##
- Trả lời bằng tiếng Việt
```

### 3.7 Location Detail Screen — Layout Fix

**File:** `location_detail_screen.dart`

Row chứa Categories + Rating box:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Flexible(child: Wrap(...categories...)),  // Flexible để wrap khi nhiều chip
    SizedBox(width: 10),
    Container(...rating box...),              // Fixed size, không Expanded
  ],
)
```
> ⚠️ **KHÔNG dùng `Spacer()` + `Wrap` trong cùng một `Row`** — Wrap cần constrained width từ Flexible.

### 3.8 Bottom Navigation

**User thường (4 tab):** Trang chủ | Khám phá | AI Chat | Cá nhân

**Admin (5 tab):** Trang chủ | Khám phá | **Quản trị** | AI Chat | Cá nhân

> Admin **không** có section quản trị trong tab Cá nhân nữa — có tab Quản trị riêng.

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

### AI & Chat
| Method | Path | Auth | Mô tả |
|---|---|---|---|
| POST | `/api/ai/chat` | Yes | Chat đơn giản (no session) — dùng cho itinerary AI |
| POST | `/api/chat/message` | Yes | Gửi tin nhắn vào session |
| GET | `/api/chat/sessions` | Yes | Danh sách phiên chat |
| GET | `/api/chat/sessions/{id}/messages` | Yes | Lịch sử phiên |
| DELETE | `/api/chat/sessions/{id}` | Yes | Xóa phiên |
| POST | `/api/ai/recommend` | Yes | Gợi ý địa điểm bằng semantic search |

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

### 5.5 url_launcher trên Android 11+
- Phải khai báo `<queries>` trong `AndroidManifest.xml` cho mỗi scheme muốn mở
- Thiếu → `canLaunchUrl()` luôn trả `false` dù URL hợp lệ
- Schemes cần khai báo: `https`, `geo` (cho Google Maps)
- Sau khi sửa manifest: **phải restart `flutter run`** (không chỉ hot reload)

### 5.6 DraggableScrollableSheet + Horizontal ListView (Card Overflow)
- Card trong horizontal ListView nhận height constraint từ sheet size
- `initialChildSize` quá nhỏ → card bị squeeze → Column overflow
- **Fix chuẩn**: set `height` cố định cho card `AnimatedContainer` (VD: `height: 115`)
- **KHÔNG dùng `Spacer()`** bên trong card Column khi card có fixed height constraint
- **KHÔNG dùng `mainAxisSize: MainAxisSize.min`** trên Column chứa `Expanded` child

### 5.7 MultipartFile Filename
- **Luôn set `filename` rõ ràng** khi dùng `MultipartFile.fromFile()` trên Android
- Không set → `upload_file.filename` có thể là `None` ở backend → crash extension detection

### 5.8 OSRM Routing
- OSRM public API: `https://router.project-osrm.org/route/v1/driving/{coords}?overview=full&geometries=geojson`
- Tọa độ format: `lng,lat` (longitude trước lat — ngược lại với Flutter LatLng)
- GeoJSON response cũng `[lng, lat]` → cần swap khi convert sang `LatLng`
- Timeout 10s, fallback sang đường thẳng nếu fail

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
docker compose logs -f ai-service
```

### Mobile
```bash
cd mobile
flutter pub get          # sau khi thay đổi pubspec.yaml
flutter clean            # khi gặp lỗi build lạ (APK corrupt, manifest issues)
flutter run              # chạy trên device/emulator

# Hot reload: nhấn 'r' trong terminal
# Hot restart: nhấn 'R'
# Sau khi sửa AndroidManifest.xml: phải flutter run lại (không hot reload)
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

## 8. Architecture & Business Logic Assessment

Dự án đã được refactor và xử lý các fault tolerance quan trọng đạt tiêu chuẩn assignment xuất sắc:
1. **API Gateway Proxying**: Xử lý triệt để lỗi UnicodeEncodeError khi pass header `X-User-Name` thông qua `urllib.parse.quote()`. Lọc bỏ hop-by-hop headers để tránh ngắt kết nối.
2. **Parallel Async Fetching**: `ItineraryRouteMapScreen` gọi đồng thời OSRM Routing và AI Suggestions qua `Future.wait`, hiển thị skeleton/loading, ngăn việc UI bị giật lag (chặn main thread).
3. **Graceful Fallback**: Nếu Gemini AI hết quota hoặc mạng lỗi, hệ thống tự fallback sang `_kFallbackAI` (Offline Suggestions) — UX không bao giờ bị gián đoạn.
4. **Relational Consistency**: Categories tự dọn dẹp (orphan categories) khi không còn location nào tham chiếu đến. Rating của Location được trigger recalculate ngay lập tức khi thêm/sửa/xóa review.
5. **UI Scaling & Bounds**: Áp dụng `DraggableScrollableSheet` và Responsive constraint cho các vùng dễ bị overflow khi text dài (VD: Location Detail categories, Route stops cards).

---

*Updated by AI Agent — TRAWIME project. For internal use.*
