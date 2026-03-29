from pydantic import BaseModel, field_validator
from typing import Optional, List
from datetime import datetime


class ReviewBase(BaseModel):
    location_id: int
    rating: float
    comment: Optional[str] = None
    photos: Optional[List[str]] = []
    visited_at: Optional[datetime] = None

    @field_validator('rating')
    @classmethod
    def validate_rating(cls, v):
        if v < 1 or v > 5:
            raise ValueError('Rating must be between 1 and 5')
        return v


class ReviewCreate(ReviewBase):
    pass


class ReviewUpdate(BaseModel):
    rating: Optional[float] = None
    comment: Optional[str] = None
    photos: Optional[List[str]] = None

    @field_validator('rating')
    @classmethod
    def validate_rating(cls, v):
        if v is not None and (v < 1 or v > 5):
            raise ValueError('Rating must be between 1 and 5')
        return v


class ReviewResponse(ReviewBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
