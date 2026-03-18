#!/usr/bin/env python3
"""Send a chat completion request to localhost:8000 (SGLang Kimi + EAGLE-3)."""
import json
import os
import sys
import urllib.error
import urllib.request

MODEL = os.environ.get("MODEL", "moonshotai/Kimi-K2.5")
PROMPT = os.environ.get("PROMPT", "")
URL = "http://localhost:8000/v1/chat/completions"

if not PROMPT:
    print('Usage: make query PROMPT="Your prompt"', file=sys.stderr)
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
    with urllib.request.urlopen(req, timeout=90) as response:
        response_text = response.read().decode("utf-8", errors="replace")
except urllib.error.URLError as err:
    print(f"Error: {err}", file=sys.stderr)
    print("Is port-forward running? Run: make forward", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(response_text)
except json.JSONDecodeError:
    print("Error: API server returned invalid JSON.", file=sys.stderr)
    if response_text.strip():
        print(response_text.strip(), file=sys.stderr)
    print("Is the server healthy? Check logs or re-run: make forward", file=sys.stderr)
    sys.exit(1)

choices = data.get("choices") or [{}]
message = choices[0].get("message", {}) if choices else {}
content = message.get("content")
reasoning = message.get("reasoning")
reasoning_content = message.get("reasoning_content")
if isinstance(content, str) and content.strip():
    print(content.strip())
elif isinstance(reasoning, str) and reasoning.strip():
    print(reasoning.strip())
elif isinstance(reasoning_content, str) and reasoning_content.strip():
    print(reasoning_content.strip())
else:
    print(json.dumps(data, indent=2))
