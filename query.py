#!/usr/bin/env python3
"""Send a completion request to localhost:8000 (vLLM)."""
import json
import os
import sys
import urllib.request

MODEL = os.environ.get("MODEL", "Qwen/Qwen2.5-1.5B-Instruct")
PROMPT = os.environ.get("PROMPT", "")
URL = "http://localhost:8000/v1/completions"

if not PROMPT:
    print("Usage: make query PROMPT=\"Your prompt\"", file=sys.stderr)
    sys.exit(1)

req = urllib.request.Request(
    URL,
    data=json.dumps({"model": MODEL, "prompt": PROMPT, "max_tokens": 128}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
except urllib.error.URLError as e:
    print(f"Error: {e}", file=sys.stderr)
    print("Is port-forward running? Run: make forward", file=sys.stderr)
    sys.exit(1)

text = (data.get("choices") or [{}])[0].get("text", "")
print(text.strip() if text else json.dumps(data, indent=2))
