# TRAWiMe Backend API

FastAPI backend cho ứng dụng du lịch TRAWiMe với tích hợp AI (Google Gemini).

## Tính năng

- ✅ Authentication (JWT)
- ✅ User Management
- ✅ Location Management
- ✅ Check-ins với photo upload
- ✅ Reviews & Ratings
- ✅ Travel Itineraries
- ✅ AI Recommendations (Gemini embedding-001 semantic search)
- ✅ AI Chatbot (Gemini 2.0 Flash)
- ✅ Admin Dashboard & Content Moderation

## Cài đặt

### 1. Tạo Virtual Environment

```bash
python -m venv venv
```

### 2. Kích hoạt Virtual Environment

**Windows:**
```bash
venv\Scripts\activate
```

**Mac/Linux:**
```bash
source venv/bin/activate
```

### 3. Cài đặt Dependencies

```bash
pip install -r requirements.txt
```

### 4. Setup Database

Cài đặt MySQL và tạo database:

```sql
CREATE DATABASE trawime_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 5. Cấu hình Environment Variables

Copy `.env.example` thành `.env` và cập nhật thông tin:

```bash
copy .env.example .env
```

Sửa file `.env`:
```
DATABASE_URL=mysql+pymysql://root:your_password@localhost/trawime_db?charset=utf8mb4
SECRET_KEY=your-secret-key-here
GEMINI_API_KEY=your-gemini-api-key
```

### 6. Seed Database (tùy chọn)

```bash
python seed_data.py
```

### 7. Chạy Server

```bash
uvicorn app.main:app --reload
```

Server sẽ chạy tại: `http://localhost:8000`

API Documentation (Swagger UI): `http://localhost:8000/docs`

## Công nghệ sử dụng

| Công nghệ | Mục đích |
|-----------|---------|
| FastAPI | Web framework |
| SQLAlchemy | ORM |
| MySQL + PyMySQL | Database |
| JWT (python-jose) | Authentication |
| Pydantic | Data validation |
| Google Gemini API | AI chatbot + embedding search |
| Pillow | Image processing |

## API Endpoints

### Authentication
- `POST /api/auth/register` - Đăng ký
- `POST /api/auth/login` - Đăng nhập
- `GET /api/auth/me` - Thông tin user hiện tại

### Users
- `GET /api/users/profile` - Xem profile
- `PUT /api/users/profile` - Cập nhật profile
- `POST /api/users/avatar` - Upload avatar

### Locations
- `GET /api/locations` - Danh sách địa điểm
- `GET /api/locations/{id}` - Chi tiết địa điểm
- `GET /api/locations/nearby` - Địa điểm gần
- `POST /api/locations` - Tạo địa điểm (admin)
- `PUT /api/locations/{id}` - Cập nhật (admin)
- `DELETE /api/locations/{id}` - Xóa (admin)

### Check-ins
- `POST /api/checkins` - Check-in
- `POST /api/checkins/upload-photos` - Upload ảnh
- `GET /api/checkins` - Lịch sử check-in
- `GET /api/checkins/location/{id}` - Check-ins tại địa điểm

### Reviews
- `POST /api/reviews` - Viết đánh giá
- `GET /api/reviews/location/{id}` - Đánh giá địa điểm
- `PUT /api/reviews/{id}` - Sửa đánh giá
- `DELETE /api/reviews/{id}` - Xóa đánh giá

### Itineraries
- `GET /api/itineraries` - Danh sách lịch trình
- `GET /api/itineraries/{id}` - Chi tiết lịch trình
- `POST /api/itineraries` - Tạo lịch trình
- `PUT /api/itineraries/{id}` - Cập nhật
- `DELETE /api/itineraries/{id}` - Xóa

### AI Services
- `POST /api/ai/recommend` - Gợi ý địa điểm (semantic embedding search)
- `POST /api/ai/chat` - Chat với AI (Gemini 2.0 Flash)
- `POST /api/ai/generate-embeddings` - Tạo embeddings (admin)
- `GET /api/ai/analyze-preferences` - Phân tích sở thích

### Admin
- `GET /api/admin/users` - Danh sách người dùng
- `PUT /api/admin/users/{id}/toggle-active` - Khóa/mở khóa tài khoản
- `GET /api/admin/reviews` - Xem tất cả đánh giá
- `DELETE /api/admin/reviews/{id}` - Xóa đánh giá vi phạm
- `DELETE /api/admin/checkins/{id}` - Xóa check-in vi phạm
- `GET /api/admin/stats` - Thống kê hệ thống

## Database Schema

### Users
- id, email, password_hash, full_name, avatar_url, phone, role, is_active

### Locations
- id, name, description, category, address, city, country, latitude, longitude, rating_avg, total_reviews, images, description_embedding

### CheckIns
- id, user_id, location_id, photos, comment, check_in_date

### Reviews
- id, user_id, location_id, rating, comment

### Itineraries
- id, user_id, title, description, start_date, end_date, locations, status

### Favorites
- id, user_id, location_id

## AI Features

Tích hợp Google Gemini API:

1. Thêm API key vào `.env`:
```
GEMINI_API_KEY=your-gemini-api-key
```

2. **Chatbot** sử dụng `gemini-2.0-flash` cho hội thoại tự nhiên bằng tiếng Việt
3. **Gợi ý địa điểm** sử dụng `models/embedding-001` cho semantic search:
   - Mô tả người dùng → embedding vector
   - Cosine similarity với embedding các địa điểm
   - Kết hợp điểm đánh giá để xếp hạng
4. Tự động fallback về mock nếu chưa có API key

## Production Deployment

1. Đổi `SECRET_KEY` thành random string mạnh
2. Cập nhật `DATABASE_URL` với production database
3. Set `CORS_ORIGINS` với domain thật
4. Sử dụng HTTPS
5. Deploy với Gunicorn hoặc similar ASGI server

```bash
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

## License

MIT
