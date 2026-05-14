#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 PROJECT_FILE" >&2
  exit 1
fi

PROJECT_FILE="$1"

CURRENT_VERSION="$(sed -n 's/.*MARKETING_VERSION = \([0-9][0-9.]*\);/\1/p' "${PROJECT_FILE}" | head -n 1)"

if [ -z "${CURRENT_VERSION}" ]; then
  echo "Failed to determine MARKETING_VERSION from ${PROJECT_FILE}" >&2
  exit 1
fi

printf '%s\n' "${CURRENT_VERSION}"
