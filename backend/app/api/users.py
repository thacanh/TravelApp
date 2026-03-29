from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from ..database import get_db
from ..models.user import User
from ..schemas.user import UserResponse, UserUpdate
from ..utils.security import get_current_active_user, verify_password, get_password_hash
from ..utils.file_upload import save_upload_file

router = APIRouter(prefix="/api/users", tags=["Users"])


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


@router.get("/profile", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_active_user)):
    """Xem hồ sơ cá nhân"""
    return current_user


@router.put("/profile", response_model=UserResponse)
async def update_profile(
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Cập nhật hồ sơ cá nhân"""
    update_data = user_update.model_dump(exclude_unset=True)
    
    # Check email uniqueness if updating email
    if 'email' in update_data and update_data['email'] != current_user.email:
        existing = db.query(User).filter(User.email == update_data['email']).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email đã được sử dụng"
            )
    
    for key, value in update_data.items():
        setattr(current_user, key, value)
    
    db.commit()
    db.refresh(current_user)
    
    return current_user


@router.put("/change-password")
async def change_password(
    request: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Đổi mật khẩu"""
    if not verify_password(request.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mật khẩu hiện tại không đúng"
        )
    
    if len(request.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Mật khẩu mới phải có ít nhất 6 ký tự"
        )
    
    current_user.password_hash = get_password_hash(request.new_password)
    db.commit()
    
    return {"message": "Đổi mật khẩu thành công"}


@router.post("/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Upload ảnh đại diện"""
    # Save file
    file_path = await save_upload_file(file, "avatars")
    
    # Update user avatar
    current_user.avatar_url = file_path
    db.commit()
    db.refresh(current_user)
    
    return current_user

