"""Optional: upload processed sounds with Roblox's official Open Cloud Assets API.

Needs your own Open Cloud API key with the "assets" read + write permission:
    set ROBLOX_API_KEY=...            (PowerShell: $env:ROBLOX_API_KEY = "...")
    python tools/audio/upload_opencloud.py --user-id 11736753688            # dry run: lists files
    python tools/audio/upload_opencloud.py --user-id 11736753688 --yes      # uploads priority 1
    python tools/audio/upload_opencloud.py --group-id 1234567 --priority 2 --limit 10 --yes

Audio upload limits (Roblox): 10 per month without ID verification, 100 per month with it,
7 minutes max. Upload as the account or group that owns the experience, or the game cannot
play the sound. Each new asset ID is recorded in sfx_manifest.json; run sync_ids.py afterwards
to write the IDs into Config.Sounds. Docs: https://create.roblox.com/docs/cloud/guides/usage-assets
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audiolib as A  # noqa: E402

API = "https://apis.roblox.com/assets/v1"


def multipart(fields: dict[str, tuple[str, bytes, str | None]]) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    body = bytearray()
    for name, (filename, data, ctype) in fields.items():
        body += f"--{boundary}\r\n".encode()
        disp = f'form-data; name="{name}"' + (f'; filename="{filename}"' if filename else "")
        body += f"Content-Disposition: {disp}\r\n".encode()
        if ctype:
            body += f"Content-Type: {ctype}\r\n".encode()
        body += b"\r\n" + data + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return bytes(body), f"multipart/form-data; boundary={boundary}"


def call(method: str, url: str, key: str, body: bytes | None = None, ctype: str | None = None) -> dict:
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key})
    if ctype:
        req.add_header("Content-Type", ctype)
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read() or b"{}")


def upload(asset: dict, key: str, creator: dict) -> int:
    path = A.ROOT / asset["file_processed"]
    request = {
        "assetType": "Audio",
        "displayName": f"SMB {asset['id']}"[:50],
        "description": "; ".join(asset["gameplay_events"])[:1000],
        "creationContext": {"creator": creator},
    }
    body, ctype = multipart({
        "request": ("", json.dumps(request).encode(), None),
        "fileContent": (path.name, path.read_bytes(), "audio/ogg"),
    })
    op = call("POST", f"{API}/assets", key, body, ctype)
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = call("GET", f"{API}/operations/{op_id}", key)
    if not op.get("done"):
        raise RuntimeError(f"upload of {asset['id']} still processing (operation {op_id}); check Creator Hub")
    if "error" in op:
        raise RuntimeError(f"upload of {asset['id']} failed: {op['error']}")
    return int(op["response"]["assetId"])


def main() -> int:
    ap = argparse.ArgumentParser()
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--user-id")
    who.add_argument("--group-id")
    ap.add_argument("--priority", type=int, default=1, help="upload files up to this priority (1-3)")
    ap.add_argument("--limit", type=int, default=10, help="most uploads this run (monthly quota!)")
    ap.add_argument("--yes", action="store_true", help="actually upload (otherwise only list)")
    args = ap.parse_args()

    manifest = json.loads(A.MANIFEST.read_text(encoding="utf-8"))
    todo = [a for a in manifest["assets"] if a.get("processing_status") == "processed"
            and not a.get("roblox_asset_id") and a["upload_priority"] <= args.priority]
    todo.sort(key=lambda a: (a["upload_priority"], a["id"]))
    todo = todo[: args.limit]
    for a in todo:
        print(f"P{a['upload_priority']} {a['id']:18} {a['file_processed']}")
    if not args.yes:
        print(f"\n{len(todo)} file(s). Dry run: add --yes to upload.")
        return 0
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        print("ROBLOX_API_KEY is not set")
        return 1
    creator = {"userId": str(args.user_id)} if args.user_id else {"groupId": str(args.group_id)}
    by_id = {a["id"]: a for a in manifest["assets"]}
    for a in todo:
        try:
            asset_id = upload(a, key, creator)
        except (urllib.error.HTTPError, RuntimeError) as err:
            detail = err.read().decode(errors="replace") if isinstance(err, urllib.error.HTTPError) else str(err)
            print(f"{a['id']}: FAILED {detail}")
            break
        by_id[a["id"]]["roblox_asset_id"] = asset_id
        by_id[a["id"]]["upload_status"] = "uploaded"
        A.MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"{a['id']}: uploaded as {asset_id}")
    print("Next: python tools/audio/sync_ids.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
