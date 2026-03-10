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

# One-shot: deploy, wait for pod, wait for vLLM health (via exec), then port-forward
start: apply
	@echo "Waiting for pod Ready..."
	@kubectl wait --for=condition=Ready pod/$(VLLM_POD) --timeout=600s 2>/dev/null || true
	@echo "Waiting for vLLM to listen (may take 1-2 min)..."
	@for i in $$(seq 1 90); do \
		kubectl exec $(VLLM_POD) -- curl -sf http://localhost:8000/health >/dev/null 2>&1 && break; \
		[ $$i -eq 90 ] && { echo "Timeout. Check: kubectl logs -f $(VLLM_POD)"; exit 1; }; \
		sleep 2; \
	done
	@pkill -f "kubectl port-forward $(VLLM_POD)" 2>/dev/null || true
	@sleep 2
	@echo "Starting port-forward (background)..."
	@kubectl port-forward $(VLLM_POD) 8000:8000 &
	@sleep 2
	@echo "Ready at http://localhost:8000"
	@echo "Run: make query PROMPT=\"Hello\""

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
