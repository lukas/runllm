#!/usr/bin/env python3
"""Send a chat completion request to localhost:8000 (TensorRT-LLM)."""
import json
import os
import sys
import urllib.request

MODEL = os.environ.get("MODEL", "moonshotai/Kimi-K2.5")
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
    with urllib.request.urlopen(req, timeout=120) as r:
        body = r.read()
except urllib.error.URLError as e:
    print(f"Error: {e}", file=sys.stderr)
    print("Is port-forward running? Run: make forward", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(body)
except (json.JSONDecodeError, ValueError):
    print(f"Non-JSON response from server:\n{body.decode(errors='replace')}", file=sys.stderr)
    sys.exit(1)

choices = data.get("choices") or [{}]
msg = choices[0].get("message", {}) if choices else {}
content = msg.get("content", "")
reasoning = msg.get("reasoning_content") or msg.get("reasoning") or ""
if reasoning and not content:
    print(reasoning.strip())
elif content:
    print(content.strip())
else:
    print(json.dumps(data, indent=2))
