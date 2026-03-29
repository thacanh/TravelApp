from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.user import User
from ..schemas.ai import AIRecommendRequest, AIRecommendResponse, ChatMessage, ChatResponse
from ..utils.security import get_current_active_user, require_admin
from ..services.ai_service import AIService

router = APIRouter(prefix="/api/ai", tags=["AI Services"])


@router.post("/recommend", response_model=AIRecommendResponse)
async def get_recommendations(
    request: AIRecommendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Nhận gợi ý địa điểm từ AI dựa trên sở thích (semantic embedding search)"""
    result = await AIService.get_recommendations(
        db=db,
        preferences=request.preferences,
        category=request.category,
        budget=request.budget,
        duration=request.duration,
    )
    return result


@router.post("/chat", response_model=ChatResponse)
async def chat_with_ai(
    message: ChatMessage,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Chat với AI chatbot (Gemini 2.0 Flash)"""
    result = await AIService.chat_response(
        message=message.message,
        context=message.context,
    )
    return result


@router.post("/generate-embeddings")
async def generate_embeddings(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Tạo embedding vectors cho tất cả địa điểm chưa có (chỉ admin)"""
    result = await AIService.generate_all_embeddings(db)
    return result


@router.get("/analyze-preferences")
async def analyze_preferences(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user),
):
    """Phân tích sở thích du lịch của người dùng"""
    user_history = []  # Could fetch from database
    result = await AIService.analyze_user_preferences(user_history)
    return result
