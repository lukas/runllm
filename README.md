# runllm

Run vLLM models on Kubernetes. Each model has a self-contained subdirectory.

## Structure

```
runllm/
  qwen2.5-1.5b/         Qwen2.5-1.5B-Instruct (1× GPU)
  qwen2.5-1.5b-sglang/  Qwen2.5-1.5B-Instruct on SGLang (1× GPU)
  qwen3-235b/            Qwen3-235B-A22B MoE (4× GPU)
  kimi-vllm/             Kimi-K2.5 on vLLM (8× GPU)
  kimi-sglang/           Kimi-K2.5 on SGLang (8× GPU)
  kimi-sglang-eagle/     Kimi-K2.5 on SGLang + EAGLE-3 speculative decoding (8× GPU)
  kimi-trt/              Kimi-K2.5 on TensorRT-LLM (8× GPU)
```

Each directory contains:
- `pod.yaml` — K8s Pod spec
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
cd qwen2.5-1.5b-sglang
make start                    # Deploy Qwen2.5-1.5B-Instruct on SGLang
```

```bash
cd qwen3-235b
make start                    # Deploy Qwen3-235B-A22B on 4× GPU
```

```bash
cd kimi-vllm
make start                    # Deploy Kimi-K2.5 on vLLM (8× GPU)
```

```bash
cd kimi-sglang
make start                    # Deploy Kimi-K2.5 on SGLang (8× GPU)
```

```bash
cd kimi-sglang-eagle
make start                    # Deploy Kimi-K2.5 on SGLang + EAGLE-3 (8× GPU)
```

```bash
cd kimi-trt
make start                    # Deploy Kimi-K2.5 on TensorRT-LLM (8× GPU)
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

## SGLang variant

`qwen2.5-1.5b-sglang/`, `kimi-sglang/`, and `kimi-sglang-eagle/` keep the same `runllm` surface (`pod.yaml`, `Makefile`, `query.py`, `test_smoke.sh`) so they can be used like the vLLM model dirs, but the pod launches `sglang serve` instead of `vllm serve`.

For sweeps, `autollm` treats explicit backend directories as sibling variants of the same model family. For example, a Kimi family sweep can compare `kimi-vllm/`, `kimi-sglang/`, and `kimi-sglang-eagle/` in the same improve loop, and a Qwen 1.5B family sweep can compare `qwen2.5-1.5b/` and `qwen2.5-1.5b-sglang/`.

`kimi-sglang/query.py` now treats non-JSON responses as a query-path bug and prints the raw server response before exiting. This makes broken port-forwards or unhealthy API responses much easier to diagnose than a bare JSON decode failure.

## Model loading

Large models generally use [Tensorizer](https://github.com/coreweave/tensorizer) to pre-serialize weights to a shared PVC (`models`, 5Ti). This cuts startup time dramatically — loading pre-serialized tensors from local NVMe is much faster than downloading safetensors from HuggingFace Hub on every pod start.

**One-time setup:** Run the serialize job to write tensors to the PVC:

```bash
kubectl apply -f models-pvc.yaml                   # create PVC (once)
kubectl apply -f qwen3-235b/serialize-job.yaml     # serialize model weights
```

The job downloads the model from HF, serializes it with tensor-parallel sharding, and writes the result to `/mnt/models/`. Subsequent pod starts mount that PVC read-only and pass `--load-format tensorizer` to vLLM.

### Kimi-K2.5 exception

`kimi-vllm/` currently uses standard HuggingFace safetensors loading with `--download-dir /mnt/models/hf-cache` and `--trust-remote-code`, not tensorizer. This is the currently working vLLM deploy path for Kimi-K2.5 because the tensorized path hit multiple incompatibilities with its multimodal + quantized model stack.

`kimi-sglang-eagle/` serves Kimi-K2.5 on SGLang with EAGLE-3 speculative decoding using `lightseekorg/kimi-k2.5-eagle3` as the draft model. Both the main model and draft model are cached on the PVC via `HF_HOME=/mnt/models/hf-cache`.

Operational implications:
- Kimi startup is slower than the tensorized Qwen paths.
- The shared PVC still matters because it caches the HF safetensors under `/mnt/models/hf-cache`.
- Benchmarks and sample queries must allow the Kimi tokenizer/processor custom code (`trust_remote_code=True`) to match the serving path.

### Runtime patches for tensorized MoE models

The latest vLLM nightly has two bugs that break tensorizer loading for Mixture-of-Experts models. The `pod.yaml` for affected tensorized models (for example `qwen3-235b/`) applies two inline patches at container startup:

1. **Patch 1 — MetaTensorMode factory ops** (vllm#25751): vLLM's `MetaTensorMode` only intercepts `aten::empty`, but MoE layers use other tensor factory ops (`aten::zeros`, `aten::ones`, `aten::full`, etc.). Without this patch, model initialization crashes because those ops try to allocate on the wrong device. The patch expands the intercept list to 18 factory ops.

2. **Patch 2 — process_weights_after_loading**: vLLM's `TensorizerLoader` skips `process_weights_after_loading` after deserializing weights. For MoE models this step is required — it initializes the fused MoE kernels and converts weight layouts. Without it the model loads but produces garbage output. The patch adds the missing call.

These patches are applied via `sed`/`python3` at startup and are idempotent (safe to re-run). They should be removed once upstream vLLM fixes land.

## Adding a new model

1. Create a new directory: `mkdir runllm/my-model`
2. Add `pod.yaml` with the K8s Pod spec (set `metadata.name`, model args, GPU count)
3. Copy `Makefile`, `query.py`, `test_smoke.sh` from an existing model dir
4. Update Makefile defaults: `VLLM_POD`, `VLLM_MODEL`
5. Test: `cd runllm/my-model && make start`

## Used by autollm

The parent [autollm](https://github.com/lukas/autollm) repo uses `runllm/` as a submodule. The Makefile inherits `KUBECONFIG` from autollm. During sweep runs, autollm copies the chosen model directory into an isolated per-run directory (`results/sweep-NAME/TIMESTAMP/runllm/`). The agent edits only that copy — the canonical `runllm/` is never modified. Agent conversations and tool calls are recorded in the parent repo's local `agent.log` files; `runllm/` itself remains just the canonical serving configs and query helpers.
