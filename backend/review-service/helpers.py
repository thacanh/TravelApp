from typing import Optional
from urllib.parse import unquote
import re as _re
from fastapi import Header, HTTPException
from models import settings, Review

# Pattern nhận dạng URL trỏ trực tiếp vào cổng dịch vụ không qua Gateway
_OLD_PORT_PATTERN = _re.compile(r'https?://[^/]+:\d+/')

class CurrentUser:
    # Đối tượng người dùng hiện tại lấy từ Header do API Gateway truyền xuống
    def __init__(self, id: int, role: str, email: str = "", name: str = ""):
        self.id = id
        self.role = role
        self.email = email
        self.name = name

def get_current_user(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_email: Optional[str] = Header(None),
    x_user_name: Optional[str] = Header(None),
) -> CurrentUser:
    # Đọc thông tin định danh và thực hiện giải mã unquote cho họ tên hoặc email tiếng Việt gửi từ Gateway
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Thiếu headers xác thực tài khoản")
    return CurrentUser(
        id=int(x_user_id),
        role=unquote(x_user_role) if x_user_role else "user",
        email=unquote(x_user_email) if x_user_email else "",
        name=unquote(x_user_name) if x_user_name else "",
    )

def _normalize_photo_url(p: str) -> str:
    # Chuẩn hóa URL ảnh đơn lẻ: viết lại phần host và port bằng BASE_URL của Gateway
    if not p:
        return p
    if p.startswith("http"):
        if _OLD_PORT_PATTERN.search(p):
            path_part = p[p.find('/', 8):]
            return settings.BASE_URL.rstrip('/') + path_part
        return p
    return f"{settings.BASE_URL}/uploads/{p}"

def _make_photo_urls(photos: list) -> list:
    # Chuẩn hóa hàng loạt mảng đường dẫn hình ảnh gửi về cho thiết bị di động
    result = []
    for p in (photos or []):
        if not p:
            continue
        if p.startswith("http"):
            if _OLD_PORT_PATTERN.search(p):
                path = "/" + p.split("/", 3)[-1]
                result.append(settings.BASE_URL + path)
            else:
                result.append(p)
        else:
            result.append(f"{settings.BASE_URL}/uploads/{p}")
    return result

def _enrich_review(review: Review) -> dict:
    # Hàm làm giàu dữ liệu đánh giá: Chuẩn hóa ảnh chụp thực tế và đóng gói UserInfo trả về dạng Object cho Frontend
    return {
        "id": review.id,
        "user_id": review.user_id,
        "location_id": review.location_id,
        "rating": review.rating,
        "comment": review.comment,
        "photos": _make_photo_urls(review.photos or []),
        "user": {
            "id": review.user_id,
            "full_name": review.user_name or "Nguoi dung TRAWIME",
            "email": review.user_email or "",
        },
        "visited_at": review.visited_at,
        "created_at": review.created_at,
    }
