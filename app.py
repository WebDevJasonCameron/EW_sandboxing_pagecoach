# app.py
import os, json, base64
from fastapi import FastAPI, UploadFile, Form, HTTPException
from fastapi.responses import JSONResponse, FileResponse
from openai import OpenAI

# Optional: import specific error types (SDK >= 1.0)
try:
    from openai import RateLimitError, APIConnectionError, APIStatusError
except Exception:
    # Older SDKs may not expose these; we'll still have a generic catch-all
    RateLimitError = APIConnectionError = APIStatusError = Exception  # type: ignore

# --- Optional env.py support (local dev convenience) -------------------------
# Create a file named env.py next to this app with:  OPENAI_API_KEY = "sk-...."
try:
    import env
    _env = env.API_KEY
    if getattr(_env, "OPENAI_API_KEY", None):
        os.environ.setdefault("OPENAI_API_KEY", _env.OPENAI_API_KEY)
except ImportError:
    pass
# -----------------------------------------------------------------------------

MODEL = os.getenv("MODEL", "gpt-4o-mini")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    # Fail early with a clear message rather than a vague 500 later
    raise RuntimeError(
        "Missing OPENAI_API_KEY. Set it in env.py (OPENAI_API_KEY='sk-...') "
        "or as an environment variable."
    )

client = OpenAI(api_key=OPENAI_API_KEY)
app = FastAPI()

SYSTEM_PROMPT = """
You are an art director for comics. Critique a single comic page sketch.
Focus on: (1) reading order (western L→R, T→B unless told manga),
(2) speech bubble placement vs art, (3) panel clarity and flow,
(4) glaring composition issues (competing focal points, tangents, cramped text).
Rules:
- Return a numbered list of 5–10 specific notes.
- Be concrete (“Move bubble in panel 3 up-left by ~10–15% to avoid covering the eyes.”).
- If unsure about panel count, say so and explain why.
- If text is unreadable, infer from layout and say so.
Output JSON only: {"notes":[ "...", "...", ... ]}
"""

@app.get("/")
def home():
    return FileResponse("index.html")

@app.post("/analyze-page")
async def analyze_page(image: UploadFile, style: str = Form("western")):
    # Basic validation
    if not image:
        raise HTTPException(status_code=400, detail="No image uploaded.")
    if image.content_type not in {"image/png", "image/jpeg", "image/webp"}:
        raise HTTPException(status_code=415, detail="Unsupported image type. Use PNG, JPG, or WEBP.")

    img_bytes = await image.read()
    if not img_bytes:
        raise HTTPException(status_code=400, detail="Empty image upload.")

    b64 = base64.b64encode(img_bytes).decode("utf-8")

    # Swap reading order hint (tiny, but helpful signal)
    style_hint = "western L→R, T→B" if style != "manga" else "manga R→L, T→B"
    prompt = SYSTEM_PROMPT.replace("western L→R, T→B", style_hint)

    # Chat Completions with vision: send text + image (as data URL)
    messages = [{
        "role": "system",
        "content": [{"type": "text", "text": prompt}]
    },{
        "role": "user",
        "content": [
            {"type": "text", "text": "Analyze this page for reading order, bubbles, and composition."},
            {"type": "image_url",
             "image_url": {"url": f"data:{image.content_type};base64,{b64}"}}        ]
    }]

    try:
        resp = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            response_format={"type": "json_object"}  # ask for strict JSON back
        )
        content = resp.choices[0].message.content

    except RateLimitError:
        # Quota/rate issues -> 429
        raise HTTPException(
            status_code=429,
            detail="Rate limit or quota exceeded with the AI provider. Check billing/quotas or try again later."
        )
    except APIConnectionError:
        # Network to OpenAI -> 503
        raise HTTPException(
            status_code=503,
            detail="Could not reach the AI service. Please try again in a moment."
        )
    except APIStatusError as e:
        # Try to surface the upstream error body so you know exactly what's wrong
        code = getattr(e, "status_code", 502) or 502
        try:
            # SDK v1 usually has .response with a .json() method
            upstream = e.response.json() if hasattr(e, "response") else None
        except Exception:
            upstream = None
        detail = upstream.get("error", {}).get("message") if isinstance(upstream, dict) else str(e)
        raise HTTPException(status_code=code, detail=f"OpenAI error: {detail}")

    except Exception:
        # Last resort guard so your route never 500s without context
        raise HTTPException(status_code=502, detail="Unexpected error while calling the AI service.")

    # Parse the model's JSON content defensively
    try:
        data = json.loads(content)
    except Exception:
        data = {"notes": [content]}

    notes = data.get("notes")
    if not isinstance(notes, list):
        notes = [str(data)]

    return JSONResponse({"notes": notes})
