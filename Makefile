# runllm - Run vLLM on Kubernetes
# Usage: make start | query | test

-include ../.env
-include .env

# Inherits from parent when run via autollm; otherwise uses autollm/kubeconfig
KUBECONFIG ?= $(CURDIR)/../kubeconfig
export KUBECONFIG

# Default vLLM deployment (VLLM_MODEL avoids clashing with parent .env MODEL)
VLLM_POD ?= vllm-qwen
VLLM_YAML ?= vllm-qwen.yaml
VLLM_MODEL ?= Qwen/Qwen2.5-1.5B-Instruct

.PHONY: apply delete-pod forward start query test help

# Delete pod so apply can recreate with new spec (K8s forbids changing container args on update)
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
	@echo "Running sample query (30s timeout)..."
	@payload='{"model":"$(VLLM_MODEL)","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}'; \
	kubectl exec $(VLLM_POD) -- curl -sf -X POST http://localhost:8000/v1/chat/completions \
		-H "Content-Type: application/json" -d "$$payload" --max-time 30 >/dev/null || \
		{ echo "Sample query failed, hung, or timed out"; exit 1; }
	@echo "Sample query OK"
	@pkill -f "kubectl port-forward $(VLLM_POD)" 2>/dev/null || true
	@sleep 2
	@echo "Starting port-forward (background)..."
	@kubectl port-forward $(VLLM_POD) 8000:8000 </dev/null >/dev/null 2>&1 &
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
	@echo "  make query     - Send chat completion (PROMPT=\"...\" required)"
	@echo "  make test      - Smoke test (requires port-forward)"
	@echo "  make apply     - Deploy pod only"
	@echo "  make forward   - Port-forward only (blocks; run in separate terminal)"
	@echo ""
	@echo "Config: VLLM_YAML=$(VLLM_YAML), VLLM_MODEL=$(VLLM_MODEL)"
	@echo "KUBECONFIG: $(KUBECONFIG)"
