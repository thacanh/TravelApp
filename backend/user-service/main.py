"""user-service: handles /api/users/* (profile, avatar, password)"""
import os
import shutil
from uuid import uuid4
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from pydantic_settings import BaseSettings
from typing import Optional
from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from passlib.context import CryptContext
from fastapi import Header


class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    UPLOAD_DIR: str = "uploads"
    BASE_URL: str = "http://localhost:8002"   # URL public của user-service
    SECRET_KEY: str = "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7"
    ALGORITHM: str = "HS256"
    class Config:
        env_file = ".env"

settings = Settings()

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class User(Base):
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
    __tablename__ = "favorites"
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    location_id = Column(Integer, primary_key=True)
    created_at = Column(DateTime, default=datetime.utcnow)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

from urllib.parse import unquote
class CurrentUser:
    def __init__(self, id: int, role: str, email: str = ""):
        self.id = id; self.role = role; self.email = email

def get_current_user(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_email: Optional[str] = Header(None),
) -> CurrentUser:
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Missing authentication headers")
    return CurrentUser(
        id=int(x_user_id), 
        role=unquote(x_user_role) if x_user_role else "user", 
        email=unquote(x_user_email) if x_user_email else ""
    )

# Schemas
from pydantic import field_validator

class UserResponse(BaseModel):
    id: int; email: str; full_name: str
    avatar_url: Optional[str]; phone: Optional[str]
    role: str; is_active: bool; created_at: datetime
    class Config: from_attributes = True

    @field_validator('avatar_url', mode='after')
    @classmethod
    def normalize_avatar(cls, v: Optional[str]) -> Optional[str]:
        """Đảm bảo avatar_url luôn là full URL (cho dữ liệu cũ lưu relative path)."""
        if v and not v.startswith('http'):
            return f"{settings.BASE_URL}/uploads/{v.lstrip('/')}"
        return v

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

ALLOWED_EXT = {"png", "jpg", "jpeg", "gif", "webp"}

def _save_file(upload_file: UploadFile, subfolder: str) -> str:
    raw_name = upload_file.filename or ""
    ext = raw_name.rsplit(".", 1)[-1].lower() if "." in raw_name else ""
    if not ext or ext not in ALLOWED_EXT:
        raise HTTPException(
            status_code=400,
            detail=f"File type not allowed: '{ext}'. Allowed: {', '.join(ALLOWED_EXT)}"
        )
    dest_dir = os.path.join(settings.UPLOAD_DIR, subfolder)
    os.makedirs(dest_dir, exist_ok=True)
    filename = f"{uuid4()}.{ext}"
    path = os.path.join(dest_dir, filename)
    with open(path, "wb") as f:
        shutil.copyfileobj(upload_file.file, f)
    return os.path.join(subfolder, filename).replace("\\", "/")

app = FastAPI(title="TRAWiMe User Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

@app.get("/health")
def health(): return {"status": "healthy", "service": "user-service"}

@app.get("/api/users/profile", response_model=UserResponse)
def get_profile(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.put("/api/users/profile", response_model=UserResponse)
def update_profile(data: UserUpdate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    update_data = data.model_dump(exclude_unset=True)
    if "email" in update_data and update_data["email"] != user.email:
        if db.query(User).filter(User.email == update_data["email"]).first():
            raise HTTPException(status_code=400, detail="Email đã được sử dụng")
    for k, v in update_data.items():
        setattr(user, k, v)
    db.commit(); db.refresh(user)
    return user

@app.put("/api/users/change-password")
def change_password(req: ChangePasswordRequest, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current.id).first()
    if not user or not pwd_context.verify(req.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Mật khẩu hiện tại không đúng")
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="Mật khẩu mới phải có ít nhất 6 ký tự")
    user.password_hash = pwd_context.hash(req.new_password)
    db.commit()
    return {"message": "Đổi mật khẩu thành công"}

@app.post("/api/users/avatar", response_model=UserResponse)
async def upload_avatar(file: UploadFile = File(...), current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Lưu file và cập nhật full public URL
    relative_path = _save_file(file, "avatars")
    user.avatar_url = f"{settings.BASE_URL}/uploads/{relative_path}"
    db.commit(); db.refresh(user)
    return user

@app.post("/api/users/favorites/{location_id}")
def add_favorite(location_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    fav = db.query(Favorite).filter_by(user_id=current.id, location_id=location_id).first()
    if not fav:
        fav = Favorite(user_id=current.id, location_id=location_id)
        db.add(fav)
        db.commit()
    return {"message": "Đã thêm vào mục yêu thích", "location_id": location_id}

@app.delete("/api/users/favorites/{location_id}", status_code=204)
def remove_favorite(location_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    fav = db.query(Favorite).filter_by(user_id=current.id, location_id=location_id).first()
    if fav:
        db.delete(fav)
        db.commit()
    return None

@app.get("/api/users/favorites")
def get_favorites(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return [fav.location_id for fav in db.query(Favorite).filter_by(user_id=current.id).all()]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8002, reload=True)
