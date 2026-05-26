from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Đường dẫn kết nối cơ sở dữ liệu MySQL
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    # Thư mục lưu trữ ảnh tải lên của người dùng
    UPLOAD_DIR: str = "uploads"
    # URL dùng làm gốc để tạo đường dẫn ảnh tuyệt đối
    BASE_URL: str = "http://localhost:8002"
    # Khóa giải mã chữ ký JWT
    SECRET_KEY: str = "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7"
    ALGORITHM: str = "HS256"

    class Config:
        env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    # Trình hỗ trợ khởi tạo phiên kết nối cơ sở dữ liệu (DB Session)
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class User(Base):
    # Lớp liên kết với bảng users lưu hồ sơ tài khoản
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=False)
    avatar_url = Column(String(500), nullable=True)
    phone = Column(String(20), nullable=True)
    role = Column(String(20), default="user")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Favorite(Base):
    # Lớp liên kết bảng favorites lưu danh sách yêu thích của người dùng
    __tablename__ = "favorites"
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    location_id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, default=datetime.utcnow)
