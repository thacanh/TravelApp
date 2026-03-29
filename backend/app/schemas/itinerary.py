from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date, time


# ──────────── ItineraryActivity ────────────

class ActivityBase(BaseModel):
    title: str
    description: Optional[str] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    cost_estimate: Optional[float] = None
    note: Optional[str] = None
    order_index: int = 0
    location_id: Optional[int] = None


class ActivityCreate(ActivityBase):
    pass


class ActivityUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    cost_estimate: Optional[float] = None
    note: Optional[str] = None
    order_index: Optional[int] = None
    location_id: Optional[int] = None


class ActivityResponse(ActivityBase):
    id: int
    day_id: int

    class Config:
        from_attributes = True


# ──────────── ItineraryDay ────────────

class DayBase(BaseModel):
    day_number: int
    date: Optional[date] = None
    title: Optional[str] = None
    description: Optional[str] = None


class DayCreate(DayBase):
    activities: Optional[List[ActivityCreate]] = []


class DayUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    date: Optional[date] = None


class DayResponse(DayBase):
    id: int
    itinerary_id: int
    activities: List[ActivityResponse] = []

    class Config:
        from_attributes = True


# ──────────── Itinerary (updated) ────────────

class ItineraryBase(BaseModel):
    title: str
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    status: str = "planned"


class ItineraryCreate(ItineraryBase):
    pass


class ItineraryUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    status: Optional[str] = None


class ItineraryResponse(ItineraryBase):
    id: int
    user_id: int
    days: List[DayResponse] = []
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
