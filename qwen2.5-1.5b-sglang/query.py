#!/usr/bin/env python3
"""Send a chat completion request to localhost:8000 (SGLang)."""
import json
import os
import sys
import urllib.error
import urllib.request

MODEL = os.environ.get("MODEL", "Qwen/Qwen2.5-1.5B-Instruct")
PROMPT = os.environ.get("PROMPT", "")
URL = "http://localhost:8000/v1/chat/completions"

if not PROMPT:
    print("Usage: make query PROMPT=\"Your prompt\"", file=sys.stderr)
    sys.exit(1)

payload = {
    "model": MODEL,
    "messages": [{"role": "user", "content": PROMPT}],
    "max_tokens": 128,
}
req = urllib.request.Request(
    URL,
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=60) as response:
        data = json.load(response)
except urllib.error.URLError as err:
    print(f"Error: {err}", file=sys.stderr)
    print("Is port-forward running? Run: make forward", file=sys.stderr)
    sys.exit(1)

choices = data.get("choices") or [{}]
content = choices[0].get("message", {}).get("content", "") if choices else ""
print(content.strip() if content else json.dumps(data, indent=2))
