#!/usr/bin/env bash
# Smoke test: verify vLLM responds to a chat completion request.
# Requires port-forward (make forward) or run after make start.
set -e
MODEL="${MODEL:-moonshotai/Kimi-K2.5}"
echo "Smoke test: GET health, then chat completion..."
curl -sf http://localhost:8000/health >/dev/null || { echo "FAIL: /health not reachable. Run: make forward"; exit 1; }
out=$(curl -sf http://localhost:8000/v1/chat/completions -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in one word.\"}],\"max_tokens\":16}" 2>/dev/null) || { echo "FAIL: No response"; exit 1; }
text=$(echo "$out" | python3 -c "import sys,json; d=json.load(sys.stdin); c=d.get('choices',[]); print(c[0].get('message',{}).get('content','') if c else '')" 2>/dev/null)
[ -n "$text" ] || { echo "FAIL: Invalid response: $out"; exit 1; }
echo "OK: $text"
