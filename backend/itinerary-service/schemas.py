from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from models import ItineraryActivity, ItineraryDay, Itinerary

class ActivityCreate(BaseModel):
    # Dữ liệu yêu cầu để tạo hoạt động mới trong ngày
    title: str
    description: Optional[str] = None
    location_id: Optional[int] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    location_image: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    cost_estimate: Optional[float] = None
    note: Optional[str] = None
    order_index: int = 0

class ActivityUpdate(BaseModel):
    # Dữ liệu cho phép cập nhật một hoạt động
    title: Optional[str] = None
    description: Optional[str] = None
    location_id: Optional[int] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    location_image: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    cost_estimate: Optional[float] = None
    note: Optional[str] = None
    order_index: Optional[int] = None

class ActivityResponse(BaseModel):
    # Dữ liệu phản hồi thông tin chi tiết hoạt động
    id: int
    day_id: int
    title: str
    description: Optional[str]
    location_id: Optional[int]
    location_name: Optional[str]
    location_lat: Optional[float]
    location_lng: Optional[float]
    location_image: Optional[str]
    cost_estimate: Optional[float]
    note: Optional[str]
    order_index: int
    created_at: datetime
    start_time: Optional[str] = None
    end_time: Optional[str] = None

    @classmethod
    def from_orm_custom(cls, act: ItineraryActivity) -> "ActivityResponse":
        # Bộ chuyển đổi thủ công để định dạng kiểu giờ start_time và end_time về chuỗi HH:MM
        fmt = lambda t: f"{t.hour:02d}:{t.minute:02d}" if t else None
        return cls(
            id=act.id,
            day_id=act.day_id,
            title=act.title,
            description=act.description,
            location_id=act.location_id,
            location_name=act.location_name,
            location_lat=act.location_lat,
            location_lng=act.location_lng,
            location_image=act.location_image,
            cost_estimate=act.cost_estimate,
            note=act.note,
            order_index=act.order_index,
            created_at=act.created_at,
            start_time=fmt(act.start_time),
            end_time=fmt(act.end_time),
        )

    class Config:
        from_attributes = True

class DayCreate(BaseModel):
    # Dữ liệu yêu cầu để tạo mới một ngày trong lịch trình
    day_number: int
    title: Optional[str] = None
    description: Optional[str] = None
    date: Optional[str] = None
    activities: Optional[List[ActivityCreate]] = []

class DayUpdate(BaseModel):
    # Dữ liệu cho phép cập nhật một ngày
    title: Optional[str] = None
    description: Optional[str] = None
    date: Optional[str] = None

class DayResponse(BaseModel):
    # Dữ liệu phản hồi thông tin chi tiết ngày kèm các hoạt động
    id: int
    itinerary_id: int
    day_number: int
    title: Optional[str]
    description: Optional[str]
    created_at: datetime
    activities: List[ActivityResponse] = []

    @classmethod
    def from_orm_custom(cls, day: ItineraryDay) -> "DayResponse":
        return cls(
            id=day.id,
            itinerary_id=day.itinerary_id,
            day_number=day.day_number,
            title=day.title,
            description=day.description,
            created_at=day.created_at,
            activities=[ActivityResponse.from_orm_custom(a) for a in day.activities],
        )

    class Config:
        from_attributes = True

class ItineraryCreate(BaseModel):
    # Dữ liệu yêu cầu để tạo mới lịch trình du lịch
    title: str
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    status: str = "planned"

class ItineraryUpdate(BaseModel):
    # Dữ liệu cho phép cập nhật lịch trình
    title: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    status: Optional[str] = None

class ItineraryResponse(BaseModel):
    # Dữ liệu phản hồi lịch trình đầy đủ kèm các ngày và hoạt động con
    id: int
    user_id: int
    title: str
    description: Optional[str]
    start_date: Optional[datetime]
    end_date: Optional[datetime]
    status: str
    created_at: datetime
    days: List[DayResponse] = []

    @classmethod
    def from_orm_custom(cls, it: Itinerary) -> "ItineraryResponse":
        return cls(
            id=it.id,
            user_id=it.user_id,
            title=it.title,
            description=it.description,
            start_date=it.start_date,
            end_date=it.end_date,
            status=it.status,
            created_at=it.created_at,
            days=[DayResponse.from_orm_custom(d) for d in it.days],
        )

    class Config:
        from_attributes = True
