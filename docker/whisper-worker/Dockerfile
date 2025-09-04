FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    WHISPER_CACHE=/root/.cache/whisper

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv ffmpeg ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip && \
    pip install "ctranslate2==4.6.0" "faster-whisper==1.2.0" "boto3==1.34.162"

WORKDIR /app
COPY docker/whisper-worker/app/ /app/
RUN chmod +x /app/run.sh

ENTRYPOINT ["/app/run.sh"]
