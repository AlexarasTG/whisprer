#!/bin/sh

set -eu

REPO_ROOT="$(cd "${PROJECT_DIR}/../.." && pwd)"
CLI_SOURCE="${WHISPRER_RUNTIME_CLI_PATH:-${REPO_ROOT}/tools/whisper-cli}"
MODEL_SOURCE="${WHISPRER_RUNTIME_MODEL_PATH:-${REPO_ROOT}/models/ggml-base.en.bin}"
RUNTIME_DIR="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/WhisperRuntime"
REQUIRE_RUNTIME_ASSETS="${WHISPRER_REQUIRE_RUNTIME_ASSETS:-NO}"

if [ ! -f "${CLI_SOURCE}" ] || [ ! -f "${MODEL_SOURCE}" ]; then
  echo "Whisprer: runtime assets not found."
  echo "Expected:"
  echo "  ${CLI_SOURCE}"
  echo "  ${MODEL_SOURCE}"

  if [ "${REQUIRE_RUNTIME_ASSETS}" = "YES" ]; then
    echo "Whisprer: release build requires bundled runtime assets."
    exit 1
  fi

  exit 0
fi

mkdir -p "${RUNTIME_DIR}"
cp -f "${CLI_SOURCE}" "${RUNTIME_DIR}/whisper-cli"
cp -f "${MODEL_SOURCE}" "${RUNTIME_DIR}/ggml-base.en.bin"
chmod +x "${RUNTIME_DIR}/whisper-cli"

echo "Whisprer: bundled runtime assets into ${RUNTIME_DIR}"
