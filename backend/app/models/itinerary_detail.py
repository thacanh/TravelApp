from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Text, Float, Time, Date
from sqlalchemy.orm import relationship
from datetime import datetime
from ..database import Base


class ItineraryDay(Base):
    """Một ngày trong lịch trình"""
    __tablename__ = "itinerary_days"

    id = Column(Integer, primary_key=True, index=True)
    itinerary_id = Column(Integer, ForeignKey("itineraries.id"), nullable=False)
    day_number = Column(Integer, nullable=False)   # Ngày 1, Ngày 2, ...
    date = Column(Date, nullable=True)             # Ngày cụ thể trên lịch (nếu có)
    title = Column(String(255), nullable=True)     # VD: "Khám phá đảo Phú Quốc"
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    itinerary = relationship("Itinerary", back_populates="days")
    activities = relationship(
        "ItineraryActivity",
        back_populates="day",
        cascade="all, delete-orphan",
        order_by="ItineraryActivity.start_time",
    )


class ItineraryActivity(Base):
    """Một hoạt động / địa điểm nhỏ trong ngày lịch trình"""
    __tablename__ = "itinerary_activities"

    id = Column(Integer, primary_key=True, index=True)
    day_id = Column(Integer, ForeignKey("itinerary_days.id"), nullable=False)
    location_id = Column(Integer, ForeignKey("locations.id"), nullable=True)  # null nếu là HĐ tự do
    title = Column(String(255), nullable=False)        # VD: "Snorkeling tại bãi Sao"
    description = Column(Text, nullable=True)
    start_time = Column(Time, nullable=True)           # 08:00
    end_time = Column(Time, nullable=True)             # 12:00
    cost_estimate = Column(Float, nullable=True)       # Ước tính chi phí (VND)
    note = Column(Text, nullable=True)                 # Ghi chú thêm
    order_index = Column(Integer, default=0)           # Thứ tự trong ngày
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    day = relationship("ItineraryDay", back_populates="activities")
    location = relationship("Location")
