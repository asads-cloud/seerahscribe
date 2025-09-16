import argparse
import json
import os
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

import boto3
from botocore.exceptions import ClientError

S3 = boto3.client("s3")
DDB = boto3.resource("dynamodb") if os.getenv("JOB_TABLE_NAME") else None
SNS = boto3.client("sns") if os.getenv("SNS_TOPIC_ARN") else None

# Tunables
OVERLAP_SEC = float(os.getenv("OVERLAP_SECONDS", "1.0"))
MIN_SEGMENT_SEC = float(os.getenv("MIN_SEGMENT_SECONDS", "0.06"))
EPS = 1e-6

def _read_s3_text(bucket: str, key: str) -> str:
    obj = S3.get_object(Bucket=bucket, Key=key)
    return obj["Body"].read().decode("utf-8")

def _read_s3_json(bucket: str, key: str) -> Dict[str, Any]:
    data = _read_s3_text(bucket, key)
    return json.loads(data)

def _put_s3_bytes(bucket: str, key: str, data: bytes, content_type: str) -> None:
    S3.put_object(Bucket=bucket, Key=key, Body=data, ContentType=content_type)

def _sec_to_hhmmss_msec_vtt(s: float) -> str:
    # 00:00:00.000
    ms = int(round(s * 1000))
    hours = ms // 3_600_000
    ms -= hours * 3_600_000
    minutes = ms // 60_000
    ms -= minutes * 60_000
    seconds = ms // 1000
    ms -= seconds * 1000
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}.{ms:03d}"

def _sec_to_hhmmss_msec_srt(s: float) -> str:
    # 00:00:00,000
    ms = int(round(s * 1000))
    hours = ms // 3_600_000
    ms -= hours * 3_600_000
    minutes = ms // 60_000
    ms -= minutes * 60_000
    seconds = ms // 1000
    ms -= seconds * 1000
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{ms:03d}"

def _derive_job_id_from_manifest_key(manifest_key: str) -> str:
    # expects "manifests/<job-id>.jsonl"
    name = os.path.basename(manifest_key)
    if name.endswith(".jsonl"):
        return name[:-6]
    return name

def _parse_manifest_jsonl(text: str) -> List[Dict[str, Any]]:
    """
    Each line must contain at least: {"index": int, "start_sec": float, "end_sec": float}
    """
    entries: List[Dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        # normalize keys
        entry = {
            "index": int(obj["index"]),
            "start_sec": float(obj["start_sec"]),
            "end_sec": float(obj["end_sec"]),
        }
        entries.append(entry)
    entries.sort(key=lambda x: x["index"])
    return entries

def _s3_key_exists(bucket: str, key: str) -> bool:
    try:
        S3.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as e:
        if e.response["ResponseMetadata"]["HTTPStatusCode"] == 404 or e.response["Error"]["Code"] in ("404", "NotFound", "NoSuchKey"):
            return False
        raise

def _guess_chunk_key(results_bucket: str, job_id: str, index: int) -> Optional[str]:
    """
    Try common layouts; fall back to listing.
    Expected: one out.json per chunk.
    """
    candidates = [
        f"chunks/{job_id}/{index:05d}/out.json",
        f"chunks/{job_id}/{index}/out.json",
        f"chunks/{job_id}/chunk-{index}/out.json",
    ]
    for k in candidates:
        if _s3_key_exists(results_bucket, k):
            return k
    # fallback: list and look for index-ish leaf folders
    prefix = f"chunks/{job_id}/"
    resp = S3.list_objects_v2(Bucket=results_bucket, Prefix=prefix)
    contents = resp.get("Contents", [])
    for c in contents:
        key = c["Key"]
        if key.endswith("/out.json"):
            # weak match: index appears in the parent path
            if f"/{index:05d}/" in key or f"/{index}/" in key or f"chunk-{index}/" in key:
                return key
    # final fallback: if only one out.json per job, return it (single chunk case)
    out_keys = [c["Key"] for c in contents if c["Key"].endswith("/out.json")]
    if len(out_keys) == 1:
        return out_keys[0]
    return None

def _load_chunk_segments(results_bucket: str, chunk_key: str) -> List[Dict[str, Any]]:
    data = _read_s3_json(results_bucket, chunk_key)
    segs = data.get("segments", [])
    # normalize
    norm: List[Dict[str, Any]] = []
    for s in segs:
        start = float(s.get("start", 0.0))
        end = float(s.get("end", 0.0))
        text = (s.get("text") or "").strip()
        if text == "":
            continue
        if end - start <= EPS:
            continue
        norm.append({"start": start, "end": end, "text": text})
    return norm

def _merge_segments(manifest: List[Dict[str, Any]], results_bucket: str, job_id: str) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
    """
    Returns (segments, meta)
    segments: [{id, start, end, text}]
    """
    merged: List[Dict[str, Any]] = []
    seg_id = 0
    last_end = 0.0
    meta = {"chunks": 0, "dropped_short": 0, "dropped_overlap": 0}

    for entry in manifest:
        idx = entry["index"]
        c_start = entry["start_sec"]
        c_end = entry["end_sec"]

        chunk_key = _guess_chunk_key(results_bucket, job_id, idx)
        if not chunk_key:
            # No chunk present — skip but continue
            continue

        segs = _load_chunk_segments(results_bucket, chunk_key)

        for s in segs:
            gs = s["start"] + c_start
            ge = s["end"] + c_start

            # clamp to chunk window (defensive)
            if ge < c_start + EPS or gs > c_end - EPS:
                continue
            gs = max(gs, c_start)
            ge = min(ge, c_end)

            # de-dupe overlap against previous global end
            if ge <= last_end + EPS:
                meta["dropped_overlap"] += 1
                continue
            if gs < last_end:
                gs = last_end  # trim left edge into the non-overlap

            # enforce min duration
            if ge - gs < MIN_SEGMENT_SEC:
                meta["dropped_short"] += 1
                continue

            merged.append({"id": seg_id, "start": round(gs, 3), "end": round(ge, 3), "text": s["text"]})
            seg_id += 1
            last_end = ge

        meta["chunks"] += 1

    # enforce strict monotonicity + fill micro-gaps (snap next start to last end)
    fixed: List[Dict[str, Any]] = []
    last = 0.0
    for seg in merged:
        s, e = seg["start"], seg["end"]
        if s < last:
            s = last
        # If there is a tiny gap, eliminate it by snapping start to last
        if s - last > 0:
            s = max(last, s)
        if e - s < MIN_SEGMENT_SEC:
            continue
        fixed.append({"id": len(fixed), "start": round(s, 3), "end": round(e, 3), "text": seg["text"]})
        last = e

    return fixed, meta

def _to_transcript_json(job_id: str, language: Optional[str], segments: List[Dict[str, Any]]) -> Dict[str, Any]:
    duration = segments[-1]["end"] if segments else 0.0
    return {
        "job_id": job_id,
        "language": language,
        "duration_sec": duration,
        "segments": segments,
    }

def _to_txt(segments: List[Dict[str, Any]]) -> str:
    # One line per segment (simple, lossless-ish)
    return "\n".join(s["text"] for s in segments) + ("\n" if segments else "")

def _to_vtt(segments: List[Dict[str, Any]]) -> str:
    lines = ["WEBVTT", ""]
    for s in segments:
        lines.append(f"{_sec_to_hhmmss_msec_vtt(s['start'])} --> {_sec_to_hhmmss_msec_vtt(s['end'])}")
        lines.append(s["text"])
        lines.append("")
    return "\n".join(lines)

def _to_srt(segments: List[Dict[str, Any]]) -> str:
    parts: List[str] = []
    for i, s in enumerate(segments, start=1):
        parts.append(str(i))
        parts.append(f"{_sec_to_hhmmss_msec_srt(s['start'])} --> {_sec_to_hhmmss_msec_srt(s['end'])}")
        parts.append(s["text"])
        parts.append("")
    return "\n".join(parts)

def _update_job_status(job_id: str, status: str, outputs: Dict[str, str]) -> None:
    if not DDB:
        return
    table_name = os.getenv("JOB_TABLE_NAME")
    table = DDB.Table(table_name)
    table.update_item(
        Key={"job_id": job_id},
        UpdateExpression="SET #s = :s, outputs = :o, updated_at = :t",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":s": status,
            ":o": outputs,
            ":t": int(__import__("time").time()),
        },
    )

def _notify(job_id: str, status: str, outputs: Dict[str, str], meta: Dict[str, Any]) -> None:
    if not SNS:
        return
    topic_arn = os.getenv("SNS_TOPIC_ARN")
    SNS.publish(
        TopicArn=topic_arn,
        Subject=f"Whisper stitcher: {job_id} {status}",
        Message=json.dumps({"job_id": job_id, "status": status, "outputs": outputs, "meta": meta}, ensure_ascii=False),
    )

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Expected event keys (from Step Functions input):
      - manifest_bucket
      - manifest_key     (e.g., 'manifests/<job-id>.jsonl')
      - results_bucket
      - language         (optional, pass-through)
    """
    manifest_bucket = event["manifest_bucket"]
    manifest_key = event["manifest_key"]
    results_bucket = event["results_bucket"]
    language = event.get("language")

    job_id = _derive_job_id_from_manifest_key(manifest_key)

    # 1) Read manifest.jsonl
    manifest_text = _read_s3_text(manifest_bucket, manifest_key)
    manifest = _parse_manifest_jsonl(manifest_text)

    # 2) Merge segments
    segments, meta = _merge_segments(manifest, results_bucket, job_id)

    # 3) Build outputs
    tjson = _to_transcript_json(job_id, language, segments)
    ttxt = _to_txt(segments)
    tvtt = _to_vtt(segments)
    tsrt = _to_srt(segments)

    # 4) Write to S3 final/<job-id>/
    final_prefix = f"final/{job_id}/"
    out_json_key = final_prefix + "transcript.json"
    out_txt_key = final_prefix + "transcript.txt"
    out_vtt_key = final_prefix + "transcript.vtt"
    out_srt_key = final_prefix + "transcript.srt"

    _put_s3_bytes(results_bucket, out_json_key, json.dumps(tjson, ensure_ascii=False).encode("utf-8"), "application/json")
    _put_s3_bytes(results_bucket, out_txt_key, ttxt.encode("utf-8"), "text/plain; charset=utf-8")
    _put_s3_bytes(results_bucket, out_vtt_key, tvtt.encode("utf-8"), "text/vtt; charset=utf-8")
    _put_s3_bytes(results_bucket, out_srt_key, tsrt.encode("utf-8"), "application/x-subrip; charset=utf-8")

    outputs = {
        "json": f"s3://{results_bucket}/{out_json_key}",
        "txt": f"s3://{results_bucket}/{out_txt_key}",
        "vtt": f"s3://{results_bucket}/{out_vtt_key}",
        "srt": f"s3://{results_bucket}/{out_srt_key}",
    }

    # 5) Optional side-effects
    _update_job_status(job_id, "COMPLETED", outputs)
    _notify(job_id, "COMPLETED", outputs, meta)

    return {
        "job_id": job_id,
        "outputs": outputs,
        "segments": len(segments),
        "meta": meta,
    }

# -------- Local runner (optional) --------
def _load_event_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Local runner for stitcher Lambda")
    parser.add_argument("--event", type=str, help="Path to a JSON file with the Step Functions input", required=False)
    args = parser.parse_args()
    if args.event:
        evt = _load_event_json(args.event)
    else:
        evt = {
            "manifest_bucket": "seerahscribe-ingest-<acct>-eu-west-1",
            "manifest_key": "manifests/<job-id>.jsonl",
            "results_bucket": "seerahscribe-results-<acct>-eu-west-1",
            "language": "en",
        }
    res = handler(evt, context=None)
    print(json.dumps(res, indent=2))