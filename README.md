# EW_sandboxing_pagecoach


## 1. Install + env (once)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install fastapi uvicorn "openai>=1.40.0" python-multipart
export OPENAI_API_KEY=sk-your-key
export MODEL=gpt-4o-mini   # small/cheap; upgrade later if needed
``` 


## 2. To run

```bash       
uvicorn app:app --reload 
```