from datetime import datetime, timedelta
from typing import Optional
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from models import User, settings, get_db

# Cấu hình Passlib sử dụng thuật toán băm Bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
# Sử dụng OAuth2 để đọc Token tự động từ header Authorization
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")

def verify_password(plain: str, hashed: str) -> bool:
    # So khớp mật khẩu thô với chuỗi băm Bcrypt
    return pwd_context.verify(plain, hashed)

def get_password_hash(password: str) -> str:
    # Băm mật khẩu bằng thuật toán Bcrypt
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    # Tạo mã thông báo JWT chứa payload và ký bằng Secret Key
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    # Giải mã Token JWT từ header và tìm kiếm thông tin người dùng tương ứng trong cơ sở dữ liệu (DB)
    exc = HTTPException(
        status_code=401,
        detail="Mã xác thực không hợp lệ hoặc đã hết hạn",
        headers={"WWW-Authenticate": "Bearer"}
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if not email:
            raise exc
    except JWTError:
        raise exc
    
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise exc
    return user
