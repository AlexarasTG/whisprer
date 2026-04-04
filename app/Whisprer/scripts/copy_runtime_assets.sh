#!/bin/sh

set -eu

REPO_ROOT="$(cd "${PROJECT_DIR}/../.." && pwd)"
CLI_SOURCE="${REPO_ROOT}/tools/whisper-cli"
MODEL_SOURCE="${REPO_ROOT}/models/ggml-base.en.bin"
RUNTIME_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/WhisperRuntime"

if [ ! -f "${CLI_SOURCE}" ] || [ ! -f "${MODEL_SOURCE}" ]; then
  echo "Whisprer: local runtime assets not found, skipping bundle copy."
  echo "Expected:"
  echo "  ${CLI_SOURCE}"
  echo "  ${MODEL_SOURCE}"
  exit 0
fi

mkdir -p "${RUNTIME_DIR}"
cp -f "${CLI_SOURCE}" "${RUNTIME_DIR}/whisper-cli"
cp -f "${MODEL_SOURCE}" "${RUNTIME_DIR}/ggml-base.en.bin"
chmod +x "${RUNTIME_DIR}/whisper-cli"

echo "Whisprer: bundled local runtime assets into ${RUNTIME_DIR}"
