# runllm

Run vLLM models on Kubernetes. Deploy, port-forward, and query.

## Setup

1. Set `KUBECONFIG` to your cluster config.
2. Ensure the `hf-token` secret exists for gated models.

## Quick start

```bash
make start                    # Deploy + port-forward (one command)
make query PROMPT="Hello"     # Send a prompt
make test                     # Smoke test
```

## Commands

| Command | Description |
|---------|-------------|
| `make start` | Deploy pod, wait for ready, start port-forward (background) |
| `make query PROMPT="..."` | Send completion request |
| `make test` | Smoke test (verifies model responds) |
| `make apply` | Deploy only |
| `make forward` | Port-forward only (blocks; run in separate terminal) |

## Config

- `vllm-qwen.yaml` – Qwen2.5-1.5B-Instruct (1 GPU)
- `vllm-kimi.yaml` – Kimi-K2.5 (8 GPUs, TP=8)

Edit the YAML to change model, args, or resources. Override with `VLLM_MODEL=...` if the served model differs from the default.
