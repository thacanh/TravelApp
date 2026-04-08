"""
API Gateway — Single entry point for all TRAWiMe microservices.
- Validates JWT and injects X-User-Id, X-User-Role, X-User-Email headers
- Reverse-proxies requests to the appropriate downstream service
"""
import os
import logging
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
    "/api/auth":       os.getenv("AUTH_SERVICE_URL",      "http://auth-service:8001"),
    "/api/users":      os.getenv("USER_SERVICE_URL",      "http://user-service:8002"),
    "/api/locations":  os.getenv("LOCATION_SERVICE_URL",  "http://location-service:8003"),
    "/api/categories": os.getenv("LOCATION_SERVICE_URL",  "http://location-service:8003"),
    "/api/reviews":    os.getenv("REVIEW_SERVICE_URL",    "http://review-service:8004"),
    "/api/itineraries":os.getenv("ITINERARY_SERVICE_URL", "http://itinerary-service:8005"),
    "/api/ai":         os.getenv("AI_SERVICE_URL",        "http://ai-service:8006"),
    "/api/chat":       os.getenv("AI_SERVICE_URL",        "http://ai-service:8006"),
    "/api/admin":      os.getenv("ADMIN_SERVICE_URL",     "http://admin-service:8007"),
}

# Public routes that don't need a valid JWT
PUBLIC_PATHS = {"/api/auth/login", "/api/auth/register", "/", "/health", "/docs", "/openapi.json"}

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

    # Auth check
    extra_headers: dict = {}
    if path not in PUBLIC_PATHS:
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing Bearer token")
        token = auth_header[len("Bearer "):]
        payload = _decode_token(token)
        extra_headers = {
            "X-User-Id":    str(payload.get("sub_id", "")),
            "X-User-Role":  str(payload.get("role", "user")),
            "X-User-Email": str(payload.get("sub", "")),
        }

    # Forward request
    target_url = service_url.rstrip("/") + path
    if request.url.query:
        target_url += "?" + request.url.query

    headers = dict(request.headers)
    headers.pop("host", None)
    headers.update(extra_headers)

    body = await request.body()

    async with httpx.AsyncClient(timeout=60) as client:
        try:
            resp = await client.request(
                method=request.method,
                url=target_url,
                headers=headers,
                content=body,
            )
        except httpx.ConnectError as e:
            logger.error(f"Cannot connect to {service_url}: {e}")
            raise HTTPException(status_code=503, detail=f"Service unavailable: {service_url}")

    return StreamingResponse(
        content=resp.aiter_bytes(),
        status_code=resp.status_code,
        headers=dict(resp.headers),
        media_type=resp.headers.get("content-type"),
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
