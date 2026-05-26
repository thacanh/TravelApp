import math
from typing import Optional
from datetime import time
from fastapi import Header, HTTPException
from sqlalchemy.orm import Session
from models import Itinerary, ItineraryDay

class CurrentUser:
    # Đối tượng lưu thông tin người dùng được giải nén từ header Gateway
    def __init__(self, id: int, role: str):
        self.id = id
        self.role = role

def get_current_user(
    x_user_id: Optional[str] = Header(None),
    x_user_role: Optional[str] = Header(None),
) -> CurrentUser:
    # Đọc thông tin ID và Quyền hạn từ headers của Gateway chuyển xuống
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Thiếu headers xác thực tài khoản")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")

def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Tính khoảng cách hình học vòng lớn (km) giữa hai tọa độ GPS phục vụ thuật toán tối ưu hóa
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

def _get_itinerary(db: Session, itinerary_id: int, user_id: int) -> Itinerary:
    # Tìm kiếm lịch trình trong DB và kiểm duyệt quyền sở hữu tài khoản để bảo mật dữ liệu
    it = db.query(Itinerary).filter(Itinerary.id == itinerary_id, Itinerary.user_id == user_id).first()
    if not it:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch trình du lịch tương ứng")
    return it

def _get_day(db: Session, itinerary_id: int, day_id: int) -> ItineraryDay:
    # Tìm kiếm một ngày trong lịch trình
    day = db.query(ItineraryDay).filter(
        ItineraryDay.id == day_id, ItineraryDay.itinerary_id == itinerary_id
    ).first()
    if not day:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông tin ngày yêu cầu")
    return day

def _parse_time(t_str: Optional[str]) -> Optional[time]:
    # Phân tích chuỗi văn bản HH:MM thành đối tượng time của Python
    if not t_str:
        return None
    try:
        parts = t_str.split(":")
        return time(int(parts[0]), int(parts[1]))
    except Exception:
        return None
