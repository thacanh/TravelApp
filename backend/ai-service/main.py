"""
ai-service: handles /api/ai/* and /api/chat/*

Gemini API fix (per user's sample):
- Chat: use GoogleSearch tool WITHOUT ThinkingConfig (they conflict on gemini-2.5-flash)
- Recommendations: use ThinkingConfig WITHOUT tools
- Use client.models.generate_content() with types.Content / types.Part.from_text()
"""
import os, json, logging
from typing import Optional, List
from datetime import datetime
from fastapi import FastAPI, Depends, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime, Text, Float, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from pydantic import BaseModel
from pydantic_settings import BaseSettings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-service")


class Settings(BaseSettings):
    DATABASE_URL: str = "mysql+pymysql://root:root@localhost/trawime_db?charset=utf8mb4"
    GEMINI_API_KEY: str = ""
    class Config: env_file = ".env"

settings = Settings()
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True, pool_recycle=3600)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# ── Models ─────────────────────────────────────────────────────────────────────
class Category(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True)
    slug = Column(String(50), unique=True)
    name = Column(String(100))

class LocationCategory(Base):
    __tablename__ = "location_categories"
    location_id = Column(Integer, ForeignKey("locations.id", ondelete="CASCADE"), primary_key=True)
    category_id = Column(Integer, ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True)

class Location(Base):
    __tablename__ = "locations"
    id = Column(Integer, primary_key=True)
    name = Column(String(255)); description = Column(Text)
    city = Column(String(100))
    images = Column(JSON, default=list)
    description_embedding = Column(JSON, nullable=True)
    # Quan hệ N-N với Category
    categories = relationship("Category", secondary="location_categories", lazy="selectin")

class ChatSession(Base):
    __tablename__ = "chat_sessions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    title = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan", order_by="ChatMessage.created_at")

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("chat_sessions.id"), nullable=False)
    role = Column(String(20), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    session = relationship("ChatSession", back_populates="messages")

def get_db():
    db = SessionLocal()
    try: yield db
    finally: db.close()

class CurrentUser:
    def __init__(self, id: int, role: str):
        self.id = id; self.role = role

def get_current_user(x_user_id: Optional[str] = Header(None), x_user_role: Optional[str] = Header(None)) -> CurrentUser:
    if not x_user_id: raise HTTPException(status_code=401, detail="Missing auth headers")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")

def require_admin(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if current.role != "admin": raise HTTPException(status_code=403, detail="Not enough permissions")
    return current


# ── Gemini client setup ────────────────────────────────────────────────────────
_gemini_available = False
_client = None
_MODEL = "gemini-3.1-flash-lite-preview"
_EMBED_MODEL = "gemini-embedding-001"  # latest Gemini embedding model

try:
    from google import genai
    from google.genai import types as gtypes

    if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY not in ("", "your-gemini-api-key"):
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
        _embed_client = genai.Client(
            api_key=settings.GEMINI_API_KEY,
            http_options={"api_version": "v1"},
        )
        _gemini_available = True
        logger.info(f"Gemini client ready ({_MODEL})")
    else:
        logger.warning("GEMINI_API_KEY not set — using mock responses")
except ImportError:
    logger.warning("google-genai not installed — using mock responses")
except Exception as e:
    logger.warning(f"Gemini init error: {e}")

_SYSTEM_INSTRUCTION = (
    "Bạn là trợ lý du lịch AI của ứng dụng TRAWIME, chuyên về du lịch Việt Nam. "
    "Hãy trả lời bằng tiếng Việt, thân thiện, ngắn gọn và hữu ích. "
    "Khi được hỏi về địa điểm, hãy đưa ra thông tin thực tế về địa danh Việt Nam. "
    "Khi người dùng muốn lập lịch trình, hãy gợi ý lịch trình cụ thể theo ngày. "
    "Luôn đề xuất 2-3 gợi ý nhanh ở cuối câu trả lời."
)


def _extract_suggestions(text: str) -> List[str]:
    defaults = ["Gợi ý địa điểm", "Lập lịch trình", "Tìm bãi biển đẹp"]
    lines = text.strip().split("\n")
    suggestions = []
    for line in reversed(lines):
        s = line.strip().lstrip("•-*0123456789.) ")
        if 3 < len(s) < 60:
            suggestions.append(s)
        if len(suggestions) >= 3:
            break
    return list(reversed(suggestions)) if suggestions else defaults


def _clean_json(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        if text.endswith("```"):
            text = text[:-3]
    return text.strip()


# ── AI Logic ────────────────────────────────────────────────────────────────────

def _cosine_similarity(a: list, b: list) -> float:
    """Pure-Python cosine similarity — no numpy needed."""
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def _get_embedding(text: str) -> List[float]:
    result = _client.models.embed_content(
        model=_EMBED_MODEL,
        contents=text,
    )
    return result.embeddings[0].values


def _embed_location(loc) -> List[float]:
    """Build a rich description for a location and embed it."""
    # Dùng danh sách tên categories từ quan hệ N-N
    cat_names = ", ".join([c.name for c in (loc.categories or [])]) or ""
    text = (
        f"{loc.name}. "
        f"Thành phố: {loc.city or ''}. "
        f"Loại: {cat_names}. "
        f"{loc.description or ''}"
    )
    return _get_embedding(text)


async def _gemini_chat(message: str, history: list = None) -> dict:
    """
    Chat with Gemini sử dụng gemini-3.1-flash-lite-preview + ThinkingConfig MINIMAL.
    history: list of {role, content} dicts từ DB (các tin nhắn trước).
    """
    contents = []
    # Đưa lịch sử cuộc trò chuyện vào context
    for h in (history or []):
        contents.append(
            gtypes.Content(
                role=h["role"],  # "user" hoặc "model"
                parts=[gtypes.Part.from_text(text=h["content"])],
            )
        )
    # Tin nhắn hiện tại
    contents.append(
        gtypes.Content(
            role="user",
            parts=[gtypes.Part.from_text(text=message)],
        )
    )
    config = gtypes.GenerateContentConfig(
        system_instruction=_SYSTEM_INSTRUCTION,
        thinking_config=gtypes.ThinkingConfig(thinking_level="MINIMAL"),
    )
    response = _client.models.generate_content(
        model=_MODEL,
        contents=contents,
        config=config,
    )
    text = response.text or ""
    return {"response": text, "suggestions": _extract_suggestions(text)}


def _recommend_by_embedding(query: str, locations: list, top_k: int = 5) -> list:
    """
    1. Embed user query.
    2. Compare against each location's stored `description_embedding`.
    3. Return top-k (score, location) sorted by cosine similarity.
    """
    query_vec = _get_embedding(query)
    scored = []
    for loc in locations:
        emb = loc.description_embedding
        if emb and isinstance(emb, list):
            score = _cosine_similarity(query_vec, emb)
        else:
            score = 0.0
        scored.append((score, loc))
    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[:top_k]


# ── Mock fallbacks ─────────────────────────────────────────────────────────────

async def _mock_chat(message: str) -> dict:
    msg = message.lower()
    if any(w in msg for w in ["xin chào", "hello", "hi", "chào"]):
        return {"response": "Xin chào! Tôi là trợ lý du lịch TRAWIME (offline mode).", "suggestions": ["Gợi ý địa điểm", "Tìm bãi biển", "Lập lịch trình"]}
    if any(w in msg for w in ["biển", "beach"]):
        return {"response": "Việt Nam có nhiều bãi biển đẹp: Phú Quốc, Nha Trang, Đà Nẵng.", "suggestions": ["Chi tiết Phú Quốc", "Bãi biển gần Hà Nội", "Bãi biển ít người"]}
    return {"response": f"(Offline) Về '{message}', hãy khám phá thêm trên app!", "suggestions": ["Gợi ý địa điểm", "Hỏi về thời tiết", "Tư vấn lịch trình"]}


async def _mock_recommend(preferences: str, category: str = None) -> dict:
    mock = [
        {"location_id": 1, "name": "Vịnh Hạ Long", "category": "nature", "city": "Quảng Ninh", "rating": 4.8, "match_score": 0.95, "reason": "Di sản thiên nhiên thế giới", "images": []},
        {"location_id": 2, "name": "Phố Cổ Hội An", "category": "cultural", "city": "Quảng Nam", "rating": 4.7, "match_score": 0.92, "reason": "Kiến trúc cổ kính", "images": []},
        {"location_id": 3, "name": "Đà Lạt", "category": "city", "city": "Lâm Đồng", "rating": 4.6, "match_score": 0.88, "reason": "Khí hậu mát mẻ", "images": []},
    ]
    if category: mock = [m for m in mock if m["category"] == category] or mock
    return {"recommendations": mock[:5], "explanation": f"(Offline) Gợi ý dựa trên '{preferences or ''}'"}


# ── Schemas ────────────────────────────────────────────────────────────────────
class AIRecommendRequest(BaseModel):
    preferences: str; category: Optional[str] = None
    budget: Optional[str] = None; duration: Optional[int] = None

class AIRecommendResponse(BaseModel):
    recommendations: list; explanation: str

class ChatMessageRequest(BaseModel):
    message: str; context: Optional[dict] = None

class ChatResponse(BaseModel):
    response: str; suggestions: List[str] = []

class SendMessageRequest(BaseModel):
    message: str; session_id: Optional[int] = None

class ChatMessageResponse(BaseModel):
    id: int; session_id: int; role: str; content: str; created_at: datetime
    class Config: from_attributes = True

class ChatSessionSummary(BaseModel):
    id: int; title: Optional[str]; created_at: datetime; updated_at: datetime
    class Config: from_attributes = True

class ChatSessionResponse(BaseModel):
    id: int; title: Optional[str]; created_at: datetime; updated_at: datetime
    messages: List[ChatMessageResponse] = []
    class Config: from_attributes = True


# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(title="TRAWIME AI Service", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.get("/health")
def health():
    return {"status": "healthy", "service": "ai-service", "gemini_available": _gemini_available}


# ── AI endpoints ───────────────────────────────────────────────────────────────
@app.post("/api/ai/recommend", response_model=AIRecommendResponse)
async def get_recommendations(req: AIRecommendRequest, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    if not _gemini_available:
        return await _mock_recommend(req.preferences, req.category)

    query = db.query(Location)
    if req.category:
        # Lọc theo category slug trong quan hệ N-N
        query = query.filter(Location.categories.any(Category.slug == req.category))
    locations = query.all()

    if not locations:
        return {"recommendations": [], "explanation": "Chưa có địa điểm nào trong hệ thống."}

    try:
        results = _recommend_by_embedding(req.preferences, locations, top_k=5)

        recommendations = []
        for score, loc in results:
            recommendations.append({
                "location_id": loc.id, "name": loc.name,
                "categories": [{"slug": c.slug, "name": c.name} for c in (loc.categories or [])],
                "city": loc.city,
                "rating": 0,
                "match_score": round(score, 4),
                "reason": f"Độ tương đồng với yêu cầu: {round(score * 100, 1)}%",
                "images": loc.images or [],
            })

        has_embeddings = any(loc.description_embedding for _, loc in results)
        if not has_embeddings:
            explanation = "Các địa điểm chưa có embedding. Admin cần chạy POST /api/ai/generate-embeddings trước."
        else:
            explanation = f"AI tìm thấy {len(recommendations)} địa điểm phù hợp nhất dựa trên mô tả của bạn."

        return {"recommendations": recommendations, "explanation": explanation}
    except Exception as e:
        logger.error(f"Embedding recommendation error: {e}")
        return await _mock_recommend(req.preferences, req.category)


@app.post("/api/ai/chat", response_model=ChatResponse)
async def chat_with_ai(message: ChatMessageRequest, current: CurrentUser = Depends(get_current_user)):
    if not _gemini_available:
        return await _mock_chat(message.message)
    try:
        return await _gemini_chat(message.message)  # no history — legacy endpoint
    except Exception as e:
        logger.error(f"Gemini chat error: {e}")
        return await _mock_chat(message.message)


@app.post("/api/ai/generate-embeddings")
async def generate_embeddings(current: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    """
    Admin endpoint: bulk-generate embeddings for all locations that lack one.
    Call this once after adding new locations via location-service.
    """
    if not _gemini_available:
        raise HTTPException(status_code=503, detail="Gemini API kh\u00f4ng kh\u1ea3 d\u1ee5ng")

    locations = db.query(Location).filter(Location.description_embedding == None).all()
    if not locations:
        return {"status": "ok", "updated": 0, "message": "T\u1ea5t c\u1ea3 \u0111\u1ecba \u0111i\u1ec3m \u0111\u00e3 c\u00f3 embedding"}

    updated = 0
    errors = 0
    for loc in locations:
        try:
            loc.description_embedding = _embed_location(loc)
            updated += 1
        except Exception as e:
            logger.error(f"Embedding error for location {loc.id}: {e}")
            errors += 1

    db.commit()
    return {
        "status": "ok",
        "updated": updated,
        "errors": errors,
        "message": f"\u0110\u00e3 t\u1ea1o embedding cho {updated} \u0111\u1ecba \u0111i\u1ec3m"
    }


@app.get("/api/ai/analyze-preferences")
async def analyze_preferences(current: CurrentUser = Depends(get_current_user)):
    return {"preferred_categories": [], "preferred_cities": [], "average_rating_given": 0, "total_visits": 0}


# ── Internal endpoints (called by other services, no auth) ─────────────────────
@app.post("/internal/embed-location/{location_id}")
def embed_single_location(location_id: int, db: Session = Depends(get_db)):
    """
    Called by location-service (background) immediately after a location is
    created or updated. Generates and stores the embedding in one step.
    """
    if not _gemini_available:
        return {"status": "skipped", "reason": "Gemini unavailable"}
    loc = db.query(Location).filter(Location.id == location_id).first()
    if not loc:
        raise HTTPException(status_code=404, detail="Location not found")
    try:
        loc.description_embedding = _embed_location(loc)
        db.commit()
        return {"status": "ok", "location_id": location_id}
    except Exception as e:
        logger.error(f"Embedding error for location {location_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))



# ── Chat session endpoints ─────────────────────────────────────────────────────
@app.get("/api/chat/sessions", response_model=List[ChatSessionSummary])
def list_sessions(current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(ChatSession).filter(ChatSession.user_id == current.id).order_by(ChatSession.updated_at.desc()).all()


@app.get("/api/chat/sessions/{session_id}", response_model=ChatSessionResponse)
def get_session(session_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    session = db.query(ChatSession).filter(ChatSession.id == session_id, ChatSession.user_id == current.id).first()
    if not session: raise HTTPException(status_code=404, detail="Không tìm thấy phiên trò chuyện")
    return session


@app.post("/api/chat/send", response_model=ChatMessageResponse)
async def send_message(body: SendMessageRequest, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    # Get or create session
    if body.session_id:
        session = db.query(ChatSession).filter(ChatSession.id == body.session_id, ChatSession.user_id == current.id).first()
        if not session: raise HTTPException(status_code=404, detail="Không tìm thấy phiên trò chuyện")
    else:
        auto_title = body.message[:60] + ("..." if len(body.message) > 60 else "")
        session = ChatSession(user_id=current.id, title=auto_title)
        db.add(session); db.flush()

    # Save user message
    user_msg = ChatMessage(session_id=session.id, role="user", content=body.message)
    db.add(user_msg)

    # Call AI with full session history for context
    history = []
    for msg in session.messages:
        # Gemini dùng role "user" / "model" (không phải "assistant")
        gemini_role = "model" if msg.role == "assistant" else "user"
        history.append({"role": gemini_role, "content": msg.content})

    if _gemini_available:
        try:
            ai_result = await _gemini_chat(body.message, history=history)
        except Exception as e:
            logger.error(f"Chat error: {e}")
            ai_result = await _mock_chat(body.message)
    else:
        ai_result = await _mock_chat(body.message)

    ai_text = ai_result.get("response", "Xin lỗi, tôi không thể trả lời lúc này.")

    # Save AI message
    ai_msg = ChatMessage(session_id=session.id, role="assistant", content=ai_text)
    db.add(ai_msg)
    session.updated_at = datetime.utcnow()
    db.commit(); db.refresh(ai_msg)
    return ai_msg


@app.delete("/api/chat/sessions/{session_id}", status_code=204)
def delete_session(session_id: int, current: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    session = db.query(ChatSession).filter(ChatSession.id == session_id, ChatSession.user_id == current.id).first()
    if not session: raise HTTPException(status_code=404, detail="Không tìm thấy phiên trò chuyện")
    db.delete(session); db.commit()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8006, reload=True)
