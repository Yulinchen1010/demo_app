AI Predictor (FastAPI)

Overview
- FastAPI service providing endpoints for upload, status, predict, and dataset driven insights.
- Persists data to SQLite (configurable via env vars).
- Built-in fatigue pipeline derived from the 30-second sampling specification:
  1. Force removal on EMG RMS (with graceful fallback when missing).
  2. Continuous overload + dual threshold + posture cap + exponential recovery.
  3. EWMA smoothing, 5-min slope, and trend classification.
  4. LED color/blink decision rules.
  5. Future fatigue labelling (30 min horizon) + baseline features + Logistic/HGB training.
- Default dataset: ``fatigue_simulated_with_recovery.csv`` (configurable via ``SIM_CSV_PATH``).

Run locally
- pip install -r requirements.txt
- uvicorn fastapi_fatigue_service:app --reload --host 0.0.0.0 --port 8000
- Docs: http://localhost:8000/docs, Health: /health
- Simulation endpoints powered by the pipeline:
  - ``GET /dataset/sessions`` – list sessions available in the CSV.
  - ``GET /dataset/session/{session_id}`` – processed timeline (E, level, LED, etc.).
  - ``GET /dataset/predict/{session_id}`` – 30 minute high-fatigue probability (Logistic & HGB).
  - ``GET /dataset/reports`` – training classification reports for baseline models.

Env vars
- DB_PATH: path to SQLite file (default: fatigue_data.db)
- SIM_CSV_PATH: path to the fatigue simulation CSV (default: ../fatigue_simulated_with_recovery.csv)

Docker
- Build: docker build -t fatigue-api .
- Run: docker run -p 8000:8000 -e DB_PATH=/data/fatigue.db -v $(pwd)/data:/data fatigue-api

Deploy (example: Render/Railway/Fly.io)
- Use this Dockerfile.
- Set persistent volume for DB_PATH if you need to keep data.
- Bundle or mount the fatigue simulation CSV if you rely on the built-in pipeline models.
- Expose port 8000.

Flutter integration
- Provide API base URL at build time: flutter run --dart-define API_BASE_URL=https://your-host:8000
- Or set at runtime via the new Cloud API page (cloud icon in app bar).
