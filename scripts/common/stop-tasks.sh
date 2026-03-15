#!/usr/bin/env bash
# Stop tasks via TapData API
# 1. Query task IDs via GET /api/Task
#    - If TASK_NAMES is set: query by specified task names (rebuild mode)
#    - If TASK_NAMES is empty/unset: query all tasks (rollback mode)
# 2. Batch stop tasks via PUT /api/Task/batchStop
# Required env vars: TAPDATA_TOKEN, TARGET_ENV
# Optional env vars: TASK_NAMES (comma separated, if empty stops all tasks)
# Output: stopped_task_ids (comma separated, via GITHUB_OUTPUT)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_CONF="${SCRIPT_DIR}/../../conf/env.conf"

echo "=== Stopping Tasks ==="

# Read base URL from env.conf
BASE_URL=$(grep "^${TARGET_ENV}=" "${ENV_CONF}" | cut -d'=' -f2-)
if [[ -z "${BASE_URL}" ]]; then
  echo "::error::No base URL configured for environment '${TARGET_ENV}' in env.conf"
  exit 1
fi

API_BASE="${BASE_URL%/}/api"

# ── Step 1: Build filter based on whether TASK_NAMES is provided ──
if [[ -n "${TASK_NAMES:-}" ]]; then
  # Rebuild mode: stop specified tasks
  echo "Mode: stop specified tasks"

  IFS=',' read -ra RAW_TASKS <<< "${TASK_NAMES}"
  TRIMMED_TASKS=()
  for task in "${RAW_TASKS[@]}"; do
    trimmed=$(echo "${task}" | xargs)
    if [[ -n "${trimmed}" ]]; then
      TRIMMED_TASKS+=("${trimmed}")
    fi
  done

  if [[ ${#TRIMMED_TASKS[@]} -eq 0 ]]; then
    echo "::error::No valid task names provided"
    exit 1
  fi

  # Build $inq JSON array
  INQ_ARRAY=$(printf '%s\n' "${TRIMMED_TASKS[@]}" | jq -R . | jq -s .)

  # Build filter with name condition
  FILTER=$(jq -n -c --argjson inq "${INQ_ARRAY}" '{
    "fields": {"id": true, "name": true},
    "where": {"name": {"$inq": $inq}}
  }')

  echo "Querying task IDs for: ${TRIMMED_TASKS[*]}"
else
  # Rollback mode: stop all tasks
  echo "Mode: stop all tasks"

  FILTER=$(jq -n -c '{
    "fields": {"id": true, "name": true}
  }')

  echo "Querying all task IDs..."
fi

# URL-encode the filter
ENCODED_FILTER=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "${FILTER}")

# ── Step 2: Call GET /api/Task to get task IDs ──
QUERY_URL="${API_BASE}/Task?access_token=${TAPDATA_TOKEN}&filter=${ENCODED_FILTER}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${QUERY_URL}")
HTTP_CODE=$(echo "${RESPONSE}" | tail -n1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [[ "${HTTP_CODE}" -ne 200 ]]; then
  echo "::error::Failed to query tasks: HTTP ${HTTP_CODE} - ${BODY}"
  exit 1
fi

# Extract task id-name pairs
TASK_COUNT=$(echo "${BODY}" | jq '.data.items | length')

if [[ "${TASK_COUNT}" -eq 0 ]]; then
  echo "::error::No tasks found"
  exit 1
fi

echo "Found ${TASK_COUNT} task(s):"
echo "${BODY}" | jq -r '.data.items[] | "  - \(.name) (id: \(.id))"'

# In rebuild mode, verify all requested tasks were found
if [[ -n "${TASK_NAMES:-}" ]]; then
  for task in "${TRIMMED_TASKS[@]}"; do
    FOUND=$(echo "${BODY}" | jq -r --arg name "${task}" '.data.items[] | select(.name == $name) | .id')
    if [[ -z "${FOUND}" ]]; then
      echo "::error::Task '${task}' not found via API"
      exit 1
    fi
  done
fi

# ── Step 3: Batch stop tasks via PUT /api/Task/batchStop ──
# Build query string with multiple taskIds params
TASK_IDS_PARAMS=""
while IFS= read -r tid; do
  if [[ -n "${TASK_IDS_PARAMS}" ]]; then
    TASK_IDS_PARAMS="${TASK_IDS_PARAMS}&taskIds=${tid}"
  else
    TASK_IDS_PARAMS="taskIds=${tid}"
  fi
done < <(echo "${BODY}" | jq -r '.data.items[].id')

STOP_URL="${API_BASE}/Task/batchStop?${TASK_IDS_PARAMS}&access_token=${TAPDATA_TOKEN}"

echo "Batch stopping ${TASK_COUNT} task(s)..."

STOP_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "${STOP_URL}")
STOP_HTTP_CODE=$(echo "${STOP_RESPONSE}" | tail -n1)
STOP_BODY=$(echo "${STOP_RESPONSE}" | sed '$d')

if [[ "${STOP_HTTP_CODE}" -ne 200 ]]; then
  echo "::error::Failed to batch stop tasks: HTTP ${STOP_HTTP_CODE} - ${STOP_BODY}"
  exit 1
fi

# Output stopped task IDs
STOPPED_IDS=$(echo "${BODY}" | jq -r '[.data.items[].id] | join(",")')
echo "stopped_task_ids=${STOPPED_IDS}" >> "${GITHUB_OUTPUT}"

echo "All tasks stopped successfully"
echo "=== Stop Tasks Complete ==="
