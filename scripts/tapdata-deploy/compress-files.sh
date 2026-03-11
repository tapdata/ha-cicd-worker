#!/usr/bin/env bash
# Compress JSON configuration files into a tar archive
# Usage: compress-files.sh <resource_type>
# resource_type: connections | tasks | apis
# Required env vars: DEPLOY_DIR, PROJECT
set -euo pipefail

RESOURCE_TYPE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."
EXPORT_DIR="${REPO_ROOT}/${PROJECT}_tapdata_export"

echo "=== Compressing ${RESOURCE_TYPE} Files ==="

# Validate inputs
if [[ -z "${RESOURCE_TYPE}" ]]; then
  echo "::error::Usage: compress-files.sh <connections|tasks|apis>"
  exit 1
fi

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

# Collect files based on resource type
FILES=()
case "${RESOURCE_TYPE}" in
  connections)
    while IFS= read -r f; do
      FILES+=("${f}")
    done < <(find "${EXPORT_DIR}" -name "*_connection.json" -type f)
    while IFS= read -r f; do
      FILES+=("${f}")
    done < <(find "${EXPORT_DIR}" -name "*_connection_metadata.json" -type f)
    if [[ -f "${EXPORT_DIR}/vault.json" ]]; then
      FILES+=("${EXPORT_DIR}/vault.json")
    fi
    ;;
  tasks)
    while IFS= read -r f; do
      FILES+=("${f}")
    done < <(find "${EXPORT_DIR}" -name "*_task.json" -type f)
    ;;
  apis)
    while IFS= read -r f; do
      FILES+=("${f}")
    done < <(find "${EXPORT_DIR}" -name "*_api.json" -type f)
    ;;
  *)
    echo "::error::Unknown resource type: ${RESOURCE_TYPE}. Expected: connections|tasks|apis"
    exit 1
    ;;
esac

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "::warning::No ${RESOURCE_TYPE} files found in ${EXPORT_DIR}"
  exit 0
fi

# Create tar archive
ARCHIVE="${DEPLOY_DIR}/${RESOURCE_TYPE}.tar"
tar -cf "${ARCHIVE}" -C "${EXPORT_DIR}" "${FILES[@]/#${EXPORT_DIR}\//}"

echo "Archive created: ${ARCHIVE}"
echo "Files included: ${#FILES[@]}"
for f in "${FILES[@]}"; do
  echo "  - $(basename "${f}")"
done
echo "=== Compression Complete ==="
