"""
API Gateway — Single entry point for all TRAWiMe microservices.
- Validates JWT and injects X-User-Id, X-User-Role, X-User-Email headers
- Reverse-proxies requests to the appropriate downstream service
"""
import os
import logging
from urllib.parse import quote, unquote
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import httpx
from jose import JWTError, jwt

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api-gateway")

app = FastAPI(
    title="TRAWiMe API Gateway",
    description="Single entry point that routes requests to microservices",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Configuration ────────────────────────────────────────────────────────────

SECRET_KEY = os.getenv("SECRET_KEY", "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7")
ALGORITHM = "HS256"

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

# Public routes that don't need a valid JWT
PUBLIC_PATHS = {"/api/auth/login", "/api/auth/register", "/", "/health", "/docs", "/openapi.json"}

# Prefix paths that are public (static files, no auth needed)
PUBLIC_PREFIXES = ("/uploads/", "/uploads/reviews/", "/uploads/avatars/", "/media/")

# ── JWT helper ────────────────────────────────────────────────────────────────

def _decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


def _get_service_url(path: str) -> str:
    for prefix, url in SERVICES.items():
        if path.startswith(prefix):
            return url
    return None


# ── Main proxy handler ────────────────────────────────────────────────────────

@app.api_route("/{full_path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy(full_path: str, request: Request):
    path = "/" + full_path

    # Root / health stays here
    if path in ("/", "/health"):
        return JSONResponse({"message": "TRAWiMe API Gateway", "version": "2.0.0", "status": "ok"})

    # Resolve service
    service_url = _get_service_url(path)
    if not service_url:
        raise HTTPException(status_code=404, detail=f"No service handles path: {path}")

    # Auth check — bỏ qua với static files
    extra_headers: dict = {}
    is_public = path in PUBLIC_PATHS or any(path.startswith(p) for p in PUBLIC_PREFIXES)
    if not is_public:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing Bearer token")
        token = auth_header[len("Bearer "):]
        payload = _decode_token(token)
        extra_headers = {
            "X-User-Id":    str(payload.get("sub_id", "")),
            "X-User-Role":  str(payload.get("role", "user")),
            "X-User-Email": quote(str(payload.get("sub", "")), safe="@."),
            # URL-encode tên tiếng Việt — HTTP headers phải là ASCII
            "X-User-Name":  quote(str(payload.get("name", "")), safe=""),
        }

    # Build target URL
    target_url = service_url.rstrip("/") + path
    if request.url.query:
        target_url += "?" + request.url.query

    # Forward request — chỉ giữ header ASCII hợp lệ, bỏ hop-by-hop headers
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
        # Bỏ header có giá trị không phải ASCII — httpx chỉ chấp nhận ASCII
        try:
            v.encode('ascii')
            headers[k] = v
        except UnicodeEncodeError:
            pass  # Bỏ qua header có Unicode (sẽ được thay thế bởi extra_headers)
    headers.update(extra_headers)

    # Stream the request body for large uploads (multipart form data)
    async def stream_body():
        async for chunk in request.stream():
            yield chunk

    async with httpx.AsyncClient(timeout=120) as client:
        try:
            resp = await client.request(
                method=request.method,
                url=target_url,
                headers=headers,
                content=stream_body() if request.method in ["POST", "PUT", "PATCH"] else None,
            )
        except httpx.ConnectError as e:
            logger.error(f"Cannot connect to {service_url}: {e}")
            raise HTTPException(status_code=503, detail=f"Service unavailable: {service_url}")
        except Exception as e:
            logger.error(f"Proxy error forwarding to {target_url}: {e}")
            raise HTTPException(status_code=502, detail=f"Bad gateway: {e}")

    return StreamingResponse(
        content=resp.aiter_bytes(),
        status_code=resp.status_code,
        headers=dict(resp.headers),
        media_type=resp.headers.get("content-type"),
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
