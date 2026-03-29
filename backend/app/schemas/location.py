from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from .category import CategoryResponse


class LocationBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: str
    address: Optional[str] = None
    city: str
    country: str = "Vietnam"
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class LocationCreate(LocationBase):
    images: Optional[List[str]] = []


class LocationUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    images: Optional[List[str]] = None


class LocationResponse(LocationBase):
    id: int
    rating_avg: float
    total_reviews: int
    images: List[str]
    created_at: datetime
    categories: List[CategoryResponse] = []
    
    class Config:
        from_attributes = True


class LocationSearch(BaseModel):
    query: Optional[str] = None
    category: Optional[str] = None
    city: Optional[str] = None
    min_rating: Optional[float] = None
