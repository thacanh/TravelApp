# TRAWIME - Auth Service

Dịch vụ Xác thực (Auth Service) chịu trách nhiệm quản lý đăng ký tài khoản mới, xác thực đăng nhập và cấp phát mã bảo mật JWT (JSON Web Token).

## Các chức năng chính

- Đăng ký tài khoản người dùng mới và băm mật khẩu bảo mật bằng thuật toán Bcrypt.
- Xác thực thông tin đăng nhập của người dùng qua email và mật khẩu.
- Cấp phát mã bảo mật JWT Token có thời hạn sử dụng 7 ngày được ký bằng thuật toán bảo mật HS256.
- Cung cấp API xác thực và giải mã thông tin tài khoản đang đăng nhập từ token JWT.

## Cổng hoạt động (Port)

Dịch vụ chạy tại cổng: `8001`

## Danh sách API chính

- `POST /api/auth/register`: Đăng ký tài khoản mới.
- `POST /api/auth/login`: Đăng nhập hệ thống (sử dụng OAuth2 Password Request Form) và trả về Access Token.
- `GET /api/auth/me`: Lấy thông tin chi tiết của tài khoản hiện tại thông qua Token gửi lên.
