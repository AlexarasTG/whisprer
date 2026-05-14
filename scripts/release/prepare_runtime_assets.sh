#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 DEST_DIR WORK_DIR" >&2
  exit 1
fi

DEST_DIR="$1"
WORK_DIR="$2"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

# Keep the release inputs pinned in tracked files instead of ad hoc workflow YAML.
set -a
. "${SCRIPT_DIR}/release.env"
. "${SCRIPT_DIR}/runtime.env"
set +a

WHISPER_CPP_DIR="${WORK_DIR}/whisper.cpp"
OPENAI_WHISPER_DIR="${WORK_DIR}/openai-whisper"
MODEL_DOWNLOAD_PATH="${WORK_DIR}/${OPENAI_WHISPER_MODEL_NAME}.pt"
MODEL_OUTPUT_DIR="${WORK_DIR}/ggml-model"
PYTHON_VENV_DIR="${WORK_DIR}/venv"

mkdir -p "${DEST_DIR}" "${WORK_DIR}"
rm -rf "${WHISPER_CPP_DIR}" "${OPENAI_WHISPER_DIR}" "${MODEL_OUTPUT_DIR}" "${PYTHON_VENV_DIR}"

git clone --branch "${WHISPER_CPP_REF}" --depth 1 "${WHISPER_CPP_REPOSITORY}" "${WHISPER_CPP_DIR}"
git clone --branch "${OPENAI_WHISPER_REF}" --depth 1 "${OPENAI_WHISPER_REPOSITORY}" "${OPENAI_WHISPER_DIR}"

curl --fail --location --silent --show-error "${OPENAI_WHISPER_MODEL_URL}" --output "${MODEL_DOWNLOAD_PATH}"
echo "${OPENAI_WHISPER_MODEL_SHA256}  ${MODEL_DOWNLOAD_PATH}" | shasum -a 256 -c -

python3 -m venv "${PYTHON_VENV_DIR}"
"${PYTHON_VENV_DIR}/bin/pip" install --upgrade pip
"${PYTHON_VENV_DIR}/bin/pip" install numpy torch

cmake -S "${WHISPER_CPP_DIR}" -B "${WHISPER_CPP_DIR}/build"
cmake --build "${WHISPER_CPP_DIR}/build" --config Release --target whisper-cli

mkdir -p "${MODEL_OUTPUT_DIR}"
"${PYTHON_VENV_DIR}/bin/python" \
  "${WHISPER_CPP_DIR}/models/convert-pt-to-ggml.py" \
  "${MODEL_DOWNLOAD_PATH}" \
  "${OPENAI_WHISPER_DIR}" \
  "${MODEL_OUTPUT_DIR}"

WHISPER_CLI_CANDIDATE="${WHISPER_CPP_DIR}/build/bin/whisper-cli"
if [ ! -x "${WHISPER_CLI_CANDIDATE}" ]; then
  WHISPER_CLI_CANDIDATE="${WHISPER_CPP_DIR}/build/bin/Release/whisper-cli"
fi

if [ ! -x "${WHISPER_CLI_CANDIDATE}" ]; then
  echo "Failed to locate built whisper-cli executable." >&2
  exit 1
fi

if [ ! -f "${MODEL_OUTPUT_DIR}/ggml-model.bin" ]; then
  echo "Failed to locate converted ggml model." >&2
  exit 1
fi

cp -f "${WHISPER_CLI_CANDIDATE}" "${DEST_DIR}/whisper-cli"
cp -f "${MODEL_OUTPUT_DIR}/ggml-model.bin" "${DEST_DIR}/ggml-base.en.bin"
chmod +x "${DEST_DIR}/whisper-cli"

(
  cd "${DEST_DIR}"
  shasum -a 256 whisper-cli ggml-base.en.bin > SHA256SUMS
)
