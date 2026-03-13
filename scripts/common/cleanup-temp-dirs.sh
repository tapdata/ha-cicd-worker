#!/usr/bin/env bash
# Cleanup old temporary directories while keeping the latest N entries.
# Required env vars: DIR_PATTERN
# Optional env vars: BASE_DIR, KEEP_COUNT
set -euo pipefail

BASE_DIR="${BASE_DIR:-/tmp}"
DIR_PATTERN="${DIR_PATTERN:-}"
KEEP_COUNT="${KEEP_COUNT:-5}"

echo "=== Cleaning Temp Directories ==="

if [[ -z "${DIR_PATTERN}" ]]; then
  echo "::error::DIR_PATTERN is not set or empty"
  exit 1
fi

if ! [[ "${KEEP_COUNT}" =~ ^[0-9]+$ ]]; then
  echo "::error::KEEP_COUNT must be a non-negative integer, got: ${KEEP_COUNT}"
  exit 1
fi

mapfile -t MATCHED_DIRS < <(
  find "${BASE_DIR}" -maxdepth 1 -mindepth 1 -type d -name "${DIR_PATTERN}" -printf '%T@ %p\n' \
    | sort -nr \
    | awk '{print $2}'
)

echo "Base directory: ${BASE_DIR}"
echo "Pattern: ${DIR_PATTERN}"
echo "Keep count: ${KEEP_COUNT}"
echo "Matched directories: ${#MATCHED_DIRS[@]}"

if [[ ${#MATCHED_DIRS[@]} -le ${KEEP_COUNT} ]]; then
  echo "Nothing to clean. Keeping all matched directories."
  exit 0
fi

echo "Keeping latest ${KEEP_COUNT} directories:"
for dir in "${MATCHED_DIRS[@]:0:${KEEP_COUNT}}"; do
  echo "  - ${dir}"
done

echo "Removing old directories:"
for dir in "${MATCHED_DIRS[@]:${KEEP_COUNT}}"; do
  echo "  - ${dir}"
  rm -rf "${dir}"
done

echo "=== Cleanup Complete ==="