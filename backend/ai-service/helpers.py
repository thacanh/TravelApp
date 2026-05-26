import os
import json
import logging
from typing import Optional, List
from fastapi import Header, HTTPException, Depends
from models import settings, Location

# Thiết lập log hệ thống
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-service")

class CurrentUser:
    # Đối tượng lưu trữ thông tin tài khoản người dùng hiện tại giải nén từ header Gateway
    def __init__(self, id: int, role: str):
        self.id = id
        self.role = role

def get_current_user(x_user_id: Optional[str] = Header(None), x_user_role: Optional[str] = Header(None)) -> CurrentUser:
    # Đọc thông tin định danh do API Gateway đính kèm vào HTTP Headers
    if not x_user_id:
        raise HTTPException(status_code=401, detail="Thiếu headers xác thực tài khoản")
    return CurrentUser(id=int(x_user_id), role=x_user_role or "user")

def require_admin(current: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    # Đảm bảo người dùng hiện tại có vai trò quản trị viên
    if current.role != "admin":
        raise HTTPException(status_code=403, detail="Không có quyền truy cập chức năng này")
    return current

# Thiết lập thư viện kết nối Google Gemini
_gemini_available = False
_client = None
_embed_client = None
gtypes = None
_MODEL = "gemini-3.1-flash-lite-preview"
_EMBED_MODEL = "gemini-embedding-001"

try:
    from google import genai
    from google.genai import types as google_gtypes
    gtypes = google_gtypes

    # Chỉ khởi tạo nếu có Khóa API hợp lệ
    if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY not in ("", "your-gemini-api-key"):
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
        _embed_client = genai.Client(
            api_key=settings.GEMINI_API_KEY,
            http_options={"api_version": "v1"},
        )
        _gemini_available = True
        logger.info(f"Khởi động thành công Google Gemini SDK Client ({_MODEL})")
    else:
        logger.warning("Chưa cấu hình GEMINI_API_KEY hệ thống sẽ tự động chuyển qua dữ liệu giả lập")
except ImportError:
    logger.warning("Thư viện google-genai chưa được cài đặt hệ thống sẽ sử dụng dữ liệu giả lập")
except Exception as e:
    logger.warning(f"Lỗi khởi tạo Gemini SDK: {e}")

_SYSTEM_INSTRUCTION = (
    "Bạn là trợ lý du lịch AI của ứng dụng TRAWIME, chuyên về du lịch Việt Nam. "
    "Hãy trả lời bằng tiếng Việt, thân thiện, ngắn gọn và hữu ích. "
    "Khi được hỏi về địa điểm, hãy đưa ra thông tin thực tế về địa danh Việt Nam. "
    "Khi người dùng muốn lập lịch trình, hãy gợi ý lịch trình cụ thể theo ngày. "
    "Luôn đề xuất 2-3 gợi ý nhanh ở cuối câu trả lời."
)

def _extract_suggestions(text: str) -> List[str]:
    # Trích xuất các câu gợi ý nhanh từ nội dung phản hồi của AI để hiển thị thành các nút bấm nhanh
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
    # Hàm loại bỏ các ký tự bọc markdown JSON để parse an toàn
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        if text.endswith("```"):
            text = text[:-3]
    return text.strip()

def _cosine_similarity(a: list, b: list) -> float:
    # Tính toán độ tương đồng Cosine giữa hai vector đặc trưng
    if not a or not b or len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)

def _get_embedding(text: str) -> List[float]:
    # Gợi API Google Cloud để sinh Vector Embedding của chuỗi văn bản đầu vào
    result = _client.models.embed_content(
        model=_EMBED_MODEL,
        contents=text,
    )
    return result.embeddings[0].values

def _embed_location(loc) -> List[float]:
    # Chuẩn hóa dữ liệu thô của địa điểm thành chuỗi văn bản làm giàu thông tin và sinh vector
    cat_names = ", ".join([c.name for c in (loc.categories or [])]) or ""
    text = (
        f"{loc.name}. "
        f"Thành phố: {loc.city or ''}. "
        f"Loại: {cat_names}. "
        f"{loc.description or ''}"
    )
    return _get_embedding(text)

async def _gemini_chat(message: str, history: list = None) -> dict:
    # Gửi tin nhắn mới cùng lịch sử hội thoại trước đó lên Gemini Text API
    contents = []
    for h in (history or []):
        contents.append(
            gtypes.Content(
                role=h["role"],
                parts=[gtypes.Part.from_text(text=h["content"])],
            )
        )
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
    # Xếp hạng gợi ý địa điểm bằng Cosine Similarity với vector đặc trưng của từng địa điểm
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

async def _mock_chat(message: str) -> dict:
    # Trả về câu trả lời giả lập nếu mất mạng hoặc API khóa bị hết hạn quota
    msg = message.lower()
    if any(w in msg for w in ["xin chào", "hello", "hi", "chào"]):
        return {"response": "Xin chào! Tôi là trợ lý du lịch TRAWIME (chế độ ngoại tuyến). Hân hạnh được hỗ trợ bạn!", "suggestions": ["Gợi ý địa điểm", "Tìm bãi biển", "Lập lịch trình"]}
    if any(w in msg for w in ["biển", "beach"]):
        return {"response": "Việt Nam có nhiều bãi biển đẹp nổi tiếng thế giới như Phú Quốc, Nha Trang, Mỹ Khê Đà Nẵng.", "suggestions": ["Chi tiết Phú Quốc", "Bãi biển miền Bắc", "Bãi biển hoang sơ"]}
    return {"response": f"(Ngoại tuyến) Cảm ơn bạn đã hỏi về '{message}'. Bạn hãy tham khảo thêm các thông tin hữu ích khác trên ứng dụng nhé!", "suggestions": ["Gợi ý địa điểm", "Hỏi thời tiết", "Tư vấn lịch trình"]}

async def _mock_recommend(preferences: str, category: str = None) -> dict:
    # Trả về danh sách địa điểm giả lập khi Gemini Embedding không khả dụng
    mock = [
        {"location_id": 1, "name": "Vịnh Hạ Long", "category": "nature", "city": "Quảng Ninh", "rating": 4.8, "match_score": 0.95, "reason": "Di sản thiên nhiên thế giới nổi tiếng với hàng nghìn đảo đảo vôi kỳ vĩ.", "images": []},
        {"location_id": 2, "name": "Phố Cổ Hội An", "category": "cultural", "city": "Quảng Nam", "rating": 4.7, "match_score": 0.92, "reason": "Thành phố cổ kính cổ xưa nổi tiếng với lồng đèn và kiến trúc độc đáo.", "images": []},
        {"location_id": 3, "name": "Thành phố sương mù Đà Lạt", "category": "city", "city": "Lâm Đồng", "rating": 4.6, "match_score": 0.88, "reason": "Không khí quanh năm trong lành mát mẻ thích hợp nghỉ dưỡng.", "images": []},
    ]
    if category:
        mock = [m for m in mock if m["category"] == category] or mock
    return {"recommendations": mock[:5], "explanation": f"(Ngoại tuyến) Đang gợi ý ngẫu nhiên dựa trên từ khóa '{preferences or ''}'"}
