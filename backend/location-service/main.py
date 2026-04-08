"""location-service: handles /api/locations/* and /api/categories/*"""
import math
import httpx
from typing import Optional, List
from datetime import datetime
from fastapi import FastAPI, Depends, HTTPException, Query, Header, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, JSON, Text, ForeignKey, func
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    AI_SERVICE_URL: str = "http://ai-service:8006"
    class Config: env_file = ".env"

settings = Settings()

async def _trigger_embedding(location_id: int):
    """Fire-and-forget: ask ai-service to embed this location."""
    import logging
    logger = logging.getLogger("location-service")
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            await client.post(
                f"{settings.AI_SERVICE_URL}/internal/embed-location/{location_id}"
            )
    except Exception as e:
        logger.warning(f"Could not trigger embedding for location {location_id}: {e}")

engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# ── Models ─────────────────────────────────────────────────────────────────────
class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True, index=True)
    slug = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False)
    icon = Column(String(50), nullable=True)

class LocationCategory(Base):
    __tablename__ = "location_categories"
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="CASCADE"), primary_key=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)

class Location(Base):
    __tablename__ = "locations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=False)
    address = Column(String(500), nullable=True)
    city = Column(String(100), nullable=False, index=True)
    country = Column(String(100), default="Vietnam")
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    images = Column(JSON, default=list)
    description_embedding = Column(JSON, nullable=True)
    created_by = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Review(Base):
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True)
    location_id = Column(Integer, ForeignKey("locations.id"), nullable=False)
    rating = Column(Float, nullable=False)

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

# ── Auth ───────────────────────────────────────────────────────────────────────
class CurrentUser:
    def __init__(self, id: int, role: str):
        self.id = id; self.role = role

def get_current_user(x_user_id: Optional[str] = Header(None), x_user_role: Optional[str] = Header(None)) -> CurrentUser:
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Missing authentication headers")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")

def require_admin(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if current.role != "admin":
        raise HTTPException(status_code=403, detail="Not enough permissions")
    return current

# ── Schemas ────────────────────────────────────────────────────────────────────
class CategoryResponse(BaseModel):
    id: int; slug: str; name: str; icon: Optional[str]
    class Config: from_attributes = True

class LocationResponse(BaseModel):
    id: int; name: str; description: Optional[str]; category: str
    address: Optional[str]; city: str; country: str
    latitude: Optional[float]; longitude: Optional[float]
    rating_avg: float; total_reviews: int
    images: Optional[list]; created_at: datetime

class LocationCreate(BaseModel):
    name: str; description: Optional[str] = None; category: str
    address: Optional[str] = None; city: str; country: str = "Vietnam"
    latitude: Optional[float] = None; longitude: Optional[float] = None
    images: Optional[list] = []

class LocationUpdate(BaseModel):
    name: Optional[str] = None; description: Optional[str] = None
    category: Optional[str] = None; address: Optional[str] = None
    city: Optional[str] = None; country: Optional[str] = None
    latitude: Optional[float] = None; longitude: Optional[float] = None
    images: Optional[list] = None

# ── Helpers ────────────────────────────────────────────────────────────────────
def haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def _enrich(loc: Location, db: Session) -> dict:
    """Compute rating_avg and total_reviews on-the-fly from the reviews table."""
    result = db.query(
        func.avg(Review.rating).label("avg_rating"),
        func.count(Review.id).label("total"),
    ).filter(Review.location_id == loc.id).first()
    rating_avg = round(float(result.avg_rating), 2) if result.avg_rating else 0.0
    total_reviews = result.total or 0
    return {
        "id": loc.id, "name": loc.name, "description": loc.description,
        "category": loc.category, "address": loc.address,
        "city": loc.city, "country": loc.country,
        "latitude": loc.latitude, "longitude": loc.longitude,
        "rating_avg": rating_avg, "total_reviews": total_reviews,
        "images": loc.images or [], "created_at": loc.created_at,
    }

def _enrich_many(locs: list, db: Session) -> list:
    """Bulk compute ratings for a list of locations in one query."""
    if not locs:
        return []
    ids = [l.id for l in locs]
    rows = db.query(
        Review.location_id,
        func.avg(Review.rating).label("avg_rating"),
        func.count(Review.id).label("total"),
    ).filter(Review.location_id.in_(ids)).group_by(Review.location_id).all()
    stats = {r.location_id: (r.avg_rating, r.total) for r in rows}

    result = []
    for loc in locs:
        avg, total = stats.get(loc.id, (None, 0))
        result.append({
            "id": loc.id, "name": loc.name, "description": loc.description,
            "category": loc.category, "address": loc.address,
            "city": loc.city, "country": loc.country,
            "latitude": loc.latitude, "longitude": loc.longitude,
            "rating_avg": round(float(avg), 2) if avg else 0.0,
            "total_reviews": total or 0,
            "images": loc.images or [], "created_at": loc.created_at,
        })
    return result

# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(title="TRAWiMe Location Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.get("/health")
def health(): return {"status": "healthy", "service": "location-service"}

# Categories
@app.get("/api/categories", response_model=List[CategoryResponse])
def get_categories(db: Session = Depends(get_db)):
    return db.query(Category).order_by(Category.name).all()

# Locations
@app.get("/api/locations")
def get_locations(
    skip: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100),
    category: Optional[str] = None, city: Optional[str] = None,
    search: Optional[str] = None, min_rating: Optional[float] = None,
    db: Session = Depends(get_db)
):
    q = db.query(Location)
    if category: q = q.filter(Location.category == category)
    if city: q = q.filter(Location.city.ilike(f"%{city}%"))
    if search: q = q.filter(Location.name.ilike(f"%{search}%") | Location.description.ilike(f"%{search}%"))
    locs = q.offset(skip).limit(limit).all()
    enriched = _enrich_many(locs, db)
    if min_rating:
        enriched = [e for e in enriched if e["rating_avg"] >= min_rating]
    # Sort by rating desc
    enriched.sort(key=lambda x: x["rating_avg"], reverse=True)
    return enriched

@app.get("/api/locations/nearby")
def get_nearby(latitude: float = Query(...), longitude: float = Query(...), radius_km: float = Query(50), db: Session = Depends(get_db)):
    all_locs = db.query(Location).filter(Location.latitude.isnot(None), Location.longitude.isnot(None)).all()
    filtered = [l for l in all_locs if haversine(latitude, longitude, l.latitude, l.longitude) <= radius_km]
    return _enrich_many(filtered, db)

@app.get("/api/locations/{location_id}")
def get_location(location_id: int, db: Session = Depends(get_db)):
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc: raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")
    return _enrich(loc, db)

@app.post("/api/locations", status_code=201)
async def create_location(data: LocationCreate, background_tasks: BackgroundTasks, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    loc = Location(**data.model_dump(), created_by=current.id)
    db.add(loc); db.commit(); db.refresh(loc)
    background_tasks.add_task(_trigger_embedding, loc.id)
    return _enrich(loc, db)

@app.put("/api/locations/{location_id}")
async def update_location(location_id: int, data: LocationUpdate, background_tasks: BackgroundTasks, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc: raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(loc, k, v)
    db.commit(); db.refresh(loc)
    if data.description is not None:
        background_tasks.add_task(_trigger_embedding, loc.id)
    return _enrich(loc, db)

@app.delete("/api/locations/{location_id}", status_code=204)
def delete_location(location_id: int, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc: raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm")
    db.delete(loc); db.commit()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8003, reload=True)
