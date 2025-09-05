# Build an FFmpeg Lambda layer zip on Amazon Linux 2
FROM public.ecr.aws/amazonlinux/amazonlinux:2

# Tools we need
RUN yum -y install curl xz zip tar && yum clean all

WORKDIR /build
ARG FFMPEG_VERSION=6.1.1
# Retry + fallback mirror; then package to /build/ffmpeg-layer.zip
RUN set -eux; \
  url1="https://johnvansickle.com/ffmpeg/releases/ffmpeg-${FFMPEG_VERSION}-amd64-static.tar.xz"; \
  url2="https://www.johnvansickle.com/ffmpeg/releases/ffmpeg-${FFMPEG_VERSION}-amd64-static.tar.xz"; \
  for u in "$url1" "$url2"; do \
    echo "Downloading $u"; \
    if curl -fsSL --retry 5 --retry-delay 5 --connect-timeout 20 "$u" -o ffmpeg.tar.xz; then break; fi; \
  done; \
  test -s ffmpeg.tar.xz; \
  tar -xJf ffmpeg.tar.xz; \
  FOLDER="ffmpeg-${FFMPEG_VERSION}-amd64-static"; \
  mkdir -p layer/bin; \
  cp "$FOLDER/ffmpeg" "$FOLDER/ffprobe" layer/bin/; \
  (strip layer/bin/ffmpeg layer/bin/ffprobe || true); \
  (cd layer && zip -r9 /build/ffmpeg-layer.zip .)
