from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel

class CategoryResponse(BaseModel):
    # Cấu trúc dữ liệu trả về thông tin danh mục
    id: int
    slug: str
    name: str
    class Config: from_attributes = True

class CategoryInput(BaseModel):
    # Dữ liệu đầu vào để gán danh mục cho địa điểm
    slug: str
    name: Optional[str] = None

class LocationResponse(BaseModel):
    # Cấu trúc dữ liệu trả về thông tin chi tiết địa điểm
    id: int
    name: str
    description: Optional[str]
    categories: List[CategoryResponse] = []
    address: Optional[str]
    city: str
    country: str
    latitude: Optional[float]
    longitude: Optional[float]
    rating_avg: float
    total_reviews: int
    images: Optional[list]
    thumbnail: Optional[str]
    created_at: datetime

class LocationCreate(BaseModel):
    # Các trường cần để tạo mới địa điểm du lịch
    name: str
    description: Optional[str] = None
    categories_input: List[CategoryInput] = []
    address: Optional[str] = None
    city: str
    country: str = "Vietnam"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    images: Optional[list] = []
    thumbnail: Optional[str] = None

class LocationUpdate(BaseModel):
    # Các trường cho phép sửa trong địa điểm du lịch
    name: Optional[str] = None
    description: Optional[str] = None
    categories_input: Optional[List[CategoryInput]] = None
    address: Optional[str] = None
    city: Optional[str] = None
    country: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    images: Optional[list] = None
    thumbnail: Optional[str] = None
