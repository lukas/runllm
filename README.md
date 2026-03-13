# runllm

Run vLLM models on Kubernetes. Each model has a self-contained subdirectory.

## Structure

```
runllm/
  qwen2.5-1.5b/    Qwen2.5-1.5B-Instruct (1× GPU)
  qwen3-235b/       Qwen3-235B-A22B MoE (4× GPU)
  kimi/              Kimi-K2.5 (8× GPU)
```

Each directory contains:
- `vllm-config.yaml` — K8s Pod spec
- `Makefile` — deploy, port-forward, query, test
- `query.py` — send chat completion requests
- `test_smoke.sh` — smoke test

## Setup

1. Set `KUBECONFIG` to your cluster config, or use `autollm/kubeconfig` when run as a submodule.
2. Ensure the `hf-token` secret exists for gated models: `kubectl create secret generic hf-token --from-literal=token=YOUR_HF_TOKEN`

## Quick start

```bash
cd qwen2.5-1.5b
make start                    # Deploy + wait for ready + sample query + port-forward
make query PROMPT="Hello"     # Send a prompt
make test                     # Smoke test
```

```bash
cd qwen3-235b
make start                    # Deploy Qwen3-235B-A22B on 4× GPU
```

## Commands (same in every model directory)

| Command | Description |
|---------|-------------|
| `make start` | Deploy pod, wait for ready, run sample query, start port-forward (background) |
| `make query PROMPT="..."` | Send chat completion request |
| `make test` | Smoke test (verifies model responds) |
| `make apply` | Delete + redeploy pod only |
| `make forward` | Port-forward only (blocks; run in separate terminal) |
| `make delete-pod` | Delete the vLLM pod |

## Adding a new model

1. Create a new directory: `mkdir runllm/my-model`
2. Add `vllm-config.yaml` with the K8s Pod spec (set `metadata.name`, model args, GPU count)
3. Copy `Makefile`, `query.py`, `test_smoke.sh` from an existing model dir
4. Update Makefile defaults: `VLLM_POD`, `VLLM_MODEL`
5. Test: `cd runllm/my-model && make start`

## Used by autollm

When used as a submodule inside [autollm](../), the Makefile inherits `KUBECONFIG` from the parent. During sweep runs, autollm copies the chosen model directory into an isolated per-run directory (`results/sweep-NAME/TIMESTAMP/runllm/`). The agent edits only that copy — the canonical `runllm/` is never modified.
