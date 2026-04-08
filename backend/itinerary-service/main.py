"""itinerary-service: handles /api/itineraries/* (CRUD + days + activities + route)"""
import math
from typing import Optional, List
from datetime import datetime, date, time
from fastapi import FastAPI, Depends, HTTPException, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime, Text, Float, Time, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from pydantic import BaseModel
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    class Config: env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# ── ORM Models ─────────────────────────────────────────────────────────────────
class Itinerary(Base):
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
    __tablename__ = "itinerary_activities"
    id = Column(Integer, primary_key=True, index=True)
    day_id = Column(Integer, ForeignKey("itinerary_days.id"), nullable=False)
    location_id = Column(Integer, nullable=True)
    location_name = Column(String(255), nullable=True)   # denormalised for display
    location_lat = Column(Float, nullable=True)
    location_lng = Column(Float, nullable=True)
    location_image = Column(Text, nullable=True)          # first image URL
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    start_time = Column(Time, nullable=True)
    end_time = Column(Time, nullable=True)
    cost_estimate = Column(Float, nullable=True)
    note = Column(Text, nullable=True)
    order_index = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    day = relationship("ItineraryDay", back_populates="activities")

Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()


class CurrentUser:
    def __init__(self, id: int, role: str):
        self.id = id; self.role = role


def get_current_user(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
) -> CurrentUser:
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Missing auth headers")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")


# ── Pydantic Schemas ────────────────────────────────────────────────────────────
class ActivityCreate(BaseModel):
    title: str
    description: Optional[str] = None
    location_id: Optional[int] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    location_image: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    cost_estimate: Optional[float] = None
    note: Optional[str] = None
    order_index: int = 0


class ActivityUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    location_id: Optional[int] = None
    location_name: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    location_image: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    cost_estimate: Optional[float] = None
    note: Optional[str] = None
    order_index: Optional[int] = None


class ActivityResponse(BaseModel):
    id: int; day_id: int; title: str; description: Optional[str]
    location_id: Optional[int]; location_name: Optional[str]
    location_lat: Optional[float]; location_lng: Optional[float]
    location_image: Optional[str]
    cost_estimate: Optional[float]; note: Optional[str]
    order_index: int; created_at: datetime
    start_time: Optional[str] = None
    end_time: Optional[str] = None

    @classmethod
    def from_orm_custom(cls, act: ItineraryActivity) -> "ActivityResponse":
        fmt = lambda t: f"{t.hour:02d}:{t.minute:02d}" if t else None
        return cls(
            id=act.id, day_id=act.day_id, title=act.title,
            description=act.description, location_id=act.location_id,
            location_name=act.location_name, location_lat=act.location_lat,
            location_lng=act.location_lng, location_image=act.location_image,
            cost_estimate=act.cost_estimate, note=act.note,
            order_index=act.order_index, created_at=act.created_at,
            start_time=fmt(act.start_time), end_time=fmt(act.end_time),
        )

    class Config: from_attributes = True


class DayCreate(BaseModel):
    day_number: int; title: Optional[str] = None; description: Optional[str] = None
    date: Optional[str] = None; activities: Optional[List[ActivityCreate]] = []


class DayUpdate(BaseModel):
    title: Optional[str] = None; description: Optional[str] = None; date: Optional[str] = None


class DayResponse(BaseModel):
    id: int; itinerary_id: int; day_number: int; title: Optional[str]; description: Optional[str]
    created_at: datetime; activities: List[ActivityResponse] = []

    @classmethod
    def from_orm_custom(cls, day: ItineraryDay) -> "DayResponse":
        return cls(
            id=day.id, itinerary_id=day.itinerary_id, day_number=day.day_number,
            title=day.title, description=day.description, created_at=day.created_at,
            activities=[ActivityResponse.from_orm_custom(a) for a in day.activities],
        )

    class Config: from_attributes = True


class ItineraryCreate(BaseModel):
    title: str; description: Optional[str] = None
    start_date: Optional[datetime] = None; end_date: Optional[datetime] = None
    status: str = "planned"


class ItineraryUpdate(BaseModel):
    title: Optional[str] = None; description: Optional[str] = None
    start_date: Optional[datetime] = None; end_date: Optional[datetime] = None
    status: Optional[str] = None


class ItineraryResponse(BaseModel):
    id: int; user_id: int; title: str; description: Optional[str]
    start_date: Optional[datetime]; end_date: Optional[datetime]; status: str
    created_at: datetime; days: List[DayResponse] = []

    @classmethod
    def from_orm_custom(cls, it: Itinerary) -> "ItineraryResponse":
        return cls(
            id=it.id, user_id=it.user_id, title=it.title, description=it.description,
            start_date=it.start_date, end_date=it.end_date, status=it.status,
            created_at=it.created_at,
            days=[DayResponse.from_orm_custom(d) for d in it.days],
        )

    class Config: from_attributes = True


# ── Helpers ─────────────────────────────────────────────────────────────────────
def _haversine(lat1, lon1, lat2, lon2) -> float:
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _get_itinerary(db: Session, itinerary_id: int, user_id: int) -> Itinerary:
    it = db.query(Itinerary).filter(Itinerary.id == itinerary_id, Itinerary.user_id == user_id).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    return it


def _get_day(db: Session, itinerary_id: int, day_id: int) -> ItineraryDay:
    day = db.query(ItineraryDay).filter(
        ItineraryDay.id == day_id, ItineraryDay.itinerary_id == itinerary_id
    ).first()
    if not day:
        raise HTTPException(status_code=404, detail="Không tìm thấy ngày")
    return day


def _parse_time(t_str: Optional[str]) -> Optional[time]:
    if not t_str:
        return None
    try:
        parts = t_str.split(":")
        return time(int(parts[0]), int(parts[1]))
    except Exception:
        return None


# ── App ─────────────────────────────────────────────────────────────────────────
app = FastAPI(title="TRAWiMe Itinerary Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])


@app.get("/health")
def health():
    return {"status": "healthy", "service": "itinerary-service"}


# ── Itinerary CRUD ──────────────────────────────────────────────────────────────
@app.get("/api/itineraries")
def get_itineraries(
    skip: int = 0, limit: int = 20,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    its = db.query(Itinerary).filter(Itinerary.user_id == current.id) \
        .order_by(Itinerary.created_at.desc()).offset(skip).limit(limit).all()
    return [ItineraryResponse.from_orm_custom(it) for it in its]


@app.get("/api/itineraries/{itinerary_id}")
def get_itinerary(itinerary_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    it = _get_itinerary(db, itinerary_id, current.id)
    return ItineraryResponse.from_orm_custom(it)


@app.post("/api/itineraries", status_code=201)
def create_itinerary(data: ItineraryCreate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    it = Itinerary(user_id=current.id, **data.model_dump())
    db.add(it); db.commit(); db.refresh(it)
    return ItineraryResponse.from_orm_custom(it)


@app.put("/api/itineraries/{itinerary_id}")
def update_itinerary(itinerary_id: int, data: ItineraryUpdate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    it = _get_itinerary(db, itinerary_id, current.id)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(it, k, v)
    db.commit(); db.refresh(it)
    return ItineraryResponse.from_orm_custom(it)


@app.delete("/api/itineraries/{itinerary_id}", status_code=204)
def delete_itinerary(itinerary_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    it = _get_itinerary(db, itinerary_id, current.id)
    db.delete(it); db.commit()


# ── Days ────────────────────────────────────────────────────────────────────────
@app.post("/api/itineraries/{itinerary_id}/days", status_code=201)
def add_day(itinerary_id: int, day: DayCreate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    _get_itinerary(db, itinerary_id, current.id)
    acts = day.activities or []
    new_day = ItineraryDay(itinerary_id=itinerary_id, **day.model_dump(exclude={"activities"}))
    db.add(new_day); db.flush()
    for act in acts:
        data = act.model_dump()
        data["start_time"] = _parse_time(data.get("start_time"))
        data["end_time"] = _parse_time(data.get("end_time"))
        db.add(ItineraryActivity(day_id=new_day.id, **data))
    db.commit(); db.refresh(new_day)
    return DayResponse.from_orm_custom(new_day)


@app.put("/api/itineraries/{itinerary_id}/days/{day_id}")
def update_day(itinerary_id: int, day_id: int, data: DayUpdate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    _get_itinerary(db, itinerary_id, current.id)
    day = _get_day(db, itinerary_id, day_id)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(day, k, v)
    db.commit(); db.refresh(day)
    return DayResponse.from_orm_custom(day)


@app.delete("/api/itineraries/{itinerary_id}/days/{day_id}", status_code=204)
def delete_day(itinerary_id: int, day_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    _get_itinerary(db, itinerary_id, current.id)
    day = _get_day(db, itinerary_id, day_id)
    db.delete(day); db.commit()


# ── Activities ──────────────────────────────────────────────────────────────────
@app.post("/api/itineraries/{itinerary_id}/days/{day_id}/activities", status_code=201)
def add_activity(
    itinerary_id: int, day_id: int, activity: ActivityCreate,
    current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db),
):
    _get_itinerary(db, itinerary_id, current.id)
    _get_day(db, itinerary_id, day_id)
    data = activity.model_dump()
    data["start_time"] = _parse_time(data.get("start_time"))
    data["end_time"] = _parse_time(data.get("end_time"))
    act = ItineraryActivity(day_id=day_id, **data)
    db.add(act); db.commit(); db.refresh(act)
    return ActivityResponse.from_orm_custom(act)


@app.put("/api/itineraries/{itinerary_id}/days/{day_id}/activities/{activity_id}")
def update_activity(
    itinerary_id: int, day_id: int, activity_id: int, data: ActivityUpdate,
    current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db),
):
    _get_itinerary(db, itinerary_id, current.id)
    act = db.query(ItineraryActivity).filter(
        ItineraryActivity.id == activity_id, ItineraryActivity.day_id == day_id
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Không tìm thấy hoạt động")
    upd = data.model_dump(exclude_unset=True)
    if "start_time" in upd:
        upd["start_time"] = _parse_time(upd["start_time"])
    if "end_time" in upd:
        upd["end_time"] = _parse_time(upd["end_time"])
    for k, v in upd.items():
        setattr(act, k, v)
    db.commit(); db.refresh(act)
    return ActivityResponse.from_orm_custom(act)


@app.delete("/api/itineraries/{itinerary_id}/days/{day_id}/activities/{activity_id}", status_code=204)
def delete_activity(
    itinerary_id: int, day_id: int, activity_id: int,
    current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db),
):
    _get_itinerary(db, itinerary_id, current.id)
    act = db.query(ItineraryActivity).filter(
        ItineraryActivity.id == activity_id, ItineraryActivity.day_id == day_id
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Không tìm thấy hoạt động")
    db.delete(act); db.commit()


# ── Route Planning ──────────────────────────────────────────────────────────────
@app.get("/api/itineraries/{itinerary_id}/days/{day_id}/route")
def get_day_route(
    itinerary_id: int,
    day_id: int,
    user_lat: float = Query(..., description="User current latitude"),
    user_lng: float = Query(..., description="User current longitude"),
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Return activities of a day sorted by proximity (nearest-neighbor from user's
    position). Also returns waypoints ready to pass to Google Directions API.
    """
    _get_itinerary(db, itinerary_id, current.id)
    day = _get_day(db, itinerary_id, day_id)

    # Filter activities that have coordinates
    geo_acts = [a for a in day.activities if a.location_lat and a.location_lng]
    no_geo_acts = [a for a in day.activities if not (a.location_lat and a.location_lng)]

    # Nearest-neighbor greedy sort from user position
    sorted_acts = []
    current_lat, current_lng = user_lat, user_lng
    remaining = list(geo_acts)

    while remaining:
        nearest = min(remaining, key=lambda a: _haversine(current_lat, current_lng, a.location_lat, a.location_lng))
        dist = _haversine(current_lat, current_lng, nearest.location_lat, nearest.location_lng)
        sorted_acts.append({"activity": nearest, "distance_km": round(dist, 2)})
        current_lat, current_lng = nearest.location_lat, nearest.location_lng
        remaining.remove(nearest)

    # Build waypoints for Google Directions API
    waypoints = []
    if sorted_acts:
        # Origin = user position
        # Destination = last stop
        # Waypoints = stops in between
        waypoints = [
            {"lat": a["activity"].location_lat, "lng": a["activity"].location_lng,
             "name": a["activity"].location_name or a["activity"].title,
             "distance_from_prev_km": a["distance_km"]}
            for a in sorted_acts
        ]

    return {
        "user_location": {"lat": user_lat, "lng": user_lng},
        "day_id": day_id,
        "sorted_stops": [
            {
                **ActivityResponse.from_orm_custom(a["activity"]).model_dump(),
                "distance_from_prev_km": a["distance_km"],
            }
            for a in sorted_acts
        ],
        "no_coordinates_stops": [ActivityResponse.from_orm_custom(a).model_dump() for a in no_geo_acts],
        "waypoints": waypoints,
        "total_stops": len(sorted_acts),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8005, reload=True)
