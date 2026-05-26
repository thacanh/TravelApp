"""
API Gateway — Cổng vào duy nhất kết nối với các microservices của TRAWIME.
- Xác thực chữ ký số JWT và tiêm các thông tin tài khoản (Id, Role, Email, Name) vào HTTP headers.
- Reverse-proxy (chuyển tiếp luồng) yêu cầu khách hàng đến đúng microservice đầu cuối.
- Dọn dẹp hop-by-hop headers để tránh lỗi ngắt kết nối.
"""
import os
import logging
from urllib.parse import quote, unquote
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import httpx
from jose import JWTError, jwt

# Cấu hình logging hệ thống
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api-gateway")

app = FastAPI(
    title="TRAWIME API Gateway",
    description="Cổng điều phối duy nhất chuyển tiếp các request tới các dịch vụ microservices",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Cấu hình khóa bảo mật JWT ──────────────────────────────────────────────────
# Khóa SECRET_KEY dùng chung giữa API Gateway và auth-service để kiểm duyệt chữ ký
SECRET_KEY = os.getenv("SECRET_KEY", "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7")
ALGORITHM = "HS256"

# Danh sách ánh xạ đường dẫn tương ứng với các microservices hạ nguồn
SERVICES = {
    "/api/auth":            os.getenv("AUTH_SERVICE_URL",      "http://auth-service:8001"),
    "/api/users":           os.getenv("USER_SERVICE_URL",      "http://user-service:8002"),
    "/uploads/avatars":     os.getenv("USER_SERVICE_URL",      "http://user-service:8002"),  # avatar tĩnh
    "/uploads/reviews":     os.getenv("REVIEW_SERVICE_URL",    "http://review-service:8004"),  # ảnh review
    "/uploads":             os.getenv("USER_SERVICE_URL",      "http://user-service:8002"),  # fallback
    "/api/locations":       os.getenv("LOCATION_SERVICE_URL",  "http://location-service:8003"),
    "/api/categories":      os.getenv("LOCATION_SERVICE_URL",  "http://location-service:8003"),
    "/media":               os.getenv("LOCATION_SERVICE_URL",  "http://location-service:8003"),  # static media
    "/api/reviews":         os.getenv("REVIEW_SERVICE_URL",    "http://review-service:8004"),
    "/api/checkins":        os.getenv("REVIEW_SERVICE_URL",    "http://review-service:8004"),
    "/api/itineraries":     os.getenv("ITINERARY_SERVICE_URL", "http://itinerary-service:8005"),
    "/api/ai":              os.getenv("AI_SERVICE_URL",        "http://ai-service:8006"),
    "/api/chat":            os.getenv("AI_SERVICE_URL",        "http://ai-service:8006"),
    "/api/admin":           os.getenv("ADMIN_SERVICE_URL",     "http://admin-service:8007"),
}

# Các đường dẫn công cộng không yêu cầu JWT Token
PUBLIC_PATHS = {"/api/auth/login", "/api/auth/register", "/", "/health", "/docs", "/openapi.json"}

# Các tiền tố tệp tĩnh công cộng (không yêu cầu JWT Token)
PUBLIC_PREFIXES = ("/uploads/", "/uploads/reviews/", "/uploads/avatars/", "/media/")

# ── Hàm bổ trợ JWT ────────────────────────────────────────────────────────────

def _decode_token(token: str) -> dict:
    """Giải mã và xác minh tính toàn vẹn của JWT Token. Trả lỗi 401 nếu token sai hoặc hết hạn."""
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Mã xác thực JWT không hợp lệ hoặc đã hết hạn",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _get_service_url(path: str) -> str:
    """Ánh xạ đường dẫn request để tìm URL của service đích phục vụ."""
    for prefix, url in SERVICES.items():
        if path.startswith(prefix):
            return url
    return None


# ── Hàm điều phối Proxy chính ─────────────────────────────────────────────────

@app.api_route("/{full_path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy(full_path: str, request: Request):
    """
    Hàm chặn bắt (intercept) và chuyển tiếp request:
    1. Kiểm tra tài nguyên yêu cầu có phải public hay không.
    2. Nếu cần bảo mật, kiểm tra và giải mã token JWT.
    3. Trích xuất ID, Quyền, Tên người dùng và mã hóa URL-encode để gửi an toàn trên HTTP Headers.
    4. Loại bỏ các hop-by-hop headers và header chứa ký tự unicode trước khi chuyển tiếp.
    5. Thực hiện request song song dạng Stream để hỗ trợ tải lên file dung lượng lớn không nghẽn RAM.
    """
    path = "/" + full_path

    # Root hoặc health check xử lý trực tiếp tại API Gateway
    if path in ("/", "/health"):
        return JSONResponse({"message": "TRAWIME API Gateway", "version": "2.0.0", "status": "ok"})

    # Tìm kiếm service đích để chuyển hướng
    service_url = _get_service_url(path)
    if not service_url:
        raise HTTPException(status_code=404, detail=f"Không tìm thấy service xử lý đường dẫn: {path}")

    # Kiểm duyệt mã bảo mật JWT
    extra_headers: dict = {}
    is_public = path in PUBLIC_PATHS or any(path.startswith(p) for p in PUBLIC_PREFIXES)
    if not is_public:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Yêu cầu mã xác thực Bearer token ở header")
        token = auth_header[len("Bearer "):]
        payload = _decode_token(token)
        
        # Tiêm các thông tin tài khoản đã giải mã vào header chuyển tiếp hạ nguồn
        extra_headers = {
            "X-User-Id":    str(payload.get("sub_id", "")),
            "X-User-Role":  str(payload.get("role", "user")),
            "X-User-Email": quote(str(payload.get("sub", "")), safe="@."),
            # URL-encode tên tiếng Việt — Bắt buộc vì HTTP headers chỉ chấp nhận ASCII
            "X-User-Name":  quote(str(payload.get("name", "")), safe=""),
        }

    # Thiết lập đường dẫn đích
    target_url = service_url.rstrip("/") + path
    if request.url.query:
        target_url += "?" + request.url.query

    # Danh sách các Hop-by-hop headers cần dọn dẹp để tránh lỗi kết nối proxy
    HOP_BY_HOP = {
        "host", "content-length", "transfer-encoding",
        "connection", "keep-alive", "te", "trailers", "upgrade",
    }
    headers = {}
    for k, v in request.headers.items():
        if not isinstance(k, str) or not isinstance(v, str):
            continue
        if k.lower() in HOP_BY_HOP:
            continue
        # httpx chỉ chấp nhận header giá trị ASCII, lọc bỏ các header unicode lỗi của client
        try:
            v.encode('ascii')
            headers[k] = v
        except UnicodeEncodeError:
            pass  # Unicode header sẽ được thay thế an toàn qua extra_headers
    headers.update(extra_headers)

    # Đọc luồng dữ liệu yêu cầu (hỗ trợ upload file lớn không tốn RAM đệm)
    async def stream_body():
        async for chunk in request.stream():
            yield chunk

    # Sử dụng httpx thực hiện cuộc gọi proxy chuyển tiếp
    async with httpx.AsyncClient(timeout=120) as client:
        try:
            resp = await client.request(
                method=request.method,
                url=target_url,
                headers=headers,
                content=stream_body() if request.method in ["POST", "PUT", "PATCH"] else None,
            )
        except httpx.ConnectError as e:
            logger.error(f"Không thể kết nối đến service {service_url}: {e}")
            raise HTTPException(status_code=503, detail=f"Dịch vụ đích tạm thời ngưng hoạt động: {service_url}")
        except Exception as e:
            logger.error(f"Lỗi cổng kết nối proxy chuyển tiếp {target_url}: {e}")
            raise HTTPException(status_code=502, detail=f"Lỗi cổng kết nối (Bad Gateway): {e}")

    # Trả luồng dữ liệu stream ngược lại về cho thiết bị di động
    return StreamingResponse(
        content=resp.aiter_bytes(),
        status_code=resp.status_code,
        headers=dict(resp.headers),
        media_type=resp.headers.get("content-type"),
    )


if __name__ == "__main__":
    import uvicorn
    # Khởi động API Gateway chạy trên cổng 8000
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
