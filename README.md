# runllm

Run vLLM models on Kubernetes. Deploy, port-forward, send chat-completions queries, and verify.

## Setup

1. Set `KUBECONFIG` to your cluster config, or use `autollm/kubeconfig` when run as a submodule.
2. Ensure the `hf-token` secret exists for gated models: `kubectl create secret generic hf-token --from-literal=token=YOUR_HF_TOKEN`

## Quick start

```bash
make start                    # Deploy + wait for ready + sample query + port-forward
make query PROMPT="Hello"     # Send a prompt
make test                     # Smoke test
```

## Commands

| Command | Description |
|---------|-------------|
| `make start` | Deploy pod, wait for ready, run sample query, start port-forward (background) |
| `make query PROMPT="..."` | Send chat completion request |
| `make test` | Smoke test (verifies model responds) |
| `make apply` | Delete + redeploy pod only |
| `make forward` | Port-forward only (blocks; run in separate terminal) |
| `make delete-pod` | Delete the vLLM pod |

## Config

- `vllm-qwen.yaml` - Qwen2.5-1.5B-Instruct (1x GPU, nightly image)
- `vllm-kimi.yaml` - Kimi-K2.5 (8x GPUs, TP=8)

Edit the YAML to change model, args, or resources. Override with `VLLM_MODEL=...` if the served model name differs from the default.

## Kubeconfig behavior

- `runllm/Makefile` respects an already-exported `KUBECONFIG`.
- When used inside `autollm`, it defaults to `../kubeconfig`.
- For standalone usage, export `KUBECONFIG=/path/to/your/config` before running `make start`.

## Used by autollm

When used as a submodule inside [autollm](../), the Makefile inherits `KUBECONFIG` from the parent. The `make start` flow (deploy, health check, sample query, port-forward) is also called by autollm's benchmark harness.
