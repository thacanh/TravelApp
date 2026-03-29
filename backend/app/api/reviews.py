from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.user import User
from ..models.review import Review
from ..models.location import Location
from ..schemas.review import ReviewCreate, ReviewUpdate, ReviewResponse
from ..utils.security import get_current_active_user
from ..services.location_service import LocationService
from ..utils.file_upload import save_multiple_files

router = APIRouter(prefix="/api/reviews", tags=["Reviews"])


@router.post("", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def create_review(
    review: ReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Viết đánh giá địa điểm"""
    # Verify location exists
    location = db.query(Location).filter(Location.id == review.location_id).first()
    if not location:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy địa điểm"
        )

    # Create review (multiple reviews per user allowed – mỗi lần ghé là một lần review)
    new_review = Review(
        user_id=current_user.id,
        **review.model_dump()
    )

    db.add(new_review)
    db.commit()
    db.refresh(new_review)

    # Update location rating
    LocationService.update_location_rating(db, review.location_id)

    return new_review


@router.post("/upload-photos")
async def upload_review_photos(
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_active_user)
):
    """Upload ảnh đánh giá/check-in"""
    file_paths = await save_multiple_files(files, "reviews")
    return {"photos": file_paths}


@router.get("/location/{location_id}", response_model=List[ReviewResponse])
async def get_location_reviews(
    location_id: int,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """Lấy danh sách đánh giá của địa điểm"""
    reviews = db.query(Review).filter(
        Review.location_id == location_id
    ).order_by(Review.created_at.desc()).offset(skip).limit(limit).all()
    
    return reviews


@router.put("/{review_id}", response_model=ReviewResponse)
async def update_review(
    review_id: int,
    review_update: ReviewUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Cập nhật đánh giá"""
    review = db.query(Review).filter(
        Review.id == review_id,
        Review.user_id == current_user.id
    ).first()
    
    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đánh giá"
        )
    
    update_data = review_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(review, key, value)
    
    db.commit()
    db.refresh(review)
    
    # Update location rating
    LocationService.update_location_rating(db, review.location_id)
    
    return review


@router.delete("/{review_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_review(
    review_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Xóa đánh giá"""
    review = db.query(Review).filter(
        Review.id == review_id,
        Review.user_id == current_user.id
    ).first()
    
    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không tìm thấy đánh giá"
        )
    
    location_id = review.location_id
    db.delete(review)
    db.commit()
    
    # Update location rating
    LocationService.update_location_rating(db, location_id)
    
    return None
