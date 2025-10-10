# syntax=docker/dockerfile:1
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# System deps (optional: fonts for Chinese rendering if charts are used)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    fonts-noto-cjk \
  && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY . .

# Port and entrypoint
EXPOSE 8000

# Allow overriding DB/MODEL path via env in cloud
ENV DB_PATH=/app/fatigue_data.db \
    MODEL_PATH=/app/models/fatigue_regressor.pkl

CMD ["uvicorn", "fastapi_fatigue_service:app", "--host", "0.0.0.0", "--port", "8000"]

