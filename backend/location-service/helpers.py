import math
import re as _re
import httpx
import logging
from typing import Optional
from fastapi import Header, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from models import settings, Category, LocationCategory, Location, Review

# Cấu hình Logger hệ thống
logger = logging.getLogger("location-service")

async def _trigger_embedding(location_id: int):
    # Gọi API nội bộ không đồng bộ để yêu cầu ai-service cập nhật embedding
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            await client.post(
                f"{settings.AI_SERVICE_URL}/internal/embed-location/{location_id}"
            )
    except Exception as e:
        logger.warning(f"Khong the kích hoat tao embedding cho location {location_id}: {e}")

class CurrentUser:
    # Thông tin người dùng giải nén từ gateway headers
    def __init__(self, id: int, role: str):
        self.id = id
        self.role = role

def get_current_user(x_user_id: Optional[str] = Header(None), x_user_role: Optional[str] = Header(None)) -> CurrentUser:
    # Trích xuất thông tin tài khoản đang đăng nhập
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Thiếu headers xác thực tài khoản")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")

def require_admin(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    # Ràng buộc quyền quản trị viên (admin)
    if current.role != "admin":
        raise HTTPException(status_code=403, detail="Không đủ thẩm quyền truy cập")
    return current

def _make_slug(name: str) -> str:
    # Sinh ra slug duy nhất từ tên danh mục
    s = name.lower().strip()
    s = _re.sub(r'[\s_]+', '-', s)
    s = _re.sub(r'[^\w-]', '', s, flags=_re.UNICODE)
    s = _re.sub(r'-+', '-', s).strip('-')
    return s or 'category'

def _resolve_categories(inputs: list, db: Session) -> list:
    # Phân tích và chèn danh mục động, tự động tạo nếu slug chưa có trong cơ sở dữ liệu (DB)
    result = []
    seen = set()
    for inp in inputs:
        slug = inp.slug.strip() if inp.slug else _make_slug(inp.name or 'category')
        if not slug or slug in seen:
            continue
        seen.add(slug)
        cat = db.query(Category).filter(Category.slug == slug).first()
        if not cat:
            name = inp.name or slug
            cat = Category(slug=slug, name=name)
            db.add(cat)
            db.flush()
        result.append(cat)
    return result

def _cleanup_orphan_categories(db: Session):
    # Dọn dẹp các danh mục không còn địa điểm nào dùng đến
    used_ids = db.query(LocationCategory.category_id).distinct().subquery()
    orphans = db.query(Category).filter(~Category.id.in_(used_ids)).all()
    for cat in orphans:
        db.delete(cat)
    if orphans:
        db.commit()

def haversine(lat1, lon1, lat2, lon2) -> float:
    # Công thức Haversine đo khoảng cách đường chim bay (km) trên mặt cầu
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def _enrich(loc: Location, db: Session) -> dict:
    # Tính rating trung bình và đếm số lượt đánh giá (review) cho một địa điểm
    result = db.query(
        func.avg(Review.rating).label("avg_rating"),
        func.count(Review.id).label("total"),
    ).filter(Review.location_id == loc.id).first()
    rating_avg = round(float(result.avg_rating), 2) if result.avg_rating else 0.0
    total_reviews = result.total or 0
    imgs = loc.images or []
    return {
        "id": loc.id, "name": loc.name, "description": loc.description,
        "categories": [{"id": c.id, "slug": c.slug, "name": c.name} for c in (loc.categories or [])],
        "address": loc.address,
        "city": loc.city, "country": loc.country,
        "latitude": loc.latitude, "longitude": loc.longitude,
        "rating_avg": rating_avg, "total_reviews": total_reviews,
        "images": imgs,
        "thumbnail": loc.thumbnail or (imgs[0] if imgs else None),
        "created_at": loc.created_at,
    }

def _enrich_many(locs: list, db: Session) -> list:
    # Tính toán hàng loạt rating của nhiều địa điểm bằng GROUP BY để tránh lỗi truy vấn N+1 Query
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
        imgs = loc.images or []
        result.append({
            "id": loc.id, "name": loc.name, "description": loc.description,
            "categories": [{"id": c.id, "slug": c.slug, "name": c.name} for c in (loc.categories or [])],
            "address": loc.address,
            "city": loc.city, "country": loc.country,
            "latitude": loc.latitude, "longitude": loc.longitude,
            "rating_avg": round(float(avg), 2) if avg else 0.0,
            "total_reviews": total or 0,
            "images": imgs,
            "thumbnail": loc.thumbnail or (imgs[0] if imgs else None),
            "created_at": loc.created_at,
        })
    return result
