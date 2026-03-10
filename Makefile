# runllm - Run vLLM on Kubernetes
# Usage: make apply | forward | test

-include ../.env
-include .env

KUBECONFIG ?= $(HOME)/cuda-play/CWKubeconfig_new-cluster
export KUBECONFIG

# Default vLLM deployment
VLLM_POD ?= vllm-qwen
VLLM_YAML ?= vllm-qwen.yaml

.PHONY: apply forward test help

apply:
	kubectl apply -f $(VLLM_YAML)

forward:
	@echo "Forwarding localhost:8000 -> $(VLLM_POD):8000"
	@echo "Test with: curl http://localhost:8000/v1/completions -d '{\"model\":\"Qwen/Qwen2.5-1.5B-Instruct\",\"prompt\":\"Hello\",\"max_tokens\":32}'"
	kubectl port-forward $(VLLM_POD) 8000:8000

test:
	@echo "Testing $(VLLM_POD) (requires port-forward in another terminal)"
	curl -s http://localhost:8000/v1/completions -H "Content-Type: application/json" \
		-d '{"model":"Qwen/Qwen2.5-1.5B-Instruct","prompt":"Explain quantum computing in one sentence.","max_tokens":64}' | \
		python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('choices',[{}])[0].get('text','') or d)"

help:
	@echo "runllm - Run vLLM on Kubernetes"
	@echo ""
	@echo "  make apply     - Deploy vLLM pod (kubectl apply)"
	@echo "  make forward   - Port-forward localhost:8000 (run in separate terminal)"
	@echo "  make test      - Send test request"
	@echo ""
	@echo "Config: VLLM_YAML=vllm-qwen.yaml (default) or vllm-kimi.yaml"
