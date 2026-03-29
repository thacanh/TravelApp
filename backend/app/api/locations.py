from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from ..database import get_db
from ..models.user import User
from ..schemas.location import LocationCreate, LocationUpdate, LocationResponse
from ..services.location_service import LocationService
from ..services.ai_service import AIService
from ..utils.security import get_current_active_user, require_admin

router = APIRouter(prefix="/api/locations", tags=["Locations"])


@router.get("", response_model=List[LocationResponse])
async def get_locations(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    category: Optional[str] = None,
    city: Optional[str] = None,
    search: Optional[str] = None,
    min_rating: Optional[float] = None,
    db: Session = Depends(get_db)
):
    """Lấy danh sách địa điểm du lịch với filter"""
    locations = LocationService.get_locations(
        db=db,
        skip=skip,
        limit=limit,
        category=category,
        city=city,
        search=search,
        min_rating=min_rating
    )
    return locations


@router.get("/nearby", response_model=List[LocationResponse])
async def get_nearby_locations(
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_km: float = Query(50, ge=1, le=500),
    db: Session = Depends(get_db)
):
    """Lấy địa điểm gần vị trí hiện tại"""
    locations = LocationService.get_nearby_locations(
        db=db,
        latitude=latitude,
        longitude=longitude,
        radius_km=radius_km
    )
    return locations


@router.get("/{location_id}", response_model=LocationResponse)
async def get_location(location_id: int, db: Session = Depends(get_db)):
    """Lấy chi tiết địa điểm"""
    location = LocationService.get_location(db, location_id)
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy địa điểm"
        )
    return location


@router.post("", response_model=LocationResponse, status_code=status.HTTP_201_CREATED)
async def create_location(
    location: LocationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Tạo địa điểm mới (chỉ admin) — tự động tạo embedding"""
    new_location = LocationService.create_location(db, location)
    # Auto-generate embedding for semantic search
    await AIService.generate_location_embedding(db, new_location)
    return new_location


@router.put("/{location_id}", response_model=LocationResponse)
async def update_location(
    location_id: int,
    location_update: LocationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Cập nhật địa điểm (chỉ admin) — tự động cập nhật embedding"""
    location = LocationService.update_location(db, location_id, location_update)
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy địa điểm"
        )
    # Re-generate embedding if description or name changed
    if location_update.name or location_update.description:
        await AIService.generate_location_embedding(db, location)
    return location


@router.delete("/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_location(
    location_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin)
):
    """Xóa địa điểm (chỉ admin)"""
    success = LocationService.delete_location(db, location_id)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy địa điểm"
        )
    return None
