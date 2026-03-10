# runllm - Run vLLM on Kubernetes
# Usage: make start | query | test

-include ../.env
-include .env

KUBECONFIG ?= $(HOME)/cuda-play/CWKubeconfig_new-cluster
export KUBECONFIG

# Default vLLM deployment (VLLM_MODEL avoids clashing with parent .env MODEL)
VLLM_POD ?= vllm-qwen
VLLM_YAML ?= vllm-qwen.yaml
VLLM_MODEL ?= Qwen/Qwen2.5-1.5B-Instruct

.PHONY: apply forward start query test help

apply:
	kubectl apply -f $(VLLM_YAML)

forward:
	@echo "Forwarding localhost:8000 -> $(VLLM_POD):8000"
	@echo "Query with: make query PROMPT=\"Your prompt\""
	kubectl port-forward $(VLLM_POD) 8000:8000

# One-shot: deploy, wait for pod, background forward, wait for health
start: apply
	@echo "Waiting for pod Ready..."
	@kubectl wait --for=condition=Ready pod/$(VLLM_POD) --timeout=600s 2>/dev/null || true
	@pkill -f "kubectl port-forward $(VLLM_POD)" 2>/dev/null || true
	@sleep 2
	@echo "Starting port-forward (background)..."
	@kubectl port-forward $(VLLM_POD) 8000:8000 & PF_PID=$$!; \
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do \
		curl -sf http://localhost:8000/health >/dev/null 2>&1 && { echo "Ready at http://localhost:8000"; echo "Run: make query PROMPT=\"Hello\""; exit 0; }; \
		sleep 2; \
	done; \
	kill $$PF_PID 2>/dev/null; echo "Timeout: model not ready. Check pod with: kubectl logs -f $(VLLM_POD)"; exit 1

# Send a completion request (requires port-forward)
query:
	@MODEL="$(VLLM_MODEL)" PROMPT="$(PROMPT)" python3 query.py

# Smoke test: send request, verify response
test:
	@MODEL="$(VLLM_MODEL)" ./test_smoke.sh

help:
	@echo "runllm - Run vLLM on Kubernetes"
	@echo ""
	@echo "  make start     - Deploy + port-forward (one command, leaves forward running)"
	@echo "  make query     - Send completion (PROMPT=\"...\" required)"
	@echo "  make test      - Smoke test (requires port-forward)"
	@echo "  make apply     - Deploy pod only"
	@echo "  make forward   - Port-forward only (blocks; run in separate terminal)"
	@echo ""
	@echo "Config: VLLM_YAML=vllm-qwen.yaml, VLLM_MODEL=$(VLLM_MODEL)"
