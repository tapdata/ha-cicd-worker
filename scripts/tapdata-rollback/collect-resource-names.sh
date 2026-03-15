#!/usr/bin/env bash
# Collect task names and API names from export directory for rollback
# Scans {PROJECT}_tapdata_export/Task for *MigrateTask.json and *SyncTask.json
# Scans {PROJECT}_tapdata_export/API for *Module.json
# Required env vars: PROJECT
# Output: task_names, api_names (via GITHUB_OUTPUT)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../.."
EXPORT_DIR="${REPO_ROOT}/${PROJECT}_tapdata_export"

echo "=== Collecting Resource Names ==="

if [[ ! -d "${EXPORT_DIR}" ]]; then
  echo "::error::Export directory not found: ${EXPORT_DIR}"
  exit 1
fi

# ── Collect task names ──
TASK_DIR="${EXPORT_DIR}/Task"
TASK_NAMES=""

if [[ -d "${TASK_DIR}" ]]; then
  while IFS= read -r file; do
    NAME=$(jq -r '.name' "${file}")
    if [[ -n "${NAME}" && "${NAME}" != "null" ]]; then
      if [[ -n "${TASK_NAMES}" ]]; then
        TASK_NAMES="${TASK_NAMES},${NAME}"
      else
        TASK_NAMES="${NAME}"
      fi
    fi
  done < <(find "${TASK_DIR}" -maxdepth 1 -type f \( -name '*MigrateTask.json' -o -name '*SyncTask.json' \) | sort)
fi

if [[ -z "${TASK_NAMES}" ]]; then
  echo "::warning::No tasks found in ${TASK_DIR}"
else
  echo "Task names: ${TASK_NAMES}"
fi

# ── Collect API names ──
API_DIR="${EXPORT_DIR}/API"
API_NAMES=""

if [[ -d "${API_DIR}" ]]; then
  while IFS= read -r file; do
    NAME=$(jq -r '.name' "${file}")
    if [[ -n "${NAME}" && "${NAME}" != "null" ]]; then
      if [[ -n "${API_NAMES}" ]]; then
        API_NAMES="${API_NAMES},${NAME}"
      else
        API_NAMES="${NAME}"
      fi
    fi
  done < <(find "${API_DIR}" -maxdepth 1 -type f -name '*Module.json' | sort)
fi

if [[ -z "${API_NAMES}" ]]; then
  echo "::warning::No APIs found in ${API_DIR}"
else
  echo "API names: ${API_NAMES}"
fi

# Set outputs
echo "task_names=${TASK_NAMES}" >> "${GITHUB_OUTPUT}"
echo "api_names=${API_NAMES}" >> "${GITHUB_OUTPUT}"

echo "=== Resource Names Collected ==="

