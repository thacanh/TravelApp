from typing import List
from datetime import datetime
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from models import get_db, Category, Location, ChatSession, ChatMessage
from helpers import (
    CurrentUser,
    get_current_user,
    require_admin,
    _gemini_available,
    _mock_recommend,
    _mock_chat,
    _gemini_chat,
    _recommend_by_embedding,
    _embed_location,
    logger
)
from schemas import (
    AIRecommendRequest,
    AIRecommendResponse,
    ChatMessageRequest,
    ChatResponse,
    SendMessageRequest,
    ChatMessageResponse,
    ChatSessionSummary,
    ChatSessionResponse
)

# Cấu Hình Ứng Dụng FastAPI
app = FastAPI(title="TRAWIME AI Service", version="2.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

@app.get("/health")
def health():
    # Kiểm tra trạng thái hoạt động của dịch vụ và tính khả dụng của Gemini API
    return {"status": "healthy", "service": "ai-service", "gemini_available": _gemini_available}

@app.post("/api/ai/recommend", response_model=AIRecommendResponse)
async def get_recommendations(
    req: AIRecommendRequest,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # API gợi ý địa điểm thông minh bằng Vector Search và Cosine Similarity
    if not _gemini_available:
        return await _mock_recommend(req.preferences, req.category)

    # Lấy toàn bộ địa điểm có sẵn trong hệ thống
    query = db.query(Location)
    if req.category:
        # Thực hiện lọc theo danh mục trước để giảm tải tính toán
        query = query.filter(Location.categories.any(Category.slug == req.category))
    locations = query.all()

    if not locations:
        return {"recommendations": [], "explanation": "Hệ thống chưa có dữ liệu địa điểm du lịch nào."}

    try:
        # Thực hiện so khớp vector và lấy ra 5 điểm phù hợp nhất
        results = _recommend_by_embedding(req.preferences, locations, top_k=5)

        recommendations = []
        for score, loc in results:
            recommendations.append({
                "location_id": loc.id,
                "name": loc.name,
                "categories": [{"slug": c.slug, "name": c.name} for c in (loc.categories or [])],
                "city": loc.city,
                "rating": 0,
                "match_score": round(score, 4),
                "reason": f"Mức độ tương thích với yêu cầu của bạn: {round(score * 100, 1)}%",
                "images": loc.images or [],
            })

        # Cảnh báo nếu admin chưa sinh vector embeddings cho cơ sở dữ liệu
        has_embeddings = any(loc.description_embedding for _, loc in results)
        if not has_embeddings:
            explanation = "Hệ thống đang chạy giả lập. Yêu cầu Admin chạy API tạo dữ liệu vector đặc trưng."
        else:
            explanation = f"Trí tuệ nhân tạo (AI) đã tìm ra {len(recommendations)} địa danh phù hợp nhất với mô tả của bạn."

        return {"recommendations": recommendations, "explanation": explanation}
    except Exception as e:
        logger.error(f"Lỗi tính toán tìm kiếm vector: {e}")
        return await _mock_recommend(req.preferences, req.category)

@app.post("/api/ai/chat", response_model=ChatResponse)
async def chat_with_ai(
    message: ChatMessageRequest,
    current: CurrentUser = Depends(get_current_user)
):
    # API gọi chatbot một lượt duy nhất không lưu lịch sử hội thoại
    if not _gemini_available:
        return await _mock_chat(message.message)
    try:
        return await _gemini_chat(message.message)
    except Exception as e:
        logger.error(f"Lỗi kết nối Gemini Chat: {e}")
        return await _mock_chat(message.message)

@app.post("/api/ai/generate-embeddings")
async def generate_embeddings(
    current: CurrentUser = Depends(require_admin),
    db: Session = Depends(get_db)
):
    # Admin API: Duyệt qua toàn bộ địa điểm chưa có vector đặc trưng và sinh hàng loạt
    if not _gemini_available:
        raise HTTPException(status_code=503, detail="Gemini Cloud API hiện không khả dụng")

    # Lấy các địa điểm chưa có vector embedding
    locations = db.query(Location).filter(Location.description_embedding == None).all()
    if not locations:
        return {"status": "ok", "updated": 0, "message": "Tất cả địa điểm trong hệ thống đã được sinh vector embedding đầy đủ."}

    updated = 0
    errors = 0
    for loc in locations:
        try:
            loc.description_embedding = _embed_location(loc)
            updated += 1
        except Exception as e:
            logger.error(f"Lỗi tạo vector cho địa điểm {loc.id}: {e}")
            errors += 1

    db.commit()
    return {
        "status": "ok",
        "updated": updated,
        "errors": errors,
        "message": f"Đã sinh thành công vector embedding cho {updated} địa điểm du lịch."
    }

@app.get("/api/ai/analyze-preferences")
async def analyze_preferences(current: CurrentUser = Depends(get_current_user)):
    # Chức năng mở rộng tương lai phân tích hành vi yêu thích của người dùng
    return {"preferred_categories": [], "preferred_cities": [], "average_rating_given": 0, "total_visits": 0}

@app.post("/internal/embed-location/{location_id}")
def embed_single_location(location_id: int, db: Session = Depends(get_db)):
    # API Nội bộ: Gọi bởi location-service để cập nhật vector embedding cho địa điểm được thêm mới hoặc sửa đổi
    if not _gemini_available:
        return {"status": "skipped", "reason": "Dịch vụ Gemini Cloud ngoại tuyến"}
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc:
        raise HTTPException(status_code=404, detail="Không tìm thấy địa điểm du lịch")
    try:
        loc.description_embedding = _embed_location(loc)
        db.commit()
        return {"status": "ok", "location_id": location_id}
    except Exception as e:
        logger.error(f"Lỗi tạo vector thời gian thực cho địa điểm {location_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/chat/sessions", response_model=List[ChatSessionSummary])
def list_sessions(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # Lấy danh sách các phiên trò chuyện cũ của tài khoản đang đăng nhập
    return db.query(ChatSession).filter(ChatSession.user_id == current.id).order_by(ChatSession.updated_at.desc()).all()

@app.get("/api/chat/sessions/{session_id}", response_model=ChatSessionResponse)
def get_session(
    session_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Lấy toàn bộ lịch sử tin nhắn của một phiên trò chuyện cụ thể
    session = db.query(ChatSession).filter(ChatSession.id == session_id, ChatSession.user_id == current.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch sử cuộc trò chuyện")
    return session

@app.post("/api/chat/send", response_model=ChatMessageResponse)
async def send_message(
    body: SendMessageRequest,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Gửi tin nhắn mới đến chatbot lưu lịch sử và lấy phản hồi từ Gemini AI
    if body.session_id:
        session = db.query(ChatSession).filter(ChatSession.id == body.session_id, ChatSession.user_id == current.id).first()
        if not session:
            raise HTTPException(status_code=404, detail="Không tìm thấy lịch sử cuộc trò chuyện")
    else:
        auto_title = body.message[:60] + ("..." if len(body.message) > 60 else "")
        session = ChatSession(user_id=current.id, title=auto_title)
        db.add(session)
        db.flush()

    # Lưu tin nhắn của User
    user_msg = ChatMessage(session_id=session.id, role="user", content=body.message)
    db.add(user_msg)

    # Đóng gói lịch sử gửi kèm
    history = []
    for msg in session.messages:
        gemini_role = "model" if msg.role == "assistant" else "user"
        history.append({"role": gemini_role, "content": msg.content})

    if _gemini_available:
        try:
            ai_result = await _gemini_chat(body.message, history=history)
        except Exception as e:
            logger.error(f"Lỗi xử lý sinh nội dung AI: {e}")
            ai_result = await _mock_chat(body.message)
    else:
        ai_result = await _mock_chat(body.message)

    ai_text = ai_result.get("response", "Hệ thống bận tôi chưa thể trả lời lúc này.")

    # Lưu tin nhắn phản hồi của AI chatbot
    ai_msg = ChatMessage(session_id=session.id, role="assistant", content=ai_text)
    db.add(ai_msg)
    
    # Cập nhật thời điểm tương tác mới nhất
    session.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(ai_msg)
    return ai_msg

@app.delete("/api/chat/sessions/{session_id}", status_code=204)
def delete_session(
    session_id: int,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Xóa bỏ một phiên trò chuyện
    session = db.query(ChatSession).filter(ChatSession.id == session_id, ChatSession.user_id == current.id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Không tìm thấy lịch sử cuộc trò chuyện")
    db.delete(session)
    db.commit()

if __name__ == "__main__":
    import uvicorn
    # Khởi động Web Server FastAPI chạy trên cổng 8006
    uvicorn.run("main:app", host="0.0.0.0", port=8006, reload=True)
