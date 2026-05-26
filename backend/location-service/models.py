from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, JSON, Text, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Chuỗi kết nối cơ sở dữ liệu MySQL
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    # Địa chỉ gọi microservice AI trong nội bộ
    AI_SERVICE_URL: str = "http://ai-service:8006"
    # URL công khai phục vụ việc tạo đường dẫn ảnh hoặc video địa điểm
    BASE_URL: str = "http://localhost:8003"
    class Config: env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    # Trình hỗ trợ khởi tạo phiên kết nối cơ sở dữ liệu (DB Session)
    db = SessionLocal()
    try: yield db
    finally: db.close()

class Category(Base):
    # Lớp liên kết bảng categories trong cơ sở dữ liệu
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False)

class LocationCategory(Base):
    # Bảng trung gian liên kết quan hệ Nhiều-Nhiều giữa Địa điểm và Danh mục
    __tablename__ = "location_categories"
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="CASCADE"), primary_key=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)

class Location(Base):
    # Lớp liên kết bảng locations trong cơ sở dữ liệu lưu thông tin địa điểm du lịch
    __tablename__ = "locations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=True)
    address = Column(String(500), nullable=True)
    city = Column(String(100), nullable=False, index=True)
    country = Column(String(100), default="Vietnam")
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    images = Column(JSON, default=list)
    thumbnail = Column(String(2048), nullable=True)
    description_embedding = Column(JSON, nullable=True)
    created_by = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    # Thiết lập mối quan hệ ORM với bảng categories
    categories = relationship("Category", secondary="location_categories", lazy="selectin")

class Review(Base):
    # Lớp liên kết bảng reviews để lấy dữ liệu tính toán điểm đánh giá trung bình
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True)
    location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    rating = Column(Float, nullable=False)
