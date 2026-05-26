import os
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Float, Text, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Cấu hình hệ thống đọc từ biến môi trường hoặc tệp .env
    # Đường dẫn kết nối cơ sở dữ liệu MySQL
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    # Thư mục vật lý lưu trữ hình ảnh check-in tải lên của người dùng
    UPLOAD_DIR: str = "uploads"
    # Địa chỉ gọi dịch vụ địa điểm
    LOCATION_SERVICE_URL: str = "http://location-service:8003"
    # Địa chỉ gọi dịch vụ người dùng để lấy thông tin hồ sơ
    USER_SERVICE_URL: str = "http://user-service:8002"
    # URL dùng làm gốc để tạo đường dẫn hình ảnh tĩnh hoàn chỉnh qua Gateway
    BASE_URL: str = "http://localhost:8004"

    class Config:
        env_file = ".env"

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

class Review(Base):
    # Lớp liên kết bảng reviews lưu trữ bình luận đánh giá của người dùng
    # user_name và user_email áp dụng cơ chế caching thông tin người dùng ngay khi viết
    # để tối ưu hóa tránh việc gọi liên dịch vụ khi đọc danh sách review
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    location_id = Column(Integer, nullable=False)
    rating = Column(Float, nullable=False)
    comment = Column(Text, nullable=True)
    photos = Column(JSON, default=list) # Lưu trữ mảng chứa các liên kết ảnh thực tế
    user_name = Column(String(100), nullable=True)
    user_email = Column(String(255), nullable=True)
    visited_at = Column(DateTime, default=datetime.utcnow) # Thời gian người dùng thực tế ghé thăm
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
