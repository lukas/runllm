# runllm

Run vLLM models on Kubernetes. Deploy, port-forward, and test.

## Setup

1. Set `KUBECONFIG` to your cluster config.
2. Ensure the `hf-token` secret exists for gated models.

## Usage

```bash
make apply          # Deploy vLLM pod
make forward        # Port-forward localhost:8000 → vllm-qwen:8000 (run in separate terminal)
make test           # Send a test request
```

## Config

- `vllm-qwen.yaml` – Qwen2.5-1.5B-Instruct (1 GPU)
- `vllm-kimi.yaml` – Kimi-K2.5 (8 GPUs, TP=8)

Edit the YAML to change model, args, or resources.
