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
from sqlalchemy.orm import sessionmaker, Session, relationship
from pydantic import BaseModel
from pydantic_settings import BaseSettings
import httpx

class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    UPLOAD_DIR: str = "uploads"
    LOCATION_SERVICE_URL: str = "http://location-service:8003"
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
    visited_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

class CurrentUser:
    def __init__(self, id: int, role: str):
        self.id = id; self.role = role

def get_current_user(x_user_id: Optional[str] = Header(None), x_user_role: Optional[str] = Header(None)) -> CurrentUser:
    if not x_user_id: raise HTTPException(status_code=401, detail="Missing auth headers")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")

# Schemas
class ReviewCreate(BaseModel):
    location_id: int; rating: float; comment: Optional[str] = None
    photos: Optional[list] = []; visited_at: Optional[datetime] = None

class ReviewUpdate(BaseModel):
    rating: Optional[float] = None; comment: Optional[str] = None
    photos: Optional[list] = None

class ReviewResponse(BaseModel):
    id: int; user_id: int; location_id: int; rating: float
    comment: Optional[str]; photos: Optional[list]
    visited_at: Optional[datetime]; created_at: datetime
    class Config: from_attributes = True

ALLOWED_EXT = {"png", "jpg", "jpeg", "gif", "webp"}



app = FastAPI(title="TRAWiMe Review Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

@app.get("/health")
def health(): return {"status": "healthy", "service": "review-service"}

@app.post("/api/reviews", response_model=ReviewResponse, status_code=201)
def create_review(review: ReviewCreate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    new_review = Review(user_id=current.id, **review.model_dump())
    db.add(new_review); db.commit(); db.refresh(new_review)
    return new_review

@app.post("/api/reviews/upload-photos")
async def upload_photos(files: List[UploadFile] = File(...), current: CurrentUser = Depends(get_current_user)):
    paths = []
    for f in files:
        ext = f.filename.rsplit(".", 1)[-1].lower()
        if ext not in ALLOWED_EXT: raise HTTPException(status_code=400, detail="File type not allowed")
        dest = os.path.join(settings.UPLOAD_DIR, "reviews")
        os.makedirs(dest, exist_ok=True)
        fname = f"{uuid4()}.{ext}"
        with open(os.path.join(dest, fname), "wb") as buf: shutil.copyfileobj(f.file, buf)
        paths.append(f"reviews/{fname}")
    return {"photos": paths}

@app.get("/api/reviews/location/{location_id}", response_model=List[ReviewResponse])
def get_location_reviews(location_id: int, skip: int = 0, limit: int = 20, db: Session = Depends(get_db)):
    return db.query(Review).filter(Review.location_id == location_id).order_by(Review.created_at.desc()).offset(skip).limit(limit).all()

@app.put("/api/reviews/{review_id}", response_model=ReviewResponse)
def update_review(review_id: int, data: ReviewUpdate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    review = db.query(Review).filter(Review.id == review_id, Review.user_id == current.id).first()
    if not review: raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá")
    for k, v in data.model_dump(exclude_unset=True).items(): setattr(review, k, v)
    db.commit(); db.refresh(review)
    return review

@app.delete("/api/reviews/{review_id}", status_code=204)
def delete_review(review_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    review = db.query(Review).filter(Review.id == review_id, Review.user_id == current.id).first()
    if not review: raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá")
    db.delete(review); db.commit()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8004, reload=True)
