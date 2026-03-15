#!/usr/bin/env bash
# Clean TapData resources (tasks, APIs) for rollback
# 1. Batch delete tasks via DELETE /api/Task/batchDelete
# 2. Delete each API via DELETE /api/Modules/{id}
# Required env vars: TAPDATA_TOKEN, TARGET_ENV
# Optional env vars: TASK_IDS (comma separated), API_IDS (comma separated)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONF="${SCRIPT_DIR}/../../conf/env.conf"

echo "=== Cleaning Resources ==="

# Read base URL from env.conf
BASE_URL=$(grep "^${TARGET_ENV}=" "${ENV_CONF}" | cut -d'=' -f2-)
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::No base URL configured for environment '${TARGET_ENV}' in env.conf"
  exit 1
fi

API_BASE="${BASE_URL%/}/api"

# ── Step 1: Batch delete tasks ──
if [[ -n "${TASK_IDS:-}" ]]; then
  echo "Deleting tasks..."

  IFS=',' read -ra TID_ARRAY <<< "${TASK_IDS}"
  TASK_IDS_PARAMS=""
  for tid in "${TID_ARRAY[@]}"; do
    tid=$(echo "${tid}" | xargs)
    if [[ -z "${tid}" ]]; then
      continue
    fi
    if [[ -n "${TASK_IDS_PARAMS}" ]]; then
      TASK_IDS_PARAMS="${TASK_IDS_PARAMS}&taskIds=${tid}"
    else
      TASK_IDS_PARAMS="taskIds=${tid}"
    fi
  done

  if [[ -n "${TASK_IDS_PARAMS}" ]]; then
    DELETE_TASK_URL="${API_BASE}/Task/batchDelete?${TASK_IDS_PARAMS}&access_token=${TAPDATA_TOKEN}"

    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${DELETE_TASK_URL}")
    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | sed '$d')

    if [[ "${HTTP_CODE}" -ne 200 ]]; then
      echo "::error::Failed to batch delete tasks: HTTP ${HTTP_CODE} - ${BODY}"
      exit 1
    fi

    echo "Tasks deleted successfully (${#TID_ARRAY[@]} task(s))"
  fi
else
  echo "No task IDs provided, skipping task deletion"
fi

# ── Step 2: Delete APIs one by one ──
if [[ -n "${API_IDS:-}" ]]; then
  echo "Deleting APIs..."

  IFS=',' read -ra AID_ARRAY <<< "${API_IDS}"
  for aid in "${AID_ARRAY[@]}"; do
    aid=$(echo "${aid}" | xargs)
    if [[ -z "${aid}" ]]; then
      continue
    fi

    echo "  Deleting API: ${aid}..."
    DELETE_API_URL="${API_BASE}/Modules/${aid}?access_token=${TAPDATA_TOKEN}"

    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "${DELETE_API_URL}")
    HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
    BODY=$(echo "${RESPONSE}" | sed '$d')

    if [[ "${HTTP_CODE}" -ne 200 ]]; then
      echo "::error::Failed to delete API '${aid}': HTTP ${HTTP_CODE} - ${BODY}"
      exit 1
    fi

    echo "  API '${aid}' deleted successfully"
  done

  echo "All APIs deleted successfully (${#AID_ARRAY[@]} API(s))"
else
  echo "No API IDs provided, skipping API deletion"
fi

echo "=== Clean Resources Complete ==="
