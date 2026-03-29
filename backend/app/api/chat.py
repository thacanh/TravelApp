from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models.user import User
from ..models.chat import ChatSession, ChatMessage
from ..schemas.chat import (
    SendMessageRequest, ChatSessionSummary, ChatSessionResponse, ChatMessageResponse
)
from ..utils.security import get_current_active_user
from ..services.ai_service import AIService

router = APIRouter(prefix="/api/chat", tags=["AI Chat Sessions"])


@router.get("/sessions", response_model=List[ChatSessionSummary])
async def list_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Danh sách phiên trò chuyện của người dùng"""
    sessions = (
        db.query(ChatSession)
        .filter(ChatSession.user_id == current_user.id)
        .order_by(ChatSession.updated_at.desc())
        .all()
    )
    return sessions


@router.get("/sessions/{session_id}", response_model=ChatSessionResponse)
async def get_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Chi tiết phiên trò chuyện (kèm toàn bộ tin nhắn)"""
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.user_id == current_user.id)
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiên trò chuyện")
    return session


@router.post("/send", response_model=ChatMessageResponse)
async def send_message(
    body: SendMessageRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """
    Gửi tin nhắn đến AI và lưu lịch sử vào DB.
    - Nếu session_id=None → tạo phiên mới tự động.
    - Tin nhắn của user và phản hồi của AI đều được lưu.
    """
    # 1. Lấy / tạo session
    if body.session_id:
        session = (
            db.query(ChatSession)
            .filter(ChatSession.id == body.session_id, ChatSession.user_id == current_user.id)
            .first()
        )
        if not session:
            raise HTTPException(status_code=404, detail="Không tìm thấy phiên trò chuyện")
    else:
        # Tạo tiêu đề tự động từ 60 ký tự đầu của tin nhắn
        auto_title = body.message[:60] + ("..." if len(body.message) > 60 else "")
        session = ChatSession(user_id=current_user.id, title=auto_title)
        db.add(session)
        db.flush()  # lấy session.id ngay

    # 2. Lưu tin nhắn của user
    user_msg = ChatMessage(session_id=session.id, role="user", content=body.message)
    db.add(user_msg)

    # 3. Xây dựng context từ lịch sử để AI hiểu ngữ cảnh
    history = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session.id)
        .order_by(ChatMessage.created_at.desc())
        .limit(10)  # 10 tin nhắn gần nhất
        .all()
    )
    context = {
        "history": [{"role": m.role, "content": m.content} for m in reversed(history)]
    }

    # 4. Gọi AI
    ai_result = await AIService.chat_response(message=body.message, context=context)
    ai_text = ai_result.get("response", "Xin lỗi, tôi không thể trả lời lúc này.")

    # 5. Lưu phản hồi AI
    ai_msg = ChatMessage(session_id=session.id, role="assistant", content=ai_text)
    db.add(ai_msg)

    # 6. Cập nhật timestamp session
    from datetime import datetime
    session.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(ai_msg)
    return ai_msg


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(
    session_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Xóa phiên trò chuyện"""
    session = (
        db.query(ChatSession)
        .filter(ChatSession.id == session_id, ChatSession.user_id == current_user.id)
        .first()
    )
    if not session:
        raise HTTPException(status_code=404, detail="Không tìm thấy phiên trò chuyện")
    db.delete(session)
    db.commit()
    return None
