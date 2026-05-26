import os
import shutil
from uuid import uuid4
from typing import List
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
import httpx

from models import settings, Review, get_db
from helpers import CurrentUser, get_current_user, _enrich_review
from schemas import ReviewCreate, ReviewUpdate

# Phần mở rộng ảnh checkin được phép tải lên
ALLOWED_EXT = {"png", "jpg", "jpeg", "gif", "webp"}

# Khởi tạo FastAPI
app = FastAPI(title="TRAWiMe Review Service", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# Gắn thư mục tĩnh để hiển thị ảnh checkin tải lên ở route uploads
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

@app.get("/health")
def health():
    return {"status": "healthy", "service": "review-service"}

@app.post("/api/reviews", status_code=201)
def create_review(
    review: ReviewCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # API tạo đánh giá mới:
    # 1. Kiểm tra họ tên thật của người dùng từ user-service bằng cuộc gọi HTTP ngắn
    # 2. Caching thông tin họ tên và email trực tiếp vào bảng reviews để tránh truy vấn N+1
    # 3. Thêm mới đánh giá và lưu vào database
    user_name = current.name or current.email
    try:
        # Gọi HTTP liên dịch vụ lấy tên người dùng hiện tại
        with httpx.Client(timeout=3) as client:
            resp = client.get(
                f"{settings.USER_SERVICE_URL}/api/users/profile",
                headers={
                    "X-User-Id": str(current.id),
                    "X-User-Role": current.role,
                    "X-User-Email": current.email,
                },
            )
            if resp.status_code == 200:
                user_name = resp.json().get("full_name", user_name)
    except Exception:
        # Giữ nguyên email nếu dịch vụ hồ sơ bận
        pass

    new_review = Review(
        user_id=current.id,
        user_name=user_name,
        user_email=current.email,
        **review.model_dump(),
    )
    db.add(new_review)
    db.commit()
    db.refresh(new_review)
    return _enrich_review(new_review)

@app.post("/api/reviews/upload-photos")
async def upload_photos(
    files: List[UploadFile] = File(...),
    current: CurrentUser = Depends(get_current_user)
):
    # API tải lên nhiều ảnh checkin đồng thời:
    # Lưu trữ các hình ảnh vào thư mục uploads/reviews và trả về danh sách liên kết URL hoàn chỉnh
    paths = []
    for f in files:
        ext = f.filename.rsplit(".", 1)[-1].lower()
        if ext not in ALLOWED_EXT:
            raise HTTPException(status_code=400, detail="Định dạng tệp tin hình ảnh không được phép")
        dest = os.path.join(settings.UPLOAD_DIR, "reviews")
        os.makedirs(dest, exist_ok=True)
        fname = f"{uuid4()}.{ext}"
        with open(os.path.join(dest, fname), "wb") as buf:
            shutil.copyfileobj(f.file, buf)
        paths.append(f"{settings.BASE_URL}/uploads/reviews/{fname}")
    return {"photos": paths}

@app.get("/api/reviews/location/{location_id}")
def get_location_reviews(
    location_id: int,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    # Lấy danh sách toàn bộ đánh giá của một địa điểm du lịch sắp xếp theo thời gian mới nhất
    reviews = (
        db.query(Review)
        .filter(Review.location_id == location_id)
        .order_by(Review.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich_review(r) for r in reviews]

@app.get("/api/checkins")
def get_my_checkins(
    skip: int = 0,
    limit: int = 20,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Lấy danh sách lịch sử tất cả các điểm checkin/đánh giá của chính người dùng đang đăng nhập
    reviews = (
        db.query(Review)
        .filter(Review.user_id == current.id)
        .order_by(Review.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich_review(r) for r in reviews]

@app.post("/api/checkins", status_code=201)
def create_checkin(
    review: ReviewCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Bí danh của API tạo đánh giá: Checkin và Review sử dụng chung một luồng xử lý
    return create_review(review, current, db)

@app.put("/api/reviews/{review_id}")
def update_review(
    review_id: int,
    data: ReviewUpdate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # API sửa đổi đánh giá cũ: Chỉ cho phép chính chủ sở hữu chỉnh sửa
    review = db.query(Review).filter(Review.id == review_id, Review.user_id == current.id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá tương ứng hoặc bạn không có quyền sửa")
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(review, k, v)
    db.commit()
    db.refresh(review)
    return _enrich_review(review)

@app.delete("/api/reviews/{review_id}", status_code=204)
def delete_review(
    review_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # API xóa bỏ đánh giá: Chỉ cho phép chính chủ sở hữu xóa
    review = db.query(Review).filter(Review.id == review_id, Review.user_id == current.id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Không tìm thấy đánh giá tương ứng hoặc bạn không có quyền xóa")
    db.delete(review)
    db.commit()

if __name__ == "__main__":
    import uvicorn
    # Khởi chạy dịch vụ review-service trên cổng 8004
    uvicorn.run("main:app", host="0.0.0.0", port=8004, reload=True)
