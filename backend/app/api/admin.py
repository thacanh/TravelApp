"""
Admin management endpoints
- User management (list, lock/unlock)
- Content moderation (delete reviews, check-ins)
- System statistics
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from ..database import get_db
from ..models.user import User
from ..models.location import Location
from ..models.review import Review
from ..models.itinerary import Itinerary
from ..schemas.user import UserResponse
from ..utils.security import require_admin

router = APIRouter(prefix="/api/admin", tags=["Admin"])


# ─── User Management ────────────────────────────────────────

@router.get("/users", response_model=List[UserResponse])
async def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    role: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Xem danh sách tất cả người dùng (admin)"""
    query = db.query(User)

    if search:
        query = query.filter(
            (User.full_name.ilike(f"%{search}%")) |
            (User.email.ilike(f"%{search}%"))
        )
    if role:
        query = query.filter(User.role == role)

    return query.order_by(User.created_at.desc()).offset(skip).limit(limit).all()


@router.put("/users/{user_id}/toggle-active")
async def toggle_user_active(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Khóa hoặc mở khóa tài khoản người dùng (admin)"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Không thể khóa chính mình")

    if user.role == "admin":
        raise HTTPException(status_code=400, detail="Không thể khóa tài khoản admin khác")

    user.is_active = not user.is_active
    db.commit()

    return {
        "user_id": user.id,
        "email": user.email,
        "is_active": user.is_active,
        "message": f"Tài khoản đã được {'mở khóa' if user.is_active else 'khóa'}",
    }


# ─── Content Moderation ─────────────────────────────────────

@router.delete("/reviews/{review_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_review(
    review_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Xóa bình luận vi phạm (admin)"""
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá")

    # Update location rating after deletion
    location_id = review.location_id
    db.delete(review)
    db.commit()

    # Recalculate rating
    from ..services.location_service import LocationService
    LocationService.update_location_rating(db, location_id)

    return None


@router.get("/reviews")
async def admin_list_reviews(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Xem tất cả đánh giá để duyệt (admin)"""
    reviews = db.query(Review).order_by(Review.created_at.desc()).offset(skip).limit(limit).all()
    return [
        {
            "id": r.id,
            "user_id": r.user_id,
            "location_id": r.location_id,
            "rating": r.rating,
            "comment": r.comment,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in reviews
    ]


# ─── Statistics ──────────────────────────────────────────────

@router.get("/stats")
async def get_system_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Thống kê tổng quan hệ thống (admin)"""
    total_users = db.query(func.count(User.id)).scalar()
    active_users = db.query(func.count(User.id)).filter(User.is_active == True).scalar()
    total_locations = db.query(func.count(Location.id)).scalar()
    total_reviews = db.query(func.count(Review.id)).scalar()
    total_itineraries = db.query(func.count(Itinerary.id)).scalar()
    avg_rating = db.query(func.avg(Review.rating)).scalar()

    # Locations by category
    category_stats = db.query(
        Location.category,
        func.count(Location.id)
    ).group_by(Location.category).all()

    return {
        "users": {
            "total": total_users,
            "active": active_users,
            "inactive": total_users - active_users,
        },
        "locations": {
            "total": total_locations,
            "by_category": {cat: count for cat, count in category_stats},
        },
        "reviews": {
            "total": total_reviews,
            "average_rating": round(float(avg_rating), 2) if avg_rating else 0,
        },
        "itineraries": {
            "total": total_itineraries,
        },
    }
