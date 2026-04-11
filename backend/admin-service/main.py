"""admin-service: handles /api/admin/* (stats, user management, content moderation)"""
from typing import Optional, List
from datetime import datetime
from fastapi import FastAPI, Depends, HTTPException, Query, Header
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Boolean, DateTime, Float, Text, JSON, ForeignKey, func, desc
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from pydantic_settings import BaseSettings
import httpx

class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    LOCATION_SERVICE_URL: str = "http://location-service:8003"
    class Config: env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, index=True)
    password_hash = Column(String(255))
    full_name = Column(String(100))
    avatar_url = Column(String(500), nullable=True)
    phone = Column(String(20), nullable=True)
    role = Column(String(20), default="user")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True)
    slug = Column(String(50), unique=True)
    name = Column(String(100))

class LocationCategory(Base):
    __tablename__ = "location_categories"
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="CASCADE"), primary_key=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)

class Location(Base):
    __tablename__ = "locations"
    id = Column(Integer, primary_key=True)
    name = Column(String(255), nullable=True)

class Review(Base):
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer)
    location_id = Column(Integer, ForeignKey("locations.id"))
    rating = Column(Float)
    comment = Column(Text)
    photos = Column(JSON, default=list)        # ← ảnh đính kèm
    user_name = Column(String(100), nullable=True)   # ← tên user cache
    user_email = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Itinerary(Base):
    __tablename__ = "itineraries"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer)

class Favorite(Base):
    __tablename__ = "favorites"
    user_id = Column(Integer, primary_key=True)
    location_id = Column(Integer, primary_key=True)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

class CurrentUser:
    def __init__(self, id: int, role: str):
        self.id = id; self.role = role

def get_admin_user(x_user_id: Optional[str] = Header(None), x_user_role: Optional[str] = Header(None)) -> CurrentUser:
    if not x_user_id: raise HTTPException(status_code=401, detail="Missing auth headers")
    user = CurrentUser(id=int(x_user_id), role=x_user_role or "user")
    if user.role != "admin": raise HTTPException(status_code=403, detail="Not enough permissions")
    return user

# Schemas
class UserResponse(BaseModel):
    id: int; email: str; full_name: str
    avatar_url: Optional[str]; phone: Optional[str]
    role: str; is_active: bool; created_at: datetime
    class Config: from_attributes = True

app = FastAPI(title="TRAWiMe Admin Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.get("/health")
def health(): return {"status": "healthy", "service": "admin-service"}

# ── User Management ─────────────────────────────────────────────────────────────
@app.get("/api/admin/users", response_model=List[UserResponse])
def list_users(
    skip: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None, role: Optional[str] = None,
    current: CurrentUser = Depends(get_admin_user), db: Session = Depends(get_db)
):
    q = db.query(User)
    if search: q = q.filter(User.full_name.ilike(f"%{search}%") | User.email.ilike(f"%{search}%"))
    if role: q = q.filter(User.role == role)
    return q.order_by(User.created_at.desc()).offset(skip).limit(limit).all()

@app.put("/api/admin/users/{user_id}/toggle-active")
def toggle_user(user_id: int, current: CurrentUser = Depends(get_admin_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user: raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    if user.id == current.id: raise HTTPException(status_code=400, detail="Không thể khóa chính mình")
    if user.role == "admin": raise HTTPException(status_code=400, detail="Không thể khóa tài khoản admin khác")
    user.is_active = not user.is_active
    db.commit()
    return {"user_id": user.id, "email": user.email, "is_active": user.is_active,
            "message": f"Tài khoản đã được {'mở khóa' if user.is_active else 'khóa'}"}

# ── Content Moderation ──────────────────────────────────────────────────────────
@app.get("/api/admin/reviews")
def list_reviews(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=500),
    current: CurrentUser = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Review, Location.name.label("location_name"))
        .outerjoin(Location, Review.location_id == Location.id)
        .order_by(Review.created_at.desc())
        .offset(skip).limit(limit)
        .all()
    )
    return [
        {
            "id": r.id,
            "user_id": r.user_id,
            "user_name": r.user_name or f"User #{r.user_id}",
            "location_id": r.location_id,
            "location_name": loc_name or f"Địa điểm #{r.location_id}",
            "rating": r.rating,
            "comment": r.comment,
            "photos": r.photos or [],
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r, loc_name in rows
    ]

@app.delete("/api/admin/reviews/{review_id}", status_code=204)
async def delete_review(review_id: int, current: CurrentUser = Depends(get_admin_user), db: Session = Depends(get_db)):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review: raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá")
    location_id = review.location_id
    db.delete(review); db.commit()
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.post(f"{settings.LOCATION_SERVICE_URL}/internal/locations/{location_id}/recalculate-rating")
    except Exception:
        pass

# ── Statistics ──────────────────────────────────────────────────────────────────
@app.get("/api/admin/stats")
def get_stats(current: CurrentUser = Depends(get_admin_user), db: Session = Depends(get_db)):
    total_users = db.query(func.count(User.id)).scalar()
    active_users = db.query(func.count(User.id)).filter(User.is_active == True).scalar()
    total_locations = db.query(func.count(Location.id)).scalar()
    total_reviews = db.query(func.count(Review.id)).scalar()
    total_itineraries = db.query(func.count(Itinerary.id)).scalar()
    avg_rating = db.query(func.avg(Review.rating)).scalar()
    # Category stats via N-N join
    category_stats = db.query(
        Category.slug, func.count(LocationCategory.location_id)
    ).join(LocationCategory, Category.id == LocationCategory.category_id) \
     .group_by(Category.slug).all()

    top_favorite_locations = db.query(
        Location.id, func.count(Favorite.location_id).label("favorite_count")
    ).join(Favorite, Location.id == Favorite.location_id).group_by(Location.id).order_by(desc("favorite_count")).limit(5).all()

    return {
        "users": {"total": total_users, "active": active_users, "inactive": total_users - active_users},
        "locations": {
            "total": total_locations,
            "by_category": {slug: cnt for slug, cnt in category_stats},
            "top_favorites": [{"location_id": l_id, "count": cnt} for l_id, cnt in top_favorite_locations]
        },
        "reviews": {"total": total_reviews, "average_rating": round(float(avg_rating), 2) if avg_rating else 0},
        "itineraries": {"total": total_itineraries},
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8007, reload=True)
