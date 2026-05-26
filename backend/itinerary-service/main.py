from typing import List
from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from models import get_db, Itinerary, ItineraryDay, ItineraryActivity
from helpers import (
    CurrentUser,
    get_current_user,
    _haversine,
    _get_itinerary,
    _get_day,
    _parse_time
)
from schemas import (
    ActivityCreate,
    ActivityUpdate,
    ActivityResponse,
    DayCreate,
    DayUpdate,
    DayResponse,
    ItineraryCreate,
    ItineraryUpdate,
    ItineraryResponse
)

# Cấu Hình Ứng Dụng FastAPI
app = FastAPI(title="TRAWiMe Itinerary Service", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

@app.get("/health")
def health():
    return {"status": "healthy", "service": "itinerary-service"}

@app.get("/api/itineraries")
def get_itineraries(
    skip: int = 0,
    limit: int = 20,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Lấy danh sách các lịch trình cá nhân của người dùng đang đăng nhập
    its = db.query(Itinerary).filter(Itinerary.user_id == current.id) \
        .order_by(Itinerary.created_at.desc()).offset(skip).limit(limit).all()
    return [ItineraryResponse.from_orm_custom(it) for it in its]

@app.get("/api/itineraries/{itinerary_id}")
def get_itinerary(
    itinerary_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Lấy thông tin chi tiết một lịch trình bao gồm các ngày và hoạt động con
    it = _get_itinerary(db, itinerary_id, current.id)
    return ItineraryResponse.from_orm_custom(it)

@app.post("/api/itineraries", status_code=201)
def create_itinerary(
    data: ItineraryCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Tạo mới một lịch trình du lịch trống
    it = Itinerary(user_id=current.id, **data.model_dump())
    db.add(it)
    db.commit()
    db.refresh(it)
    return ItineraryResponse.from_orm_custom(it)

@app.put("/api/itineraries/{itinerary_id}")
def update_itinerary(
    itinerary_id: int,
    data: ItineraryUpdate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Cập nhật các thông tin tổng quan của lịch trình như tiêu đề, mô tả, mốc ngày
    it = _get_itinerary(db, itinerary_id, current.id)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(it, k, v)
    db.commit()
    db.refresh(it)
    return ItineraryResponse.from_orm_custom(it)

@app.delete("/api/itineraries/{itinerary_id}", status_code=204)
def delete_itinerary(
    itinerary_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Xóa bỏ lịch trình: các ngày con và hoạt động con sẽ bị xóa hàng loạt nhờ Cascade delete
    it = _get_itinerary(db, itinerary_id, current.id)
    db.delete(it)
    db.commit()

@app.post("/api/itineraries/{itinerary_id}/days", status_code=201)
def add_day(
    itinerary_id: int,
    day: DayCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Thêm một ngày cụ thể vào lịch trình ví dụ Ngày 1, Ngày 2
    _get_itinerary(db, itinerary_id, current.id)
    acts = day.activities or []
    new_day = ItineraryDay(itinerary_id=itinerary_id, **day.model_dump(exclude={"activities"}))
    db.add(new_day)
    db.flush()
    # Thêm kèm danh sách hoạt động con nếu client truyền mảng sẵn
    for act in acts:
        data = act.model_dump()
        data["start_time"] = _parse_time(data.get("start_time"))
        data["end_time"] = _parse_time(data.get("end_time"))
        db.add(ItineraryActivity(day_id=new_day.id, **data))
    db.commit()
    db.refresh(new_day)
    return DayResponse.from_orm_custom(new_day)

@app.put("/api/itineraries/{itinerary_id}/days/{day_id}")
def update_day(
    itinerary_id: int,
    day_id: int,
    data: DayUpdate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Cập nhật thông tin chi tiết một ngày
    _get_itinerary(db, itinerary_id, current.id)
    day = _get_day(db, itinerary_id, day_id)
    for k, v in data.model_dump(exclude_unset=True).items():
        setattr(day, k, v)
    db.commit()
    db.refresh(day)
    return DayResponse.from_orm_custom(day)

@app.delete("/api/itineraries/{itinerary_id}/days/{day_id}", status_code=204)
def delete_day(
    itinerary_id: int,
    day_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Xóa bỏ một ngày khỏi lịch trình
    _get_itinerary(db, itinerary_id, current.id)
    day = _get_day(db, itinerary_id, day_id)
    db.delete(day)
    db.commit()

@app.post("/api/itineraries/{itinerary_id}/days/{day_id}/activities", status_code=201)
def add_activity(
    itinerary_id: int,
    day_id: int,
    activity: ActivityCreate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Thêm một hoạt động chi tiết như điểm tham quan, ăn uống vào ngày chỉ định
    _get_itinerary(db, itinerary_id, current.id)
    _get_day(db, itinerary_id, day_id)
    data = activity.model_dump()
    data["start_time"] = _parse_time(data.get("start_time"))
    data["end_time"] = _parse_time(data.get("end_time"))
    act = ItineraryActivity(day_id=day_id, **data)
    db.add(act)
    db.commit()
    db.refresh(act)
    return ActivityResponse.from_orm_custom(act)

@app.put("/api/itineraries/{itinerary_id}/days/{day_id}/activities/{activity_id}")
def update_activity(
    itinerary_id: int,
    day_id: int,
    activity_id: int,
    data: ActivityUpdate,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Cập nhật chi tiết thông tin hoặc đổi thứ tự sắp xếp của hoạt động
    _get_itinerary(db, itinerary_id, current.id)
    act = db.query(ItineraryActivity).filter(
        ItineraryActivity.id == activity_id, ItineraryActivity.day_id == day_id
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Không tìm thấy hoạt động yêu cầu")
    upd = data.model_dump(exclude_unset=True)
    if "start_time" in upd:
        upd["start_time"] = _parse_time(upd["start_time"])
    if "end_time" in upd:
        upd["end_time"] = _parse_time(upd["end_time"])
    for k, v in upd.items():
        setattr(act, k, v)
    db.commit()
    db.refresh(act)
    return ActivityResponse.from_orm_custom(act)

@app.delete("/api/itineraries/{itinerary_id}/days/{day_id}/activities/{activity_id}", status_code=204)
def delete_activity(
    itinerary_id: int,
    day_id: int,
    activity_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Xóa bỏ một hoạt động khỏi ngày của lịch trình
    _get_itinerary(db, itinerary_id, current.id)
    act = db.query(ItineraryActivity).filter(
        ItineraryActivity.id == activity_id, ItineraryActivity.day_id == day_id
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Không tìm thấy hoạt động")
    db.delete(act)
    db.commit()

@app.get("/api/itineraries/{itinerary_id}/days/{day_id}/route")
def get_day_route(
    itinerary_id: int,
    day_id: int,
    user_lat: float = Query(..., description="Vĩ độ hiện tại của người dùng"),
    user_lng: float = Query(..., description="Kinh độ hiện tại của người dùng"),
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # API tối ưu hóa lộ trình di chuyển cho các địa điểm trong ngày
    # Sử dụng thuật toán tham lam Láng giềng gần nhất bắt đầu từ vị trí GPS hiện tại của người dùng
    # Hàm tính toán khoảng cách Haversine và trả về mảng điểm dừng đã sắp xếp kèm điểm waypoints chỉ đường
    _get_itinerary(db, itinerary_id, current.id)
    day = _get_day(db, itinerary_id, day_id)

    # Lọc ra các hoạt động có gắn tọa độ địa lý rõ ràng
    geo_acts = [a for a in day.activities if a.location_lat and a.location_lng]
    # Tách riêng các hoạt động không có tọa độ để tránh lỗi tính toán hình học
    no_geo_acts = [a for a in day.activities if not (a.location_lat and a.location_lng)]

    # Sắp xếp Láng giềng gần nhất
    sorted_acts = []
    current_lat, current_lng = user_lat, user_lng
    remaining = list(geo_acts)

    while remaining:
        # Tìm địa điểm có khoảng cách Haversine gần nhất với điểm hiện tại
        nearest = min(remaining, key=lambda a: _haversine(current_lat, current_lng, a.location_lat, a.location_lng))
        dist = _haversine(current_lat, current_lng, nearest.location_lat, nearest.location_lng)
        sorted_acts.append({"activity": nearest, "distance_km": round(dist, 2)})
        
        # Cập nhật điểm hiện tại thành điểm vừa được chọn
        current_lat, current_lng = nearest.location_lat, nearest.location_lng
        remaining.remove(nearest)

    # Đóng gói danh sách chặng đi waypoints phục vụ vẽ tuyến đường
    waypoints = []
    if sorted_acts:
        waypoints = [
            {"lat": a["activity"].location_lat, "lng": a["activity"].location_lng,
             "name": a["activity"].location_name or a["activity"].title,
             "distance_from_prev_km": a["distance_km"]}
            for a in sorted_acts
        ]

    return {
        "user_location": {"lat": user_lat, "lng": user_lng},
        "day_id": day_id,
        "sorted_stops": [
            {
                **ActivityResponse.from_orm_custom(a["activity"]).model_dump(),
                "distance_from_prev_km": a["distance_km"],
            }
            for a in sorted_acts
        ],
        "no_coordinates_stops": [ActivityResponse.from_orm_custom(a).model_dump() for a in no_geo_acts],
        "waypoints": waypoints,
        "total_stops": len(sorted_acts),
    }

if __name__ == "__main__":
    import uvicorn
    # Khởi động dịch vụ itinerary-service trên cổng 8005
    uvicorn.run("main:app", host="0.0.0.0", port=8005, reload=True)
