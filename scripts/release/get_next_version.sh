#!/bin/sh

set -eu

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 VERSION_BUMP PROJECT_FILE" >&2
  exit 1
fi

VERSION_BUMP="$1"
PROJECT_FILE="$2"

CURRENT_VERSION="$(sed -n 's/.*MARKETING_VERSION = \([0-9][0-9.]*\);/\1/p' "${PROJECT_FILE}" | head -n 1)"

if [ -z "${CURRENT_VERSION}" ]; then
  echo "Failed to determine MARKETING_VERSION from ${PROJECT_FILE}" >&2
  exit 1
fi

IFS=. read -r MAJOR MINOR PATCH <<EOF
${CURRENT_VERSION}
EOF

PATCH="${PATCH:-0}"

case "${VERSION_BUMP}" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Unsupported version bump: ${VERSION_BUMP}" >&2
    exit 1
    ;;
esac

printf '%s.%s.%s\n' "${MAJOR}" "${MINOR}" "${PATCH}"
