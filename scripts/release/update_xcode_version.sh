#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 VERSION PROJECT_FILE" >&2
  exit 1
fi

VERSION="$1"
PROJECT_FILE="$2"

perl -0pi -e "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${VERSION};/g; s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${VERSION};/g" "${PROJECT_FILE}"
