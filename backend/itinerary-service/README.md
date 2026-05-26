# TRAWIME - Itinerary Service

Dịch vụ Lịch trình (Itinerary Service) quản lý kế hoạch di chuyển cá nhân của du khách, chia nhỏ lịch trình theo từng ngày, các hoạt động cụ thể và cung cấp thuật toán tối ưu hóa lộ trình di chuyển.

## Các chức năng chính

- CRUD Lịch trình tổng quát (Tên chuyến đi, thời gian, trạng thái chuyến đi).
- Phân nhỏ lịch trình theo ngày (Ngày 1, Ngày 2,...) và hỗ trợ xóa đồng loạt thông qua ràng buộc cơ sở dữ liệu Cascade Delete.
- Quản lý hoạt động chi tiết trong ngày (Địa điểm ghé thăm, ghi chú, chi phí dự kiến, thời gian bắt đầu/kết thúc).
- Áp dụng kỹ thuật phi bình thường hóa (Denormalization) lưu tọa độ, tên và hình ảnh địa điểm trực tiếp tại hoạt động để tăng tốc hiển thị bản đồ mà không cần truy vấn xuyên microservices.
- Thuật toán tối ưu hóa lộ trình di chuyển trong ngày (Route Optimization): Sử dụng thuật toán tham lam Láng giềng gần nhất (Nearest-Neighbor) dựa trên tọa độ GPS hiện tại của người dùng kết hợp với công thức tính khoảng cách Haversine. Trả về danh sách địa điểm đã được sắp xếp lại thứ tự tối ưu kèm các tọa độ điểm dừng (waypoints).

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8005`

## Danh sách API chính

- `GET /api/itineraries`: Lấy danh sách lịch trình cá nhân của người dùng.
- `GET /api/itineraries/{itinerary_id}`: Lấy thông tin chi tiết một lịch trình bao gồm các ngày và các hoạt động.
- `POST /api/itineraries`: Tạo một lịch trình trống mới.
- `PUT /api/itineraries/{itinerary_id}`: Chỉnh sửa thông tin lịch trình (tiêu đề, mô tả, mốc ngày).
- `DELETE /api/itineraries/{itinerary_id}`: Xóa lịch trình (tự động xóa sạch các ngày và hoạt động liên kết).
- `POST /api/itineraries/{itinerary_id}/days`: Thêm một ngày mới vào lịch trình.
- `PUT /api/itineraries/{itinerary_id}/days/{day_id}`: Sửa thông tin ngày đi.
- `DELETE /api/itineraries/{itinerary_id}/days/{day_id}`: Xóa một ngày đi khỏi lịch trình.
- `POST /api/itineraries/{itinerary_id}/days/{day_id}/activities`: Thêm hoạt động chi tiết vào ngày.
- `PUT /api/itineraries/{itinerary_id}/days/{day_id}/activities/{activity_id}`: Sửa hoạt động hoặc thay đổi thứ tự hiển thị (order_index).
- `DELETE /api/itineraries/{itinerary_id}/days/{day_id}/activities/{activity_id}`: Xóa một hoạt động.
- `GET /api/itineraries/{itinerary_id}/days/{day_id}/route`: Nhận tọa độ GPS hiện tại của người dùng và trả về lộ trình di chuyển tối ưu nhất được sắp xếp lại bằng thuật toán.
