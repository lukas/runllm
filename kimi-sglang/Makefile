# runllm/kimi-sglang — Kimi-K2.5 on SGLang (8× GPU)
# Usage: make start | query | test

-include ../../.env
-include .env

KUBECONFIG ?= $(CURDIR)/../../kubeconfig
export KUBECONFIG

VLLM_POD ?= sglang-kimi
POD_YAML ?= pod.yaml
VLLM_MODEL ?= moonshotai/Kimi-K2.5

.PHONY: apply delete-pod forward start query test help

delete-pod:
	kubectl delete pod $(VLLM_POD) --ignore-not-found=true
	@kubectl wait --for=delete pod/$(VLLM_POD) --timeout=120s 2>/dev/null || true
	@sleep 2

apply: delete-pod
	kubectl apply -f $(POD_YAML)

forward:
	@echo "Forwarding localhost:8000 -> $(VLLM_POD):8000"
	@echo "Query with: make query PROMPT=\"Your prompt\""
	kubectl port-forward $(VLLM_POD) 8000:8000

start: apply
	@echo "Waiting for pod Ready..."
	@kubectl wait --for=condition=Ready pod/$(VLLM_POD) --timeout=900s 2>/dev/null || true
	@echo "Waiting for SGLang to answer on /model_info (large model — may take 10-15 min)..."
	@pkill -f "kubectl port-forward $(VLLM_POD) 8000:8000" 2>/dev/null || true
	@kubectl port-forward $(VLLM_POD) 8000:8000 </dev/null >/dev/null 2>&1 & \
	PF_PID=$$!; \
	trap 'kill $$PF_PID 2>/dev/null || true' EXIT; \
	for i in $$(seq 1 450); do \
		curl -sf http://localhost:8000/model_info >/dev/null 2>&1 && break; \
		[ $$i -eq 450 ] && { echo "\nTimeout after 15 min. Check: kubectl logs -f $(VLLM_POD)"; exit 1; }; \
		elapsed=$$((i * 2)); \
		printf "\r  [%4ds] waiting for /health..." "$$elapsed"; \
		sleep 2; \
	done; \
	echo ""; \
	echo "Running sample query (90s timeout)..."; \
	payload='{"model":"$(VLLM_MODEL)","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}'; \
	out=$$(curl -sf -X POST http://localhost:8000/v1/chat/completions \
		-H "Content-Type: application/json" -d "$$payload" --max-time 90) || \
		{ echo "Sample query failed, hung, or timed out"; exit 1; }; \
	echo "$$out" | python3 -c "import json,sys; d=json.load(sys.stdin); m=(d.get('choices') or [{}])[0].get('message', {}) or {}; ok=(isinstance(m.get('content'), str) and m.get('content').strip()) or (isinstance(m.get('reasoning'), str) and m.get('reasoning').strip()) or (isinstance(m.get('reasoning_content'), str) and m.get('reasoning_content').strip()) or ((m.get('tool_calls') or []) != []); sys.exit(0 if ok else 1)" || \
		{ echo "Sample query returned empty response: $$out"; exit 1; }; \
	trap - EXIT
	@echo "Sample query OK"
	@echo "Ready at http://localhost:8000"
	@echo "Run: make query PROMPT=\"Hello\""

query:
	@MODEL="$(VLLM_MODEL)" PROMPT="$(PROMPT)" python3 query.py

test:
	@MODEL="$(VLLM_MODEL)" bash ./test_smoke.sh

help:
	@echo "runllm/kimi-sglang — Kimi-K2.5 on SGLang (8× GPU)"
	@echo ""
	@echo "  make start     - Deploy + port-forward"
	@echo "  make query     - Send chat completion (PROMPT=\"...\" required)"
	@echo "  make test      - Smoke test (requires port-forward)"
	@echo "  make apply     - Deploy pod only"
	@echo "  make forward   - Port-forward only"
	@echo ""
	@echo "Config: VLLM_YAML=$(POD_YAML), VLLM_MODEL=$(VLLM_MODEL)"
