import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone

from faster_whisper import WhisperModel
import ctranslate2

def pick_device():
    env = os.getenv("WHISPER_DEVICE")
    if env in {"cuda", "cpu", "auto"}:
        return env
    return "cuda" if ctranslate2.get_cuda_device_count() > 0 else "cpu"

def main():
    parser = argparse.ArgumentParser(description="Transcribe one audio file with faster-whisper.")
    parser.add_argument("--audio", required=True, help="Path to local audio file (wav/mp3/m4a/ogg/flac).")
    parser.add_argument("--out", required=True, help="Path to output JSON transcript.")
    parser.add_argument("--model", default="large-v3", help="Whisper model size (default: large-v3).")
    parser.add_argument("--language", default=None, help="Force language code (e.g., en). If unset, auto-detect.")
    parser.add_argument("--beam_size", type=int, default=5)
    parser.add_argument("--vad_filter", action="store_true", help="Enable VAD filtering.")
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--compute_type", default="int8_float16", help="CTranslate2 compute type.")
    parser.add_argument("--max_new_tokens", type=int, default=None)
    parser.add_argument("--initial_prompt", default=None, help="Optional prepend prompt for chunk continuity.")
    args = parser.parse_args()

    audio_path = args.audio
    out_path   = args.out

    if not os.path.exists(audio_path):
        print(f"[error] audio not found: {audio_path}", file=sys.stderr)
        sys.exit(2)

    device = pick_device()
    print(f"[info] device={device} model={args.model} compute_type={args.compute_type}", flush=True)

    t0 = time.time()
    model = WhisperModel(
        args.model,
        device=device,
        compute_type=args.compute_type,
        download_root=os.getenv("WHISPER_CACHE", "/root/.cache/whisper")
    )

    segments, info = model.transcribe(
        audio_path,
        language=args.language,
        beam_size=args.beam_size,
        vad_filter=args.vad_filter,
        temperature=args.temperature,
        initial_prompt=args.initial_prompt,
        max_new_tokens=args.max_new_tokens
    )
    load_and_cfg_s = time.time() - t0

    seg_list = []
    for i, seg in enumerate(segments):
        seg_list.append({
            "id": i,
            "start": seg.start,
            "end": seg.end,
            "text": seg.text,
            "avg_logprob": getattr(seg, "avg_logprob", None),
            "no_speech_prob": getattr(seg, "no_speech_prob", None),
            "temperature": args.temperature,
        })

    out = {
        "version": "1.0",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "input": {"audio_path": audio_path, "language": args.language, "initial_prompt": args.initial_prompt},
        "engine": {
            "impl": "faster-whisper",
            "model": args.model,
            "device": device,
            "ctranslate2_compute_type": args.compute_type,
            "beam_size": args.beam_size,
            "vad_filter": args.vad_filter,
        },
        "detected": {
            "language": getattr(info, "language", None),
            "language_probability": getattr(info, "language_probability", None),
            "duration": getattr(info, "duration", None),
        },
        "timing": {"total_s": time.time() - t0, "init_and_config_s": load_and_cfg_s},
        "segments": seg_list,
    }

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    rt_factor = (out["detected"]["duration"] or 0) / max(out["timing"]["total_s"], 1e-6)
    print(f"[done] wrote {out_path} | duration={out['detected']['duration']}s | wall={out['timing']['total_s']:.2f}s | x{rt_factor:.2f} realtime")

if __name__ == "__main__":
    main()
