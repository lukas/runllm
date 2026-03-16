#!/usr/bin/env python3
"""Send a chat completion request to localhost:8000 (vLLM)."""
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

# Chat API: instruct models expect messages format; vLLM applies the chat template
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
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
except urllib.error.URLError as e:
    print(f"Error: {e}", file=sys.stderr)
    print("Is port-forward running? Run: make forward", file=sys.stderr)
    sys.exit(1)

# Chat API returns content in message, not text
choices = data.get("choices") or [{}]
content = choices[0].get("message", {}).get("content", "") if choices else ""
print(content.strip() if content else json.dumps(data, indent=2))
