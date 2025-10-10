AI Predictor (FastAPI)

Overview
- FastAPI service providing endpoints for upload, status, predict, and more.
- Persists data to SQLite (configurable via env vars).
- Model: RandomForestRegressor serialized at models/fatigue_regressor.pkl.

Run locally
- pip install -r requirements.txt
- uvicorn fastapi_fatigue_service:app --reload --host 0.0.0.0 --port 8000
- Docs: http://localhost:8000/docs, Health: /health

Env vars
- DB_PATH: path to SQLite file (default: fatigue_data.db)
- MODEL_PATH: path to model file (default: models/fatigue_regressor.pkl)

Docker
- Build: docker build -t fatigue-api .
- Run: docker run -p 8000:8000 -e DB_PATH=/data/fatigue.db -v $(pwd)/data:/data fatigue-api

Deploy (example: Render/Railway/Fly.io)
- Use this Dockerfile.
- Set persistent volume for DB_PATH if you need to keep data.
- Expose port 8000.

Flutter integration
- Provide API base URL at build time: flutter run --dart-define API_BASE_URL=https://your-host:8000
- Or set at runtime via the new Cloud API page (cloud icon in app bar).
