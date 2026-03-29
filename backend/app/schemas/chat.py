from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ──────────── ChatMessage ────────────

class ChatMessageBase(BaseModel):
    role: str   # "user" | "assistant"
    content: str


class ChatMessageCreate(BaseModel):
    content: str  # chỉ cần nội dung, role luôn là "user"


class ChatMessageResponse(ChatMessageBase):
    id: int
    session_id: int
    created_at: datetime

    class Config:
        from_attributes = True


# ──────────── ChatSession ────────────

class ChatSessionCreate(BaseModel):
    title: Optional[str] = None
    first_message: Optional[str] = None  # tự động tạo session từ tin nhắn đầu tiên


class ChatSessionResponse(BaseModel):
    id: int
    user_id: int
    title: Optional[str]
    created_at: datetime
    updated_at: datetime
    messages: List[ChatMessageResponse] = []

    class Config:
        from_attributes = True


class ChatSessionSummary(BaseModel):
    """Dùng cho danh sách (không tải toàn bộ messages)"""
    id: int
    user_id: int
    title: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SendMessageRequest(BaseModel):
    """Gửi tin nhắn vào session (hoặc tạo session mới)"""
    session_id: Optional[int] = None   # None => tạo session mới
    message: str
