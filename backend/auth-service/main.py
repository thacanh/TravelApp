import sys
sys.path.insert(0, "/app")

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

# Import các mô-đun nội bộ sau khi đã được tách
from models import get_db, User
from helpers import get_password_hash, verify_password, create_access_token, get_current_user, settings
from schemas import UserCreate, UserResponse, Token

app = FastAPI(title="TRAWIME Auth Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.get("/health")
def health(): 
    # API kiểm tra sức khỏe của service
    return {"status": "healthy", "service": "auth-service"}

@app.post("/api/auth/register", response_model=UserResponse, status_code=201)
async def register(user: UserCreate, db: Session = Depends(get_db)):
    # API đăng ký tài khoản mới, thực hiện băm mật khẩu bằng Bcrypt
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Dia chi Email nay da duoc dang ky tren he thong")
    new_user = User(
        email=user.email,
        password_hash=get_password_hash(user.password),
        full_name=user.full_name,
        phone=user.phone,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/api/auth/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # API đăng nhập hệ thống, xác thực mật khẩu bằng Bcrypt và cấp phát mã bảo mật JWT Token
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email hoac mat khau khong chinh xac",
                            headers={"WWW-Authenticate": "Bearer"})
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Tai khoan cua ban da bi khoa")
    
    # Cấp token thời hạn 7 ngày
    token = create_access_token(
        data={"sub": user.email, "sub_id": user.id, "role": user.role, "name": user.full_name},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    return {"access_token": token, "token_type": "bearer"}

@app.get("/api/auth/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    # API lấy thông tin cá nhân tương ứng từ token JWT truyền lên
    return current_user

if __name__ == "__main__":
    import uvicorn
    # Khởi động Web Server uvicorn tại cổng 8001
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
