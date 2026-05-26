# TRAWiMe - Ứng dụng Quản lý Lịch trình Du lịch Việt Nam

TRAWiMe là hệ thống hỗ trợ và quản lý lịch trình du lịch Việt Nam, tích hợp trợ lý ảo chatbot và gợi ý địa điểm thông minh bằng trí tuệ nhân tạo (AI) thông qua tìm kiếm vector (Vector Search) và độ tương đồng Cosine. Dự án bao gồm hệ thống backend xây dựng theo kiến trúc microservices sử dụng FastAPI và ứng dụng di động phía người dùng xây dựng bằng Flutter.

## Hướng dẫn cài đặt và khởi chạy hệ thống

### 1. Khởi chạy Backend

Bạn có thể lựa chọn một trong hai phương thức chạy backend dưới đây:

#### Phương thức 1: Sử dụng Docker Compose (Khuyên dùng)
Đây là phương thức nhanh nhất để khởi chạy cơ sở dữ liệu MySQL và toàn bộ các microservices:

1. Di chuyển vào thư mục backend:
```bash
cd backend
```

2. Sao chép cấu hình môi trường mẫu:
```bash
copy .env.example .env
```

3. Khởi chạy Docker Compose:
```bash
docker compose up --build -d
```

Toàn bộ các dịch vụ và API Gateway sẽ tự động được biên dịch và khởi chạy ngầm. Bạn có thể kiểm tra trạng thái hoạt động của gateway tại: http://localhost:8000/health

#### Phương thức 2: Chạy thủ công từng Microservice bằng Python
Nếu không sử dụng Docker, bạn cần thiết lập cơ sở dữ liệu MySQL và chạy độc lập từng microservice:

1. Tạo cơ sở dữ liệu MySQL:
```sql
CREATE DATABASE trawime_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. Nhập dữ liệu khởi tạo (nếu cần):
```bash
mysql -u root -p trawime_db < init_db.sql
```

3. Tạo tệp cấu hình môi trường `.env` tại thư mục backend bằng cách sao chép file mẫu:
```bash
cd backend
copy .env.example .env
```
(Hãy chỉnh sửa các tham số trong .env cho khớp với cấu hình MySQL cục bộ của bạn và thêm khóa GEMINI_API_KEY)

4. Chạy từng dịch vụ bằng Uvicorn:
Mở terminal tại thư mục của từng microservice con, kích hoạt môi trường ảo và chạy:
```bash
cd backend/<ten-dich-vu>
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --port <cong-tuong-ung> --reload
```

#### Khởi tạo dữ liệu mẫu (Seed Data)
Sau khi toàn bộ backend đã chạy thành công, chạy script python để tự động chèn dữ liệu địa điểm và danh mục du lịch mẫu vào cơ sở dữ liệu:

1. Mở terminal tại thư mục backend
2. Chạy lệnh:
```bash
python seed_data.py
```

### 2. Cài đặt và chạy Mobile Client (Flutter)

1. Di chuyển vào thư mục mobile:
```bash
cd mobile
```

2. Cài đặt các thư viện phụ thuộc:
```bash
flutter pub get
```

3. Cấu hình địa chỉ IP của API Gateway:
Mở tệp lib/config/app_config.dart và cập nhật giá trị baseUrl:
- Nếu chạy trên máy ảo Android (Emulator):
```dart
static const String baseUrl = "http://10.0.2.2:8000";
```
- Nếu chạy trên thiết bị thật (máy tính và điện thoại cần kết nối chung mạng Wifi):
```dart
static const String baseUrl = "http://<IP_MAY_TINH_CUA_BAN>:8000";
```

4. Khởi chạy ứng dụng:
```bash
flutter run
```

5. Build ứng dụng thành file APK cài đặt:
```bash
flutter build apk --release
```
Tệp APK đầu ra sẽ nằm tại: `mobile/build/app/outputs/flutter-apk/app-release.apk`

## Tổng quan kiến trúc hệ thống

Hệ thống được chia làm hai phần chính:

1. **Backend (Kiến trúc Microservices)**:
   Các dịch vụ chạy độc lập và giao tiếp nội bộ, được điều phối duy nhất thông qua API Gateway:
   - api-gateway (Cổng 8000): Nhận các yêu cầu từ ứng dụng di động, thực hiện xác thực chữ ký JWT và chuyển tiếp yêu cầu đến các microservices tương ứng.
   - auth-service (Cổng 8001): Quản lý tài khoản người dùng, đăng ký, đăng nhập và cấp phát token JWT.
   - user-service (Cổng 8002): Quản lý thông tin hồ sơ người dùng và danh sách địa điểm yêu thích.
   - location-service (Cổng 8003): Quản lý thông tin địa điểm du lịch, danh mục và tọa độ GPS lân cận.
   - review-service (Cổng 8004): Quản lý bình luận, nhận xét và ảnh check-in thực tế của du khách.
   - itinerary-service (Cổng 8005): Quản lý kế hoạch du lịch cá nhân và tối ưu hóa tuyến đường di chuyển trong ngày bằng thuật toán Nearest-Neighbor.
   - ai-service (Cổng 8006): Tích hợp mô hình ngôn ngữ lớn để trả lời chatbot du lịch và tính toán độ tương đồng Cosine trên vector đặc trưng của các địa điểm.

2. **Mobile Client (Flutter)**:
   Ứng dụng di động cài đặt trên hệ điều hành Android/iOS để người dùng trực tiếp sử dụng dịch vụ.

Chi tiết về cấu trúc và sơ đồ API của từng dịch vụ con được trình bày riêng trong tệp README.md đặt tại thư mục của dịch vụ đó.

Cấu trúc thư mục chính:
```
trawime/
├── backend/          - Chứa mã nguồn backend và file cấu hình Docker Compose
│   ├── api-gateway/
│   ├── auth-service/
│   ├── user-service/
│   ├── location-service/
│   ├── review-service/
│   ├── itinerary-service/
│   └── ai-service/
└── mobile/           - Chứa mã nguồn ứng dụng Flutter
```

## Tài khoản thử nghiệm mặc định

Sau khi chạy script seed dữ liệu mẫu, bạn có thể đăng nhập ứng dụng bằng các tài khoản sau:

Tài khoản Quản trị viên (Admin):
- Email: `admin@trawime.com`
- Mật khẩu: `admin123`

Tài khoản Người dùng (User):
- Email: `user@test.com`
- Mật khẩu: `user123`
