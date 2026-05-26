# TRAWiMe - Review Service

Dịch vụ Nhận xét (Review Service) quản lý các hoạt động check-in, chụp ảnh thực tế và viết nhận xét đánh giá của người dùng tại các địa điểm du lịch.

## Các chức năng chính

- Viết đánh giá, bình luận và xếp hạng sao (rating) cho các địa điểm.
- Caching thông tin họ tên thực và email người dùng tại thời điểm viết đánh giá để tăng tốc truy vấn danh sách, tránh lỗi truy vấn N+1 xuyên microservices.
- Hỗ trợ người dùng tải lên nhiều hình ảnh check-in thực tế đồng thời lên thư mục lưu trữ cục bộ.
- Chuẩn hóa địa chỉ liên kết ảnh tĩnh qua API Gateway để thiết bị di động hiển thị chính xác.
- Cung cấp danh sách nhận xét của từng địa điểm và lịch sử check-in cá nhân của người dùng.
- Cho phép người dùng chỉnh sửa hoặc xóa đánh giá cũ do chính mình sở hữu.

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8004`

## Danh sách API chính

- `POST /api/reviews`: Viết đánh giá mới (bao gồm điểm số sao, mô tả, mảng ảnh tải lên và thời gian ghé thăm thực tế).
- `POST /api/reviews/upload-photos`: Tải lên hàng loạt ảnh chụp thực tế check-in của người dùng.
- `GET /api/reviews/location/{location_id}`: Lấy toàn bộ nhận xét của một địa điểm du lịch cụ thể (sắp xếp mới nhất xếp trước).
- `GET /api/checkins`: Xem danh sách tất cả các điểm đã check-in của người dùng đang đăng nhập.
- `POST /api/checkins`: Viết check-in mới (bí danh hoạt động tương tự như tạo đánh giá mới).
- `PUT /api/reviews/{review_id}`: Chỉnh sửa đánh giá cũ (yêu cầu đúng tài khoản sở hữu).
- `DELETE /api/reviews/{review_id}`: Xóa nhận xét cũ (yêu cầu đúng tài khoản sở hữu).
