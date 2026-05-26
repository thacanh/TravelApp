import os
import sys
sys.path.insert(0, "/app")

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session

# Import các mô-đun nội bộ sau khi đã được tách
from models import get_db, User, Favorite, settings
from helpers import CurrentUser, get_current_user, _save_file, pwd_context
from schemas import UserResponse, UserUpdate, ChangePasswordRequest

app = FastAPI(title="TRAWIME User Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

# Gắn kết thư mục chứa tệp tải lên làm thư mục tĩnh
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

@app.get("/health")
def health(): 
    # API kiểm tra sức khỏe của user-service
    return {"status": "healthy", "service": "user-service"}

@app.get("/api/users/profile", response_model=UserResponse)
def get_profile(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API lấy hồ sơ người dùng đang đăng nhập
    user = db.query(User).filter(User.id == current.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User khong ton tai")
    return user

@app.put("/api/users/profile", response_model=UserResponse)
def update_profile(data: UserUpdate, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API cập nhật hồ sơ cá nhân: họ tên, số điện thoại, email
    user = db.query(User).filter(User.id == current.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User khong ton tai")
    update_data = data.model_dump(exclude_unset=True)
    if "email" in update_data and update_data["email"] != user.email:
        if db.query(User).filter(User.email == update_data["email"]).first():
            raise HTTPException(status_code=400, detail="Email nay da duoc su dung")
    for k, v in update_data.items():
        setattr(user, k, v)
    db.commit()
    db.refresh(user)
    return user

@app.put("/api/users/change-password")
def change_password(req: ChangePasswordRequest, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API đổi mật khẩu cá nhân, kiểm tra mật khẩu cũ bằng Bcrypt
    user = db.query(User).filter(User.id == current.id).first()
    if not user or not pwd_context.verify(req.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Mat khau hien tai khong dung")
    if len(req.new_password) < 6:
        raise HTTPException(status_code=400, detail="Mat khau moi phai co do dai tu 6 ky tu tro len")
    user.password_hash = pwd_context.hash(req.new_password)
    db.commit()
    return {"message": "Doi mat khau thanh cong"}

@app.post("/api/users/avatar", response_model=UserResponse)
async def upload_avatar(file: UploadFile = File(...), current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API tải lên ảnh đại diện lên ổ đĩa cục bộ và cập nhật liên kết URL vào DB
    user = db.query(User).filter(User.id == current.id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User khong ton tai")
    relative_path = _save_file(file, "avatars")
    user.avatar_url = f"{settings.BASE_URL}/uploads/{relative_path}"
    db.commit()
    db.refresh(user)
    return user

@app.post("/api/users/favorites/{location_id}")
def add_favorite(location_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API thêm địa điểm vào danh sách yêu thích của người dùng
    fav = db.query(Favorite).filter_by(user_id=current.id, location_id=location_id).first()
    if not fav:
        fav = Favorite(user_id=current.id, location_id=location_id)
        db.add(fav)
        db.commit()
    return {"message": "Da them vao muc yeu thich", "location_id": location_id}

@app.delete("/api/users/favorites/{location_id}", status_code=204)
def remove_favorite(location_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API xóa địa điểm khỏi danh sách yêu thích
    fav = db.query(Favorite).filter_by(user_id=current.id, location_id=location_id).first()
    if fav:
        db.delete(fav)
        db.commit()
    return None

@app.get("/api/users/favorites")
def get_favorites(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # API lấy danh sách ID các địa điểm đã yêu thích
    return [fav.location_id for fav in db.query(Favorite).filter_by(user_id=current.id).all()]

if __name__ == "__main__":
    import uvicorn
    # Khởi động máy chủ uvicorn tại cổng cục bộ 8002
    uvicorn.run("main:app", host="0.0.0.0", port=8002, reload=True)
