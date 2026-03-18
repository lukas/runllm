# runllm/kimi-trt — Kimi-K2.5 on TensorRT-LLM (8× GPU)
# Usage: make start | query | test

-include ../../.env
-include .env

KUBECONFIG ?= $(CURDIR)/../../kubeconfig
export KUBECONFIG

VLLM_POD ?= trtllm-kimi
POD_YAML ?= pod.yaml
VLLM_MODEL ?= moonshotai/Kimi-K2.5

.PHONY: apply delete-pod forward start query test help

delete-pod:
	kubectl delete pod $(VLLM_POD) --ignore-not-found=true
	@kubectl wait --for=delete pod/$(VLLM_POD) --timeout=90s 2>/dev/null || true
	@sleep 2

apply: delete-pod
	kubectl apply -f $(POD_YAML)

forward:
	@echo "Forwarding localhost:8000 -> $(VLLM_POD):8000"
	@echo "Query with: make query PROMPT=\"Your prompt\""
	kubectl port-forward $(VLLM_POD) 8000:8000

start: apply
	@echo "Waiting for pod Ready..."
	@kubectl wait --for=condition=Ready pod/$(VLLM_POD) --timeout=600s 2>/dev/null || true
	@echo "Waiting for TensorRT-LLM to listen (large model — may take 10-15 min for engine build)..."
	@echo "Streaming pod logs while waiting..."
	@kubectl logs -f $(VLLM_POD) --tail=5 2>/dev/null &\
	LOGPID=$$!; \
	for i in $$(seq 1 600); do \
		kubectl exec $(VLLM_POD) -- curl -sf http://localhost:8000/health >/dev/null 2>&1 && break; \
		[ $$i -eq 600 ] && { kill $$LOGPID 2>/dev/null; echo "Timeout after 20 min."; exit 1; }; \
		sleep 2; \
	done; \
	kill $$LOGPID 2>/dev/null || true; \
	wait $$LOGPID 2>/dev/null || true
	@echo ""
	@echo "TensorRT-LLM is healthy."
	@echo "Running sample query (120s timeout)..."
	@payload='{"model":"$(VLLM_MODEL)","messages":[{"role":"user","content":"Say hi"}],"max_tokens":16}'; \
	kubectl exec $(VLLM_POD) -- curl -sf -X POST http://localhost:8000/v1/chat/completions \
		-H "Content-Type: application/json" -d "$$payload" --max-time 120 >/dev/null || \
		{ echo "Sample query failed, hung, or timed out"; exit 1; }
	@echo "Sample query OK"
	@pkill -f "kubectl port-forward $(VLLM_POD)" 2>/dev/null || true
	@sleep 2
	@echo "Starting port-forward (background)..."
	@kubectl port-forward $(VLLM_POD) 8000:8000 </dev/null >/dev/null 2>&1 &
	@sleep 2
	@echo "Ready at http://localhost:8000"
	@echo "Run: make query PROMPT=\"Hello\""

query:
	@MODEL="$(VLLM_MODEL)" PROMPT="$(PROMPT)" python3 query.py

test:
	@MODEL="$(VLLM_MODEL)" ./test_smoke.sh

help:
	@echo "runllm/kimi-trt — Kimi-K2.5 on TensorRT-LLM (8× GPU)"
	@echo ""
	@echo "  make start     - Deploy + port-forward"
	@echo "  make query     - Send chat completion (PROMPT=\"...\" required)"
	@echo "  make test      - Smoke test (requires port-forward)"
	@echo "  make apply     - Deploy pod only"
	@echo "  make forward   - Port-forward only"
	@echo ""
	@echo "Config: VLLM_YAML=$(POD_YAML), VLLM_MODEL=$(VLLM_MODEL)"
