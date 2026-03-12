#!/usr/bin/env bash
# Compress all files in export directory into a tar archive
# Usage: compress-files.sh
# Required env vars: DEPLOY_DIR, PROJECT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."
EXPORT_DIR="${REPO_ROOT}/${PROJECT}_tapdata_export"

echo "=== Compressing Export Files ==="

# Validate inputs
if [[ -z "${DEPLOY_DIR:-}" ]]; then
  echo "::error::DEPLOY_DIR is not set or empty"
  exit 1
fi

if [[ -z "${PROJECT:-}" ]]; then
  echo "::error::PROJECT is not set or empty"
  exit 1
fi

if [[ ! -d "${EXPORT_DIR}" ]]; then
  echo "::error::Export directory not found: ${EXPORT_DIR}"
  exit 1
fi

# Create deploy directory
mkdir -p "${DEPLOY_DIR}"

# Collect all files in export directory
FILES=()
while IFS= read -r f; do
  FILES+=("${f}")
done < <(find "${EXPORT_DIR}" -type f)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "::warning::No files found in ${EXPORT_DIR}"
  exit 0
fi

# Create tar archive
ARCHIVE="${DEPLOY_DIR}/export.tar"
tar -cf "${ARCHIVE}" -C "${EXPORT_DIR}" "${FILES[@]/#${EXPORT_DIR}\//}"

echo "Archive created: ${ARCHIVE}"
echo "Files included: ${#FILES[@]}"
for f in "${FILES[@]}"; do
  echo "  - $(basename "${f}")"
done
echo "=== Compression Complete ==="

