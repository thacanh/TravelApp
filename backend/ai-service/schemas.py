from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

class AIRecommendRequest(BaseModel):
    # Dữ liệu yêu cầu gợi ý địa điểm tương thích
    preferences: str
    category: Optional[str] = None
    budget: Optional[str] = None
    duration: Optional[int] = None

class AIRecommendResponse(BaseModel):
    # Dữ liệu phản hồi danh sách địa điểm gợi ý kèm giải thích từ AI
    recommendations: list
    explanation: str

class ChatMessageRequest(BaseModel):
    # Dữ liệu yêu cầu chat một lượt
    message: str
    context: Optional[dict] = None

class ChatResponse(BaseModel):
    # Dữ liệu phản hồi từ chatbot một lượt
    response: str
    suggestions: List[str] = []

class SendMessageRequest(BaseModel):
    # Dữ liệu gửi tin nhắn trong một phiên chat có lưu lịch sử
    message: str
    session_id: Optional[int] = None

class ChatMessageResponse(BaseModel):
    # Chi tiết tin nhắn trả về từ database
    id: int
    session_id: int
    role: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True

class ChatSessionSummary(BaseModel):
    # Tóm tắt thông tin phiên chat để hiển thị trong danh sách
    id: int
    title: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class ChatSessionResponse(BaseModel):
    # Chi tiết phiên chat kèm toàn bộ các tin nhắn con
    id: int
    title: Optional[str]
    created_at: datetime
    updated_at: datetime
    messages: List[ChatMessageResponse] = []

    class Config:
        from_attributes = True
