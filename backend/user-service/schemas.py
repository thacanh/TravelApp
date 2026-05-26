from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator
from models import settings

class UserResponse(BaseModel):
    # Cấu trúc dữ liệu trả về hồ sơ người dùng
    id: int
    email: str
    full_name: str
    avatar_url: Optional[str]
    phone: Optional[str]
    role: str
    is_active: bool
    created_at: datetime
    class Config: 
        from_attributes = True

    @field_validator('avatar_url', mode='after')
    @classmethod
    def normalize_avatar(cls, v: Optional[str]) -> Optional[str]:
        # Tự động sinh ra URL tuyệt đối nếu ảnh đại diện lưu đường dẫn tương đối
        if v and not v.startswith('http'):
            return f"{settings.BASE_URL}/uploads/{v.lstrip('/')}"
        return v

class UserUpdate(BaseModel):
    # Các trường dữ liệu cho phép sửa trong hồ sơ cá nhân
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None

class ChangePasswordRequest(BaseModel):
    # Trường dữ liệu cần thiết để thực hiện đổi mật khẩu
    current_password: str
    new_password: str
