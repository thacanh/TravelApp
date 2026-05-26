# TRAWIME - User Service

Dịch vụ Người dùng (User Service) chịu trách nhiệm quản lý hồ sơ thông tin cá nhân người dùng, tải lên ảnh đại diện, thay đổi mật khẩu và quản lý danh mục địa điểm yêu thích.

## Các chức năng chính

- Cung cấp API đọc hồ sơ cá nhân của tài khoản đang đăng nhập.
- Cập nhật thông tin hồ sơ: Họ tên, số điện thoại, email.
- Đổi mật khẩu tài khoản và kiểm tra tính hợp lệ của mật khẩu cũ.
- Tải lên ảnh đại diện (avatar) của người dùng lên đĩa cục bộ và tự động chuẩn hóa URL.
- Quản lý danh sách các địa điểm du lịch yêu thích của người dùng (Thêm, Xóa, Lấy danh sách).

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8002`

## Danh sách API chính

- `GET /api/users/profile`: Lấy hồ sơ tài khoản hiện tại.
- `PUT /api/users/profile`: Cập nhật hồ sơ tài khoản (họ tên, điện thoại, email).
- `PUT /api/users/change-password`: Thay đổi mật khẩu người dùng.
- `POST /api/users/avatar`: Tải lên hình ảnh đại diện cá nhân mới.
- `POST /api/users/favorites/{location_id}`: Thêm một địa điểm du lịch vào danh sách yêu thích.
- `DELETE /api/users/favorites/{location_id}`: Xóa địa điểm khỏi danh sách yêu thích.
- `GET /api/users/favorites`: Lấy danh sách mã số (ID) các địa điểm đã yêu thích của người dùng.
