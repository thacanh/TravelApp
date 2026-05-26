import os
import shutil
from uuid import uuid4
from typing import Optional
from fastapi import Header, HTTPException, UploadFile
from urllib.parse import unquote
from models import settings

class CurrentUser:
    # Thông tin người dùng giải nén từ headers của Gateway
    def __init__(self, id: int, role: str, email: str = ""):
        self.id = id
        self.role = role
        self.email = email

def get_current_user(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
    x_user_email: Optional[str] = Header(None),
) -> CurrentUser:
    # Trích xuất thông tin tài khoản được gateway gửi qua header HTTP
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Thiếu headers xác thực tài khoản")
    return CurrentUser(
        id=int(x_user_id), 
        role=unquote(x_user_role) if x_user_role else "user", 
        email=unquote(x_user_email) if x_user_email else ""
    )

# Định dạng đuôi ảnh được phép
ALLOWED_EXT = {"png", "jpg", "jpeg", "gif", "webp"}

def _save_file(upload_file: UploadFile, subfolder: str) -> str:
    # Ghi tệp tin ảnh vào ổ đĩa và sinh chuỗi UUID duy nhất cho tên tệp tin
    raw_name = upload_file.filename or ""
    ext = raw_name.rsplit(".", 1)[-1].lower() if "." in raw_name else ""
    if not ext or ext not in ALLOWED_EXT:
        raise HTTPException(
            status_code=400,
            detail=f"Dinh dang file khong duoc chap thuan: '{ext}'. Chi cho phep: {', '.join(ALLOWED_EXT)}"
        )
    dest_dir = os.path.join(settings.UPLOAD_DIR, subfolder)
    os.makedirs(dest_dir, exist_ok=True)
    filename = f"{uuid4()}.{ext}"
    path = os.path.join(dest_dir, filename)
    with open(path, "wb") as f:
        shutil.copyfileobj(upload_file.file, f)
    return os.path.join(subfolder, filename).replace("\\", "/")
