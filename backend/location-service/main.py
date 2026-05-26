import os
import uuid
import aiofiles
from pathlib import Path
from typing import Optional, List
import sys
sys.path.insert(0, "/app")

from fastapi import FastAPI, Depends, HTTPException, Query, BackgroundTasks, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

# Import các mô-đun nội bộ sau khi đã được tách
from models import get_db, Category, Location, settings
from helpers import (
    _trigger_embedding,
    CurrentUser,
    get_current_user,
    require_admin,
    _resolve_categories,
    _cleanup_orphan_categories,
    haversine,
    _enrich,
    _enrich_many,
)
from schemas import (
    CategoryResponse,
    CategoryCreate,
    LocationResponse,
    LocationCreate,
    LocationUpdate,
)

# Thiết lập các tham số lưu trữ media
MEDIA_DIR = Path("/app/media")
MEDIA_DIR.mkdir(parents=True, exist_ok=True)

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/x-msvideo", "video/webm"}
ALLOWED_MEDIA_TYPES = ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES
MAX_IMAGE_SIZE = 10 * 1024 * 1024   # 10 MB
MAX_VIDEO_SIZE = 100 * 1024 * 1024  # 100 MB

app = FastAPI(title="TRAWiMe Location Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# Gắn kết thư mục chứa ảnh/video để phục vụ truy cập trực tiếp từ liên kết
app.mount("/media", StaticFiles(directory=str(MEDIA_DIR)), name="media")

@app.get("/health")
def health(): 
    # API kiểm tra trạng thái hoạt động của location-service
    return {"status": "healthy", "service": "location-service"}

@app.post("/api/locations/upload-media")
async def upload_media(file: UploadFile = File(...), current: CurrentUser = Depends(require_admin)):
    # API tải lên hình ảnh hoặc video của địa điểm lên ổ đĩa
    content_type = file.content_type or ""
    if content_type not in ALLOWED_MEDIA_TYPES:
        raise HTTPException(status_code=400, detail=f"Dinh dang file khong duoc ho tro: {content_type}")

    content = await file.read()
    size = len(content)
    if content_type in ALLOWED_IMAGE_TYPES and size > MAX_IMAGE_SIZE:
        raise HTTPException(status_code=413, detail="Dung luong anh vuot qua 10MB")
    if content_type in ALLOWED_VIDEO_TYPES and size > MAX_VIDEO_SIZE:
        raise HTTPException(status_code=413, detail="Dung luong video vuot qua 100MB")

    ext = Path(file.filename).suffix.lower() if file.filename else ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = MEDIA_DIR / filename

    async with aiofiles.open(dest, "wb") as f:
        await f.write(content)

    public_url = f"{settings.BASE_URL}/media/{filename}"
    return {"url": public_url, "filename": filename}

@app.delete("/api/locations/media/{filename}", status_code=204)
async def delete_media(filename: str, current: CurrentUser = Depends(require_admin)):
    # API xóa tệp tin media ra khỏi ổ đĩa
    if "/" in filename or "\\" in filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Ten file khong dung quy cach")
    dest = MEDIA_DIR / filename
    if dest.exists():
        dest.unlink()

@app.get("/api/categories", response_model=List[CategoryResponse])
def get_categories(db: Session = Depends(get_db)):
    # API lấy toàn bộ danh mục địa điểm
    return db.query(Category).order_by(Category.name).all()

@app.post("/api/categories", response_model=CategoryResponse, status_code=201)
def create_category(data: CategoryCreate, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    # API tạo một danh mục mới
    if db.query(Category).filter(Category.slug == data.slug).first():
        raise HTTPException(status_code=400, detail=f"Danh muc '{data.slug}' da co san")
    cat = Category(slug=data.slug, name=data.name)
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return cat

@app.delete("/api/categories/{slug}", status_code=204)
def delete_category(slug: str, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    # API xóa một danh mục theo slug
    cat = db.query(Category).filter(Category.slug == slug).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Khong tim thay danh muc")
    db.delete(cat)
    db.commit()

@app.get("/api/locations")
def get_locations(
    skip: int = Query(0, ge=0), limit: int = Query(20, ge=1, le=100),
    category: Optional[str] = None, city: Optional[str] = None,
    search: Optional[str] = None, min_rating: Optional[float] = None,
    db: Session = Depends(get_db)
):
    # API lấy danh sách các địa điểm du lịch có phân trang, tìm kiếm và sắp xếp theo điểm đánh giá
    from sqlalchemy.orm import joinedload
    q = db.query(Location).options(joinedload(Location.categories))
    if category:
        q = q.filter(Location.categories.any(Category.slug == category))
    if city: 
        q = q.filter(Location.city.ilike(f"%{city}%"))
    if search: 
        q = q.filter(Location.name.ilike(f"%{search}%") | Location.description.ilike(f"%{search}%"))
    locs = q.offset(skip).limit(limit).all()
    enriched = _enrich_many(locs, db)
    if min_rating:
        enriched = [e for e in enriched if e["rating_avg"] >= min_rating]
    enriched.sort(key=lambda x: x["rating_avg"], reverse=True)
    return enriched

@app.get("/api/locations/nearby")
def get_nearby(latitude: float = Query(...), longitude: float = Query(...), radius_km: float = Query(50), db: Session = Depends(get_db)):
    # API tìm kiếm các địa điểm lân cận trong bán kính bằng công thức Haversine
    all_locs = db.query(Location).filter(Location.latitude.isnot(None), Location.longitude.isnot(None)).all()
    filtered = [l for l in all_locs if haversine(latitude, longitude, l.latitude, l.longitude) <= radius_km]
    return _enrich_many(filtered, db)

@app.get("/api/locations/{location_id}")
def get_location(location_id: int, db: Session = Depends(get_db)):
    # API lấy thông tin chi tiết của một địa điểm kèm điểm sao trung bình
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc: 
        raise HTTPException(status_code=404, detail="Khong tim thay dia diem")
    return _enrich(loc, db)

@app.post("/api/locations", status_code=201)
async def create_location(data: LocationCreate, background_tasks: BackgroundTasks, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    # API tạo địa điểm mới (chỉ quản trị viên), kích hoạt tạo vector đặc trưng chạy ngầm
    cats = _resolve_categories(data.categories_input, db)
    loc = Location(
        name=data.name, description=data.description,
        address=data.address, city=data.city, country=data.country,
        latitude=data.latitude, longitude=data.longitude,
        images=data.images or [], thumbnail=data.thumbnail,
        created_by=current.id,
    )
    loc.categories = cats
    db.add(loc)
    db.commit()
    db.refresh(loc)
    background_tasks.add_task(_trigger_embedding, loc.id)
    return _enrich(loc, db)

@app.put("/api/locations/{location_id}")
async def update_location(location_id: int, data: LocationUpdate, background_tasks: BackgroundTasks, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    # API chỉnh sửa địa điểm, dọn dẹp các danh mục mồ côi
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc: 
        raise HTTPException(status_code=404, detail="Khong tim thay dia diem")
    for k, v in data.model_dump(exclude_unset=True, exclude={"categories_input"}).items():
        setattr(loc, k, v)
    if data.categories_input is not None:
        cats = _resolve_categories(data.categories_input, db)
        loc.categories = cats
    db.commit()
    db.refresh(loc)
    _cleanup_orphan_categories(db)
    if data.description is not None:
        background_tasks.add_task(_trigger_embedding, loc.id)
    return _enrich(loc, db)

@app.delete("/api/locations/{location_id}", status_code=204)
def delete_location(location_id: int, current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    # API xóa địa điểm (chỉ quản trị viên)
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc: 
        raise HTTPException(status_code=404, detail="Khong tim thay dia diem")
    db.delete(loc)
    db.commit()
    _cleanup_orphan_categories(db)

if __name__ == "__main__":
    import uvicorn
    # Khởi động máy chủ uvicorn tại cổng 8003
    uvicorn.run("main:app", host="0.0.0.0", port=8003, reload=True)
