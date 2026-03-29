from pydantic import BaseModel
from typing import Optional, List, Dict, Any


class AIRecommendRequest(BaseModel):
    preferences: Optional[str] = None
    category: Optional[str] = None
    budget: Optional[str] = None
    duration: Optional[int] = None


class AIRecommendResponse(BaseModel):
    recommendations: List[Dict[str, Any]]
    explanation: str


class ChatMessage(BaseModel):
    message: str
    context: Optional[Dict[str, Any]] = None


class ChatResponse(BaseModel):
    response: str
    suggestions: Optional[List[str]] = None
