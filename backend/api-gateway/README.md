# TRAWiMe - API Gateway Service

Dịch vụ API Gateway là cổng vào duy nhất xử lý và điều phối toàn bộ các yêu cầu từ ứng dụng di động tới các dịch vụ microservices hạ nguồn.

## Các chức năng chính

- Xác thực chữ ký số mã bảo mật JWT gửi từ client.
- Giải mã và trích xuất thông tin người dùng (ID người dùng, vai trò, email, họ tên).
- Thực hiện mã hóa URL-safe và tiêm thông tin người dùng vào HTTP Headers chuyển tiếp cho các service con (`X-User-Id`, `X-User-Role`, `X-User-Email`, `X-User-Name`).
- Loại bỏ các hop-by-hop headers để tránh lỗi proxy.
- Chuyển tiếp luồng (reverse-proxy) dạng Stream để hỗ trợ tải lên tệp tin hình ảnh, video lớn không gây nghẽn RAM của Gateway.

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8000`

## Ánh xạ định tuyến (Routing Rules)

API Gateway chuyển tiếp các tiền tố đường dẫn tới các dịch vụ hạ nguồn tương ứng:
- `/api/auth` -> auth-service (Cổng 8001)
- `/api/users` -> user-service (Cổng 8002)
- `/uploads/avatars` -> user-service (Cổng 8002)
- `/api/locations` -> location-service (Cổng 8003)
- `/api/categories` -> location-service (Cổng 8003)
- `/media` -> location-service (Cổng 8003)
- `/api/reviews` -> review-service (Cổng 8004)
- `/api/checkins` -> review-service (Cổng 8004)
- `/uploads/reviews` -> review-service (Cổng 8004)
- `/api/itineraries` -> itinerary-service (Cổng 8005)
- `/api/ai` -> ai-service (Cổng 8006)
- `/api/chat` -> ai-service (Cổng 8006)
