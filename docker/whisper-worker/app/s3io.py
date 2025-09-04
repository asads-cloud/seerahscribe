import sys, os
import urllib.parse as up
import boto3

def parse_s3(uri: str):
    if not uri.startswith("s3://"):
        raise ValueError("Not an S3 URI")
    p = up.urlparse(uri)
    bucket, key = p.netloc, p.path.lstrip("/")
    if not bucket or not key:
        raise ValueError(f"Bad S3 URI: {uri}")
    return bucket, key

def main():
    if len(sys.argv) < 2:
        print("usage: s3io.py [get s3://b/k LOCAL] | [put LOCAL s3://b/k]", file=sys.stderr); sys.exit(2)
    cmd = sys.argv[1]
    s3 = boto3.client("s3")
    if cmd == "get":
        if len(sys.argv) != 4: print("usage: s3io.py get s3://bucket/key LOCAL", file=sys.stderr); sys.exit(2)
        s3_uri, local = sys.argv[2], sys.argv[3]
        b, k = parse_s3(s3_uri)
        os.makedirs(os.path.dirname(local) or ".", exist_ok=True)
        s3.download_file(b, k, local)
        print(f"[s3io] downloaded {s3_uri} -> {local}")
    elif cmd == "put":
        if len(sys.argv) != 4: print("usage: s3io.py put LOCAL s3://bucket/key", file=sys.stderr); sys.exit(2)
        local, s3_uri = sys.argv[2], sys.argv[3]
        b, k = parse_s3(s3_uri)
        s3.upload_file(local, b, k)
        print(f"[s3io] uploaded {local} -> {s3_uri}")
    else:
        print("unknown command", file=sys.stderr); sys.exit(2)

if __name__ == "__main__":
    main()
