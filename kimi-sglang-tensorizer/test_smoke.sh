#!/usr/bin/env bash
# Smoke test: verify SGLang Kimi (tensorizer) responds to a chat completion request.
# Requires port-forward (make forward) or run after make start.
set -e
MODEL="${MODEL:-moonshotai/Kimi-K2.5}"
echo "Smoke test: GET model_info, then chat completion..."
curl -sf http://localhost:8000/model_info >/dev/null || { echo "FAIL: /model_info not reachable. Run: make forward"; exit 1; }
out=$(curl -sf http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in one short sentence.\"}],\"max_tokens\":32}" 2>/dev/null) || { echo "FAIL: No response"; exit 1; }
text=$(echo "$out" | python3 -c "import sys,json; d=json.load(sys.stdin); m=(d.get('choices') or [{}])[0].get('message', {}) or {}; text=m.get('content') or m.get('reasoning') or m.get('reasoning_content') or ''; print(text if isinstance(text, str) else '')" 2>/dev/null)
[ -n "$text" ] || { echo "FAIL: Invalid response: $out"; exit 1; }
echo "OK: $text"
