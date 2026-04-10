"""review-service: handles /api/reviews/*"""
import os, shutil
from uuid import uuid4
from typing import Optional, List
from datetime import datetime
from fastapi import FastAPI, Depends, HTTPException, status, UploadFile, File, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime, Float, Text, JSON, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from pydantic_settings import BaseSettings
import httpx

class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    UPLOAD_DIR: str = "uploads"
    LOCATION_SERVICE_URL: str = "http://location-service:8003"
    USER_SERVICE_URL: str = "http://user-service:8002"
    BASE_URL: str = "http://localhost:8004"  # URL public của review-service
    class Config: env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Review(Base):
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    location_id = Column(Integer, nullable=False)
    rating = Column(Float, nullable=False)
    comment = Column(Text, nullable=True)
    photos = Column(JSON, default=list)
    # Lưu user info để tránh round-trip sang user-service khi đọc
    user_name = Column(String(100), nullable=True)
    user_email = Column(String(255), nullable=True)
    visited_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

class CurrentUser:
    def __init__(self, id: int, role: str, email: str = "", name: str = ""):
        self.id = id; self.role = role; self.email = email; self.name = name

def get_current_user(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_email: Optional[str] = Header(None),
    x_user_name: Optional[str] = Header(None),
) -> CurrentUser:
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Missing auth headers")
    return CurrentUser(
        id=int(x_user_id),
        role=x_user_role or "user",
        email=x_user_email or "",
        name=x_user_name or "",
    )

def _make_photo_urls(photos: list) -> list:
    """Chuyển relative path thành full URL."""
    result = []
    for p in (photos or []):
        if p and not p.startswith("http"):
            result.append(f"{settings.BASE_URL}/uploads/{p}")
        else:
            result.append(p)
    return result

# Schemas
class ReviewCreate(BaseModel):
    location_id: int
    rating: float
    comment: Optional[str] = None
    photos: Optional[list] = []
    visited_at: Optional[datetime] = None

class ReviewUpdate(BaseModel):
    rating: Optional[float] = None
    comment: Optional[str] = None
    photos: Optional[list] = None

class UserInfo(BaseModel):
    id: int
    full_name: str
    email: str

class ReviewResponse(BaseModel):
    id: int
    user_id: int
    location_id: int
    rating: float
    comment: Optional[str]
    photos: Optional[list]
    user: Optional[UserInfo]   # ← trả về user object cho frontend
    visited_at: Optional[datetime]
    created_at: datetime
    class Config: from_attributes = True

def _enrich_review(review: Review) -> dict:
    """Thêm user object và chuyển photo paths thành full URL."""
    return {
        "id": review.id,
        "user_id": review.user_id,
        "location_id": review.location_id,
        "rating": review.rating,
        "comment": review.comment,
        "photos": _make_photo_urls(review.photos or []),
        "user": {
            "id": review.user_id,
            "full_name": review.user_name or "Người dùng",
            "email": review.user_email or "",
        },
        "visited_at": review.visited_at,
        "created_at": review.created_at,
    }

ALLOWED_EXT = {"png", "jpg", "jpeg", "gif", "webp"}

app = FastAPI(title="TRAWiMe Review Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

Base.metadata.create_all(bind=engine)

os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

@app.get("/health")
def health(): return {"status": "healthy", "service": "review-service"}

@app.post("/api/reviews", status_code=201)
def create_review(
    review: ReviewCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Lấy tên user từ user-service (best-effort, không block nếu fail)
    user_name = current.name or current.email
    try:
        with httpx.Client(timeout=3) as client:
            resp = client.get(
                f"{settings.USER_SERVICE_URL}/api/users/profile",
                headers={
                    "X-User-Id": str(current.id),
                    "X-User-Role": current.role,
                    "X-User-Email": current.email,
                },
            )
            if resp.status_code == 200:
                user_name = resp.json().get("full_name", user_name)
    except Exception:
        pass  # Dùng email nếu không lấy được tên

    new_review = Review(
        user_id=current.id,
        user_name=user_name,
        user_email=current.email,
        **review.model_dump(),
    )
    db.add(new_review)
    db.commit()
    db.refresh(new_review)
    return _enrich_review(new_review)

@app.post("/api/reviews/upload-photos")
async def upload_photos(
    files: List[UploadFile] = File(...),
    current: CurrentUser = Depends(get_current_user),
):
    paths = []
    for f in files:
        ext = f.filename.rsplit(".", 1)[-1].lower()
        if ext not in ALLOWED_EXT:
            raise HTTPException(status_code=400, detail="File type not allowed")
        dest = os.path.join(settings.UPLOAD_DIR, "reviews")
        os.makedirs(dest, exist_ok=True)
        fname = f"{uuid4()}.{ext}"
        with open(os.path.join(dest, fname), "wb") as buf:
            shutil.copyfileobj(f.file, buf)
        paths.append(f"{settings.BASE_URL}/uploads/reviews/{fname}")  # ← full URL
    return {"photos": paths}

@app.get("/api/reviews/location/{location_id}")
def get_location_reviews(
    location_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    reviews = (
        db.query(Review)
        .filter(Review.location_id == location_id)
        .order_by(Review.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich_review(r) for r in reviews]

@app.get("/api/checkins")
def get_my_checkins(
    skip: int = 0,
    limit: int = 20,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reviews = (
        db.query(Review)
        .filter(Review.user_id == current.id)
        .order_by(Review.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich_review(r) for r in reviews]

@app.post("/api/checkins", status_code=201)
def create_checkin(
    review: ReviewCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Alias của create_review (checkin = review)."""
    return create_review(review, current, db)

@app.put("/api/reviews/{review_id}")
def update_review(
    review_id: int,
    data: ReviewUpdate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id, Review.user_id == current.id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(review, k, v)
    db.commit()
    db.refresh(review)
    return _enrich_review(review)

@app.delete("/api/reviews/{review_id}", status_code=204)
def delete_review(
    review_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    review = db.query(Review).filter(Review.id == review_id, Review.user_id == current.id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá")
    db.delete(review)
    db.commit()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8004, reload=True)
