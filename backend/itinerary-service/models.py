from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime, Text, Float, Time, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Cấu hình kết nối cơ sở dữ liệu đọc từ biến môi trường hoặc tệp .env
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    class Config: env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    # Trình hỗ trợ khởi tạo kết nối Database cho mỗi request
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class Itinerary(Base):
    # Lớp liên kết bảng itineraries chứa thông tin tổng quát của kế hoạch lịch trình
    # days là quan hệ ORM 1-N với bảng ngày, tự động xóa các ngày con khi xóa lịch trình
    __tablename__ = "itineraries"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    start_date = Column(DateTime, nullable=True)
    end_date = Column(DateTime, nullable=True)
    status = Column(String(20), default="planned")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    days = relationship("ItineraryDay", back_populates="itinerary",
                        cascade="all, delete-orphan", order_by="ItineraryDay.day_number")

class ItineraryDay(Base):
    # Lớp liên kết bảng itinerary_days lưu trữ các ngày trong lịch trình
    # activities là quan hệ ORM 1-N với bảng hoạt động chi tiết trong ngày
    __tablename__ = "itinerary_days"
    id = Column(Integer, primary_key=True, index=True)
    itinerary_id = Column(Integer, ForeignKey("itineraries.id"), nullable=False)
    day_number = Column(Integer, nullable=False)
    date = Column(Date, nullable=True)
    title = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    itinerary = relationship("Itinerary", back_populates="days")
    activities = relationship("ItineraryActivity", back_populates="day",
                              cascade="all, delete-orphan", order_by="ItineraryActivity.order_index")

class ItineraryActivity(Base):
    # Lớp liên kết bảng itinerary_activities lưu trữ hoạt động chi tiết trong từng ngày
    # Các trường tọa độ và tên địa điểm áp dụng kỹ thuật phi bình thường hóa để đọc nhanh
    __tablename__ = "itinerary_activities"
    id = Column(Integer, primary_key=True, index=True)
    day_id = Column(Integer, ForeignKey("itinerary_days.id"), nullable=False)
    location_id = Column(Integer, nullable=True)
    location_name = Column(String(255), nullable=True)
    location_lat = Column(Float, nullable=True)
    location_lng = Column(Float, nullable=True)
    location_image = Column(Text, nullable=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    start_time = Column(Time, nullable=True)
    end_time = Column(Time, nullable=True)
    cost_estimate = Column(Float, nullable=True)
    note = Column(Text, nullable=True)
    order_index = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    day = relationship("ItineraryDay", back_populates="activities")
