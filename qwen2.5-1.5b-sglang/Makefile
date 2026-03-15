# runllm/qwen2.5-1.5b-sglang — Qwen2.5-1.5B-Instruct on SGLang (1× GPU)
# Usage: make start | query | test

-include ../../.env
-include .env

KUBECONFIG ?= $(CURDIR)/../../kubeconfig
export KUBECONFIG

VLLM_POD ?= sglang-qwen
VLLM_YAML ?= vllm-config.yaml
VLLM_MODEL ?= Qwen/Qwen2.5-1.5B-Instruct

.PHONY: apply delete-pod forward start query test help

delete-pod:
	kubectl delete pod $(VLLM_POD) --ignore-not-found=true
	@kubectl wait --for=delete pod/$(VLLM_POD) --timeout=90s 2>/dev/null || true
	@sleep 2

apply: delete-pod
	kubectl apply -f $(VLLM_YAML)

forward:
	@echo "Forwarding localhost:8000 -> $(VLLM_POD):8000"
	@echo "Query with: make query PROMPT=\"Your prompt\""
	kubectl port-forward $(VLLM_POD) 8000:8000

start: apply
	@echo "Waiting for pod Ready..."
	@kubectl wait --for=condition=Ready pod/$(VLLM_POD) --timeout=600s 2>/dev/null || true
	@echo "Waiting for SGLang to answer on /health (may take 2-5 min)..."
	@pkill -f "kubectl port-forward $(VLLM_POD) 8000:8000" 2>/dev/null || true
	@kubectl port-forward $(VLLM_POD) 8000:8000 </dev/null >/dev/null 2>&1 & \
	PF_PID=$$!; \
	trap 'kill $$PF_PID 2>/dev/null || true' EXIT; \
	for i in $$(seq 1 180); do \
		curl -sf http://localhost:8000/health >/dev/null 2>&1 && break; \
		[ $$i -eq 180 ] && { echo "\nTimeout after 6 min. Check: kubectl logs -f $(VLLM_POD)"; exit 1; }; \
		elapsed=$$((i * 2)); \
		printf "\r  [%3ds] waiting for /health..." "$$elapsed"; \
		sleep 2; \
	done; \
	echo ""; \
	echo "Running sample query (60s timeout)..."; \
	payload='{"model":"$(VLLM_MODEL)","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}'; \
	curl -sf -X POST http://localhost:8000/v1/chat/completions \
		-H "Content-Type: application/json" -d "$$payload" --max-time 60 >/dev/null || \
		{ echo "Sample query failed, hung, or timed out"; exit 1; }; \
	trap - EXIT
	@echo "Sample query OK"
	@echo "Ready at http://localhost:8000"
	@echo "Run: make query PROMPT=\"Hello\""

query:
	@MODEL="$(VLLM_MODEL)" PROMPT="$(PROMPT)" python3 query.py

test:
	@MODEL="$(VLLM_MODEL)" bash ./test_smoke.sh

help:
	@echo "runllm/qwen2.5-1.5b-sglang — Qwen2.5-1.5B-Instruct on SGLang (1× GPU)"
	@echo ""
	@echo "  make start     - Deploy + port-forward"
	@echo "  make query     - Send chat completion (PROMPT=\"...\" required)"
	@echo "  make test      - Smoke test (requires port-forward)"
	@echo "  make apply     - Deploy pod only"
	@echo "  make forward   - Port-forward only"
	@echo ""
	@echo "Config: VLLM_YAML=$(VLLM_YAML), VLLM_MODEL=$(VLLM_MODEL)"
