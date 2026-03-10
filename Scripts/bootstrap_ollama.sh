#!/usr/bin/env bash
set -euo pipefail

MODEL_LOCAL="qwen3:4b"
MODEL_CLOUD="gpt-oss:120b-cloud"

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is not installed. Install from https://ollama.com/download"
  exit 1
fi

if ! ollama list >/dev/null 2>&1; then
  echo "Starting Ollama daemon..."
  nohup ollama serve >/tmp/ollama-rightclickwriter.log 2>&1 &
  sleep 2
fi

echo "Checking cloud model visibility: ${MODEL_CLOUD}"
if ! ollama show "${MODEL_CLOUD}" >/dev/null 2>&1; then
  echo "Cloud model metadata not locally visible yet. This is okay if your account resolves it at runtime."
fi

echo "Ensuring local fallback model exists: ${MODEL_LOCAL}"
ollama pull "${MODEL_LOCAL}"

echo "Bootstrap complete."
