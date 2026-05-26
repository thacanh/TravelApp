from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime, Text, Float, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Cấu hình hệ thống đọc từ biến môi trường hoặc tệp .env
    # Đường dẫn kết nối cơ sở dữ liệu MySQL
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    # Khóa API kết nối với dịch vụ Google Gemini
    GEMINI_API_KEY: str = ""

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

class Category(Base):
    # Lớp liên kết với bảng categories lưu trữ các danh mục địa điểm du lịch
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True)
    slug = Column(String(50), unique=True)
    name = Column(String(100))

class LocationCategory(Base):
    # Bảng nối quan hệ Nhiều-Nhiều giữa Địa điểm và Danh mục địa điểm
    __tablename__ = "location_categories"
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="CASCADE"), primary_key=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)

class Location(Base):
    # Lớp liên kết với bảng locations lưu trữ thông tin các điểm du lịch
    __tablename__ = "locations"
    id = Column(Integer, primary_key=True)
    name = Column(String(255))
    description = Column(Text)
    city = Column(String(100))
    images = Column(JSON, default=list)
    description_embedding = Column(JSON, nullable=True)
    # Tải trước quan hệ categories bằng phương thức selectin
    categories = relationship("Category", secondary="location_categories", lazy="selectin")

class ChatSession(Base):
    # Lớp liên kết với bảng chat_sessions quản lý các phiên hội thoại của người dùng
    __tablename__ = "chat_sessions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    title = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan", order_by="ChatMessage.created_at")

class ChatMessage(Base):
    # Lớp liên kết bảng chat_messages chứa nội dung chi tiết từng tin nhắn trong một phiên
    __tablename__ = "chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("chat_sessions.id"), nullable=False)
    role = Column(String(20), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    session = relationship("ChatSession", back_populates="messages")
