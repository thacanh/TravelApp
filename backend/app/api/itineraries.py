from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.user import User
from ..models.itinerary import Itinerary
from ..models.itinerary_detail import ItineraryDay, ItineraryActivity
from ..schemas.itinerary import (
    ItineraryCreate, ItineraryUpdate, ItineraryResponse,
    DayCreate, DayUpdate, DayResponse,
    ActivityCreate, ActivityUpdate, ActivityResponse,
)
from ..utils.security import get_current_active_user

router = APIRouter(prefix="/api/itineraries", tags=["Itineraries"])


# ══════════ Itinerary CRUD ══════════

@router.get("", response_model=List[ItineraryResponse])
async def get_itineraries(
    skip: int = 0, limit: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    return db.query(Itinerary).filter(
        Itinerary.user_id == current_user.id
    ).order_by(Itinerary.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{itinerary_id}", response_model=ItineraryResponse)
async def get_itinerary(
    itinerary_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    return it


@router.post("", response_model=ItineraryResponse, status_code=status.HTTP_201_CREATED)
async def create_itinerary(
    itinerary: ItineraryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    new_it = Itinerary(user_id=current_user.id, **itinerary.model_dump())
    db.add(new_it)
    db.commit()
    db.refresh(new_it)
    return new_it


@router.put("/{itinerary_id}", response_model=ItineraryResponse)
async def update_itinerary(
    itinerary_id: int,
    itinerary_update: ItineraryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    for key, value in itinerary_update.model_dump(exclude_unset=True).items():
        setattr(it, key, value)
    db.commit()
    db.refresh(it)
    return it


@router.delete("/{itinerary_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_itinerary(
    itinerary_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    db.delete(it)
    db.commit()
    return None


# ══════════ Days within Itinerary ══════════

@router.post("/{itinerary_id}/days", response_model=DayResponse, status_code=status.HTTP_201_CREATED)
async def add_day(
    itinerary_id: int,
    day: DayCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Thêm một ngày mới vào lịch trình"""
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")

    # Tách activities ra, tạo ngày trước
    activities_data = day.activities or []
    day_data = day.model_dump(exclude={"activities"})
    new_day = ItineraryDay(itinerary_id=itinerary_id, **day_data)
    db.add(new_day)
    db.flush()

    # Thêm activities nếu có
    for act in activities_data:
        db.add(ItineraryActivity(day_id=new_day.id, **act.model_dump()))

    db.commit()
    db.refresh(new_day)
    return new_day


@router.put("/{itinerary_id}/days/{day_id}", response_model=DayResponse)
async def update_day(
    itinerary_id: int, day_id: int,
    day_update: DayUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Cập nhật thông tin ngày"""
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    day = db.query(ItineraryDay).filter(
        ItineraryDay.id == day_id, ItineraryDay.itinerary_id == itinerary_id
    ).first()
    if not day:
        raise HTTPException(status_code=404, detail="Không tìm thấy ngày")
    for key, value in day_update.model_dump(exclude_unset=True).items():
        setattr(day, key, value)
    db.commit()
    db.refresh(day)
    return day


@router.delete("/{itinerary_id}/days/{day_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_day(
    itinerary_id: int, day_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Xóa một ngày (kèm toàn bộ hoạt động trong ngày đó)"""
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    day = db.query(ItineraryDay).filter(
        ItineraryDay.id == day_id, ItineraryDay.itinerary_id == itinerary_id
    ).first()
    if not day:
        raise HTTPException(status_code=404, detail="Không tìm thấy ngày")
    db.delete(day)
    db.commit()
    return None


# ══════════ Activities within a Day ══════════

@router.post("/{itinerary_id}/days/{day_id}/activities", response_model=ActivityResponse, status_code=status.HTTP_201_CREATED)
async def add_activity(
    itinerary_id: int, day_id: int,
    activity: ActivityCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Thêm hoạt động vào ngày"""
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    day = db.query(ItineraryDay).filter(
        ItineraryDay.id == day_id, ItineraryDay.itinerary_id == itinerary_id
    ).first()
    if not day:
        raise HTTPException(status_code=404, detail="Không tìm thấy ngày")

    new_act = ItineraryActivity(day_id=day_id, **activity.model_dump())
    db.add(new_act)
    db.commit()
    db.refresh(new_act)
    return new_act


@router.put("/{itinerary_id}/days/{day_id}/activities/{activity_id}", response_model=ActivityResponse)
async def update_activity(
    itinerary_id: int, day_id: int, activity_id: int,
    act_update: ActivityUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Cập nhật hoạt động"""
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    act = db.query(ItineraryActivity).filter(
        ItineraryActivity.id == activity_id, ItineraryActivity.day_id == day_id
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Không tìm thấy hoạt động")
    for key, value in act_update.model_dump(exclude_unset=True).items():
        setattr(act, key, value)
    db.commit()
    db.refresh(act)
    return act


@router.delete("/{itinerary_id}/days/{day_id}/activities/{activity_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_activity(
    itinerary_id: int, day_id: int, activity_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Xóa hoạt động"""
    it = db.query(Itinerary).filter(
        Itinerary.id == itinerary_id, Itinerary.user_id == current_user.id
    ).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình")
    act = db.query(ItineraryActivity).filter(
        ItineraryActivity.id == activity_id, ItineraryActivity.day_id == day_id
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Không tìm thấy hoạt động")
    db.delete(act)
    db.commit()
    return None
