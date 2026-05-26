from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    # Định nghĩa các trường dữ liệu đầu vào khi đăng ký tài khoản
    email: EmailStr
    password: str
    full_name: str
    phone: Optional[str] = None

class UserResponse(BaseModel):
    # Định nghĩa các trường trả về cho người dùng sau khi xác thực
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

class Token(BaseModel):
    # Định nghĩa cấu trúc trả về cho Token JWT sau khi đăng nhập
    access_token: str
    token_type: str
