"""
AI Service using Google GenAI SDK (new google-genai package)
- Chatbot: gemini-3-flash-preview with thinking + Google Search
- Recommendations: Gemini-powered location ranking
"""
import logging
import json
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session

from ..config import settings

logger = logging.getLogger(__name__)

# --- Google GenAI setup ---
_gemini_available = False
_client = None
_model_name = "gemini-2.5-flash"

try:
    from google import genai
    from google.genai import types

    if settings.GEMINI_API_KEY and settings.GEMINI_API_KEY not in ("", "your-gemini-api-key"):
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
        _gemini_available = True
        logger.info(f"✅ Google GenAI configured ({_model_name} + Google Search)")
    else:
        logger.warning("⚠️ GEMINI_API_KEY not set — falling back to mock AI")
except ImportError:
    logger.warning("⚠️ google-genai not installed — falling back to mock AI")
except Exception as e:
    logger.warning(f"⚠️ GenAI init error: {e} — falling back to mock AI")


# ───────────────────────── helpers ─────────────────────────

_SYSTEM_INSTRUCTION = (
    "Bạn là trợ lý du lịch AI của ứng dụng TRAWiMe, chuyên về du lịch Việt Nam. "
    "Hãy trả lời bằng tiếng Việt, thân thiện, ngắn gọn và hữu ích. "
    "Khi được hỏi về địa điểm, hãy đưa ra thông tin thực tế về địa danh Việt Nam. "
    "Khi người dùng muốn lập lịch trình, hãy gợi ý lịch trình cụ thể theo ngày. "
    "Luôn đề xuất 2-3 gợi ý nhanh ở cuối câu trả lời."
)


def _extract_suggestions(text: str) -> List[str]:
    """Try to pull short suggestion phrases from the AI response."""
    defaults = ["Gợi ý địa điểm", "Lập lịch trình", "Tìm bãi biển đẹp"]
    lines = text.strip().split("\n")
    suggestions = []
    for line in reversed(lines):
        stripped = line.strip().lstrip("•-*0123456789.) ")
        if 3 < len(stripped) < 60:
            suggestions.append(stripped)
        if len(suggestions) >= 3:
            break
    return list(reversed(suggestions)) if suggestions else defaults


def _clean_json_response(text: str) -> str:
    """Remove markdown code blocks from Gemini response."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        if text.endswith("```"):
            text = text[:-3]
        text = text.strip()
    return text


# ───────────────────────── main service ─────────────────────────

class AIService:
    """
    AI Service backed by Google GenAI SDK (google-genai).
    Uses gemini-3-flash-preview with thinking and Google Search.
    Falls back to mock responses when GEMINI_API_KEY is not configured.
    """

    # ── Chatbot ────────────────────────────────────────────

    @staticmethod
    async def chat_response(message: str, context: Dict = None) -> Dict[str, Any]:
        """Generate chatbot response using Gemini with thinking + Google Search."""

        if not _gemini_available or _client is None:
            return await AIService._mock_chat(message)

        try:
            contents = [
                types.Content(
                    role="user",
                    parts=[types.Part.from_text(text=message)],
                ),
            ]

            # Enable Google Search for real-time info
            tools = [
                types.Tool(googleSearch=types.GoogleSearch()),
            ]

            config = types.GenerateContentConfig(
                system_instruction=_SYSTEM_INSTRUCTION,
                thinking_config=types.ThinkingConfig(
                    thinking_budget=-1,
                ),
                tools=tools,
            )

            response = _client.models.generate_content(
                model=_model_name,
                contents=contents,
                config=config,
            )

            text = response.text or ""
            suggestions = _extract_suggestions(text)

            return {
                "response": text,
                "suggestions": suggestions,
            }
        except Exception as e:
            logger.error(f"Gemini chat error: {e}")
            return await AIService._mock_chat(message)

    # ── Recommendations (Gemini-powered) ─────────────────

    @staticmethod
    async def get_recommendations(
        db: Session,
        preferences: str,
        category: str = None,
        budget: str = None,
        duration: int = None,
        user_history: List[Dict] = None,
    ) -> Dict[str, Any]:
        """
        Recommend locations using Gemini AI directly.
        1. Load all locations from DB
        2. Send location list + user preferences to Gemini
        3. Parse Gemini's ranked response
        """
        from ..models.location import Location

        if not _gemini_available or _client is None:
            return await AIService._mock_recommendations(preferences, category)

        # 1. Fetch locations from DB
        query = db.query(Location)
        if category:
            query = query.filter(Location.category == category)
        locations = query.all()

        if not locations:
            return {
                "recommendations": [],
                "explanation": "Chưa có địa điểm nào trong hệ thống.",
            }

        # 2. Build location summary for Gemini
        loc_summaries = []
        for loc in locations:
            loc_summaries.append(
                f"ID:{loc.id} | {loc.name} | {loc.category} | {loc.city} | "
                f"Rating:{loc.rating_avg or 0}/5 | {(loc.description or '')[:100]}"
            )
        loc_text = "\n".join(loc_summaries)

        # 3. Ask Gemini to rank
        user_query = preferences or "gợi ý địa điểm du lịch hay"
        if budget:
            user_query += f", ngân sách: {budget}"
        if duration:
            user_query += f", thời gian: {duration} ngày"

        prompt = f"""Bạn là trợ lý du lịch AI. Người dùng muốn: "{user_query}"

Danh sách địa điểm có sẵn:
{loc_text}

Hãy chọn tối đa 5 địa điểm phù hợp nhất. Trả lời ĐÚNG format JSON sau (không thêm gì khác):
{{
  "picks": [
    {{"id": <location_id>, "score": <0.0-1.0>, "reason": "<giải thích ngắn tiếng Việt>"}},
    ...
  ],
  "explanation": "<tóm tắt gợi ý tiếng Việt>"
}}"""

        try:
            contents = [
                types.Content(
                    role="user",
                    parts=[types.Part.from_text(text=prompt)],
                ),
            ]

            config = types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(
                    thinking_budget=-1,
                ),
            )

            response = _client.models.generate_content(
                model=_model_name,
                contents=contents,
                config=config,
            )

            text = _clean_json_response(response.text or "{}")
            parsed = json.loads(text)
            picks = parsed.get("picks", [])
            explanation = parsed.get("explanation", "")

            # Map picks back to location data
            loc_map = {loc.id: loc for loc in locations}
            recommendations = []
            for pick in picks:
                loc_id = pick.get("id")
                loc = loc_map.get(loc_id)
                if loc:
                    recommendations.append({
                        "location_id": loc.id,
                        "name": loc.name,
                        "category": loc.category,
                        "city": loc.city,
                        "rating": loc.rating_avg or 0,
                        "match_score": round(pick.get("score", 0.8), 4),
                        "reason": pick.get("reason", ""),
                        "images": loc.images or [],
                    })

            return {
                "recommendations": recommendations,
                "explanation": explanation or f"Dựa trên yêu cầu '{preferences}', AI đã tìm thấy {len(recommendations)} địa điểm phù hợp.",
            }

        except Exception as e:
            logger.error(f"Gemini recommendation error: {e}")
            return await AIService._mock_recommendations(preferences, category)

    # ── Bulk embedding generation ──────────────────────────

    @staticmethod
    async def generate_all_embeddings(db: Session) -> Dict[str, Any]:
        """Generate embeddings for all locations (kept for compatibility)."""
        return {
            "status": "ok",
            "message": "Recommendations now use Gemini directly — embeddings not needed.",
            "total": 0,
            "embedded": 0,
        }

    # ── Generate single location embedding ─────────────────

    @staticmethod
    async def generate_location_embedding(db: Session, location) -> bool:
        """Generate embedding (no-op, kept for compatibility)."""
        return True

    # ── Analyze preferences ────────────────────────────────

    @staticmethod
    async def analyze_user_preferences(user_history: List[Dict]) -> Dict[str, Any]:
        """Analyze user's travel preferences from history."""
        if not user_history:
            return {
                "preferred_categories": [],
                "preferred_cities": [],
                "average_rating_given": 0,
                "total_visits": 0,
            }

        categories: Dict[str, int] = {}
        cities: Dict[str, int] = {}
        total_rating = 0

        for item in user_history:
            cat = item.get("category", "unknown")
            categories[cat] = categories.get(cat, 0) + 1
            city = item.get("city", "unknown")
            cities[city] = cities.get(city, 0) + 1
            if "rating" in item:
                total_rating += item["rating"]

        return {
            "preferred_categories": [c[0] for c in sorted(categories.items(), key=lambda x: x[1], reverse=True)[:3]],
            "preferred_cities": [c[0] for c in sorted(cities.items(), key=lambda x: x[1], reverse=True)[:3]],
            "average_rating_given": total_rating / len(user_history) if user_history else 0,
            "total_visits": len(user_history),
        }

    # ═══════════════════ MOCK FALLBACKS ═══════════════════

    @staticmethod
    async def _mock_chat(message: str) -> Dict[str, Any]:
        """Fallback mock chatbot when Gemini is unavailable."""
        message_lower = message.lower()

        if any(w in message_lower for w in ["xin chào", "hello", "hi", "chào"]):
            return {
                "response": "Xin chào! Tôi là trợ lý du lịch AI (chế độ offline). Tôi có thể trả lời cơ bản về du lịch Việt Nam.",
                "suggestions": ["Gợi ý địa điểm", "Tìm bãi biển đẹp", "Lập kế hoạch du lịch"],
            }
        if any(w in message_lower for w in ["biển", "beach"]):
            return {
                "response": "Việt Nam có nhiều bãi biển đẹp: Phú Quốc, Nha Trang, Đà Nẵng, Vũng Tàu.\n\n• Tìm hiểu Phú Quốc\n• Bãi biển gần Hà Nội\n• Bãi biển ít người",
                "suggestions": ["Chi tiết Phú Quốc", "Bãi biển gần Hà Nội", "Bãi biển ít người"],
            }
        if any(w in message_lower for w in ["núi", "mountain", "sapa", "đà lạt"]):
            return {
                "response": "Các điểm đến núi: Sapa, Đà Lạt, Mù Cang Chải.\n\n• Trekking Sapa\n• Khám phá Đà Lạt\n• Núi gần Hà Nội",
                "suggestions": ["Trekking Sapa", "Khám phá Đà Lạt", "Núi gần Hà Nội"],
            }

        return {
            "response": f"(Chế độ offline) Về '{message}', tôi khuyên bạn tìm hiểu thêm trên ứng dụng.\n\n• Gợi ý địa điểm\n• Hỏi về thời tiết\n• Tư vấn lịch trình",
            "suggestions": ["Gợi ý địa điểm", "Hỏi về thời tiết", "Tư vấn lịch trình"],
        }

    @staticmethod
    async def _mock_recommendations(preferences: str, category: str = None) -> Dict[str, Any]:
        """Fallback mock recommendations when Gemini is unavailable."""
        mock = [
            {"location_id": 1, "name": "Vịnh Hạ Long", "category": "nature", "city": "Quảng Ninh", "rating": 4.8, "match_score": 0.95, "reason": "Di sản thiên nhiên thế giới", "images": []},
            {"location_id": 2, "name": "Phố Cổ Hội An", "category": "cultural", "city": "Quảng Nam", "rating": 4.7, "match_score": 0.92, "reason": "Kiến trúc cổ kính", "images": []},
            {"location_id": 3, "name": "Đà Lạt", "category": "city", "city": "Lâm Đồng", "rating": 4.6, "match_score": 0.88, "reason": "Khí hậu mát mẻ", "images": []},
            {"location_id": 4, "name": "Phú Quốc", "category": "beach", "city": "Kiên Giang", "rating": 4.5, "match_score": 0.85, "reason": "Bãi biển đẹp", "images": []},
            {"location_id": 5, "name": "Sapa", "category": "mountain", "city": "Lào Cai", "rating": 4.4, "match_score": 0.82, "reason": "Ruộng bậc thang", "images": []},
        ]
        if category:
            mock = [m for m in mock if m["category"] == category] or mock

        return {
            "recommendations": mock[:5],
            "explanation": f"(Chế độ offline) Gợi ý dựa trên từ khóa '{preferences or ''}'",
        }
