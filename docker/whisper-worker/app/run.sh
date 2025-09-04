#!/usr/bin/env bash
set -euo pipefail

echo "[run] starting whisper worker"
: "${IN_URI:?set IN_URI}"
: "${OUT_URI:?set OUT_URI}"

MODEL="${MODEL:-large-v3}"
LANGUAGE="${LANGUAGE:-}"
BEAM_SIZE="${BEAM_SIZE:-5}"
COMPUTE_TYPE="${COMPUTE_TYPE:-int8_float16}"
VAD="${VAD:-}"
INITIAL_PROMPT="${INITIAL_PROMPT:-}"
MAX_NEW_TOKENS="${MAX_NEW_TOKENS:-}"

mkdir -p /work
IN_LOCAL="/work/in.audio"
OUT_LOCAL="/work/out.json"

# Fetch input
if [[ "$IN_URI" == s3://* ]]; then
  echo "[run] downloading $IN_URI"
  python3 /app/s3io.py get "$IN_URI" "$IN_LOCAL"
else
  echo "[run] using local input $IN_URI"
  cp "$IN_URI" "$IN_LOCAL"
fi

ARGS=(--audio "$IN_LOCAL" --out "$OUT_LOCAL" --model "$MODEL" --beam_size "$BEAM_SIZE" --compute_type "$COMPUTE_TYPE")
[[ -n "$LANGUAGE" ]] && ARGS+=(--language "$LANGUAGE")
[[ -n "$INITIAL_PROMPT" ]] && ARGS+=(--initial_prompt "$INITIAL_PROMPT")
[[ -n "$MAX_NEW_TOKENS" ]] && ARGS+=(--max_new_tokens "$MAX_NEW_TOKENS")
[[ "$VAD" == "1" ]] && ARGS+=(--vad_filter)

echo "[run] transcribing... (${ARGS[*]})"
python3 /app/transcribe.py "${ARGS[@]}"

# Deliver output
if [[ "$OUT_URI" == s3://* ]]; then
  echo "[run] uploading -> $OUT_URI"
  python3 /app/s3io.py put "$OUT_LOCAL" "$OUT_URI"
else
  echo "[run] writing local -> $OUT_URI"
  mkdir -p "$(dirname "$OUT_URI")"
  cp "$OUT_LOCAL" "$OUT_URI"
fi

echo "[run] done."