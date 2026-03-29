# TRAWiMe - Ứng dụng Du lịch Việt Nam

Ứng dụng di động Android hoàn chỉnh cho phép người dùng khám phá, tìm kiếm và quản lý các hoạt động du lịch tại Việt Nam với hỗ trợ AI thông minh.

![TRAWiMe](https://via.placeholder.com/800x200/00BCD4/FFFFFF?text=TRAWiMe+-+Travel+Vietnam)

## ✨ Tính năng

### Core Features
- ✅ **Xác thực người dùng**: Đăng ký, đăng nhập với JWT
- ✅ **Khám phá địa điểm**: Tìm kiếm, lọc theo danh mục, thành phố
- ✅ **Chi tiết địa điểm**: Xem ảnh, mô tả, đánh giá, vị trí
- ✅ **Check-in**: Upload ảnh, viết bình luận khi đến địa điểm
- ✅ **Đánh giá & Review**: Đánh giá sao và nhận xét
- ✅ **Quản lý lịch trình**: Tạo và quản lý kế hoạch du lịch
- ✅ **Bản đồ**: Hiển thị vị trí địa điểm
- ✅ **Profile**: Quản lý thông tin cá nhân

### AI Features
- 🤖 **AI Chatbot**: Trợ lý du lịch thông minh
- 🎯 **AI Recommendations**: Gợi ý địa điểm dựa trên sở thích

## 🏗️ Kiến trúc

```
trawime/
├── backend/          # FastAPI Backend
│   ├── app/
│   │   ├── api/      # API endpoints
│   │   ├── models/   # Database models
│   │   ├── schemas/  # Pydantic schemas
│   │   ├── services/ # Business logic
│   │   └── utils/    # Utilities
│   └── requirements.txt
│
└── mobile/           # Flutter Mobile App
    ├── lib/
    │   ├── config/   # Configuration
    │   ├── models/   # Data models
    │   ├── providers/# State management
    │   ├── screens/  # UI screens
    │   ├── services/ # API services
    │   └── widgets/  # Reusable widgets
    └── pubspec.yaml
```

## 🛠️ Tech Stack

### Backend
- **Framework**: FastAPI (Python)
- **Database**: MySQL
- **Authentication**: JWT
- **ORM**: SQLAlchemy
- **AI**: Google Gemini API (gemini-2.0-flash + embedding-001)
- **API Documentation**: Swagger/OpenAPI

### Mobile
- **Framework**: Flutter
- **State Management**: Provider
- **HTTP Client**: Dio
- **Local Storage**: Flutter Secure Storage
- **UI**: Material Design 3
- **Fonts**: Google Fonts (Poppins)

## 📱 Screenshots

(Thêm screenshots của app sau khi build)

## 🚀 Cài đặt & Chạy

### Yêu cầu
- Python 3.9+
- MySQL 8.0+
- Flutter 3.16+
- Android SDK (cho build APK)

### Backend Setup

#### 1. Clone repository
```bash
cd backend
```

#### 2. Tạo virtual environment
```bash
python -m venv venv
venv\Scripts\activate  # Windows
# hoặc: source venv/bin/activate  # Mac/Linux
```

#### 3. Cài đặt dependencies
```bash
pip install -r requirements.txt
```

#### 4. Setup database
```sql
-- Mở MySQL và tạo database
CREATE DATABASE trawime_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

#### 5. Cấu hình environment
```bash
copy .env.example .env
# Sửa file .env với thông tin database của bạn
```

#### 6. Seed database (tùy chọn)
```bash
python seed_data.py
```

#### 7. Chạy server
```bash
uvicorn app.main:app --reload
```

API sẽ chạy tại: `http://localhost:8000`  
API Docs: `http://localhost:8000/docs`

### Mobile App Setup

#### 1. Di chuyển vào thư mục mobile
```bash
cd ../mobile
```

#### 2. Cài đặt dependencies
```bash
flutter pub get
```

#### 3. Cấu hình API endpoint
Mở `lib/config/app_config.dart` và cập nhật:
```dart
static const String baseUrl = "http://10.0.2.2:8000"; // Android emulator
// hoặc
static const String baseUrl = "http://<YOUR_IP>:8000"; // Physical device
```

#### 4. Chạy app trên emulator/device
```bash
flutter run
```

### Build APK

#### Debug APK (để test)
```bash
flutter build apk --debug
```

#### Release APK (production)
```bash
flutter build apk --release
```

APK file sẽ được tạo tại: `build/app/outputs/flutter-apk/app-release.apk`

#### Cài đặt APK trên điện thoại
1. Copy file APK vào điện thoại
2. Mở file APK và cho phép cài đặt từ nguồn không xác định
3. Cài đặt và sử dụng

## 📖 Hướng dẫn sử dụng

### Đăng ký tài khoản
1. Mở app
2. Nhấn "Đăng ký ngay"
3. Điền thông tin và nhấn "Đăng ký"

### Khám phá địa điểm
1. Vào tab "Khám phá"
2. Tìm kiếm hoặc lọc theo danh mục
3. Nhấn vào địa điểm để xem chi tiết

### Check-in
1. Vào chi tiết địa điểm
2. Nhấn "Check-in"
3. Upload ảnh và viết bình luận

### Chat với AI
1. Vào tab "AI Chat"
2. Nhập câu hỏi hoặc yêu cầu
3. AI sẽ trả lời và gợi ý

## 🔑 Tài khoản Test

Sau khi chạy `seed_data.py`, bạn có thể dùng:

**Admin:**
- Email: `admin@trawime.com`
- Password: `admin123`

**User:**
- Email: `user@test.com`
- Password: `user123`

## 🌐 API Endpoints

### Authentication
- `POST /api/auth/register` - Đăng ký
- `POST /api/auth/login` - Đăng nhập
- `GET /api/auth/me` - Thông tin user

### Locations
- `GET /api/locations` - Danh sách địa điểm
- `GET /api/locations/{id}` - Chi tiết địa điểm
- `GET /api/locations/nearby` - Địa điểm gần

### Check-ins
- `POST /api/checkins` - Tạo check-in
- `GET /api/checkins` - Lịch sử check-in

### Reviews
- `POST /api/reviews` - Viết đánh giá
- `GET /api/reviews/location/{id}` - Đánh giá của địa điểm

### AI
- `POST /api/ai/recommend` - Gợi ý từ AI (embedding-based semantic search)
- `POST /api/ai/chat` - Chat với AI (Gemini 2.0 Flash)
- `POST /api/ai/generate-embeddings` - Tạo embeddings cho địa điểm (admin)

### Admin
- `GET /api/admin/users` - Danh sách người dùng (admin)
- `PUT /api/admin/users/{id}/toggle-active` - Khóa/mở khóa tài khoản (admin)
- `DELETE /api/admin/reviews/{id}` - Xóa đánh giá vi phạm (admin)
- `DELETE /api/admin/checkins/{id}` - Xóa check-in vi phạm (admin)
- `GET /api/admin/reviews` - Xem tất cả đánh giá (admin)
- `GET /api/admin/stats` - Thống kê hệ thống (admin)

*Xem full API documentation tại: `/docs` khi chạy backend*

## 🎨 Design System

### Colors
- **Primary**: Teal (#00BCD4)
- **Secondary**: Deep Orange (# FF5722)
- **Accent**: Amber (#FFC107)

### Typography
- **Font Family**: Poppins
- **Heading**: Bold, 20-32px
- **Body**: Regular, 14-16px

## 🔧 Troubleshooting

### Backend không kết nối được database
```bash
# Kiểm tra MySQL đang chạy
# Kiểm tra thông tin trong .env (mysql+pymysql://user:pass@localhost/trawime_db)
# Thử tạo lại database
```

### Mobile app không kết nối được API
```bash
# Kiểm tra baseUrl trong app_config.dart
# Đảm bảo backend đang chạy
# Với emulator: dùng 10.0.2.2
# Với device: dùng IP máy tính (cùng mạng WiFi)
```

### Build APK lỗi
```bash
# Xóa cache và rebuild
flutter clean
flutter pub get
flutter build apk --release
```

## 🚀 Future Enhancements

- [ ] Tích hợp Google Maps thật
- [ ] Push notifications
- [ ] Social sharing
- [ ] Offline mode
- [ ] Multi-language support
- [ ] Payment integration
- [ ] Booking system
- [ ] Real-time chat between users

## 👥 Đối tượng sử dụng

- **User**: Người dùng cuối, du khách
- **Admin**: Quản trị viên, quản lý nội dung

## 📄 License

MIT License - Xem file LICENSE

## 👨‍💻 Phát triển bởi

TRAWiMe Team

## 📞 Liên hệ

- Email: support@trawime.com
- Website: https://trawime.com

---

**Lưu ý**: Đây là phiên bản MVP. Một số tính năng có thể cần cải thiện thêm trước khi release production.

**Cảm ơn bạn đã sử dụng TRAWiMe! 🎉**
