FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY backend/requirements.txt /tmp/backend-requirements.txt
COPY worker/requirements.txt /tmp/worker-requirements.txt
RUN pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cpu \
    --extra-index-url https://pypi.org/simple \
    -r /tmp/worker-requirements.txt

COPY backend/ /app/backend/
COPY worker/ /app/worker/
COPY tools/ /app/tools/
COPY shared/ /app/shared/

ENV BIBLEAI_DATA=/data
RUN mkdir -p /data

ENTRYPOINT ["python"]
