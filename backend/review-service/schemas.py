from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class ReviewCreate(BaseModel):
    # Dữ liệu yêu cầu để tạo mới một đánh giá hoặc checkin
    location_id: int
    rating: float
    comment: Optional[str] = None
    photos: Optional[list] = []
    visited_at: Optional[datetime] = None

class ReviewUpdate(BaseModel):
    # Dữ liệu cho phép cập nhật một đánh giá
    rating: Optional[float] = None
    comment: Optional[str] = None
    photos: Optional[list] = None

class UserInfo(BaseModel):
    # Thông tin người dùng thu gọn để trả về kèm review
    id: int
    full_name: str
    email: str

class ReviewResponse(BaseModel):
    # Schema trả về thông tin chi tiết của review
    id: int
    user_id: int
    location_id: int
    rating: float
    comment: Optional[str]
    photos: Optional[list]
    user: Optional[UserInfo]
    visited_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True
