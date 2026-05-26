# TRAWiMe - Location Service

Dịch vụ Địa điểm (Location Service) chịu trách nhiệm quản lý thông tin các địa danh du lịch, danh mục địa điểm, hình ảnh media đính kèm và cung cấp thuật toán tìm kiếm địa điểm xung quanh dựa trên tọa độ GPS.

## Các chức năng chính

- Quản lý thông tin địa điểm du lịch (Thêm, Sửa, Xóa - chỉ dành cho Quản trị viên).
- Tự động kích hoạt tác vụ chạy ngầm (Background Tasks) gọi tới ai-service để sinh vector đặc trưng (description_embedding) ngay khi địa điểm được thêm mới hoặc sửa mô tả.
- Quản lý danh mục địa điểm (tự động tạo hoặc dọn dẹp các danh mục mồ côi không có địa điểm liên kết).
- Tải lên hình ảnh, video giới thiệu địa điểm lên thư mục media cục bộ.
- Tìm kiếm danh sách địa điểm hỗ trợ tìm kiếm theo từ khóa, lọc theo thành phố, danh mục và sắp xếp theo điểm đánh giá trung bình (rating_avg).
- Thuật toán tìm kiếm địa điểm lân cận trong bán kính chỉ định sử dụng công thức khoảng cách mặt cầu Haversine.

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8003`

## Danh sách API chính

- `GET /api/locations`: Lấy danh sách địa điểm có phân trang, lọc theo danh mục, thành phố và tìm kiếm theo tên/mô tả.
- `GET /api/locations/{location_id}`: Lấy chi tiết thông tin một địa điểm kèm điểm sao đánh giá trung bình.
- `GET /api/locations/nearby`: Tìm kiếm các địa điểm lân cận từ vĩ độ/kinh độ đầu vào trong bán kính radius_km (mặc định 50km).
- `POST /api/locations`: Tạo một địa điểm du lịch mới (chỉ Admin) và kích hoạt tác vụ ngầm tạo vector embedding.
- `PUT /api/locations/{location_id}`: Chỉnh sửa thông tin địa điểm.
- `DELETE /api/locations/{location_id}`: Xóa địa điểm.
- `POST /api/locations/upload-media`: Tải lên tệp tin hình ảnh/video cho địa điểm.
- `GET /api/categories`: Lấy toàn bộ danh mục địa điểm hiện tại.
- `POST /api/categories`: Tạo một danh mục địa điểm mới.
- `DELETE /api/categories/{slug}`: Xóa danh mục.
